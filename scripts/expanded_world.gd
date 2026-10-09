class_name ExpandedHouse
extends HouseWorld

const CACHE := "res://assets/generated/house_shell.res"
var baking := false
var obstacles_by_floor:Dictionary={0:[],1:[]}
var visuals:Array[Dictionary]=[]
var hatch_lids:Dictionary={}
var offering:MeshInstance3D
var restored_photo:MeshInstance3D
var fire_nodes:Array[MeshInstance3D]=[]
var fire_light:OmniLight3D
var altar_point:=Vector3(7,0,-9)
var radio_point:=Vector3(-9,0.9,5)
var author_zone:=""
var visibility_clock:=0.0
var room_visible:Dictionary={}
var artifact_audit:Dictionary={}
var chunks_root:Node3D
var cache_valid:=false
var cinematic_fire:=false
var cinematic_active:=false
var scare_chair:Node3D

func _ready() -> void:
	cache_valid=not baking and ResourceLoader.exists(CACHE)
	if cache_valid and OS.has_feature("editor"):
		cache_valid=load(CACHE).get_meta("fingerprint","")==source_fingerprint()
	super._ready()

static func source_fingerprint() -> String:
	var sources:=""
	for path in ["expanded_world.gd","world.gd","house_layout.gd","surface_builder.gd"]:
		sources+=FileAccess.get_file_as_string("res://scripts/"+path)
	return sources.sha256_text()

func _zone(pos:Vector3) -> String:
	return author_zone if not author_zone.is_empty() else HouseLayout.room_id(pos)

func _tag(node:Node3D,pos:Vector3) -> void:
	if node.has_meta("zone"):return
	var zone:=_zone(pos)
	node.set_meta("zone",zone)
	visuals.append({"node":node,"zone":zone,"until":0.0})

func box(pos:Vector3,size:Vector3,mat:String,collision:bool=false,rot_y:float=0) -> void:
	if not cache_valid:
		surfaces.add_box(pos,size,mat,rot_y)
		surfaces.boxes[-1]["chunk"]=_zone(pos)
	if collision:_block(pos,size,rot_y).set_meta("surface",mat)

func _block(pos:Vector3,size:Vector3,rot_y:float=0) -> StaticBody3D:
	var body:=super._block(pos,size,rot_y)
	var extent:=Vector2(size.x,size.z)
	if absf(sin(rot_y))>0.5:extent=Vector2(size.z,size.x)
	for level in [0,1]:
		var base:=float(level)*HouseLayout.UPPER
		if pos.y+size.y/2>base+0.4 and pos.y-size.y/2<base+1.5:
			obstacles_by_floor[level].append(Rect2(Vector2(pos.x,pos.z)-extent/2,extent))
	return body

func mesh_box(parent:Node3D,pos:Vector3,size:Vector3,mat:String) -> MeshInstance3D:
	var node:=super.mesh_box(parent,pos,size,mat)
	if parent==self:_tag(node,pos)
	return node

func cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,mat:String,top:float=-1) -> MeshInstance3D:
	var node:=super.cylinder(parent,pos,radius,height,mat,top)
	if parent==self:_tag(node,pos)
	return node

func _prop(model:String,pos:Vector3,scale_factor:float=1,rot:float=0,footprint:Vector3=Vector3.ZERO) -> Node3D:
	var node:=super._prop(model,pos,scale_factor,rot,footprint)
	if node:_tag(node,pos)
	return node

func _flush_batches() -> void:
	if cache_valid:
		chunks_root=(load(CACHE) as PackedScene).instantiate()
		surface_audit=chunks_root.get_meta("audit",{}).duplicate(true)
	else:
		surfaces.resolve()
		surface_audit=surfaces.stats.duplicate()
		surface_audit["remaining_conflicts"]=surfaces.conflicts().size()
		chunks_root=Node3D.new()
		chunks_root.name="ResolvedShell"
		var meshes:=surfaces.create_meshes(materials)
		for key in meshes:
			var node:=MeshInstance3D.new()
			node.mesh=meshes[key]
			node.name=str(key).replace("|","_")
			node.set_meta("zone",str(key).split("|")[0])
			chunks_root.add_child(node)
			node.owner=chunks_root
		chunks_root.set_meta("audit",surface_audit)
	add_child(chunks_root)
	for child in chunks_root.get_children():
		visuals.append({"node":child,"zone":child.get_meta("zone","yard"),"until":0.0})
	if baking:
		DirAccess.make_dir_recursive_absolute("res://assets/generated")
		var packed:=PackedScene.new()
		packed.pack(chunks_root)
		packed.set_meta("fingerprint",source_fingerprint())
		assert(ResourceSaver.save(packed,CACHE)==OK)

