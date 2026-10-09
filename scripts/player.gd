class_name HousePlayer
extends CharacterBody3D

signal interact_requested
signal journal_requested
signal pause_requested
signal throw_requested
signal footstep(position: Vector3, strength: float)
signal flashlight_changed(on: bool)

var camera: Camera3D
var flashlight: SpotLight3D
var controlled: bool = false
var crouching: bool = false
var flashlight_on: bool = true
var touch_move := Vector2.ZERO
var touch_sprint: bool = false
var stamina: float = 1.0
var step_distance: float = 0.0
var bob_time: float = 0.0
var look_pitch: float = 0.0
var collider: CollisionShape3D
var forced_crouch:bool=false

func _ready() -> void:
	_setup_input()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length=0.28
	floor_constant_speed=true
	name = "Player"
	collider = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.7
	collider.shape = shape
	collider.position.y = 0.87
	add_child(collider)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 1.62
	camera.fov = 76
	camera.near = 0.12
	camera.far = 45
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.13,-0.12,-0.1)
	flashlight.light_color = Color(1.0,0.87,0.65)
	flashlight.light_energy = 2.8
	flashlight.spot_range = 12
	flashlight.spot_angle = 29
	flashlight.spot_attenuation = 1.2
	flashlight.spot_angle_attenuation = 0.8
	flashlight.shadow_enabled = false
	# Compatibility/WebGL needs more than the default bias to avoid banded
	# self-shadowing on flat walls. Keep this modest to retain contact shadows.
	flashlight.shadow_bias = 0.5
	flashlight.shadow_normal_bias = 2.0
	camera.add_child(flashlight)
	Session.settings_changed.connect(apply_quality)
	apply_quality()

func _setup_input() -> void:
	var bindings := {"move_forward":[KEY_W,KEY_UP],"move_back":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"crouch":[KEY_C,KEY_CTRL],"sprint":[KEY_SHIFT],"flashlight":[KEY_F],"journal":[KEY_J,KEY_TAB],"pause_game":[KEY_ESCAPE],"throw_phone":[KEY_Q]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action,event)

func apply_quality() -> void:
	if flashlight:
		flashlight.shadow_enabled = Session.quality == "high"
		flashlight.light_energy = 2.8 * Session.brightness

func set_control(value: bool) -> void:
	controlled = value
	touch_move = Vector2.ZERO
	if not value:
		velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not Session.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controlled:
		return
	# A click is a fresh browser user gesture if capture was lost externally.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not Session.touch_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event.is_action_pressed("interact"):
		interact_requested.emit()
	if event.is_action_pressed("journal"):
		journal_requested.emit()
	if event.is_action_pressed("pause_game"):
		pause_requested.emit()
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	if event.is_action_pressed("crouch"):
		toggle_crouch()
	if event.is_action_pressed("throw_phone"):
		throw_requested.emit()

func look(relative: Vector2) -> void:
	rotation_degrees.y -= relative.x * Session.sensitivity
	look_pitch = clampf(look_pitch - relative.y * Session.sensitivity, -78, 78)
	camera.rotation_degrees.x = look_pitch

func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	flashlight_changed.emit(flashlight_on)

func toggle_crouch() -> void:
	if forced_crouch:return
	if crouching and not can_stand():return
	crouching=not crouching
	_update_collider()

func can_stand() -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	var shape:=CapsuleShape3D.new()
	shape.radius=0.24
	shape.height=1.7
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,0.88,0))
	query.collision_mask=1
	query.exclude=[get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _update_collider() -> void:
	collider.shape.height=1.0 if crouching else 1.7
	collider.position.y=0.52 if crouching else 0.87

func _physics_process(delta: float) -> void:
	if not controlled:
		return
	forced_crouch=position.y < -0.6
	if forced_crouch:crouching=true
	_update_collider()
	var input := Input.get_vector("move_left","move_right","move_forward","move_back") + touch_move
	input = input.limit_length()
	var sprinting := (Input.is_action_pressed("sprint") or touch_sprint) and not crouching and stamina > 0.05 and input.length() > 0.1
	var speed := 4.0 if sprinting else (1.15 if crouching else 2.4)
	stamina = move_toward(stamina,0.0 if sprinting else 1.0,delta*(0.17 if sprinting else 0.1))
	var direction := transform.basis * Vector3(input.x,0,input.y)
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*16)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*16)
	velocity.y -= 18 * delta
	if is_on_floor():
		velocity.y = -0.1
	var old := position
	move_and_slide()
	var distance := Vector2(position.x-old.x,position.z-old.z).length()
	step_distance += distance
	if step_distance > (1.55 if crouching else 1.35):
		step_distance = 0.0
		footstep.emit(global_position,0.08 if crouching else (0.78 if sprinting else 0.32))
	var moving := input.length() > 0.1
	bob_time += delta * speed * 3.0 if moving else 0.0
	var bob := sin(bob_time) * 0.018 if moving and not Session.reduced_motion else 0.0
	camera.position.y = lerpf(camera.position.y,(0.9 if crouching else 1.62)+bob,delta*10)
	if position.y < -3:
		position = Vector3(0,0.1,5.5)

func target() -> HouseInteractable:
	var start := camera.global_position
	var end := start-camera.global_transform.basis.z*2.8
	var query := PhysicsRayQueryParameters3D.create(start,end,3)
	query.exclude=[get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is HouseInteractable and hit.collider.enabled:
		return hit.collider
	return null

func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	position = pos
	rotation.y = yaw
	look_pitch = 0
	if camera:
		camera.rotation.x=0
	velocity=Vector3.ZERO
	forced_crouch=pos.y < -0.6
	crouching=forced_crouch
	if collider:_update_collider()
	if camera:camera.position.y=0.9 if crouching else 1.62
