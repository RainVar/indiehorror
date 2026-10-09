class_name ListeningEntity
extends CharacterBody3D
## Deterministic hearing and bounded pathfinding. No navigation baking or threads.

signal caught
signal state_changed(state: String)
signal cue(kind: String, position: Vector3)

enum State { DORMANT, INVESTIGATE, SEARCH, HUNT, RETREAT }
var state: State = State.DORMANT
var world: HouseWorld
var player: HousePlayer
var grid: AStar3D
var cell_nodes:Dictionary={}
var salt_nodes:Array[int]=[]
var chase_locked:bool=false
var target_point := Vector3.ZERO
var path: PackedVector3Array = []
var repath_timer: float = 0.0
var state_timer: float = 0.0
var grace: float = 14.0
var suspicion: float = 0.0
var enabled: bool = false
var visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var head: Node3D
var animation_time: float = 0.0
var cycle_time: float = 0.0
var listening: bool = false
var _last_cue: float = 0.0
var _stuck: float = 0.0
var _last_position := Vector3.ZERO
var salt_cells:Dictionary={}

func _ready() -> void:
	collision_layer=8
	collision_mask=1
	floor_snap_length=0.3
	floor_constant_speed=true
	var col:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.23
	capsule.height=2.4
	col.shape=capsule
	col.position.y=1.2
	add_child(col)
	_build_creature()
	visible=false

func setup(house:HouseWorld,hero:HousePlayer) -> void:
	world=house
	player=hero
	_build_grid()
	Session.changed.connect(_sync_salt)
	_sync_salt()
	reset()

func _sync_salt() -> void:
	if not grid:return
	var closed:=Session.has_flag("salt_line") and not Session.has_flag("sealed")
	for id in salt_nodes:grid.set_point_disabled(id,closed)
	repath_timer=0.0

func _build_creature() -> void:
	visual=Node3D.new()
	add_child(visual)
	var cloth:=StandardMaterial3D.new()
	cloth.albedo_color=Color(0.032,0.041,0.036)
	cloth.roughness=1.0
	var bone:=StandardMaterial3D.new()
	bone.albedo_color=Color(0.4,0.43,0.34)
	bone.roughness=1.0
	var mouth:=StandardMaterial3D.new()
	mouth.albedo_color=Color(0.012,0.009,0.008)
	# Jagged dress: uneven rings produce a memorable silhouette at very low cost.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=[Vector2(0.48,0.12),Vector2(0.36,0.8),Vector2(0.23,1.35),Vector2(0.44,1.85),Vector2(0.12,2.03)]
	for ring in range(rings.size()-1):
		for j in range(10):
			var a:=float(j)*TAU/10
			var b:=float(j+1)*TAU/10
			var r0:Vector2=rings[ring]
			var r1:Vector2=rings[ring+1]
			var p0:=Vector3(cos(a)*r0.x,r0.y+(0.07*sin(j*4) if ring==0 else 0.0),sin(a)*r0.x*0.62)
			var p1:=Vector3(cos(b)*r0.x,r0.y+(0.07*sin((j+1)*4) if ring==0 else 0.0),sin(b)*r0.x*0.62)
			var p2:=Vector3(cos(a)*r1.x,r1.y,sin(a)*r1.x*0.62)
			var p3:=Vector3(cos(b)*r1.x,r1.y,sin(b)*r1.x*0.62)
			for p in [p0,p2,p1,p1,p2,p3]:
				st.add_vertex(p)
	st.generate_normals()
	var robe:=MeshInstance3D.new()
	robe.mesh=st.commit()
	robe.material_override=cloth
	visual.add_child(robe)
	head=Node3D.new()
	head.position=Vector3(0,2.1,-0.03)
	visual.add_child(head)
	var mask:=MeshInstance3D.new()
	var skull:=SphereMesh.new()
	skull.radius=0.17
	skull.height=0.5
	skull.radial_segments=8
	skull.rings=4
	skull.material=bone
	mask.mesh=skull
	mask.position=Vector3(0,0.17,0)
	mask.scale=Vector3(0.85,1.0,0.75)
	head.add_child(mask)
	_limb(head,Vector3(0,0.06,0.115),Vector3(0.04,0.19,0.028),mouth)
	# A cloth blindfold where the eyes should be, not glowing eyes.
	_limb(head,Vector3(0,0.25,0.116),Vector3(0.27,0.055,0.025),cloth)
	_limb(head,Vector3(-0.145,-0.08,-0.06),Vector3(0.055,0.62,0.09),cloth)
	_limb(head,Vector3(0.145,-0.02,-0.06),Vector3(0.045,0.49,0.09),cloth)
	for side in [-1.0,1.0]:
		var arm:=Node3D.new()
		arm.position=Vector3(side*0.37,1.8,0)
		arm.rotation.z=side*0.13
		visual.add_child(arm)
		_limb(arm,Vector3(side*0.05,-0.5,0),Vector3(0.11,1.0,0.12),cloth)
		_limb(arm,Vector3(side*0.09,-1.09,0),Vector3(0.085,0.28,0.09),bone)
		for f in range(4):
			_limb(arm,Vector3(side*0.09+(f-1.5)*0.024,-1.32,0.015),Vector3(0.015,0.24+0.025*sin(f),0.02),bone)
		if side<0:left_arm=arm
		else:right_arm=arm

