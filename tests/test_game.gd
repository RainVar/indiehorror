extends GdUnitTestSuite

var game:Node3D

func before_test() -> void:
	Session.persistence_enabled=false
	Session.language="en"
	Session.new_game()
	game=auto_free(load("res://scenes/main.tscn").instantiate())
	add_child(game)
	game.playing=true
	game._freeze()

func after_test() -> void:
	Session.active=false
	Session.flags.clear()
	Session.checkpoint.clear()

func _begin_story() -> void:
	Session.set_flag("arrival")
	Session.set_flag("fuse")
	Session.set_flag("rules")
	Session.make_checkpoint("sala")
	Session.make_branch_checkpoint()
	Session.commit_route(Session.Route.KEEPER)
	Session.set_flag("rice")
	Session.set_flag("offering")

func _chores() -> void:
	_begin_story()
	for key in ["shutter_kitchen","shutter_lola","shutter_family","portrait","salt"]:
		game.handle_interaction(key)
	game.handle_interaction("winding_key")
	game.set_clock(6,15)
	game._freeze()
	game.handle_interaction("threshold")

func test_title_cannot_be_taken_before_rules_and_key() -> void:
	game.handle_interaction("baul")
	assert_bool(Session.has_flag("title")).is_false()
	game.handle_interaction("portrait")
	assert_bool(Session.has_flag("key")).is_false()

func test_wrong_clock_does_not_advance() -> void:
	_begin_story()
	game.handle_interaction("winding_key")
	game.set_clock(6,30)
	assert_bool(Session.has_flag("clock_stopped")).is_false()
	game.set_clock(6,15)
	assert_bool(Session.has_flag("clock_stopped")).is_true()

func test_salt_requires_inventory() -> void:
	_begin_story()
	game.handle_interaction("threshold")
	assert_bool(Session.has_flag("salt_line")).is_false()
	game.handle_interaction("salt")
	game.handle_interaction("threshold")
	assert_bool(Session.has_flag("salt_line")).is_true()

func test_six_chores_unlock_key_and_final_checkpoint() -> void:
	_chores()
	assert_bool(Session.chores_done()).is_true()
	assert_bool(Session.has_flag("key")).is_false()
	game.handle_interaction("portrait")
	assert_bool(Session.has_flag("key")).is_true()
	game.handle_interaction("baul")
	assert_int(Session.act()).is_equal(3)
	assert_str(Session.checkpoint.spawn).is_equal("store")

func test_checkpoint_restores_objectives_not_later_progress() -> void:
	_begin_story()
	Session.set_flag("shutter_lola")
	Session.restore_checkpoint(true)
	assert_bool(Session.has_flag("rules")).is_true()
	assert_bool(Session.has_flag("shutter_lola")).is_false()
	assert_int(Session.catches).is_equal(1)

func test_optional_memories_are_idempotent() -> void:
	Session.set_flag("memory_photo")
	Session.set_flag("memory_photo")
	assert_int(Session.memory_count()).is_equal(1)
	Session.set_flag("memory_letter")
	Session.set_flag("memory_tape")
	assert_int(Session.memory_count()).is_equal(3)
	assert_str(Story.ending("break").post).contains("remembered them all")

func test_both_endings_have_distinct_localized_text() -> void:
	var en_seal:Dictionary=Story.ending("seal")
	var en_break:Dictionary=Story.ending("break")
	assert_str(en_seal.title).is_not_equal(en_break.title)
	Session.language="fil"
	assert_str(Story.ending("seal").title).is_not_equal(en_seal.title)
	assert_str(Story.ending("break").title).is_not_equal(en_break.title)

func test_no_mic_required_for_all_story_flags() -> void:
	_chores()
	game.handle_interaction("portrait")
	game.handle_interaction("baul")
	game.handle_interaction("pact")
	game.handle_interaction("rice")
	game.handle_interaction("candle_0")
	assert_bool(Session.has_flag("candles")).is_true()
	assert_bool(Session.mic_enabled).is_false()

