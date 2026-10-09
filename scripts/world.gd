class_name HouseWorld
extends Node3D
## Authored, compact layout. Static geometry is batched per material.

const InteractableScript = preload("res://scripts/interactable.gd")
const SurfaceBuilderScript = preload("res://scripts/surface_builder.gd")
var materials: Dictionary = {}
var surfaces:=SurfaceBuilderScript.new()
var surface_audit:Dictionary={}
var interactables: Dictionary = {}
var doors: Dictionary = {}
var lights: Array[OmniLight3D] = []
var obstacles: Array[Rect2] = []
var salt: MeshInstance3D
var portrait: Node3D
var clock_hour: MeshInstance3D
var clock_minute: MeshInstance3D
var candles: Array[OmniLight3D] = []
var rain: MultiMeshInstance3D
var environment: WorldEnvironment
var clock_rotation: float = 0.0
var threat: float = 0.0
var world_time: float = 0.0
var active_lights: bool = false

func _ready() -> void:
	_make_materials()
	_make_environment()
	_structure()
	_furnish()
	_details()
	_exterior()
	_flush_batches()
	_sync_state()
	Session.changed.connect(_sync_state)
	Session.settings_changed.connect(apply_quality)
	apply_quality()

func _make_materials() -> void:
	for entry in [
		["wood", "wood", Color(0.72,0.62,0.5)], ["darkwood", "wood", Color(0.3,0.24,0.18)],
		["plaster", "plaster", Color(0.75,0.78,0.66)], ["mold", "mold", Color(0.62,0.71,0.66)],
		["tiles", "tiles", Color(0.8,0.82,0.75)], ["concrete", "concrete", Color(0.67,0.73,0.67)],
		["capiz", "capiz", Color(0.65,0.71,0.65)], ["woven", "woven", Color(0.6,0.62,0.48)],
		["paper", "paper", Color(0.95,0.88,0.7)]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/" + str(entry[1]) + ".png")
		mat.albedo_color = entry[2]
		mat.roughness = 0.93
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.65,0.65,0.65)
		materials[entry[0]] = mat
	for entry in [["black", Color(0.025,0.033,0.028)], ["brass", Color(0.48,0.36,0.17)], ["white", Color(0.72,0.71,0.58)], ["red", Color(0.35,0.075,0.045)], ["blue", Color(0.045,0.16,0.19)], ["green", Color(0.1,0.17,0.08)], ["skin", Color(0.54,0.57,0.43)], ["cloth", Color(0.24,0.27,0.2)]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[1]
		mat.roughness = 0.9
		materials[entry[0]] = mat
	for entry in [["lamp", Color(1.0,0.7,0.3)], ["moon", Color(0.21,0.4,0.43)], ["eyes", Color(0.72,0.4,0.22)], ["salt", Color(0.8,0.77,0.58)]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[1]
		mat.emission_enabled = true
		mat.emission = entry[1]
		mat.emission_energy_multiplier = 0.6
		materials[entry[0]] = mat
	# A shared ordering policy supplements real geometric separation. Depth
	# testing stays enabled: higher layers must never show through solid walls.
	for material_name in materials:
		materials[material_name].render_priority=SurfaceBuilderScript.priority(material_name)

func _make_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018,0.029,0.031)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36,0.48,0.48)
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.09,0.14,0.14)
	env.fog_density = 0.012
	env.fog_sky_affect = 1.0
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-57,-38,0)
	moon.light_color = Color(0.31,0.48,0.51)
	moon.light_energy = 0.33
	moon.shadow_enabled = false
	add_child(moon)

func box(pos: Vector3, size: Vector3, mat: String, collision: bool = false, rot_y: float = 0.0) -> void:
	surfaces.add_box(pos,size,mat,rot_y)
	if collision:
		_block(pos, size, rot_y).set_meta("surface",mat)