func _floor(rect:Rect2,y:float,cuts:Array,mat:String="wood") -> void:
	var pieces:Array[Rect2]=[rect]
	for cut in cuts:
		var next:Array[Rect2]=[]
		for piece in pieces:next.append_array(HouseSurfaceBuilder.subtract_rect(piece,cut))
		pieces=next
	for piece in pieces:
		box(Vector3(piece.get_center().x,y-0.18,piece.get_center().y),Vector3(piece.size.x,0.36,piece.size.y),mat,true)

func _wall(axis:String,a:float,b:float,line:float,level:int,material_name:String="plaster") -> void:
	var openings:Array[float]=[]
	for d in HouseLayout.DOORS:
		if d[1]!=axis or d[4]!=level:continue
		var center:float=d[2] if axis=="x" else d[3]
		var fixed:float=d[3] if axis=="x" else d[2]
		if is_equal_approx(fixed,line) and center>a+0.86 and center<b-0.86:openings.append(center)
	openings.sort()
	var start:=a
	for point in openings:
		_wall_segment(axis,start,point-0.86,line,level,material_name)
		var p:=Vector3(point,float(level)*3.6+2.97,line) if axis=="x" else Vector3(line,float(level)*3.6+2.97,point)
		# The service ramp passes through this opening: leave full rising headroom.
		if not (axis=="x" and level==0 and is_equal_approx(line,-6) and is_equal_approx(point,-9.6)):
			box(p,Vector3(1.72,0.54,0.22) if axis=="x" else Vector3(0.22,0.54,1.72),material_name,true)
		start=point+0.86
	_wall_segment(axis,start,b,line,level,material_name)

func _wall_segment(axis:String,a:float,b:float,line:float,level:int,mat:String) -> void:
	if b-a<0.001:return
	var p:=Vector3((a+b)/2,float(level)*3.6+1.62,line) if axis=="x" else Vector3(line,float(level)*3.6+1.62,(a+b)/2)
	var size:=Vector3(b-a,3.24,0.22) if axis=="x" else Vector3(0.22,3.24,b-a)
	box(p,size,mat,true)
	p.y=float(level)*3.6+0.5
	size.y=0.85
	box(p,size+Vector3(0.035,0,0.035),"darkwood")

func _structure() -> void:
	var ground_cuts:Array=[HouseLayout.COURT]
	for p in HouseLayout.HATCHES.values():ground_cuts.append(Rect2(p.x-0.55,p.z-0.55,1.1,1.1))
	author_zone="shell_0"
	_floor(HouseLayout.BOUNDS,0,ground_cuts)
	var upper_cuts:Array=[HouseLayout.COURT]
	for stair in HouseLayout.STAIRS:upper_cuts.append(Rect2(stair.x-1,stair.z-stair.run-0.15,2,stair.run+0.3))
	author_zone="shell_1"
	_floor(HouseLayout.BOUNDS,3.6,upper_cuts)
	author_zone="roof"
	_floor(HouseLayout.BOUNDS,7.15,[HouseLayout.COURT],"darkwood")
	for level in [0,1]:
		author_zone="shell_%s"%level
		for z in [-12.0,8.0]:_wall("x",-11,11,z,level)
		for x in [-11.0,11.0]:_wall("z",-12,8,x,level)
		for room in HouseLayout.ROOMS:
			if room[1]!=level:continue
			# Boundary walls remain visible from galleries and adjacent rooms.
			# Only furniture/lights may disappear when a room is not in view.
			author_zone="shell_%s"%level
			var r:Rect2=room[2]
			_wall("x",r.position.x,r.end.x,r.position.y,level)
			_wall("x",r.position.x,r.end.x,r.end.y,level)
			_wall("z",r.position.y,r.end.y,r.position.x,level)
			_wall("z",r.position.y,r.end.y,r.end.x,level)
		author_zone="gallery_%s"%level
		# Courtyard balustrades leave two independent galleries on either side.
		for x in [-1.5,1.5]:
			box(Vector3(x,level*3.6+0.52,-2),Vector3(0.12,1.04,4.0),"darkwood",true)
		if level==1:
			for z in [-4.0,0.0]:box(Vector3(0,4.12,z),Vector3(3.0,1.04,0.12),"darkwood",true)
	author_zone=""
	for d in HouseLayout.DOORS:
		var point:=Vector3(d[2],d[4]*3.6,d[3])
		_door(d[0],point+Vector3(-0.85,0,0) if d[1]=="x" else point+Vector3(0,0,-0.85),0 if d[1]=="x" else -PI/2,1.7)
		_tag(doors[d[0]].hinge,point)
	for stair in HouseLayout.STAIRS:_stair(stair)
	_crawlspace()

