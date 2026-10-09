class_name HouseEndings
extends RefCounted
var game:Node3D
var camera:Camera3D
var stage:Node3D
var extra_plate:MeshInstance3D
var name_label:Label3D
var active:=false
var gallery:=false
var kind:=""
var elapsed:=0.0
var duration:=35.0
var skip_time:=0.0
var phase:=-1
var old_environment:Dictionary={}
var held_photo:MeshInstance3D

func _init(owner_game:Node3D) -> void:
	game=owner_game
	camera=Camera3D.new()
	camera.near=0.12
	camera.far=45
	camera.fov=76
	game.add_child(camera)
	held_photo=game.world.mesh_box(camera,Vector3(-0.12,-0.28,-0.72),Vector3(0.24,0.30,0.014),"paper")
	var photo_material:=StandardMaterial3D.new()
	photo_material.albedo_texture=load("res://assets/textures/family-restored.svg")
	photo_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var print_face:=MeshInstance3D.new()
	var print_mesh:=QuadMesh.new()
	print_mesh.size=Vector2(0.24,0.30)
	print_face.mesh=print_mesh
	print_face.material_override=photo_material
	print_face.position.z=0.008
	held_photo.add_child(print_face)
	held_photo.rotation.z=0.08
	held_photo.visible=false
	stage=Node3D.new()
	stage.position=Vector3(-40,0,0)
	game.add_child(stage)
	game.world.mesh_box(stage,Vector3(0,-0.05,0),Vector3(5,0.1,5),"wood")
	game.world.mesh_box(stage,Vector3(0,1.6,-2),Vector3(5,3.2,0.15),"plaster")
	game.world.mesh_box(stage,Vector3(-2.4,1.6,0),Vector3(0.15,3.2,4),"plaster")
	game.world.mesh_box(stage,Vector3(0,0.8,0),Vector3(2,0.1,1.2),"wood")
	for x in [-0.8,0.8]:
		for z in [-0.4,0.4]:game.world.mesh_box(stage,Vector3(x,0.4,z),Vector3(0.1,0.8,0.1),"darkwood")
	game.world.cylinder(stage,Vector3(-0.45,0.87,0),0.22,0.04,"white")
	extra_plate=game.world.cylinder(stage,Vector3(0.45,0.87,0),0.22,0.04,"white")
	name_label=Label3D.new()
	name_label.text="MIKA"
	name_label.font_size=48
	name_label.pixel_size=0.002
	name_label.position=Vector3(0.45,0.905,0)
	name_label.rotation.x=-PI/2
	stage.add_child(name_label)
	var light:=OmniLight3D.new()
	light.position=Vector3(0,2,0.6)
	light.light_energy=1.1
	light.omni_range=6
	light.light_color=Color(1,0.8,0.55)
	stage.add_child(light)
	stage.visible=false

func start(ending:String,replay:bool=false) -> void:
	kind=ending
	gallery=replay
	elapsed=0
	skip_time=0
	phase=-1
	duration=35 if ending=="seal" else 40
	active=true
	game.world.cinematic_fire=ending=="break"
	game.world.cinematic_active=true
	game.world._sync_state()
	old_environment={"energy":game.world.environment.environment.ambient_light_energy,
		"color":game.world.environment.environment.ambient_light_color,"rain":game.world.rain.visible,
		"sky":game.world.environment.environment.background_color,"fog":game.world.environment.environment.fog_light_color}
	game.world.environment.environment.ambient_light_energy=0.62
	game.world.environment.environment.ambient_light_color=Color(0.55,0.57,0.48)
	if ending=="seal":
		game.world.environment.environment.background_color=Color(0.34,0.38,0.32)
		game.world.environment.environment.fog_light_color=Color(0.36,0.39,0.32)
	game.world.rain.visible=false
	game.world.threat=0
	game.sound.threat=0
	game.ui.film.material.set_shader_parameter("danger",0.0)
	game.ui.show_cinema()
	camera.make_current()
	update(0)