func _limb(parent:Node3D,pos:Vector3,size:Vector3,mat:Material) -> void:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	mesh.material=mat
	node.mesh=mesh
	node.position=pos
	parent.add_child(node)

func _build_grid() -> void:
	grid=AStar3D.new()
	cell_nodes.clear()
	salt_nodes.clear()
	for level in [0,1]:
		for x in range(-21,22):
			for z in range(-23,16):
				var p:=Vector2(x*0.5,z*0.5)
				var solid:bool=level==1 and HouseLayout.COURT.grow(0.25).has_point(p)
				for stair in HouseLayout.STAIRS:
					if Rect2(stair.x-1,stair.z-stair.run-0.15,2,stair.run+0.3).has_point(p):solid=true
				for rect in world.obstacles_by_floor[level]:
					if rect.grow(0.24).has_point(p):solid=true;break
				if solid:continue
				var key:=Vector3i(x,level,z)
				var id:int=level*4096+(x+24)*64+z+28
				cell_nodes[key]=id
				grid.add_point(id,Vector3(p.x,level*3.6+0.05,p.y))
				if level==0 and Rect2(2.7,-6.25,0.6,1.7).has_point(p):salt_nodes.append(id)
	for key in cell_nodes:
		for step in [Vector3i(1,0,0),Vector3i(0,0,1)]:
			if cell_nodes.has(key+step):grid.connect_points(cell_nodes[key],cell_nodes[key+step])
	for s in range(HouseLayout.STAIRS.size()):
		var stair:Dictionary=HouseLayout.STAIRS[s]
		var ground:int=grid.get_closest_point(Vector3(stair.x,0.05,stair.z+0.5))
		var upper:int=grid.get_closest_point(Vector3(stair.x,3.65,stair.z-stair.run-0.5))
		var previous:=ground
		for i in range(13):
			var id:=10000+s*100+i
			grid.add_point(id,Vector3(stair.x,i*0.3+0.05,stair.z-i*0.5))
			grid.connect_points(previous,id)
			previous=id
		grid.connect_points(previous,upper)

func _nearest_cell(point:Vector3) -> int:
	return grid.get_closest_point(point)

func reset() -> void:
	state=State.DORMANT
	state_timer=0.0
	grace=18.0
	suspicion=0.0
	cycle_time=0.0
	position=Vector3(0,0.05,-10.5)
	chase_locked=false
	visible=false
	path.clear()
	velocity=Vector3.ZERO
	listening=false