func _block(pos: Vector3, size: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	if pos.y + size.y/2.0 > 0.4 and pos.y - size.y/2.0 < 1.5:
		var footprint := Vector2(size.x, size.z)
		if absf(sin(rot_y)) > 0.5:
			footprint = Vector2(size.z,size.x)
		obstacles.append(Rect2(Vector2(pos.x,pos.z)-footprint/2.0, footprint))
	return body

func mesh_box(parent: Node3D, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[mat]
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: String, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = materials[mat]
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node

func _flush_batches() -> void:
	surfaces.resolve()
	surface_audit=surfaces.stats.duplicate()
	if OS.is_debug_build():surface_audit["remaining_conflicts"]=surfaces.conflicts().size()
	var meshes:=surfaces.create_meshes(materials)
	for mat in meshes:
		var node := MeshInstance3D.new()
		node.mesh = meshes[mat]
		node.name = "Batch_" + mat
		add_child(node)
	if not OS.is_debug_build():surfaces=null

func _structure() -> void:
	box(Vector3(0,-0.18,-1), Vector3(18.4,0.36,18.4), "wood", true)
	box(Vector3(-6,0.018,5), Vector3(5.8,0.02,5.8), "tiles")
	box(Vector3(0,3.25,-1), Vector3(18.4,0.2,18.4), "darkwood")
	# Exterior shell; front door has a wide opening.
	_wall_x(-9,9,-10,"mold")
	_wall_z(-10,8,-9,"plaster")
	_wall_z(-10,8,9,"plaster")
	_wall_x(-9,-1.05,8,"plaster")
	_wall_x(1.05,9,8,"plaster")
	box(Vector3(0,2.92,8),Vector3(2.1,0.55,0.22),"plaster",true)
	# Two rows of rooms joined by the central sala / hallway.
	_partition_z(-10,8,-3,[-7.0,-1.0,5.0])
	_partition_z(-10,8,3,[-6.2,3.8])
	_wall_x(-9,-3,-4,"mold")
	_wall_x(-9,-3,2,"plaster")
	_wall_x(3,9,0,"mold")
	for x in [-9.0,-3.0,3.0,9.0]:
		for z in [-10.0,-4.0,2.0,8.0]:
			box(Vector3(x,1.6,z),Vector3(0.2,3.2,0.2),"darkwood")
	for z in [-10.0,-4.0,2.0,8.0]:
		box(Vector3(0,3.02,z),Vector3(18.0,0.24,0.2),"darkwood")
	for x in [-6.0,0.0,6.0]:
		box(Vector3(x,3.02,-1),Vector3(0.18,0.23,18.0),"darkwood")
	# Wainscot and plinths make the room read as an old wooden home.
	for z in [-10.0,8.0]:
		for x in range(-8,9,2):
			if z == 8.0 and abs(x) < 2:
				continue
			box(Vector3(x,0.52,z+0.12 if z<0 else z-0.12),Vector3(1.85,0.93,0.08),"darkwood")
	_door("front",Vector3(-1.02,0,8),0.0,2.02)
	_door("kitchen",Vector3(-3,0,4.15),-PI/2.0,1.7)
	_door("family",Vector3(-3,0,-1.85),-PI/2.0,1.7)
	_door("store",Vector3(-3,0,-7.85),-PI/2.0,1.7)
	_door("lola",Vector3(3,0,2.95),-PI/2.0,1.7)
	_door("altar",Vector3(3,0,-7.05),-PI/2.0,1.7)
	for data in [[Vector3(-8.82,1.9,5),PI/2.0,"shutter_kitchen"],[Vector3(8.82,1.9,4),-PI/2.0,"shutter_lola"],[Vector3(-8.82,1.9,-1),PI/2.0,"shutter_family"]]:
		_window(data[0],data[1],data[2])
	# Fixed moonlit capiz panes in the back rooms.
	for x in [-6.0,0.0,6.0]:
		box(Vector3(x,1.9,-9.85),Vector3(1.9,1.4,0.08),"capiz")
		box(Vector3(x,1.1,-9.72),Vector3(2.05,0.09,0.24),"darkwood")
	for p in [Vector3(0,2.7,4),Vector3(0,2.7,-5),Vector3(-6,2.7,5),Vector3(-6,2.7,-1),Vector3(6,2.7,4),Vector3(6,2.7,-5),Vector3(-6,2.7,-7)]:
		box(p+Vector3(0,0.35,0),Vector3(0.04,0.45,0.04),"black")
		cylinder(self,p,0.21,0.12,"darkwood",0.06)
		cylinder(self,p-Vector3(0,0.1,0),0.065,0.13,"lamp")
		var light := OmniLight3D.new()
		light.position=p-Vector3(0,0.2,0)
		light.light_color=Color(1.0,0.69,0.35)
		light.omni_range=6.0
		light.light_energy=1.3
		light.shadow_enabled=false
		add_child(light)
		lights.append(light)

func _wall_x(a: float, b: float, z: float, mat: String) -> void:
	box(Vector3((a+b)/2.0,1.6,z),Vector3(b-a,3.2,0.22),mat,true)
	box(Vector3((a+b)/2.0,0.15,z),Vector3(b-a,0.3,0.29),"darkwood")
	box(Vector3((a+b)/2.0,1.0,z),Vector3(b-a,0.07,0.26),"darkwood")

func _wall_z(a: float, b: float, x: float, mat: String) -> void:
	box(Vector3(x,1.6,(a+b)/2.0),Vector3(0.22,3.2,b-a),mat,true)
	box(Vector3(x,0.15,(a+b)/2.0),Vector3(0.29,0.3,b-a),"darkwood")
	box(Vector3(x,1.0,(a+b)/2.0),Vector3(0.26,0.07,b-a),"darkwood")

func _partition_z(a: float,b: float,x: float,openings: Array) -> void:
	var start:=a
	for opening in openings:
		_wall_z(start,float(opening)-0.88,x,"plaster")
		box(Vector3(x,2.94,opening),Vector3(0.22,0.52,1.76),"plaster",true)
		for side in [-1.0,1.0]:
			box(Vector3(x,1.35,float(opening)+side*0.89),Vector3(0.3,2.7,0.1),"darkwood")
		start=float(opening)+0.88
	_wall_z(start,b,x,"plaster")

func _door(id: String,pos: Vector3,rotation_y: float,width: float) -> void:
	var hinge:=Node3D.new()
	hinge.name="Door_"+id
	hinge.position=pos
	hinge.rotation.y=rotation_y
	add_child(hinge)
	mesh_box(hinge,Vector3(width/2,1.3,0),Vector3(width,2.6,0.12),"darkwood")
	for y in [0.7,1.8]:
		mesh_box(hinge,Vector3(width/2,y,0.075),Vector3(width-0.26,0.8,0.06),"wood")
	mesh_box(hinge,Vector3(width-0.18,1.16,0.12),Vector3(0.12,0.055,0.06),"brass")
	var body:=StaticBody3D.new()
	var col:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(width,2.6,0.14)
	col.shape=shape
	col.position=Vector3(width/2,1.3,0)
	body.add_child(col)
	hinge.add_child(body)
	var item:=InteractableScript.new()
	item.setup("door_"+id,"Open / close door","Buksan / isara ang pinto",Vector3(width,2.5,0.22))
	item.position=Vector3(width/2,1.3,0)
	hinge.add_child(item)
	interactables["door_"+id]=item
	doors[id]={"hinge":hinge,"base":rotation_y,"open":false,"collision":col}
	# The navigation grid treats doorways as passable; the entity opens closed doors.

func toggle_door(id: String,force_open: bool=false) -> bool:
	if not doors.has(id):
		return false
	var door:Dictionary=doors[id]
	var opened:bool=not door.open if not force_open else true
	door.open=opened
	var hinge:Node3D=door.hinge
	var tween:=create_tween()
	tween.tween_property(hinge,"rotation:y",float(door.base)+(-1.35 if opened else 0.0),0.5).set_trans(Tween.TRANS_SINE)
	var col:CollisionShape3D=door.collision
	col.set_deferred("disabled",opened)
	return opened

func _window(pos: Vector3,rot: float,id: String) -> void:
	var node:=Node3D.new()
	node.position=pos
	node.rotation.y=rot
	add_child(node)
	mesh_box(node,Vector3.ZERO,Vector3(1.9,1.4,0.1),"capiz")
	for x in [-1.0,0.0,1.0]:
		mesh_box(node,Vector3(x,0,0.08),Vector3(0.07,1.53,0.16),"darkwood")
	for y in [-0.8,0.8]:
		mesh_box(node,Vector3(0,y,0.08),Vector3(2.08,0.07,0.16),"darkwood")
	var latch:=mesh_box(node,Vector3(0,-0.5,0.23),Vector3(0.3,0.045,0.1),"brass")
	var item:=_item(id,pos,Vector3(2,1.7,0.36),"Latch the window","Isara ang bintana",rot)
	item.visual=latch
	var light:=OmniLight3D.new()
	light.position=pos+Basis(Vector3.UP,rot)*Vector3(0,0,0.7)
	light.light_color=Color(0.31,0.53,0.56)
	light.light_energy=0.6
	light.omni_range=3.5
	add_child(light)

func _item(id:String,pos:Vector3,size:Vector3,en:String,fil:String,rot:float=0.0) -> HouseInteractable:
	var item:=InteractableScript.new()
	item.setup(id,en,fil,size)
	item.position=pos
	item.rotation.y=rot
	item.name="Interact_"+id
	add_child(item)
	interactables[id]=item
	return item

func _prop(model:String,pos:Vector3,scale_factor:float=1.0,rot:float=0.0,footprint:Vector3=Vector3.ZERO) -> Node3D:
	var path:="res://assets/models/"+model+".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene:PackedScene=load(path)
	var node:Node3D=scene.instantiate()
	node.position=pos
	node.scale=Vector3.ONE*scale_factor
	node.rotation.y=rot
	add_child(node)
	_age_prop(node)
	if footprint!=Vector3.ZERO:
		_block(pos+Vector3(0,footprint.y/2,0),footprint,rot)
	return node

func _age_prop(node:Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original:Material=node.mesh.surface_get_material(i)
			if original is StandardMaterial3D:
				var mat:StandardMaterial3D=original.duplicate()
				mat.albedo_color=mat.albedo_color*Color(0.56,0.53,0.42,1)
				mat.roughness=0.95
				mat.render_priority=SurfaceBuilderScript.priority("wood")
				node.set_surface_override_material(i,mat)
	for child in node.get_children():
		_age_prop(child)

func _table(pos:Vector3,size:Vector2,height:float=0.82) -> void:
	box(pos+Vector3(0,height,0),Vector3(size.x,0.1,size.y),"wood",true)
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			box(pos+Vector3(x*(size.x/2-0.14),height/2,z*(size.y/2-0.14)),Vector3(0.09,height,0.09),"darkwood")

func _furnish() -> void:
	# Sala: family table, long bench, old radio and cabinet.
	_table(Vector3(0.7,0,3.6),Vector2(1.5,1.0),0.72)
	box(Vector3(0.7,0.0205,3.6),Vector3(2.7,0.025,3.0),"woven")
	_prop("chair",Vector3(0.7,0,5.1),1.6,PI,Vector3(0.7,0.9,0.65))
	_prop("chairCushion",Vector3(0.8,0,2.15),1.6,0.0,Vector3(0.7,1.0,0.7))
	_table(Vector3(-2.28,0,1),Vector2(0.8,1.9),0.8)
	_prop("radio",Vector3(-2.28,0.87,0.8),1.35,PI/2)
	_prop("pottedPlant",Vector3(2.35,0,6.9),1.8)
	_note_mesh(Vector3(0.55,0.795,3.45),"rules","Read Lola's last instructions","Basahin ang huling bilin ni Lola")
	box(Vector3(1.2,0.84,3.45),Vector3(0.16,0.09,0.12),"brass")
	# Fuse box at the entrance.
	box(Vector3(-1.65,1.5,7.81),Vector3(0.5,0.65,0.17),"black")
	box(Vector3(-1.65,1.5,7.69),Vector3(0.43,0.55,0.04),"concrete")
	mesh_box(self,Vector3(-1.65,1.45,7.64),Vector3(0.12,0.21,0.06),"red")
	_item("fuse",Vector3(-1.65,1.5,7.65),Vector3(0.6,0.8,0.3),"Restore the power","Buksan ang kuryente")
	# Kitchen: a dining table, enamel rice pot, water jug, cabinet.
	_table(Vector3(-6.1,0,4.8),Vector2(2.0,1.2))
	for data in [[Vector3(-6.1,0,6.0),PI],[Vector3(-6.1,0,3.6),0.0],[Vector3(-7.6,0,4.8),PI/2]]:
		_prop("chair",data[0],1.6,data[1],Vector3(0.6,0.8,0.6))
	_prop("kitchenCabinet",Vector3(-8.2,0,2.8),2.0,0.0,Vector3(1.2,0.95,0.65))
	_prop("kitchenStove",Vector3(-7.0,0,2.8),2.0,0.0,Vector3(1.0,0.9,0.7))
	_prop("kitchenSink",Vector3(-5.75,0,2.8),2.0,0.0,Vector3(1.1,0.9,0.7))
	cylinder(self,Vector3(-6.35,1.01,4.6),0.26,0.28,"white")
	cylinder(self,Vector3(-6.35,1.18,4.6),0.29,0.04,"black")
	box(Vector3(-6.35,1.23,4.6),Vector3(0.12,0.07,0.07),"black")
	_item("rice",Vector3(-6.35,1.06,4.6),Vector3(0.65,0.6,0.65),"Take a bowl of rice","Kumuha ng kanin")
	cylinder(self,Vector3(-5.6,0.91,4.9),0.15,0.15,"white",0.2)
	cylinder(self,Vector3(-5.55,1.09,4.4),0.09,0.32,"white")
	_item("salt",Vector3(-5.55,1.09,4.4),Vector3(0.3,0.5,0.3),"Take the salt","Kunin ang asin")
	cylinder(self,Vector3(-8.2,0.46,7),0.4,0.9,"blue",0.3)
	cylinder(self,Vector3(-8.2,0.96,7),0.16,0.18,"blue")
	# Bedrooms retain silhouettes from a Filipino home, not a Western haunted mansion.
	_prop("bedSingle",Vector3(7,0,5.7),2.0,PI,Vector3(1.5,0.75,2.6))
	_prop("cabinetBed",Vector3(8,0,2.0),2.0,PI/2,Vector3(1.0,0.85,0.7))
	box(Vector3(6.7,0.78,5.6),Vector3(1.28,0.04,1.5),"woven")
	_table(Vector3(4.1,0,1.1),Vector2(1.2,0.65),0.75)
	_note_mesh(Vector3(4.1,0.82,1.1),"memory_letter","Read the unsent letter","Basahin ang liham")
	_prop("coatRack",Vector3(8.25,0,0.8),1.9)
	_prop("bedDouble",Vector3(-6.5,0,-2.1),1.9,0.0,Vector3(2.3,0.7,2.5))
	_prop("cabinetBed",Vector3(-4.3,0,-3.15),1.8,0.0,Vector3(0.8,0.8,0.6))
	_note_mesh(Vector3(-4.3,0.82,-3.1),"memory_photo","Look at the old photograph","Tingnan ang lumang larawan")
	box(Vector3(-7.6,0.033,0.1),Vector3(1.5,0.05,1.0),"woven")
	# Baul / storeroom.
	box(Vector3(-6.2,0.38,-8.55),Vector3(1.9,0.76,0.9),"darkwood",true)
	box(Vector3(-6.2,0.81,-8.55),Vector3(2.0,0.12,1.0),"wood")
	for x in [-6.85,-5.55]:
		box(Vector3(x,0.44,-8.02),Vector3(0.06,0.7,0.04),"brass")
	box(Vector3(-6.2,0.67,-7.98),Vector3(0.16,0.2,0.06),"brass")
	_item("baul",Vector3(-6.2,0.63,-8.15),Vector3(2.0,1.1,1.05),"Unlock Lola's baul","Buksan ang baul ni Lola")
	_prop("bookcaseOpen",Vector3(-8.2,0,-5.3),2.0,PI/2,Vector3(0.75,2.0,1.4))
	_table(Vector3(-6.9,0,-5.15),Vector2(0.85,0.65),0.7)
	_note_mesh(Vector3(-6.9,0.77,-5.15),"memory_tape","Examine the cassette","Suriin ang cassette")
	for pos in [Vector3(-4.1,0.4,-9),Vector3(-4.2,0.3,-5),Vector3(-4.3,1,-9)]:
		box(pos,Vector3(0.9,0.65,0.7),"wood",true)
	# Altar / old dining room.
	_table(Vector3(6.2,0,-8.55),Vector2(2.7,1.0),0.95)
	box(Vector3(6.2,1.02,-8.5),Vector3(2.45,0.025,0.9),"cloth")
	box(Vector3(6.2,1.85,-9.68),Vector3(0.1,0.9,0.06),"darkwood")
	box(Vector3(6.2,2.02,-9.68),Vector3(0.6,0.1,0.06),"darkwood")
	_item("altar",Vector3(6.2,1.25,-8.3),Vector3(2.7,1.2,1.0),"Prepare the offering","Ihanda ang alay")
	for x in [5.3,6.2,7.1]:
		cylinder(self,Vector3(x,1.21,-8.7),0.055,0.37,"white")
		var flame:=cylinder(self,Vector3(x,1.44,-8.7),0.028,0.08,"lamp",0.0)
		flame.name="Flame"
		var light:=OmniLight3D.new()
		light.position=Vector3(x,1.5,-8.7)
		light.omni_range=2.4
		light.light_color=Color(1,0.56,0.18)
		light.light_energy=0.65
		add_child(light)
		light.set_meta("flame",flame)
		candles.append(light)
	_prop("chair",Vector3(6.2,0,-6.1),1.8,PI,Vector3(0.7,0.9,0.7))
	# Salt threshold, readable from either side of the door.
	salt=mesh_box(self,Vector3(3,0.03,-6.2),Vector3(0.12,0.025,1.7),"salt")
	_item("threshold",Vector3(3,0.4,-6.2),Vector3(0.8,0.85,1.8),"Lay the salt line","Ilatag ang asin")
	# The pact stays on the baul after retrieving the title.
	_note_mesh(Vector3(-6.2,0.89,-8.45),"pact","Read the family agreement","Basahin ang kasunduan")

func _note_mesh(pos:Vector3,id:String,en:String,fil:String) -> void:
	box(pos,Vector3(0.32,0.014,0.42),"paper")
	for i in range(6):
		box(pos+Vector3(-0.01,0.014,-0.12+i*0.045),Vector3(0.23 if i%3!=0 else 0.14,0.002,0.004),"darkwood")
	_item(id,pos+Vector3(0,0.04,0),Vector3(0.58,0.2,0.6),en,fil)

func _details() -> void:
	portrait=Node3D.new()
	portrait.position=Vector3(2.79,1.9,0.25)
	portrait.rotation.y=-PI/2
	add_child(portrait)
	mesh_box(portrait,Vector3.ZERO,Vector3(0.95,1.22,0.09),"brass")
	var photo:=mesh_box(portrait,Vector3(0,0,0.052),Vector3(0.81,1.08,0.01),"paper")
	var material:=StandardMaterial3D.new()
	material.albedo_texture=load("res://assets/textures/family.svg")
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.render_priority=SurfaceBuilderScript.priority("paper")
	photo.material_override=material
	_item("portrait",Vector3(2.7,1.9,0.25),Vector3(0.3,1.35,1.1),"Turn the family portrait","Iharap ang larawan sa dingding")
	# A readable, analog clock with independently movable hands.
	var clock:=Node3D.new()
	clock.position=Vector3(-2.79,2.05,-2.8)
	clock.rotation.y=PI/2
	add_child(clock)
	var disk:=cylinder(clock,Vector3.ZERO,0.4,0.08,"darkwood")
	disk.rotation.x=PI/2
	var face:=cylinder(clock,Vector3(0,0,0.05),0.35,0.015,"paper")
	face.rotation.x=PI/2
	for i in range(12):
		var angle:=float(i)*TAU/12
		var mark:=mesh_box(clock,Vector3(sin(angle)*0.3,cos(angle)*0.3,0.070),Vector3(0.018,0.045,0.008),"black")
		mark.rotation.z=-angle
	clock_hour=mesh_box(clock,Vector3(0,-0.09,0.088),Vector3(0.025,0.18,0.013),"black")
	clock_minute=mesh_box(clock,Vector3(0.13,0,0.113),Vector3(0.26,0.012,0.013),"black")
	_item("clock",Vector3(-2.66,2.05,-2.8),Vector3(0.4,0.95,0.95),"Set the clock","Itakda ang orasan")
	# Decorative wall calendar, sampaguita, slippers, sockets and woven baskets.
	box(Vector3(-2.78,1.72,6.55),Vector3(0.025,0.6,0.42),"paper")
	for i in range(6):
		box(Vector3(-2.75,1.87-i*0.07,6.55),Vector3(0.01,0.016,0.32),"red" if i==0 else "darkwood")
	for x in [1.2,1.43]:
		box(Vector3(x,0.04,7.25),Vector3(0.14,0.07,0.33),"blue")
		box(Vector3(x,0.09,7.28),Vector3(0.15,0.07,0.045),"black")
	for p in [Vector3(-2.76,0.4,6),Vector3(2.76,0.4,-4),Vector3(-8.76,0.4,-2)]:
		box(p,Vector3(0.035,0.15,0.1),"white")
	for p in [Vector3(7.9,0.2,7.1),Vector3(-8,0.25,-3.25)]:
		cylinder(self,p,0.32,0.45,"woven",0.4)
	# Clothesline silhouettes on the veranda, plants, bamboo fence.
	box(Vector3(-5,2.55,9.5),Vector3(5.7,0.02,0.02),"black")
	for x in [-7.0,-5.5,-4.0]:
		box(Vector3(x,2.05,9.5),Vector3(0.8,0.95,0.02),"cloth")
	# Door labels.
	_label3d("KUSINA",Vector3(-2.78,2.83,5),PI/2)
	_label3d("BODEGA",Vector3(-2.78,2.83,-7),PI/2)
	_label3d("LOLA",Vector3(2.78,2.83,3.8),-PI/2)

func _label3d(text:String,pos:Vector3,rot:float) -> void:
	var label:=Label3D.new()
	label.text=text
	label.font_size=32
	label.pixel_size=0.003
	label.modulate=Color(0.62,0.58,0.4)
	label.no_depth_test=false
	label.position=pos
	label.rotation.y=rot
	add_child(label)

func _exterior() -> void:
	# Yard, veranda and interior share a walkable y=0 surface. The old 10 cm
	# solid veranda lip trapped the no-jump controller before the front door.
	# Split the original yard rectangle around the house footprint: x +/-9.2,
	# front z=8.2. Never place a second y=0 surface beneath the wooden floor.
	box(Vector3(0,-0.15,18.6),Vector3(45,0.3,20.8),"concrete",true)
	for side in [-1.0,1.0]:
		box(Vector3(side*15.85,-0.15,3.6),Vector3(13.3,0.3,9.2),"concrete",true)
	for x in [-8.9,-3.0,3.0,8.9]:
		box(Vector3(x,1.55,10.8),Vector3(0.22,3.1,0.22),"darkwood",true)
	box(Vector3(0,3.1,9.8),Vector3(19,0.18,4),"darkwood")
	for x in [-6.1,6.1]:
		box(Vector3(x,1.9,8.16),Vector3(3.0,1.35,0.1),"capiz")
		for dx in [-1.53,0.0,1.53]:
			box(Vector3(x+dx,1.9,8.24),Vector3(0.09,1.58,0.16),"darkwood")
		for y in [1.14,2.67]:
			box(Vector3(x,y,8.24),Vector3(3.15,0.09,0.18),"darkwood")
		var lantern:=OmniLight3D.new()
		lantern.position=Vector3(x,2.55,8.9)
		lantern.light_color=Color(0.85,0.59,0.29)
		lantern.light_energy=0.6
		lantern.omni_range=4.8
		add_child(lantern)
	_prop("pottedPlant",Vector3(2.5,0,8.5),2.0)
	_prop("pottedPlant",Vector3(-2.5,0,8.5),1.5)
	# Broad corrugated pitched roof, a visible capiz front facade.
	for x in range(-10,11):
		box(Vector3(x,3.45,-1),Vector3(0.93,0.12,20.0),"black")
	for side in [-1.0,1.0]:
		for i in range(17):
			box(Vector3(side*11,0.7,1+i),Vector3(0.13,1.5,0.12),"wood")
		box(Vector3(side*11,0.95,9),Vector3(0.1,0.08,17),"darkwood",true)
	for x in [-10.0,-7.0,6.0,10.0]:
		_tree(Vector3(x,0,16.5),1.0+absf(x)*0.05)
	for p in [Vector3(-12,0,-8),Vector3(12,0,4),Vector3(13,0,-5),Vector3(-12,0,6)]:
		_tree(p,1.6)
	box(Vector3(0,0.5,21),Vector3(35,1.0,0.3),"black",true)
	box(Vector3(-13,0.5,9),Vector3(0.3,1,30),"black",true)
	box(Vector3(13,0.5,9),Vector3(0.3,1,30),"black",true)
	box(Vector3(0,0.018,14),Vector3(2.5,0.02,8),"tiles")
	_item("gate",Vector3(0,1,19),Vector3(4,2,0.3),"Leave the house","Umalis sa bahay")
	# Cheap outdoor rain: one draw call, never inside the rooms.
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	var drop:=BoxMesh.new()
	drop.size=Vector3(0.01,0.2,0.01)
	drop.material=materials["moon"]
	mm.mesh=drop
	mm.instance_count=180
	var rng:=RandomNumberGenerator.new()
	rng.seed=54
	for i in range(mm.instance_count):
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-11,11),rng.randf_range(0,8),rng.randf_range(11,20))))
	rain=MultiMeshInstance3D.new()
	rain.multimesh=mm
	# Decorative rain must not project moving, oversized stripes onto walls.
	rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)

