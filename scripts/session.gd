extends Node
## Persistent settings and story state. The save contains no microphone data.

signal changed
signal settings_changed

const SAVE_PATH := "user://bulong_save_v2.json"
const OLD_SAVE_PATH := "user://bulong_save_v1.json"
const SETTINGS_PATH := "user://bulong_settings_v1.json"
const SCHEMA_VERSION := 2
enum Route { UNDECIDED, KEEPER, RELEASE }
var route: int = Route.UNDECIDED
var seen_scares: Dictionary = {}
var branch_checkpoint: Dictionary = {}
var ending_records: Dictionary = {}
var pending_ending: String = ""
var migration_notice: bool = false
var qa_silent: bool = false
const MEMORIES := ["memory_photo", "memory_letter", "memory_tape"]
var flags: Dictionary = {}
var checkpoint: Dictionary = {}
var endings: Array = []
var play_seconds: float = 0.0
var catches: int = 0
var save_available: bool = true
var language: String = "en"
var quality: String = "medium"
var sensitivity: float = 0.12
var volume: float = 0.8
var brightness: float = 1.0
var reduced_motion: bool = false
var subtitles: bool = true
var touch_mode: bool = false
var mic_enabled: bool = false
var mic_threshold: float = 0.055
var active: bool = false
var persistence_enabled: bool = true

func _ready() -> void:
	if "--bake-world" in OS.get_cmdline_user_args() or "--qa-test" in OS.get_cmdline_user_args():
		persistence_enabled=false
	if OS.is_debug_build():
		qa_silent="--qa-silent" in OS.get_cmdline_user_args()
		if OS.has_feature("web"):
			qa_silent=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa')==='1'"))
		if qa_silent:AudioServer.set_bus_mute(0,true)
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if touch_mode:
		quality = "low"
	load_settings()
	if qa_silent:touch_mode=true
	load_save()

func _process(delta: float) -> void:
	if active:
		play_seconds += delta

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))

func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value
	changed.emit()

func act() -> int:
	if has_flag("title"):
		return 3
	if has_flag("rules"):
		return 2
	return 1

func memory_count() -> int:
	var count := 0
	for key in MEMORIES:
		if has_flag(key):
			count += 1
	return count

func chores_done() -> bool:
	return has_flag("shutter_kitchen") and has_flag("shutter_lola") and has_flag("shutter_family") and has_flag("portrait") and has_flag("clock_stopped") and has_flag("salt_line")

func new_game() -> void:
	flags.clear()
	route=Route.UNDECIDED
	seen_scares.clear()
	branch_checkpoint.clear()
	pending_ending=""
	play_seconds = 0.0
	catches = 0
	checkpoint = {"flags": {}, "spawn": "entry", "play_seconds": 0.0}
	save_game()
	changed.emit()

func make_checkpoint(spawn: String) -> void:
	checkpoint = {"flags": flags.duplicate(true), "spawn": spawn, "play_seconds": play_seconds,"route":route}
	save_game()
	changed.emit()

func restore_checkpoint(record_capture: bool = false) -> String:
	flags = checkpoint.get("flags", {}).duplicate(true)
	route=int(checkpoint.get("route",Route.UNDECIDED))
	pending_ending=""
	if record_capture:
		catches += 1
	changed.emit()
	return str(checkpoint.get("spawn", "entry"))

func complete(ending: String) -> void:
	if ending not in endings:
		endings.append(ending)
	ending_records[ending]={"memories":memory_count(),"seconds":play_seconds,"catches":catches}
	pending_ending=ending
	save_game()

func commit_route(value:int) -> bool:
	if route!=Route.UNDECIDED or value not in [Route.KEEPER,Route.RELEASE] or not has_flag("rules"):return false
	route=value
	make_checkpoint("sala")
	return true

func make_branch_checkpoint() -> void:
	make_checkpoint("sala")
	branch_checkpoint=checkpoint.duplicate(true)
	save_game()

func replay_branch() -> void:
	checkpoint=branch_checkpoint.duplicate(true)
	route=Route.UNDECIDED
	seen_scares.clear()
	pending_ending=""
	catches=0
	play_seconds=float(checkpoint.get("play_seconds",0))
	restore_checkpoint()
	save_game()

func can_continue() -> bool:
	return not checkpoint.is_empty() and not checkpoint.get("flags", {}).is_empty()

func save_game() -> void:
	_write_json(SAVE_PATH, {"version": SCHEMA_VERSION, "checkpoint": checkpoint, "branch":branch_checkpoint,"scares":seen_scares,"records":ending_records,"pending":pending_ending,"endings": endings, "play_seconds": play_seconds, "catches": catches})

