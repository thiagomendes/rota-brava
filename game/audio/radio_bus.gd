class_name RadioBus extends RefCounted
## G20: bus "Radio" (walkie-talkie do Farol 7), criado POR CODIGO. Motivo: a Godot reescreve
## res://audio/default_bus_layout.tres ao rodar e o tools/test.sh restaura o arquivo, entao um bus salvo nele
## seria instavel. `ensure()` e idempotente; AudioDirector chama no _ready.
## O bus manda para "Voz" (send), entao o volume de voz das Opcoes (bus Voz) tambem controla o radio.
## Cadeia (provisoria; aceite perceptual pendente com Thiago). Mantenha em sincronia com CHAIN em tools/audio/radio_fx.py:
##   passa-altas 300 Hz (12 dB/oit) -> passa-baixas 3400 Hz (12 dB/oit) -> distorcao ATAN (suave) drive 0,2,
##   pos-ganho -1 dB -> compressor limiar -18 dB, 3:1, ataque 5 ms, liberacao 150 ms, ganho +2 dB.

const NAME := &"Radio"
const PARENT := &"Voz"
const HP_HZ := 300.0
const LP_HZ := 3400.0
const DRIVE := 0.2
const POST_GAIN_DB := -1.0
const COMP_THRESHOLD_DB := -18.0
const COMP_RATIO := 3.0
const COMP_ATTACK_US := 5000.0
const COMP_RELEASE_MS := 150.0
const COMP_GAIN_DB := 2.0


static func ensure() -> int:
	var idx := AudioServer.get_bus_index(NAME)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, NAME)
	AudioServer.set_bus_send(idx, PARENT)
	AudioServer.set_bus_volume_db(idx, 0.0)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = HP_HZ
	hp.db = AudioEffectFilter.FILTER_12DB
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = LP_HZ
	lp.db = AudioEffectFilter.FILTER_12DB
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_ATAN
	dist.drive = DRIVE
	dist.pre_gain = 0.0
	dist.post_gain = POST_GAIN_DB
	dist.keep_hf_hz = 16000.0
	var comp := AudioEffectCompressor.new()
	comp.threshold = COMP_THRESHOLD_DB
	comp.ratio = COMP_RATIO
	comp.attack_us = COMP_ATTACK_US
	comp.release_ms = COMP_RELEASE_MS
	comp.gain = COMP_GAIN_DB
	for e: AudioEffect in [hp, lp, dist, comp]:
		AudioServer.add_bus_effect(idx, e)
	return idx