func _stair(stair:Dictionary) -> void:
	author_zone="stairs"
	for i in range(20):
		var height:float=(i+1)*0.18
		box(Vector3(stair.x,height/2,stair.z-(i+0.5)*0.3),Vector3(stair.width,height,0.3),"wood")
	# Smooth non-rendered collision, so walking needs neither jumping nor step hacks.
	var verts:=PackedVector3Array()
	for x in [stair.x-stair.width/2,stair.x+stair.width/2]:
		for p in [Vector2(stair.z,0),Vector2(stair.z-stair.run,0),Vector2(stair.z-stair.run,3.6)]:
			verts.append(Vector3(x,p.y,p.x))
	var ramp:=StaticBody3D.new()
	var col:=CollisionShape3D.new()
	var shape:=ConvexPolygonShape3D.new()
	shape.points=verts
	col.shape=shape
	ramp.add_child(col)
	add_child(ramp)
	for side in [-1,1]:
		for i in range(7):
			var z:float=stair.z-float(i)
			var y:float=float(i)*0.6
			box(Vector3(stair.x+side*(stair.width/2+0.12),y+0.6,z),Vector3(0.1,1.2,0.1),"darkwood",true)
		var rail:=mesh_box(self,Vector3(stair.x+side*(stair.width/2+0.12),2.9,stair.z-3),Vector3(0.1,0.1,7.0),"darkwood")
		rail.rotation.x=atan(0.6)
	author_zone=""

func _crawlspace() -> void:
	author_zone="crawl"
	for r in HouseLayout.CRAWL_RECTS:_floor(r,HouseLayout.CRAWL,[],"concrete")
	# Low walls arranged around the L-shaped path and its small side recess.
	for data in [
		[Vector3(-4.5,-0.96,-5),Vector3(2.2,1.2,0.16)],
		[Vector3(-3.5,-0.96,-6.5),Vector3(0.16,1.2,3)],
		[Vector3(-8,-0.96,-6),Vector3(0.16,1.2,2)],
		[Vector3(-6.7,-0.96,-5),Vector3(2.6,1.2,0.16)],
		[Vector3(-6.7,-0.96,-7),Vector3(2.6,1.2,0.16)],
		[Vector3(-5.5,-0.96,-8.5),Vector3(0.16,1.2,3)],
		[Vector3(-2.25,-0.96,-10),Vector3(6.5,1.2,0.16)],
		[Vector3(-1.25,-0.96,-8),Vector3(4.5,1.2,0.16)],
		[Vector3(1,-0.96,-9),Vector3(0.16,1.2,2)]
	]:box(data[0],data[1],"mold",true)
	for data in [["portrait",Vector3(-7.3,-0.85,-6)],["clock",Vector3(-4.5,-0.85,-9.6)],["bowl",Vector3(-1.4,-0.85,-9.6)]]:
		cylinder(self,data[1],0.14,0.32,"brass")
		_item("binding_"+data[0],data[1],Vector3(0.4,0.4,0.4),"Unbind: "+data[0],"Kalagin: "+{"portrait":"larawan","clock":"orasan","bowl":"mangkok"}[data[0]])
		_label3d(data[0].to_upper(),data[1]+Vector3(0,0.2,0),0)
	_note_mesh(Vector3(-6.7,-1.25,-6.2),"crawl_lore","Read the marks on the beam","Basahin ang marka sa biga")
	for id in HouseLayout.HATCHES:
		var p:Vector3=HouseLayout.HATCHES[id]
		var hatch:=Node3D.new()
		hatch.position=p
		add_child(hatch)
		var lid:=mesh_box(hatch,Vector3(0,-0.06,0),Vector3(1.06,0.12,1.06),"darkwood")
		var body:=StaticBody3D.new()
		var col:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(1.06,0.12,1.06)
		col.shape=shape
		col.position.y=-0.06
		body.add_child(col)
		hatch.add_child(body)
		hatch_lids[id]=lid
		author_zone=""
		_tag(hatch,p)
		_item("hatch_"+id,p+Vector3(0,0.18,0),Vector3(1.05,0.4,1.05),"Enter the crawlspace","Bumaba sa ilalim ng bahay")
		author_zone="crawl"
		_item("hatch_exit_"+id,p+Vector3(0,-0.7,0),Vector3(0.9,0.8,0.9),"Climb out: "+id,"Umahon mula sa ilalim")
	author_zone=""