func _tree(pos:Vector3,size:float) -> void:
	var tree:=Node3D.new()
	tree.position=pos
	tree.scale=Vector3.ONE*size
	add_child(tree)
	cylinder(tree,Vector3(0,2.3,0),0.2,4.6,"wood",0.11)
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in range(7):
		var angle:=float(leaf)*TAU/7.0
		var direction:=Vector3(cos(angle),0,sin(angle))
		var across:=Vector3(-sin(angle),0,cos(angle))
		for segment in range(4):
			var t:=float(segment)/4.0
			var u:=float(segment+1)/4.0
			var a:=Vector3(0,4.6,0)+direction*(t*3.2)+Vector3(0,sin(t*PI)*0.7-t*0.9,0)
			var b:=Vector3(0,4.6,0)+direction*(u*3.2)+Vector3(0,sin(u*PI)*0.7-u*0.9,0)
			var w:=sin(t*PI)*0.36
			var v:=sin(u*PI)*0.36
			for p in [a-across*w,b-across*v,a+across*w,a+across*w,b-across*v,b+across*v]:st.add_vertex(p)
	st.generate_normals()
	var leaves:=MeshInstance3D.new()
	leaves.mesh=st.commit()
	var mat:StandardMaterial3D=materials["green"].duplicate()
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	leaves.material_override=mat
	tree.add_child(leaves)

