extends Node3D

const WorldScript=preload("res://scripts/expanded_world.gd")
const PlayerScript=preload("res://scripts/player.gd")
const EntityScript=preload("res://scripts/entity.gd")
const NoiseScript=preload("res://scripts/noise.gd")
const AudioScript=preload("res://scripts/audio.gd")
const UIScript=preload("res://scripts/ui.gd")
var world:ExpandedHouse
var player:HousePlayer
var entity:ListeningEntity
var noise:HouseNoise
var sound:HouseAudio
var ui:HouseUI
var menu_camera:Camera3D
var playing:bool=false
var paused:bool=true
var transition:bool=false
var ritual_time:float=0.0
var phone:HouseInteractable
var phone_time:float=0.0
var phone_rings:int=0
var final_kind:String=""
var ui_tick:float=0.0
var time:float=0.0
var _qa_callback
var _qa_enabled:bool=false
var _web_pause_callback
var routes:HouseRoutes
var scares:HouseScares
var endings:HouseEndings
var transition_tween:Tween
var commit_target:=""
var commit_time:=0.0

func _ready() -> void:
	world=WorldScript.new()
	world.name="House"
	add_child(world)
	player=PlayerScript.new()
	add_child(player)
	player.position=world.spawn_position("entry")
	entity=EntityScript.new()
	entity.name="AngNakikinig"
	add_child(entity)
	entity.setup(world,player)
	noise=NoiseScript.new()
	add_child(noise)
	sound=AudioScript.new()
	add_child(sound)
	ui=UIScript.new()
	add_child(ui)
	routes=HouseRoutes.new(self)
	scares=HouseScares.new(self)
	endings=HouseEndings.new(self)
	menu_camera=Camera3D.new()
	menu_camera.position=Vector3(7.8,2.3,17.2)
	menu_camera.fov=63
	menu_camera.near=0.12
	menu_camera.far=45
	add_child(menu_camera)
	menu_camera.look_at(Vector3(-1.0,1.65,6.0))
	menu_camera.make_current()
	_connect_signals()
	apply_quality()
	_setup_qa()
	if OS.has_feature("web"):
		_web_pause_callback=JavaScriptBridge.create_callback(func(args):
			if not args.is_empty() and str(args[0])=="pointer" and not player.controlled:return
			if playing and not paused:pause_game()
			elif paused:player.set_control(false))
		JavaScriptBridge.get_interface("window").bulongPause=_web_pause_callback
	# Engine lifecycle signals pause play when the application loses focus.
	get_tree().auto_accept_quit=false
	print("BULONG_READY version=0.2.0 renderer=gl_compatibility")
	if OS.is_debug_build() and "--capture-native" in OS.get_cmdline_user_args():
		call_deferred("_capture_native")