func _furnish() -> void:
	for room in HouseLayout.ROOMS:
		author_zone=room[0]
		var r:Rect2=room[2]
		var p:=Vector3(r.get_center().x,room[1]*3.6,r.get_center().y)
		if room[0] in ["family","guest","lola","tomas"]:
			var bedpos:=p+Vector3(1.0 if room[0]=="lola" else -1.5,0,0)
			if room[0]=="guest":bedpos=Vector3(8.5,3.6,3.4)
			_prop("bedSingle",bedpos,1.7,0,Vector3(1.2,0.7,2.2))
			_prop("cabinetBed",p+Vector3(1.4,0,1.2),1.6,0,Vector3(0.7,0.8,0.7))
			box(bedpos+Vector3(0,0.69,0.2),Vector3(1.1,0.04,1.6),"woven")
		elif room[0]=="wash":
			_prop("kitchenSink",p+Vector3(-0.9,0,-1),1.6,0,Vector3(0.9,0.9,0.7))
			cylinder(self,p+Vector3(0.6,0.35,1.0),0.3,0.7,"blue")
			box(p+Vector3(0,0.018,0),Vector3(2,0.02,3),"tiles")
			box(p+Vector3(-1.8,1.8,-1),Vector3(0.04,0.8,0.6),"black")
		elif room[0]=="kitchen":
			_prop("kitchenCabinet",Vector3(-6.6,0,-11.2),1.6,0,Vector3(0.8,0.8,0.6))
			_prop("kitchenStove",Vector3(-7.5,0,-11.2),1.6,0,Vector3(0.8,0.8,0.6))
			_table(Vector3(-7,0,-8.1),Vector2(1.3,1.0))
		elif room[0]=="store":
			box(Vector3(1.2,0.4,-10.7),Vector3(1.7,0.8,0.85),"darkwood",true)
			box(Vector3(1.2,0.85,-10.7),Vector3(1.8,0.1,0.9),"wood")
			_prop("bookcaseOpen",Vector3(-2,0,-10.5),1.6,0,Vector3(0.65,1.8,1.1))
		elif room[0]=="altar":
			_table(Vector3(7,0,-9.5),Vector2(2.5,1.1),0.95)
			box(Vector3(7,1.02,-9.5),Vector3(2.35,0.02,1.0),"cloth")
			scare_chair=_prop("chair",Vector3(7,0,-7.4),1.7,PI,Vector3(0.6,0.9,0.6))
		else:
			_table(p+Vector3(-0.15,0,-0.1) if room[0]=="sewing" else p+Vector3(0,0,-0.8),Vector2(1.5,0.9),0.76)
			_prop("chair",p+Vector3(0,0,0.5),1.5,PI,Vector3(0.5,0.8,0.5))
			if room[0] in ["study","pantry"]:_prop("bookcaseOpen",p+Vector3(-1,0,-1.8),1.5,0,Vector3(0.6,1.7,1))
		# Each room has an inexpensive lamp, room plaque and a personal detail.
		var light:=OmniLight3D.new()
		light.position=p+Vector3(0,2.8,0)
		light.omni_range=5.2
		light.light_color=Color(1,0.7,0.4)
		add_child(light)
		lights.append(light)
		_tag(light,p)
		cylinder(self,p+Vector3(0,2.95,0),0.16,0.12,"lamp")
		var plaque:=Vector3(r.get_center().x,room[1]*3.6+2.7,r.position.y+0.16)
		_label3d(room[4],plaque,0)
		if room[0] not in ["altar","kitchen","store"]:
			cylinder(self,p+Vector3(0.35,0.9,-0.1) if room[0]=="sewing" else p+Vector3(0.6,0.9,-0.8),0.07,0.18,"white")
			box(p+Vector3(-0.55,0.84,0.1) if room[0]=="sewing" else p+Vector3(-0.3,0.84,-0.8),Vector3(0.24,0.01,0.32),"paper")
	author_zone=""
	_prop("radio",radio_point,1.5,0)
	_table(Vector3(-9,0,5),Vector2(1.2,0.7),0.78)
	_note_mesh(Vector3(-6.5,0.84,4.3),"rules","Read Lola's instructions","Basahin ang bilin ni Lola")
	_item("fuse",Vector3(-1.7,1.5,7.65),Vector3(0.6,0.8,0.3),"Restore the power","Buksan ang kuryente")
	box(Vector3(-1.7,1.5,7.79),Vector3(0.5,0.65,0.14),"black")
	_note_mesh(Vector3(-8.5,0.84,5.2),"memory_tape","Examine the forbidden cassette","Suriin ang ipinagbabawal na cassette")
	_item("radio",radio_point+Vector3(0,0.15,0),Vector3(0.8,0.6,0.5),"Play the forbidden tape · reject the rules","Patugtugin ang cassette · tanggihan ang mga bilin")
	_note_mesh(Vector3(-6,4.42,-5.1),"memory_letter","Read the unsent letter","Basahin ang liham")
	_table(Vector3(-6,3.6,-5.1),Vector2(1.0,0.6),0.76)
	_note_mesh(Vector3(-7,4.35,4.2),"memory_photo","Examine the cut photograph","Suriin ang ginupit na larawan")
	_table(Vector3(-7,3.6,4.2),Vector2(1.0,0.6),0.69)
	_note_mesh(Vector3(7,4.4,-6),"tomas_clue","Read Tomas's notebook","Basahin ang tala ni Tomas")
	_table(Vector3(7,3.6,-6),Vector2(1.0,0.6),0.74)
	_item("winding_key",Vector3(-5.4,4.45,-1.8),Vector3(0.4,0.3,0.4),"Take the clock winding key","Kunin ang susi ng orasan")
	cylinder(self,Vector3(-5.4,4.4,-1.8),0.07,0.1,"brass")
	_item("sewing",Vector3(-3.4,4.5,-9.6),Vector3(1.2,0.7,0.8),"Restore Tomas's photograph","Buuin ang larawan ni Tomas")
	# Original low-poly sewing machine; no large asset pack required.
	box(Vector3(-3.4,4.65,-9.6),Vector3(0.65,0.3,0.18),"black")
	box(Vector3(-3.4,4.43,-9.6),Vector3(0.75,0.14,0.42),"black")
	cylinder(self,Vector3(-3.1,4.78,-9.6),0.12,0.09,"brass")
	restored_photo=mesh_box(self,Vector3(-3.95,4.42,-9.35),Vector3(0.32,0.012,0.42),"paper")
	var print_face:=MeshInstance3D.new()
	var print_mesh:=QuadMesh.new()
	print_mesh.size=Vector2(0.32,0.42)
	print_face.mesh=print_mesh
	var print_material:=StandardMaterial3D.new()
	print_material.albedo_texture=load("res://assets/textures/family-restored.svg")
	print_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	print_face.material_override=print_material
	print_face.position.y=0.008
	print_face.rotation.x=-PI/2
	restored_photo.add_child(print_face)
	_item("baul",Vector3(1.2,0.6,-10.3),Vector3(1.8,1.0,1),"Unlock Lola's baul","Buksan ang baul ni Lola")
	_note_mesh(Vector3(1.2,0.92,-10.6),"pact","Read the family agreement","Basahin ang kasunduan")
	for data in [
		["rice",Vector3(-7,1.04,-8.1),"Take a bowl of rice","Kumuha ng kanin"],
		["salt",Vector3(-6.5,1.04,-8.1),"Take salt","Kunin ang asin"],
		["matches",Vector3(-7.4,1.04,-8.1),"Take the matches","Kunin ang posporo"]
	]:
		cylinder(self,data[1],0.12,0.12,"white" if data[0]!="matches" else "red")
		_item(data[0],data[1],Vector3(0.3,0.3,0.3),data[2],data[3])
	_item("altar",Vector3(7,1.13,-9.2),Vector3(0.8,0.35,0.55),"Offer rice · keep Lola's promise","Ialay ang kanin · tuparin ang pangako")
	offering=cylinder(self,Vector3(7,1.13,-9.25),0.2,0.18,"white",0.25)
	for i in range(3):
		var p:=Vector3(6.3+i*0.7,1.24,-9.7)
		cylinder(self,p,0.055,0.37,"white")
		var flame:=cylinder(self,p+Vector3(0,0.23,0),0.028,0.08,"lamp",0)
		var light:=OmniLight3D.new()
		light.position=p+Vector3(0,0.27,0)
		light.omni_range=2
		light.light_color=Color(1,0.6,0.2)
		light.light_energy=0.65
		light.set_meta("flame",flame)
		add_child(light)
		candles.append(light)
		_item("candle_%s"%i,p,Vector3(0.35,0.5,0.4),"Light candle %s"%(i+1),"Sindihan ang kandila %s"%(i+1))
	salt=mesh_box(self,Vector3(3,0.03,-5.4),Vector3(0.12,0.025,1.65),"salt")
	_item("threshold",Vector3(3,0.45,-5.4),Vector3(0.7,0.8,1.6),"Lay the salt ward","Ilatag ang asin")
	_window(Vector3(-7.4,1.9,-11.78),0,"shutter_kitchen")
	_window(Vector3(-6.5,5.5,-11.78),0,"shutter_lola")
	_window(Vector3(10.78,5.5,5),-PI/2,"shutter_family")
	_fire()

