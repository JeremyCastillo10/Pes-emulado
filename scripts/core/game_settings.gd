extends Node
## Ajustes globales persistentes: calidad gráfica, cámara, controles táctiles, vibración.
## Se guardan en user://settings.cfg.

signal quality_changed(level: int)
signal settings_changed

enum Quality { LOW, MEDIUM, HIGH }
enum CameraMode { BROADCAST, WIDE, CLOSE, BEHIND }
enum TimeOfDay { DAY, SUNSET, NIGHT }

const SAVE_PATH := "user://settings.cfg"
const QUALITY_KEYS := ["quality_low", "quality_medium", "quality_high"]
const CAMERA_KEYS := ["cam_broadcast", "cam_wide", "cam_close", "cam_behind"]
const TIME_KEYS := ["time_day", "time_sunset", "time_night"]

var quality: int = Quality.MEDIUM
var auto_quality: bool = true
var camera_mode: int = CameraMode.BROADCAST
var time_of_day: int = TimeOfDay.DAY
var wet_pitch: bool = false
var vibration: bool = true
var show_fps: bool = true
var controls_opacity: float = 0.55
var controls_scale: float = 1.0
## Desplazamientos personalizados de cada botón táctil (nombre -> Vector2 en px de referencia).
var button_offsets: Dictionary = {}


func _ready() -> void:
	var first_run := not FileAccess.file_exists(SAVE_PATH)
	load_settings()
	if first_run or auto_quality:
		quality = detect_quality()
	apply_quality.call_deferred()


## Elige un nivel de calidad según la memoria y los núcleos del dispositivo.
func detect_quality() -> int:
	if not OS.has_feature("mobile"):
		return Quality.HIGH
	var mem: Dictionary = OS.get_memory_info()
	var physical: int = int(mem.get("physical", -1))
	var cores: int = OS.get_processor_count()
	var gb := float(physical) / (1024.0 * 1024.0 * 1024.0)
	if physical > 0 and gb < 3.2:
		return Quality.LOW
	if cores <= 4:
		return Quality.LOW
	if physical > 0 and gb < 5.5:
		return Quality.MEDIUM
	return Quality.HIGH


func set_quality(level: int, is_auto: bool = false) -> void:
	auto_quality = is_auto
	quality = detect_quality() if is_auto else clampi(level, 0, 2)
	apply_quality()
	save_settings()


func apply_quality() -> void:
	var vp := get_viewport()
	match quality:
		Quality.LOW:
			Engine.max_fps = 30
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
		Quality.MEDIUM:
			Engine.max_fps = 60
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
		Quality.HIGH:
			Engine.max_fps = 60
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	quality_changed.emit(quality)


## Cantidad de público según la calidad (LOD de multitud).
func crowd_density() -> float:
	return [0.3, 0.6, 1.0][quality]


func shadows_enabled() -> bool:
	return quality == Quality.HIGH


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "auto_quality", auto_quality)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("game", "camera_mode", camera_mode)
	cfg.set_value("game", "time_of_day", time_of_day)
	cfg.set_value("game", "wet_pitch", wet_pitch)
	cfg.set_value("controls", "vibration", vibration)
	cfg.set_value("controls", "opacity", controls_opacity)
	cfg.set_value("controls", "scale", controls_scale)
	cfg.set_value("controls", "button_offsets", button_offsets)
	cfg.save(SAVE_PATH)
	settings_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = int(cfg.get_value("video", "quality", quality))
	auto_quality = bool(cfg.get_value("video", "auto_quality", auto_quality))
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	camera_mode = int(cfg.get_value("game", "camera_mode", camera_mode))
	time_of_day = int(cfg.get_value("game", "time_of_day", time_of_day))
	wet_pitch = bool(cfg.get_value("game", "wet_pitch", wet_pitch))
	vibration = bool(cfg.get_value("controls", "vibration", vibration))
	controls_opacity = float(cfg.get_value("controls", "opacity", controls_opacity))
	controls_scale = float(cfg.get_value("controls", "scale", controls_scale))
	button_offsets = cfg.get_value("controls", "button_offsets", {})