func _sync_state() -> void:
	active_lights=Session.has_flag("fuse")
	salt.visible=Session.has_flag("salt_line")
	portrait.rotation.y=-PI/2+(PI if Session.has_flag("portrait") else 0.0)
	for id in ["shutter_kitchen","shutter_lola","shutter_family"]:
		var item:HouseInteractable=interactables[id]
		if item.visual:
			item.visual.rotation.z=PI/2 if Session.has_flag(id) else 0.0
	for i in range(candles.size()):
		candles[i].visible=Session.has_flag("candles")
		candles[i].get_meta("flame").visible=Session.has_flag("candles")
	interactables["pact"].enabled=Session.has_flag("title")
	interactables["pact"].collision_layer=2 if Session.has_flag("title") else 0
	interactables["baul"].enabled=not Session.has_flag("title")
	interactables["baul"].collision_layer=0 if Session.has_flag("title") else 2

func apply_quality() -> void:
	if environment:
		environment.environment.ambient_light_energy=0.46*Session.brightness
	if rain:
		rain.multimesh.visible_instance_count=70 if Session.quality=="low" else 180

func _process(delta:float) -> void:
	world_time+=delta
	for i in range(lights.size()):
		var light:=lights[i]
		var pulse:=1.0+sin(world_time*1.7+i*2.4)*0.035
		light.light_energy=(1.2 if active_lights else 0.035)*pulse*Session.brightness
		light.light_color=Color(1,0.68,0.33).lerp(Color(0.87,0.15,0.055),threat*0.6)
	if rain and Session.quality!="low":
		rain.position.y=-fmod(world_time*5.0,7.0)

func spawn_position(id:String) -> Vector3:
	match id:
		"sala":return Vector3(0,0.05,5.7)
		"final":return Vector3(0,0.05,-7.0)
		_:return Vector3(0,0.05,14.5)

func room_at(pos:Vector3) -> String:
	if pos.z>8:return Story.text("THE VERANDA","ANG BERANDA")
	if pos.x < -3:
		if pos.z>2:return Story.text("KITCHEN","KUSINA")
		if pos.z> -4:return Story.text("FAMILY BEDROOM","KUWARTO NG PAMILYA")
		return Story.text("STOREROOM","BODEGA")
	if pos.x>3:
		return Story.text("LOLA'S ROOM","KUWARTO NI LOLA") if pos.z>0 else Story.text("THE OLD ALTAR","ANG LUMANG ALTAR")
	return Story.text("SALA","SALA") if pos.z> -2 else Story.text("BACK HALLWAY","PASILYO SA LIKOD")