func _details() -> void:
	# Reuse the independently separated portrait/clock meshes, relocated into dining.
	super._details()
	portrait.position=Vector3(-3.22,1.9,-2)
	portrait.rotation.y=PI/2
	interactables.portrait.position=Vector3(-3.38,1.9,-2)
	_tag(portrait,portrait.position)
	var clock:=clock_hour.get_parent() as Node3D
	clock.position=Vector3(-10.78,2.05,-1)
	clock.rotation.y=PI/2
	interactables.clock.position=Vector3(-10.6,2.05,-1)
	_tag(clock,clock.position)

func _exterior() -> void:
	# Real non-overlapping yard slabs; the entrance remains flush at y=0.
	author_zone="yard"
	_floor(Rect2(-13,-14,26,35),0,[HouseLayout.BOUNDS],"concrete")
	_floor(HouseLayout.COURT,0,[],"tiles")
	for x in [-10.8,-3.0,3.0,10.8]:box(Vector3(x,1.55,10.5),Vector3(0.2,3.1,0.2),"darkwood",true)
	box(Vector3(0,3.2,9.4),Vector3(22.4,0.18,3.2),"darkwood")
	for x in [-12.7,12.7]:box(Vector3(x,0.55,3),Vector3(0.2,1.1,35),"darkwood",true)
	box(Vector3(0,0.55,21),Vector3(26,1.1,0.2),"darkwood",true)
	for p in [Vector3(-10,0,16),Vector3(10,0,16),Vector3(12,0,-11)]:_tree(p,1.1)
	_item("gate",Vector3(0,1,19),Vector3(4,2,0.3),"Leave the house","Umalis sa bahay")
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	var drop:=BoxMesh.new()
	drop.size=Vector3(0.01,0.2,0.01)
	drop.material=materials.moon
	mm.mesh=drop
	mm.instance_count=180
	var rng:=RandomNumberGenerator.new()
	rng.seed=1954
	for i in range(180):mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-11,11),rng.randf_range(0,8),rng.randf_range(11,20))))
	rain=MultiMeshInstance3D.new()
	rain.multimesh=mm
	rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	author_zone=""