func test_microphone_strength_is_bounded_and_noise_gated() -> void:
	assert_float(HouseNoise.rms_to_strength(0.01,0.05)).is_equal(0.0)
	assert_float(HouseNoise.rms_to_strength(0.8,0.05)).is_equal(1.0)
	assert_float(HouseNoise.rms_to_strength(0.06,0.05)).is_greater(0.0)
	game.noise.enabled=false
	game.noise.emit_noise(Vector3.ZERO,1.0,"test")
	assert_float(game.noise.meter).is_equal(0.0)

func test_entity_grace_and_loud_noise_transitions() -> void:
	_begin_story()
	game.entity.enabled=true
	game.entity.listening=true
	game.entity.hear(Vector3(0,0,-6),1.0,"test")
	assert_int(game.entity.state).is_equal(ListeningEntity.State.DORMANT)
	game.entity.grace=0
	game.entity.hear(Vector3(0,0,-6),1.0,"test")
	assert_int(game.entity.state).is_equal(ListeningEntity.State.HUNT)

func test_phone_lure_redirects_hunt() -> void:
	_begin_story()
	game.entity.enabled=true
	game.entity.grace=0
	game.entity.state=ListeningEntity.State.HUNT
	game.entity.hear(Vector3(0,0,-5),0.9,"phone")
	assert_int(game.entity.state).is_equal(ListeningEntity.State.INVESTIGATE)
	assert_vector(game.entity.target_point).is_equal(Vector3(0,0,-5))

func test_navigation_connects_every_room() -> void:
	var origin:int=game.entity._nearest_cell(Vector3(0,0,4))
	for room in HouseLayout.ROOMS:
		var r:Rect2=room[2]
		var point:=Vector3(r.get_center().x,room[1]*3.6+0.05,r.get_center().y)
		var target:int=game.entity._nearest_cell(point)
		var path:PackedVector3Array=game.entity.grid.get_point_path(origin,target)
		assert_bool(not path.is_empty()).override_failure_message("No navigation route to %s" % point).is_true()

func test_interactables_exist_and_pact_is_locked_initially() -> void:
	for id in ["fuse","rules","portrait","clock","salt","rice","threshold","baul","pact","altar","shutter_kitchen","shutter_lola","shutter_family"]:
		assert_bool(game.world.interactables.has(id)).is_true()
	assert_bool(game.world.interactables.pact.enabled).is_false()

func test_pause_stops_player_entity_and_mic_events() -> void:
	game.resume_game()
	game.pause_game()
	assert_bool(game.player.controlled).is_false()
	assert_bool(game.entity.enabled).is_false()
	assert_bool(game.noise.enabled).is_false()
	assert_bool(Session.active).is_false()

func test_localization_has_complete_notes() -> void:
	for id in ["arrival","rules","memory_photo","memory_letter","memory_tape","pact","clock_hint"]:
		Session.language="en"
		var en:Dictionary=Story.note(id)
		Session.language="fil"
		var fil:Dictionary=Story.note(id)
		assert_str(en.body).is_not_empty()
		assert_str(fil.body).is_not_empty()
		assert_str(en.body).is_not_equal(fil.body)

func test_corrupt_save_is_rejected_without_a_crash() -> void:
	assert_bool(Session.valid_save({})).is_false()
	assert_bool(Session.valid_save({"version":1,"checkpoint":{"flags":[],"spawn":"sala"}})).is_false()
	assert_bool(Session.valid_save({"version":1,"checkpoint":{"flags":{"rules":"yes"},"spawn":"sala"}})).is_false()
	assert_bool(Session.valid_save({"version":1,"checkpoint":{"flags":{},"spawn":"outside"}})).is_false()
	assert_bool(Session.valid_save({"version":2,"checkpoint":{"flags":{"rules":true},"spawn":"sala","route":0},"endings":[],"catches":0,"play_seconds":12.4})).is_true()

