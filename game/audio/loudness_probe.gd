class_name LoudnessProbe extends RefCounted
## G22b: mede a loudness REAL que sai da Godot. Poe um AudioEffectCapture no fim de um bus, junta os quadros
## mixados pelo AudioServer (funciona no driver Dummy do --headless, em tempo real) e calcula LUFS integrado
## (ITU-R BS.1770: filtro K, blocos de 400 ms com passo de 100 ms, bloqueio absoluto -70 e relativo -10).
## Uso em teste e em captura (tests/capture_g22b.gd). Nao serve para tocar: so medir.


static func attach(bus: StringName) -> AudioEffectCapture:
	var idx := AudioServer.get_bus_index(bus)
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 12.0
	AudioServer.add_bus_effect(idx, cap)
	return cap


static func detach(bus: StringName, cap: AudioEffectCapture) -> void:
	var idx := AudioServer.get_bus_index(bus)
	for i in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
		if AudioServer.get_bus_effect(idx, i) == cap:
			AudioServer.remove_bus_effect(idx, i)


## Esvazia o que ja estava no buffer (antes do inicio da medida).
static func drain(cap: AudioEffectCapture) -> void:
	cap.get_buffer(cap.get_frames_available())


## Junta `seconds` de audio (tempo real) de varias capturas ao mesmo tempo. Devolve um PackedVector2Array por captura.
static func collect(tree: SceneTree, caps: Array, seconds: float) -> Array:
	var out: Array = []
	for c in caps:
		out.append(PackedVector2Array())
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await tree.process_frame
		for i in caps.size():
			var c: AudioEffectCapture = caps[i]
			out[i].append_array(c.get_buffer(c.get_frames_available()))
	for i in caps.size():
		var c: AudioEffectCapture = caps[i]
		out[i].append_array(c.get_buffer(c.get_frames_available()))
	return out


static func _biquad(x: PackedFloat32Array, b: Array, a: Array) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := float(x[i])
		var o: float = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = o
		y[i] = o
	return y


## Filtro K (pre-filtro de prateleira + passa-altas RLB) para a taxa `sr` (mesma formulacao do pyloudnorm).
static func k_weight(x: PackedFloat32Array, sr: float) -> PackedFloat32Array:
	var k := tan(PI * 1681.974450955533 / sr)
	var q := 0.7071752369554196
	var vh := pow(10.0, 3.999843853973347 / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var a0 := 1.0 + k / q + k * k
	var s := _biquad(x, [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0],
		[1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])
	k = tan(PI * 38.13547087602444 / sr)
	q = 0.5003270373238773
	a0 = 1.0 + k / q + k * k
	return _biquad(s, [1.0, -2.0, 1.0], [1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])


## LUFS integrado de um trecho estereo. -99 se tudo abaixo do bloqueio.
static func lufs(frames: PackedVector2Array, sr: float = AudioServer.get_mix_rate()) -> float:
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	l.resize(frames.size())
	r.resize(frames.size())
	for i in frames.size():
		l[i] = frames[i].x
		r[i] = frames[i].y
	l = k_weight(l, sr)
	r = k_weight(r, sr)
	var n := int(0.4 * sr)
	var h := int(0.1 * sr)
	var ms: Array[float] = []
	var i0 := 0
	while i0 + n <= l.size():
		var acc := 0.0
		for i in range(i0, i0 + n):
			acc += l[i] * l[i] + r[i] * r[i]
		ms.append(acc / n)
		i0 += h
	var gated: Array[float] = []
	for m in ms:
		if -0.691 + 10.0 * log(m + 1e-12) / log(10.0) > -70.0:
			gated.append(m)
	if gated.is_empty():
		return -99.0
	var rel := -0.691 + 10.0 * log(_mean(gated)) / log(10.0) - 10.0
	var g2: Array[float] = []
	for m in gated:
		if -0.691 + 10.0 * log(m + 1e-12) / log(10.0) > rel:
			g2.append(m)
	return -0.691 + 10.0 * log(_mean(g2)) / log(10.0)


static func _mean(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


static func peak_dbfs(frames: PackedVector2Array) -> float:
	var m := 0.0
	for f in frames:
		m = maxf(m, maxf(absf(f.x), absf(f.y)))
	return linear_to_db(maxf(m, 1e-6))


static func rms_dbfs(frames: PackedVector2Array) -> float:
	var s := 0.0
	for f in frames:
		s += (f.x * f.x + f.y * f.y) * 0.5
	return linear_to_db(sqrt(s / maxf(frames.size(), 1)) + 1e-9)


## WAV PCM 16 bits estereo.
static func write_wav(path: String, frames: PackedVector2Array, sr: int = int(AudioServer.get_mix_rate())) -> void:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for i in frames.size():
		data.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(sr)
	f.store_32(sr * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