func _capture_native() -> void:
	Session.persistence_enabled=false
	Session.language="en"
	Session.touch_mode=false
	Session.quality="medium"
	apply_quality()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/qa/native-title.png")
	start_new()
	Session.set_flag("arrival")
	Session.set_flag("fuse")
	Session.set_flag("rules")
	ui.close_modal()
	player.teleport(Vector3(0,0.05,6.5))
	resume_game()
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/qa/native-sala.png")
	print("NATIVE_PERF ",JSON.stringify({"fps":Engine.get_frames_per_second(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"vram_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}))
	entity.position=Vector3(0,0.05,1.8)
	entity.rotation.y=0
	entity._change(ListeningEntity.State.SEARCH,15.0)
	entity.grace=999
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/qa/native-entity.png")
	_freeze()
	get_tree().quit()

func _connect_signals() -> void:
	player.interact_requested.connect(interact)
	player.journal_requested.connect(open_journal)
	player.pause_requested.connect(pause_game)
	player.throw_requested.connect(throw_phone)
	player.footstep.connect(func(pos,strength):noise.emit_noise(pos,strength,"footstep");sound.play_at("step",pos,-15.0 if player.crouching else -6.0,0.85+fmod(time,0.3)))
	player.flashlight_changed.connect(func(_on):sound.play_at("match",player.position,-24))
	noise.noise_emitted.connect(entity.hear)
	noise.microphone_status.connect(ui.mic_status)
	entity.caught.connect(capture_player)
	entity.cue.connect(func(id,pos):sound.play_at(id,pos,-6.0))
	entity.state_changed.connect(func(state):
		if state=="hunt":ui.toast(Story.text("Break its line of sight. Keep moving.","Magtago sa paningin nito. Huwag huminto."),3))
	sound.caption.connect(ui.caption)
	ui.new_game_requested.connect(start_new)
	ui.continue_requested.connect(continue_game)
	ui.resume_requested.connect(resume_game)
	ui.restart_requested.connect(restart_checkpoint)
	ui.quit_requested.connect(return_to_title)
	ui.microphone_requested.connect(func(on):noise.start_microphone() if on else noise.stop_microphone())
	ui.ending_replay.connect(replay_ending)
	ui.branch_replay.connect(replay_branch)
	ui.clock_submitted.connect(set_clock)
	ui.interact_touch.connect(interact)
	ui.crouch_touch.connect(player.toggle_crouch)
	ui.flashlight_touch.connect(func():player.toggle_flashlight())
	ui.journal_touch.connect(open_journal)
	ui.phone_touch.connect(throw_phone)
	ui.pause_touch.connect(pause_game)
	ui.touch_move_changed.connect(func(value):player.touch_move=value)
	ui.touch_look.connect(func(value):player.look(value))
	Session.settings_changed.connect(apply_quality)

func apply_quality() -> void:
	get_viewport().scaling_3d_scale={"low":0.6,"medium":0.8,"high":1.0}.get(Session.quality,0.8)
	Engine.max_fps=60

func start_new() -> void:
	_cancel_traversal()
	if endings.active:endings.stop()
	Session.new_game()
	playing=true
	transition=false
	final_kind=""
	ritual_time=0
	_reset_phone()
	entity.reset()
	routes.reset()
	scares.reset()
	player.teleport(world.spawn_position("entry"))
	for id in world.doors:
		if world.doors[id].open:world.toggle_door(id)
	player.camera.make_current()
	ui.show_game()
	# The arrival note must keep the cursor free. Requesting then immediately
	# releasing browser pointer lock races its asynchronous permission result.
	show_note("arrival",func():
		Session.set_flag("arrival")
		resume_game()
		ui.toast(Story.text("E to interact · F for your flashlight · J for your journal","E para gamitin · F para sa flashlight · J para sa talaan"),6))

func continue_game() -> void:
	var pending:=Session.pending_ending
	playing=true
	transition=false
	var spawn:=str(Session.checkpoint.get("spawn","sala"))
	Session.restore_checkpoint()
	player.teleport(world.spawn_position(spawn))
	entity.reset()
	_reset_phone()
	ritual_time=0
	routes.reset()
	scares.reset()
	player.camera.make_current()
	ui.show_game()
	resume_game()
	if pending in ["seal","break"]:
		Session.pending_ending=pending
		_begin_cinematic(pending)
	elif Session.migration_notice:
		ui.toast(Story.text("Your older save resumes at the new branch. Memories and unlocked endings were kept.","Bumalik ang lumang save sa bagong sangang-daan. Napanatili ang mga alaala at nakita nang wakas."),8)
		Session.migration_notice=false

func resume_game() -> void:
	if not playing:return
	if transition:
		paused=false
		ui.close_modal()
		sound.paused_game=false
		if endings.active:ui.cinema_overlay.show()
		elif transition_tween:transition_tween.play()
		return
	paused=false
	Session.active=true
	player.set_control(true)
	entity.enabled=true
	noise.enabled=true
	sound.paused_game=false
	ui.close_modal()

func _freeze() -> void:
	paused=true
	Session.active=false
	player.set_control(false)
	entity.enabled=false
	noise.enabled=false
	sound.paused_game=true
	commit_target=""
	commit_time=0
	if ui:ui.touch_use_down=false

func pause_game() -> void:
	if not playing or (paused and ui.modal_kind=="pause"):return
	if transition_tween and transition:transition_tween.pause()
	ui.cinema_overlay.hide()
	_freeze()
	Session.save_game()
	ui.show_pause()

func return_to_title() -> void:
	if endings.active:endings.stop()
	_cancel_traversal()
	_freeze()
	playing=false
	transition=false
	Session.save_game()
	noise.stop_microphone()
	entity.reset()
	world.threat=0
	scares.recover()
	ui.film.material.set_shader_parameter("danger",0.0)
	menu_camera.make_current()
	ui.show_title()

func show_note(id:String,callback:Callable=Callable()) -> void:
	_freeze()
	sound.play_at("creak",player.position,-22)
	ui.show_note(id,callback if callback.is_valid() else resume_game)

func open_journal() -> void:
	if not playing or paused or transition:return
	_freeze()
	ui.show_journal(resume_game)

func interact() -> void:
	if not playing or paused or transition:return
	var target:=player.target()
	if target:
		if Session.route==Session.Route.UNDECIDED and target.interaction_id in ["radio","altar"] and Session.has_flag("rules"):
			if target.interaction_id=="altar" and not Session.has_flag("rice"):handle_interaction("altar");return
			commit_target=target.interaction_id
			commit_time=0
			return
		handle_interaction(target.interaction_id)

func handle_interaction(id:String) -> void:
	if routes.handle(id):return
	if id.begins_with("door_"):
		var door_id:=id.trim_prefix("door_")
		world.toggle_door(door_id)
		sound.play_at("creak",player.position,-12)
		noise.emit_noise(player.position,0.36,"door")
		return
	if id=="fuse":
		if Session.has_flag("fuse"):
			ui.toast(Story.text("The fuse is holding. For now.","Maayos pa ang fuse. Sa ngayon."))
			return
		Session.set_flag("fuse")
		sound.play_at("knock",player.position,-7)
		ui.toast(Story.text("A light is on in the sala.","May ilaw na sa sala."))
	elif id=="rules":
		if not Session.has_flag("fuse"):
			ui.toast(Story.text("Restore the power first. The fuse box is by the front door.","Buksan muna ang kuryente. Nasa tabi ng pintuan ang fuse box."))
			return
		show_note("rules",func():
			if not Session.has_flag("rules"):
				Session.set_flag("rules")
				Session.make_branch_checkpoint()
				entity.grace=20
				ui.toast(Story.text("CHAPTER II · The listening house\nCheckpoint saved.","KABANATA II · Ang nakikinig na bahay\nNai-save ang checkpoint."),5)
			resume_game())
	elif id in Session.MEMORIES:
		Session.set_flag(id)
		show_note(id)
	elif id=="pact":
		if not Session.has_flag("title"):return
		Session.set_flag("pact")
		show_note("pact")
	elif id=="phone":
		_reset_phone()
		ui.toast(Story.text("Phone retrieved.","Nakuha ang telepono."))

func set_clock(hour:int,minute:int) -> void:
	if Session.route!=Session.Route.KEEPER or not Session.has_flag("winding_key"):return
	if hour==6 and minute==15:
		Session.set_flag("clock_stopped")
		ui.close_modal()
		resume_game()
		sound.play_at("knock",player.position,-9)
		ui.toast(Story.text("The ticking stops. The house feels closer.","Tumigil ang tik-tak. Parang lumapit ang bahay."))
		routes.check_wards()
	else:
		ui.toast(Story.text("The hands spring back. Read Lola's instruction again.","Bumalik ang mga kamay. Basahin muli ang bilin ni Lola."))

func throw_phone() -> void:
	if paused or not playing or transition:return
	if is_instance_valid(phone):
		ui.toast(Story.text("Retrieve your phone before throwing it again.","Pulutin muna ang telepono bago ihagis muli."))
		return
	var from:=player.camera.global_position
	var direction:=-player.camera.global_transform.basis.z
	direction.y=0
	direction=direction.normalized()
	var point:=player.position+direction*4.0
	var query:=PhysicsRayQueryParameters3D.create(from,from+direction*4.0,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit:point=hit.position-direction*0.5
	point.y=HouseLayout.stair_height(player.position)+0.06
	phone=HouseInteractable.new()
	phone.setup("phone","Retrieve phone","Pulutin ang telepono",Vector3(0.5,0.3,0.5))
	phone.position=point
	add_child(phone)
	world.mesh_box(phone,Vector3.ZERO,Vector3(0.1,0.025,0.21),"moon")
	phone_time=0
	phone_rings=0
	ui.toast(Story.text("Your phone rings where it lands.","Tumunog ang telepono sa binagsakan nito."),2)

func _reset_phone() -> void:
	if is_instance_valid(phone):phone.queue_free()
	phone=null
	phone_time=0
	phone_rings=0

func capture_player() -> void:
	if transition or paused:return
	transition=true
	_freeze()
	scares.recover()
	# A brief diegetic close-up, not an unrelated full-screen image.
	entity.visible=true
	entity.position=player.position-player.transform.basis.z*0.85
	entity.rotation.y=player.rotation.y+PI
	sound.play_at("impact",player.camera.global_position,-1)
	ui.caption("[It found your voice]","[Natagpuan nito ang boses mo]")
	var tween:=create_tween()
	transition_tween=tween
	tween.tween_property(ui.fade,"color",Color(0.015,0.005,0.002,1),0.32)
	tween.tween_interval(1.2)
	tween.tween_callback(func():
		transition=false
		restart_checkpoint(true)
		ui.toast(Story.text("It heard you. Crouch, break line of sight, or throw your phone.\nCheckpoint restored.","Narinig ka nito. Yumuko, magtago, o ihagis ang telepono.\nNaibalik ang checkpoint."),6))
	tween.tween_property(ui.fade,"color",Color(0,0,0,0),0.7)

func restart_checkpoint(captured:bool=false) -> void:
	if not captured:_cancel_traversal()
	if endings.active:endings.stop()
	transition=false
	playing=true
	final_kind=""
	var spawn:=Session.restore_checkpoint(captured)
	player.teleport(world.spawn_position(spawn))
	player.camera.make_current()
	entity.reset()
	routes.reset()
	scares.recover()
	ritual_time=0
	_reset_phone()
	ui.show_game()
	resume_game()

func choose_ending(kind:String) -> void:
	if kind=="seal" and (Session.route!=Session.Route.KEEPER or not Session.has_flag("sealed")):return
	if kind=="break" and (Session.route!=Session.Route.RELEASE or not Session.has_flag("pact_burned")):return
	if kind not in ["seal","break"]:return
	final_kind=kind
	Session.complete(kind)
	_begin_cinematic(kind)

func _begin_cinematic(kind:String,replay:bool=false) -> void:
	final_kind=kind
	_freeze()
	playing=true
	transition=true
	paused=false
	sound.paused_game=false
	endings.start(kind,replay)

func replay_ending(kind:String) -> void:
	if kind not in Session.endings:return
	_begin_cinematic(kind,true)

func replay_branch() -> void:
	Session.replay_branch()
	restart_checkpoint()
	scares.reset()

func travel_hatch(id:String) -> void:
	var exiting:=id.begins_with("hatch_exit_")
	var key:=id.trim_prefix("hatch_exit_") if exiting else id.trim_prefix("hatch_")
	if not HouseLayout.HATCHES.has(key):return
	transition=true
	player.controlled=false # Keep existing pointer capture during this short traversal.
	player.velocity=Vector3.ZERO
	entity.enabled=false
	noise.enabled=false
	Session.active=false
	transition_tween=create_tween()
	transition_tween.parallel().tween_property(world.hatch_lids[key],"rotation:x",-0.85,0.16)
	transition_tween.tween_property(ui.fade,"color",Color(0,0,0,1),0.18)
	transition_tween.tween_callback(func():
		var p:Vector3=HouseLayout.HATCHES[key]
		p.y=0.05 if exiting else HouseLayout.CRAWL+0.05
		if exiting:p.z+=0.8
		player.teleport(p)
		scares.recover())
	transition_tween.tween_property(ui.fade,"color",Color(0,0,0,0),0.18)
	transition_tween.tween_callback(func():
		world.hatch_lids[key].rotation.x=0
		transition=false
		resume_game())

func _cancel_traversal() -> void:
	if is_instance_valid(transition_tween):transition_tween.kill()
	transition_tween=null
	if ui:ui.fade.color=Color(0,0,0,0)
	if world:
		for lid in world.hatch_lids.values():lid.rotation.x=0

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and transition and not paused:
		pause_game()
		get_viewport().set_input_as_handled()

func _process(delta:float) -> void:
	time+=delta
	if not playing:
		world.update_visibility(menu_camera,delta)
		menu_camera.position.y=2.3+sin(time*0.18)*0.025
	if endings and endings.active:endings.update(delta)
	if playing and not paused and not transition:
		if not commit_target.is_empty():
			var aimed:=player.target()
			if (Input.is_action_pressed("interact") or ui.touch_use_down) and aimed and aimed.interaction_id==commit_target:
				commit_time+=delta
				ui.toast(Story.text("HOLD TO CHOOSE THIS PATH · ","PINDUTIN NANG MATAGAL PARA PUMILI · ")+str(int(commit_time/1.5*100))+"%",0.3)
				if commit_time>=1.5:
					var choice:=commit_target
					commit_target=""
					handle_interaction(choice)
			else:commit_target="";commit_time=0
		if paused:return
		routes.update(delta)
		scares.update(delta)
		world.update_visibility(player.camera,delta)
		noise.source_position=player.global_position
		world.threat=entity.threat_level()
		sound.threat=world.threat
		if is_instance_valid(phone):
			phone_time-=delta
			if phone_time<=0 and phone_rings<4:
				sound.play_at("phone",phone.position,-4)
				noise.emit_noise(phone.position,0.9,"phone")
				phone_time=2.5
				phone_rings+=1
		ui_tick-=delta
		if ui_tick<=0:
			var target:=player.target()
			ui.update_hud(world.room_at(player.position),target.get_prompt() if target else "",noise.meter,player.stamina,world.threat,entity.listening,noise.mic_ready)
			if routes.trial>=0:ui.objective_label.text+=" · %.1f / 8s"%routes.ritual_time
			ui_tick=0.07
	if _qa_enabled and int(time*4)!=int((time-delta)*4):
		_publish_qa_state()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and playing and not paused:
		pause_game()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		Session.save_game()
		get_tree().quit()

func _setup_qa() -> void:
	# This bridge is available only in debug web exports with an explicit qa=1 URL.
	# It is absent from release builds and never used by gameplay.
	if not OS.has_feature("web") or not OS.is_debug_build():return
	var enabled=JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'")
	if not enabled:return
	_qa_enabled=true
	_qa_callback=JavaScriptBridge.create_callback(_qa_command)
	JavaScriptBridge.get_interface("window").bulongCommand=_qa_callback
	JavaScriptBridge.eval("window.bulongTest = { ready: true, state: {} }")
	_publish_qa_state()

func _qa_command(args:Array) -> void:
	var data=JSON.parse_string(str(args[0]))
	if not data is Dictionary:return
	match str(data.get("action","")):
		"start":start_new()
		"continue":continue_game()
		"resume":resume_game()
		"close_note":
			if ui.modal_close.is_valid():
				var callback:=ui.modal_close
				ui.close_modal()
				callback.call()
		"interact":handle_interaction(str(data.get("id","")))
		"teleport":player.teleport(Vector3(data.get("x",0),data.get("y",0.05),data.get("z",0)),float(data.get("yaw",0)));player.look_pitch=float(data.get("pitch",0));player.camera.rotation_degrees.x=player.look_pitch
		"clock":set_clock(int(data.get("hour",0)),int(data.get("minute",0)))
		"noise":noise.emit_noise(player.position,float(data.get("strength",1.0)),"test")
		"grace":entity.grace=float(data.get("seconds",0))
		"ritual":routes.ritual_time=7.95
		"choice":choose_ending(str(data.get("kind","seal")))
		"restart":restart_checkpoint()
		"pause":pause_game()
		"title":return_to_title()
		"quality":Session.quality=str(data.get("value","low"));Session.save_settings()
		"language":Session.language=str(data.get("value","fil"));Session.save_settings()
		"touch":Session.touch_mode=bool(data.get("value",true));Session.save_settings()
		"mic":noise.start_microphone() if data.get("enabled",false) else noise.stop_microphone()
		"capture":capture_player()
		"cinema_skip":endings.finish() if endings.active else null
		"replay":replay_ending(str(data.get("kind","seal")))
		"entity_path":
			entity.position=Vector3(data.get("x",4.4),data.get("y",0.05),data.get("z",7.5))
			entity.target_point=Vector3(data.get("tx",4.4),data.get("ty",3.65),data.get("tz",0.5))
			entity.grace=999
			entity.repath_timer=0
			entity._change(ListeningEntity.State.INVESTIGATE,30)
		"entity_reset":entity.reset()
		"save_probe":
			var saved:=Session._read_json(Session.SAVE_PATH)
			JavaScriptBridge.eval("window.bulongStorage="+JSON.stringify({"data":saved,"valid":Session.valid_save(saved),"persistent":Session.persistence_enabled,"pending":Session.pending_ending}))
		"branch":replay_branch()
		"scare":scares.grace=0;scares.cooldown=0;scares.trigger(str(data.get("id","window")),true)
		"shadow_probe":
			player.flashlight.shadow_bias=float(data.get("bias",0.5))
			player.flashlight.shadow_normal_bias=float(data.get("normal",2.0))
	_publish_qa_state()

func _publish_qa_state() -> void:
	var aimed:HouseInteractable=player.target()
	var data:={"ready":true,"playing":playing,"paused":paused,"flags":Session.flags,"objective":Story.objective(),"act":Session.act(),"memories":Session.memory_count(),"modal":ui.modal_kind,"entity_state":ListeningEntity.State.keys()[entity.state],"grace":entity.grace,"noise":noise.meter,"mic":Session.mic_enabled,"mic_ready":noise.mic_ready,"fps":Engine.get_frames_per_second(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"vram":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"player":[player.position.x,player.position.y,player.position.z],"ritual":ritual_time,"ending":final_kind,"quality":Session.quality,"language":Session.language,"touch":Session.touch_mode,"target":aimed.interaction_id if aimed else "","save_available":Session.save_available}
	data["yaw"]=player.rotation.y
	data["surfaces"]=world.surface_audit
	data["route"]=Session.Route.keys()[Session.route]
	data["floor"]=HouseLayout.floor_of(player.position)
	data["room"]=HouseLayout.room_id(player.position)
	data["trial"]=routes.trial
	data["cinematic"]={"active":endings.active,"time":endings.elapsed,"kind":endings.kind,"skip":endings.skip_time}
	data["scares"]={"last":scares.last_id,"seen":Session.seen_scares,"major":scares.major_count}
	data["muted"]=AudioServer.is_bus_mute(0)
	data["crouching"]=player.crouching
	data["body_height"]=player.collider.shape.height
	data["controlled"]=player.controlled
	data["checkpoint"]=Session.checkpoint
	data["unlocked"]=Session.endings
	data["entity_position"]=[entity.position.x,entity.position.y,entity.position.z]
	var items:Dictionary={}
	for id in world.interactables:
		var p:Vector3=world.interactables[id].global_position
		items[id]=[p.x,p.y,p.z]
	data["items"]=items
	JavaScriptBridge.eval("window.bulongTest.state = "+JSON.stringify(data))