func test_salt_protects_ritual_until_promise_is_sealed() -> void:
	Session.set_flag("salt_line")
	assert_bool(game.entity.salt_nodes.is_empty()).is_false()
	assert_bool(game.entity.grid.is_point_disabled(game.entity.salt_nodes[0])).is_true()
	Session.set_flag("candles")
	assert_bool(game.entity.grid.is_point_disabled(game.entity.salt_nodes[0])).is_true()
	Session.set_flag("sealed")
	assert_bool(game.entity.grid.is_point_disabled(game.entity.salt_nodes[0])).is_false()

func test_ritual_requires_silence_and_proximity() -> void:
	Session.set_flag("candles")
	game.paused=false
	game.routes.trial=0
	game.player.teleport(Vector3(7,0,-8))
	game.routes.ritual_time=7.5
	game.noise.meter=1.0
	game._process(1.0)
	assert_bool(Session.has_flag("trial_0")).is_false()
	game.noise.meter=0.0
	game.player.teleport(Vector3(0,0,4))
	game._process(1.0)
	assert_bool(Session.has_flag("ritual_survived")).is_false()
	game.player.teleport(Vector3(7,0,-8))
	game.routes.ritual_time=7.5
	game._process(1.0)
	assert_bool(Session.has_flag("trial_0")).is_true()

func test_manual_restart_does_not_count_as_capture() -> void:
	_begin_story()
	Session.restore_checkpoint()
	assert_int(Session.catches).is_equal(0)

func _level_floor_rects(material_name:String) -> Array[Rect2]:
	var floors:Array[Rect2]=[]
	# box() creates mesh and collider from the same dimensions. Inspect the
	# collider since the headless dummy renderer cannot read MultiMesh buffers.
	for body in game.world.get_children():
		if not body is StaticBody3D or body.get_meta("surface","")!=material_name:continue
		var size:Vector3=body.get_child(0).shape.size
		var origin:Vector3=body.position
		if absf(origin.y+size.y*0.5)<0.0001 and size.x>1.0 and size.z>1.0:
			floors.append(Rect2(Vector2(origin.x-size.x*0.5,origin.z-size.z*0.5),Vector2(size.x,size.z)))
	return floors

func test_indoor_and_outdoor_floor_surfaces_do_not_overlap() -> void:
	var indoor:=_level_floor_rects("wood")
	var outdoor:=_level_floor_rects("concrete")
	assert_bool(indoor.is_empty()).is_false()
	assert_bool(outdoor.is_empty()).is_false()
	for wood in indoor:
		for concrete in outdoor:
			var overlap:=wood.intersection(concrete)
			assert_bool(overlap.size.x>0.0001 and overlap.size.y>0.0001).override_failure_message("Coplanar wood/concrete floor overlap: %s" % overlap).is_false()

func test_entry_floor_stays_continuous_and_level() -> void:
	var floors:=_level_floor_rects("wood")+_level_floor_rects("concrete")
	for point in [Vector2(0,7.9),Vector2(0,8.2),Vector2(0,8.21),Vector2(0,11.9),Vector2(0,12.1),Vector2(0,14.5),Vector2(-10,4),Vector2(10,4)]:
		var covered:=false
		for floor_rect in floors:
			if floor_rect.grow(0.0001).has_point(point):covered=true
		assert_bool(covered).override_failure_message("Missing level floor at %s" % point).is_true()

func test_entire_static_house_has_no_competing_coplanar_faces() -> void:
	assert_int(game.world.surface_audit.remaining_conflicts).is_equal(0)
	assert_int(game.world.surface_audit.priority_resolutions).is_greater(0)
	assert_int(game.world.surface_audit.boxes).is_greater(200)
	for material_name in game.world.materials:
		var material:StandardMaterial3D=game.world.materials[material_name]
		assert_bool(material.no_depth_test).is_false()
		assert_int(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
		assert_int(material.render_priority).is_equal(HouseSurfaceBuilder.priority(material_name))

func test_flashlight_bias_and_rain_do_not_create_striped_shadow_artifacts() -> void:
	assert_float(game.player.flashlight.shadow_bias).is_equal(0.5)
	assert_float(game.player.flashlight.shadow_normal_bias).is_equal(2.0)
	assert_int(game.world.rain.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
