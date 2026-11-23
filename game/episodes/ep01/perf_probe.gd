class_name PerfProbe
extends Node
## Sonda de desempenho (RB-04): mede tempos de quadro reais em execucao com renderizacao.
## Uso: RotaBrava.console.exe --perf-probe [--perf-warmup=4] [--perf-seconds=15] --ep01-demo (a chegada e o cais).
## Imprime uma linha `[RB] perf {json}` e encerra. Nao substitui medicao em aparelho nem no editor.

var warmup_seconds: float = 4.0
var sample_seconds: float = 15.0

var _elapsed: float = 0.0
var _last_us: int = 0
var _frames: Array[float] = []
var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _draws: Array[float] = []
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--perf-warmup="):
			warmup_seconds = float(arg.trim_prefix("--perf-warmup="))
		elif arg.begins_with("--perf-seconds="):
			sample_seconds = float(arg.trim_prefix("--perf-seconds="))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_usec()
	var dt_ms := float(now - _last_us) / 1000.0
	_last_us = now
	_elapsed += dt_ms / 1000.0
	if _elapsed < warmup_seconds:
		return
	_frames.append(dt_ms)
	var rid := get_viewport().get_viewport_rid()
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _elapsed >= warmup_seconds + sample_seconds:
		_finish()


static func percentile(values: Array[float], p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var idx := clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[idx]


static func mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += v
	return s / values.size()


func report() -> Dictionary:
	var win := get_window()
	return {
		"frames": _frames.size(),
		"seconds": snappedf(sample_seconds, 0.1),
		"frame_ms": {"mean": snappedf(mean(_frames), 0.01), "p50": snappedf(percentile(_frames, 0.5), 0.01),
			"p95": snappedf(percentile(_frames, 0.95), 0.01), "p99": snappedf(percentile(_frames, 0.99), 0.01),
			"max": snappedf(_frames.max() if not _frames.is_empty() else 0.0, 0.01)},
		"gpu_ms": {"mean": snappedf(mean(_gpu), 0.01), "p95": snappedf(percentile(_gpu, 0.95), 0.01)},
		"cpu_render_ms": {"mean": snappedf(mean(_cpu), 0.01), "p95": snappedf(percentile(_cpu, 0.95), 0.01)},
		"draw_calls": {"mean": snappedf(mean(_draws), 0.1), "max": snappedf(_draws.max() if not _draws.is_empty() else 0.0, 0.1)},
		"objects_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"static_mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"window": [win.size.x, win.size.y],
		"vsync": DisplayServer.window_get_vsync_mode(),
		"renderer": String(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"adapter": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name() + " " + OS.get_version(),
		"engine": Engine.get_version_info().get("string", ""),
	}


func _finish() -> void:
	_done = true
	print("[RB] perf %s" % JSON.stringify(report()))
	get_tree().quit(0)