func stop() -> void:
	active=false
	stage.visible=false
	held_photo.visible=false
	game.world.cinematic_fire=false
	game.world.cinematic_active=false
	game.ui.cinema_overlay.hide()
	if not old_environment.is_empty():
		game.world.environment.environment.ambient_light_energy=old_environment.energy
		game.world.environment.environment.ambient_light_color=old_environment.color
		game.world.rain.visible=old_environment.rain
		game.world.environment.environment.background_color=old_environment.sky
		game.world.environment.environment.fog_light_color=old_environment.fog
	game.world._sync_state()

func finish() -> void:
	var replay:=gallery
	stop()
	game.transition=false
	if not replay:
		Session.pending_ending=""
		Session.save_game()
		game.ui.show_ending(kind)
		game.paused=true
		game.ui.fade.color=Color(0,0,0,0)
	else:game.return_to_title()

func update(delta:float) -> void:
	if not active or game.paused:return
	elapsed+=delta
	if Input.is_action_pressed("interact") or game.ui.cinema_skip_down:skip_time+=delta
	else:skip_time=0
	if skip_time>=2 or elapsed>=duration:finish();return
	var next:int=(0 if elapsed<7 else (1 if elapsed<15 else 2)) if kind=="seal" else (0 if elapsed<12 else (1 if elapsed<25 else 2))
	if next!=phase:
		phase=next
		stage.visible=kind=="seal" and phase==2
		game.ui.fade.color=Color(0,0,0,0.65)
		if kind=="seal":
			if phase==0:
				camera.position=Vector3(7,1.62,-7.7)
				camera.look_at(Vector3(7,1.15,-9.5))
				game.sound.play_at("chime",game.world.altar_point,-16)
			elif phase==1:
				camera.position=Vector3(0,1.62,10)
				camera.look_at(Vector3(0,1.3,19))
			else:
				camera.position=Vector3(-40,1.62,1.6)
				camera.look_at(Vector3(-40,0.86,0))
		else:
			if phase==0:
				camera.position=Vector3(0,1.62,18.5)
				camera.look_at(Vector3(0,3.5,8))
			elif phase==1:
				camera.position=Vector3(-0.5,1.62,18)
				camera.look_at(Vector3(0,1.0,19))
			else:
				camera.position=Vector3(0,1.62,19)
				camera.look_at(Vector3(0,3.4,7))
		for flame in game.world.fire_nodes:flame.visible=kind=="break"
	game.ui.fade.color.a=move_toward(game.ui.fade.color.a,0,delta*1.5)
	extra_plate.visible=elapsed>=21
	held_photo.visible=kind=="break" and phase==1
	name_label.visible=elapsed>=29
	var line:=""
	if kind=="seal":
		if elapsed<7:line=Story.text("You seal the agreement. The empty chair grows still.","Isinelyo mo ang kasunduan. Pumirmi ang bakanteng upuan.")
		elif elapsed<15:line=Story.text("Dawn. You leave with the land title.","Bukang-liwayway. Dala mo ang titulo.")
		elif elapsed<21:line=Story.text("The following morning.","Kinabukasan.")
		elif elapsed<29:line=Story.text("Mama: “Anak, why did you set another plate?”","Mama: “Anak, bakit ka naglagay ng dagdag na plato?”")
		else:line=Story.text("Mika: “I don't remember doing it.”","Mika: “Hindi ko maalalang ginawa ko iyon.”")
	else:
		if elapsed<12:line=Story.text("The neighbors will say the house burned without a sound.","Sasabihin ng mga kapitbahay na tahimik na nasunog ang bahay.")
		elif elapsed<25:line=Story.text("Mama: “My brother. His name was Tomas.”","Mama: “Kapatid ko. Tomas ang pangalan niya.”")
		else:line=Story.text("“Tomas.” This time, the wind carries nothing back.","“Tomas.” Sa pagkakataong ito, walang ibinulong ang hangin.")
	game.ui.cinema_text.text=line
	game.ui.cinema_skip.text=Story.text("HOLD E / HOLD SKIP · ","PINDUTIN NANG MATAGAL ANG E / SKIP · ")+str(int(skip_time*50))+"%"
	game.world.update_visibility(camera,delta)