func load_save() -> void:
	var data := _read_json(SAVE_PATH)
	if not valid_save(data):
		data=migrate_v1(_read_json(OLD_SAVE_PATH))
		if data.is_empty():return
		migration_notice=true
	if data.get("checkpoint") is Dictionary:
		checkpoint = data["checkpoint"]
	if data.get("endings") is Array:
		endings = data["endings"].filter(func(x): return x in ["seal", "break"])
	play_seconds = maxf(0.0, float(data.get("play_seconds", 0.0)))
	catches = maxi(0, int(data.get("catches", 0)))
	route=int(checkpoint.get("route",0))
	branch_checkpoint=data.get("branch",{}).duplicate(true)
	seen_scares=data.get("scares",{}).duplicate(true)
	ending_records=data.get("records",{}).duplicate(true)
	pending_ending=str(data.get("pending",""))
	if migration_notice:save_game()

static func migrate_v1(data:Dictionary) -> Dictionary:
	if data.get("version")!=1 or not data.get("checkpoint") is Dictionary:return {}
	if not data.get("endings",[]) is Array:return {}
	var old=data.checkpoint.get("flags",{})
	if not old is Dictionary:return {}
	var kept:Dictionary={}
	for key in ["arrival","fuse","rules"]+MEMORIES:
		if old.get(key) is bool and old.get(key,false):kept[key]=true
	var cp:={"flags":kept,"spawn":"sala","route":0,"play_seconds":0.0}
	return {"version":2,"checkpoint":cp,"branch":cp.duplicate(true),"endings":data.get("endings",[]),"play_seconds":0,"catches":0,"scares":{},"records":{},"pending":""}

static func valid_save(data: Dictionary) -> bool:
	if data.get("version") != SCHEMA_VERSION:
		return false
	var cp = data.get("checkpoint")
	if not cp is Dictionary or not cp.get("flags") is Dictionary:
		return false
	if cp.get("spawn") not in ["entry", "sala", "final","store","upper","crawl"]:
		return false
	# JSON represents numbers as floats, while Array.has uses strict Variant types.
	var saved_route=cp.get("route",0)
	if not (saved_route is int or saved_route is float):return false
	if float(saved_route)!=int(saved_route) or int(saved_route) not in [0,1,2]:return false
	if not (cp.get("play_seconds",0) is float or cp.get("play_seconds",0) is int):return false
	if not data.get("branch",{}) is Dictionary or not data.get("scares",{}) is Dictionary or not data.get("records",{}) is Dictionary:return false
	if data.get("pending","") not in ["","seal","break"]:return false
	for key in cp.flags:
		if not key is String or not cp.flags[key] is bool:
			return false
	var branch:Dictionary=data.get("branch",{})
	if not branch.is_empty():
		if not branch.get("flags") is Dictionary or branch.get("spawn") not in ["entry","sala","final","store","upper","crawl"] or branch.get("route",0)!=0:return false
		for key in branch.flags:
			if not key is String or not branch.flags[key] is bool:return false
		if not (branch.get("play_seconds",0) is float or branch.get("play_seconds",0) is int):return false
	for key in data.get("scares",{}):
		if not key is String or not data.scares[key] is bool:return false
	for key in data.get("records",{}):
		var record=data.records[key]
		if key not in ["seal","break"] or not record is Dictionary:return false
		for field in ["memories","seconds","catches"]:
			if not (record.get(field) is float or record.get(field) is int):return false
	if not data.get("endings", []) is Array:
		return false
	for key in ["play_seconds", "catches"]:
		var value = data.get(key, 0)
		if not (value is float or value is int):
			return false
	return true

func save_settings() -> void:
	_write_json(SETTINGS_PATH, {"language": language, "quality": quality, "sensitivity": sensitivity, "volume": volume, "brightness": brightness, "reduced_motion": reduced_motion, "subtitles": subtitles, "touch_mode": touch_mode})
	settings_changed.emit()

func load_settings() -> void:
	var data := _read_json(SETTINGS_PATH)
	language = "fil" if data.get("language") == "fil" else "en"
	quality = str(data.get("quality", quality))
	if quality not in ["low", "medium", "high"]:
		quality = "medium"
	sensitivity = clampf(float(data.get("sensitivity", 0.12)), 0.04, 0.3)
	volume = clampf(float(data.get("volume", 0.8)), 0.0, 1.0)
	brightness = clampf(float(data.get("brightness", 1.0)), 0.7, 1.5)
	reduced_motion = bool(data.get("reduced_motion", false))
	subtitles = bool(data.get("subtitles", true))
	touch_mode = bool(data.get("touch_mode", touch_mode))

func _write_json(path: String, data: Dictionary) -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_available = false
		return
	file.store_string(JSON.stringify(data))
	save_available = true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_available = false
		return {}
	var result = JSON.parse_string(file.get_as_text())
	return result if result is Dictionary else {}