func _fire() -> void:
	var flame_material:=ShaderMaterial.new()
	flame_material.shader=load("res://shaders/fire.gdshader")
	for i in range(12):
		var node:=mesh_box(self,Vector3(4.2+(i%4)*1.7,0.5,-10.8+(i/4)*1.7),Vector3(0.18,0.9,0.18),"red")
		node.material_override=flame_material
		fire_nodes.append(node)
	for i in range(8):
		var node:=cylinder(self,Vector3(-8.5+i*2.4,1.4+sin(i*3)*0.25,8.32),0.4,2.3+sin(i*2)*0.5,"lamp",0.02)
		node.material_override=flame_material
		fire_nodes.append(node)
	fire_light=OmniLight3D.new()
	fire_light.position=Vector3(7,2,-8)
	fire_light.light_color=Color(1,0.23,0.03)
	fire_light.omni_range=10
	fire_light.light_energy=2.5
	add_child(fire_light)

func _sync_state() -> void:
	active_lights=Session.has_flag("fuse")
	if not offering:return
	offering.visible=Session.has_flag("offering")
	salt.visible=Session.has_flag("salt_line")
	portrait.rotation.y=PI/2+(PI if Session.has_flag("portrait") else 0)
	restored_photo.visible=Session.has_flag("photo_restored")
	for id in ["shutter_kitchen","shutter_lola","shutter_family"]:
		interactables[id].visual.rotation.z=PI/2 if Session.has_flag(id) else 0
	for i in range(3):
		var on:=Session.has_flag("candle_%s"%i)
		candles[i].visible=on
		candles[i].get_meta("flame").visible=on
	interactables.pact.enabled=Session.has_flag("title")
	interactables.pact.collision_layer=2 if Session.has_flag("title") else 0
	interactables.baul.enabled=not Session.has_flag("title")
	interactables.baul.collision_layer=0 if Session.has_flag("title") else 2
	var candle_phase:=Session.route==Session.Route.KEEPER and Session.has_flag("pact") and not Session.has_flag("ritual_survived")
	interactables.altar.enabled=not candle_phase
	interactables.altar.collision_layer=0 if candle_phase else 2
	for flame in fire_nodes:flame.visible=cinematic_fire if cinematic_active else Session.has_flag("pact_burned")
	fire_light.visible=cinematic_fire if cinematic_active else Session.has_flag("pact_burned")