func hear(pos:Vector3,intensity:float,category:String) -> void:
	if not enabled or not Session.has_flag("rules") or grace>0.0 or not HouseLayout.BOUNDS.has_point(Vector2(pos.x,pos.z)) or pos.y < -0.6:
		return
	var distance:=global_position.distance_to(pos)
	var effective:=intensity*clampf(1.0-distance/20.0,0.18,1.0)
	if not listening and state==State.DORMANT:
		effective*=0.3
	if effective<0.1:return
	suspicion=clampf(suspicion+effective*0.65,0,1)
	if category in ["phone","radio"]:
		target_point=pos
		_change(State.INVESTIGATE,9.0)
	elif effective>0.48 or suspicion>0.65:
		target_point=pos
		_change(State.HUNT,9.0)
	elif effective>0.17 or suspicion>0.28:
		target_point=pos
		_change(State.INVESTIGATE,8.0)
	repath_timer=0.0

func _change(next:State,duration:float) -> void:
	if state!=next:
		state_changed.emit(State.keys()[next].to_lower())
		if next==State.HUNT:cue.emit("whisper",position)
	state=next
	state_timer=duration
	visible=state!=State.DORMANT

func _sees_player() -> bool:
	if not HouseLayout.BOUNDS.has_point(Vector2(player.position.x,player.position.z)) or player.position.y < -0.6:return false
	var distance:=global_position.distance_to(player.global_position)
	if distance>(5.0 if player.crouching else 7.0):return false
	var from:=global_position+Vector3(0,1.8,0)
	var to:=player.camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(from,to,1|4)
	query.exclude=[get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==player

func _physics_process(delta:float) -> void:
	if not enabled or not is_instance_valid(player) or not Session.has_flag("rules"):
		return
	grace=maxf(0,grace-delta)
	suspicion=move_toward(suspicion,0.0,delta*0.045)
	cycle_time+=delta
	listening=fmod(cycle_time,43.0)>28.0 or Session.has_flag("candles")
	animation_time+=delta
	_last_cue-=delta
	if listening and _last_cue<=0.0:
		cue.emit("knock",position)
		_last_cue=9.0
	if state==State.DORMANT:
		return
	state_timer-=delta
	if chase_locked:state_timer=maxf(state_timer,2.0)
	if _sees_player() and grace<=0.0:
		target_point=player.position
		_change(State.HUNT,5.0)
	if state_timer<=0.0:
		if state==State.INVESTIGATE or state==State.HUNT:
			_change(State.SEARCH,5.0)
		elif state==State.SEARCH:
			target_point=Vector3(0,0,-10.5)
			_change(State.RETREAT,9.0)
		else:
			_change(State.DORMANT,0.0)
			return
	if state==State.SEARCH:
		rotation.y+=delta*0.7
		velocity=Vector3.ZERO
	else:
		repath_timer-=delta
		if repath_timer<=0.0:
			path.clear()
			path=grid.get_point_path(_nearest_cell(position),_nearest_cell(target_point))
			repath_timer=0.7
		while not path.is_empty() and position.distance_to(path[0])<0.28:
			path.remove_at(0)
		if not path.is_empty():
			var direction:Vector3=path[0]-position
			direction.y=0
			direction=direction.normalized()
			var speed:=2.75 if state==State.HUNT else 1.25
			velocity=direction*speed
			velocity.y=-2.0
			rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),delta*6.0)
			for id in world.doors:
				var door:Dictionary=world.doors[id]
				if not door.open and door.hinge.global_position.distance_to(position)<1.9:
					world.toggle_door(id,true)
			move_and_slide()
		else:
			velocity=Vector3.ZERO
			if state==State.INVESTIGATE:_change(State.SEARCH,5.0)
	visual.position.y=sin(animation_time*2.5)*0.028
	head.rotation.z=sin(animation_time*0.8)*0.16
	left_arm.rotation.x=sin(animation_time*3.0)*0.12
	right_arm.rotation.x=-sin(animation_time*3.0)*0.12
	if state!=State.RETREAT and global_position.distance_to(player.global_position)<0.88 and grace<=0.0:
		grace=20.0
		caught.emit()

func threat_level() -> float:
	if not enabled:return 0.0
	if state==State.HUNT:return 1.0
	if state==State.INVESTIGATE or state==State.SEARCH:return 0.6
	return 0.32 if listening else suspicion*0.3
