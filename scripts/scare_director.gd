class_name HouseScares
extends RefCounted
var game:Node3D
var cooldown:=0.0
var grace:=15.0
var major_count:=0
var elapsed:=0.0
var apparition:Node3D
var effect_time:=0.0
var last_id:=""
var history:Array[String]=[]
var hand:Node3D

func _init(owner_game:Node3D) -> void:
	game=owner_game
	# Reuse the creature's mesh, but never couple a non-lethal sighting to its AI.
	var model:=ListeningEntity.new()
	model._build_creature()
	apparition=model.visual
	model.remove_child(apparition)
	model.free()
	game.add_child(apparition)
	apparition.visible=false
	hand=Node3D.new()
	game.add_child(hand)
	game.world.mesh_box(hand,Vector3.ZERO,Vector3(0.2,0.25,0.07),"paper")
	for i in range(4):
		game.world.mesh_box(hand,Vector3((i-1.5)*0.048,0.22,0),Vector3(0.028,0.24+sin(i)*0.035,0.04),"paper")
	game.world.mesh_box(hand,Vector3(-0.13,0.02,0),Vector3(0.09,0.05,0.04),"paper")
	hand.visible=false

func reset() -> void:
	cooldown=0
	grace=15
	major_count=0
	for key in Session.seen_scares:
		if key in ["window","chair","crawl_hand","tomas_door"]:major_count+=1
	history.clear()
	effect_time=0
	apparition.visible=false
	hand.visible=false
	if game.world.scare_chair:game.world.scare_chair.position=Vector3(7,0,-7.4)

func recover() -> void:
	grace=15
	effect_time=0
	apparition.visible=false
	hand.visible=false
	if game.world.scare_chair:game.world.scare_chair.position=Vector3(7,0,-7.4)

func trigger(id:String,major:bool=false) -> bool:
	if Session.seen_scares.has(id) or grace>0 or (major and (cooldown>0 or major_count>=3)):return false
	Session.seen_scares[id]=true
	Session.save_game()
	last_id=id
	history.append(id)
	if major:cooldown=45;major_count+=1
	var p:Vector3=game.player.camera.global_position
	match id:
		"power_sighting":
			apparition.position=Vector3(4.4,3.6,0.1)
			apparition.rotation.y=PI
			game.sound.play_at("creak",apparition.position,-20)
			game.ui.caption("[Something waits at the upper landing]","[May naghihintay sa hagdanan sa itaas]")
			effect_time=3
		"window":
			var forward:Vector3=-game.player.camera.global_transform.basis.z
			game.sound.play_at("impact",p+forward*2,-13)
			game.ui.caption("[A palm strikes the other side of the shutter]","[May palad na humampas sa kabila ng bintana]")
			hand.position=p+forward*0.9
			hand.rotation=Vector3(0,game.player.rotation.y+PI,0.18)
			hand.visible=true
			effect_time=0.35
		"portrait_change":
			game.world.portrait.scale.x=0.94
			game.sound.play_at("whisper",game.world.portrait.position,-20)
			game.ui.caption("[The photograph has one more shadow]","[May dagdag na anino sa larawan]")
		"voice_lure":
			game.sound.play_at("whisper",Vector3(7,5.0,-8),-18,0.8)
			game.ui.caption("A borrowed voice: “Mika. Dito ka.”","Hiram na boses: “Mika. Dito ka.”")
		"chair":
			game.sound.play_at("creak",Vector3(7,0,-7.4),-13)
			game.ui.caption("[The empty chair scrapes toward you]","[Lumapit ang bakanteng upuan]")
			effect_time=0.6
		"crawl_steps":
			game.sound.play_at("step",p+Vector3(0,1.8,0),-16,0.65)
			game.ui.caption("[Footsteps overhead. They stop when you stop.]","[Mga yabag sa itaas. Humihinto kasabay mo.]")
		"crawl_hand":
			hand.position=p+(-game.player.transform.basis.z)*0.8+Vector3(0,0.15,0)
			hand.rotation=Vector3(0,game.player.rotation.y+PI,PI)
			hand.visible=true
			game.sound.play_at("impact",p+Vector3(0,0.5,0),-15)
			game.ui.caption("[Fingers push through the boards]","[Mga daliring sumuot sa sahig]")
			effect_time=0.45
		"tomas_door":
			apparition.position=Vector3(4.2,3.6,-8)
			apparition.rotation.y=-PI/2
			game.sound.play_at("knock",apparition.position,-12)
			effect_time=0.8
		"burn":
			game.sound.play_at("thunder",game.world.altar_point,-13)
			game.ui.caption("[Every remembered voice falls silent]","[Tumahimik ang lahat ng iningatang boses]")
	if effect_time>0 and id in ["power_sighting","tomas_door"]:apparition.visible=true
	return true

func update(delta:float) -> void:
	grace=maxf(0,grace-delta)
	cooldown=maxf(0,cooldown-delta)
	elapsed+=delta
	if effect_time>0:
		effect_time-=delta
		if last_id=="chair" and game.world.scare_chair:
			game.world.scare_chair.position.z=-7.4+sin(clampf(1-effect_time/0.6,0,1)*PI)*0.6
		if effect_time<=0:
			apparition.visible=false
			hand.visible=false
			if game.world.scare_chair:game.world.scare_chair.position.z=-7.4
	if Session.has_flag("pact_burned"):trigger("burn")
	if game.entity.state==ListeningEntity.State.HUNT:return
	var room:=HouseLayout.room_id(game.player.position)
	if Session.has_flag("fuse") and room=="foyer":trigger("power_sighting")
	if Session.route==Session.Route.KEEPER:
		if Session.has_flag("shutter_family") and room=="guest":trigger("window",true)
		if Session.has_flag("portrait") and room=="dining":trigger("portrait_change")
		if Session.has_flag("candle_1") and room=="altar":trigger("chair",true)
	if Session.has_flag("memory_letter") and room.begins_with("gallery"):trigger("voice_lure")
	if room=="crawl":
		trigger("crawl_steps")
		if Session.route==Session.Route.RELEASE and Session.has_flag("binding_portrait"):trigger("crawl_hand",true)
	if Session.route==Session.Route.RELEASE and room=="tomas":trigger("tomas_door",true)