func _process(delta:float) -> void:
	super._process(delta)
	if not fire_nodes.is_empty() and (Session.has_flag("pact_burned") or cinematic_fire):
		for i in range(fire_nodes.size()):fire_nodes[i].scale.y=0.9+sin(world_time*2+i)*0.22

func update_visibility(camera:Camera3D,delta:float) -> void:
	visibility_clock-=delta
	if visibility_clock>0:return
	visibility_clock=0.3
	var current:=HouseLayout.room_id(camera.global_position-Vector3(0,1.4,0))
	room_visible.clear()
	var space:=get_world_3d().direct_space_state
	for room in HouseLayout.ROOMS:
		var id:String=room[0]
		var seen:bool=id==current
		var r:Rect2=room[2]
		for point in [r.get_center(),r.position+Vector2(0.4,0.4),r.end-Vector2(0.4,0.4),Vector2(r.position.x+0.4,r.end.y-0.4),Vector2(r.end.x-0.4,r.position.y+0.4)]:
			if seen:break
			var target:=Vector3(point.x,room[1]*3.6+1.4,point.y)
			if camera.global_position.distance_to(target)>22:continue
			var query:=PhysicsRayQueryParameters3D.create(camera.global_position,target,1)
			seen=space.intersect_ray(query).is_empty()
		room_visible[id]=seen
	for record in visuals:
		var id:String=record.zone
		if not room_visible.has(id):continue
		if room_visible[id]:record.until=world_time+0.9
		record.node.visible=bool(room_visible[id]) or world_time<float(record.until)
	# Story-controlled props have their own visibility, never resurrect them via culling.
	var cinema_seal:=cinematic_active and not cinematic_fire
	offering.visible=(Session.has_flag("offering") or cinema_seal) and room_visible.get("altar",true)
	restored_photo.visible=Session.has_flag("photo_restored") and room_visible.get("sewing",true)
	for flame in fire_nodes:flame.visible=cinematic_fire if cinematic_active else Session.has_flag("pact_burned")
	fire_light.visible=cinematic_fire if cinematic_active else Session.has_flag("pact_burned")
	for i in range(candles.size()):
		var on:bool=(Session.has_flag("candle_%s"%i) or cinema_seal) and room_visible.get("altar",true)
		candles[i].visible=on
		candles[i].get_meta("flame").visible=on

func spawn_position(id:String) -> Vector3:
	return HouseLayout.SPAWNS.get(id,HouseLayout.SPAWNS.entry)

func room_at(pos:Vector3) -> String:
	return HouseLayout.room_name(pos)
