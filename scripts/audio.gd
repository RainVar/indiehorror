class_name HouseAudio
extends Node
## Original synthesized atmospheres, with a hard cap of 15 active sound voices.

var pool: Array[AudioStreamPlayer3D] = []
var ambient: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var heartbeat: AudioStreamPlayer
var drone: AudioStreamPlayer
var time: float = 0.0
var paused_game: bool = true
var threat: float = 0.0
var next_thunder: float = 19.0
signal caption(en: String, fil: String)

func _exit_tree() -> void:
	for voice in pool:
		voice.stop()
		voice.stream=null
	for voice in ambient:
		voice.stop()
		voice.stream=null
	streams.clear()

func _ready() -> void:
	for sound in ["rain","wind","drone","step","knock","creak","whisper","chime","impact","heartbeat","match","phone","thunder"]:
		streams[sound]=load("res://assets/audio/"+sound+".wav")
	for i in range(11):
		var player:=AudioStreamPlayer3D.new()
		player.max_distance=22
		player.unit_size=3
		player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		pool.append(player)
	_loop("rain",-19.0)
	_loop("wind",-26.0)
	drone=_loop("drone",-28.0)
	heartbeat=_loop("heartbeat",-60.0)
	Session.settings_changed.connect(apply_settings)
	apply_settings()

func _loop(id:String,db:float) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new()
	var stream:AudioStreamWAV=streams[id].duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=int(stream.get_length()*stream.mix_rate)
	player.stream=stream
	player.volume_db=db
	add_child(player)
	# Dummy/headless tests have no listener or audible output; don't allocate mixer voices.
	if DisplayServer.get_name()!="headless":player.play()
	ambient.append(player)
	return player

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(Session.volume,0.001)))
	AudioServer.set_bus_mute(0,Session.qa_silent or Session.volume<=0.0)

func play_at(id:String,pos:Vector3,db:float=0.0,pitch:float=1.0) -> void:
	if not streams.has(id):return
	var chosen:AudioStreamPlayer3D=null
	for voice in pool:
		if not voice.playing:
			chosen=voice
			break
	if chosen==null:
		chosen=pool[0]
	chosen.stop()
	chosen.stream=streams[id]
	chosen.position=pos
	chosen.volume_db=db
	chosen.pitch_scale=pitch
	if DisplayServer.get_name()!="headless":chosen.play()
	if id=="whisper":caption.emit("[A breath where no one is standing]","[Hininga mula sa kawalan]")
	elif id=="knock":caption.emit("[Three knocks, somewhere in the house]","[Tatlong katok sa loob ng bahay]")
	elif id=="thunder":caption.emit("[Distant thunder]","[Malayong kulog]")

func _process(delta:float) -> void:
	time+=delta
	next_thunder-=delta
	if next_thunder<=0:
		play_at("thunder",Vector3(0,5,13),-7.0)
		next_thunder=24.0+fmod(time,13.0)
	heartbeat.volume_db=lerpf(heartbeat.volume_db,-15.0 if threat>0.8 and not paused_game else -60.0,delta*3)
	drone.volume_db=lerpf(drone.volume_db,-20.0 if threat>0.5 and not paused_game else -29.0,delta*2)
