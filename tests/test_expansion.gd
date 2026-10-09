extends GdUnitTestSuite
var game:Node3D

func before_test() -> void:
	Session.persistence_enabled=false
	Session.new_game()
	Session.language="en"
	game=auto_free(load("res://scenes/main.tscn").instantiate())
	add_child(game)
	game.playing=true
	game._freeze()
	Session.set_flag("arrival")
	Session.set_flag("fuse")
	Session.set_flag("rules")
	Session.make_branch_checkpoint()

func after_test() -> void:
	Session.active=false
	await get_tree().process_frame
	await get_tree().process_frame

func _release() -> void:
	game.handle_interaction("radio")
	game._freeze()
	for flag in Session.MEMORIES:Session.set_flag(flag)
	Session.set_flag("tomas_clue")

func _bindings() -> void:
	_release()
	for flag in ["binding_portrait","binding_clock","binding_bowl"]:game.handle_interaction(flag)

func test_house_is_fourteen_rooms_across_two_storeys() -> void:
	assert_int(HouseLayout.ROOMS.size()).is_equal(14)
	var lower:=0
	var upper:=0
	for room in HouseLayout.ROOMS:
		if room[1]==0:lower+=1
		else:upper+=1
	assert_int(lower).is_equal(7)
	assert_int(upper).is_equal(7)
	assert_int(HouseLayout.STAIRS.size()).is_equal(2)
	assert_int(HouseLayout.HATCHES.size()).is_equal(2)

func test_route_commitment_is_early_and_exclusive() -> void:
	assert_bool(Session.commit_route(Session.Route.RELEASE)).is_true()
	assert_bool(Session.commit_route(Session.Route.KEEPER)).is_false()
	game.handle_interaction("shutter_kitchen")
	assert_bool(Session.has_flag("shutter_kitchen")).is_false()
	game.choose_ending("seal")
	assert_str(game.final_kind).is_empty()

func test_keeper_requires_rice_to_commit() -> void:
	game.handle_interaction("altar")
	assert_int(Session.route).is_equal(0)
	game.handle_interaction("rice")
	game.handle_interaction("altar")
	assert_int(Session.route).is_equal(Session.Route.KEEPER)
	assert_bool(Session.has_flag("offering")).is_true()
	game.handle_interaction("radio")
	assert_int(Session.route).is_equal(Session.Route.KEEPER)

func test_release_cannot_skip_evidence_or_binding_order() -> void:
	game.handle_interaction("radio")
	game.handle_interaction("binding_portrait")
	assert_bool(Session.has_flag("binding_portrait")).is_false()
	for flag in Session.MEMORIES:Session.set_flag(flag)
	Session.set_flag("tomas_clue")
	game.handle_interaction("binding_portrait")
	game.handle_interaction("binding_bowl")
	assert_bool(Session.has_flag("binding_portrait")).is_false()
	assert_bool(Session.has_flag("key")).is_false()

func test_release_has_its_own_key_and_never_needs_wards() -> void:
	_bindings()
	assert_bool(Session.has_flag("key")).is_true()
	assert_bool(Session.chores_done()).is_false()
	game.handle_interaction("sewing")
	game.handle_interaction("baul")
	game.handle_interaction("pact")
	game._freeze()
	game.handle_interaction("matches")
	game.handle_interaction("altar")
	assert_bool(Session.has_flag("pact_burned")).is_false()
	game.handle_interaction("radio")
	game.handle_interaction("altar")
	assert_bool(Session.has_flag("pact_burned")).is_true()
	assert_bool(game.entity.chase_locked).is_true()
	assert_str(Session.pending_ending).is_empty()
	game.handle_interaction("gate")
	assert_str(Session.pending_ending).is_equal("break")
	assert_bool(game.endings.active).is_true()

func test_candle_trials_preserve_completed_phases() -> void:
	Session.commit_route(Session.Route.KEEPER)
	Session.set_flag("pact")
	game.player.teleport(Vector3(7,0.05,-8))
	game.handle_interaction("candle_1")
	assert_int(game.routes.trial).is_equal(-1)
	game.handle_interaction("candle_0")
	game.routes.update(8.1)
	assert_bool(Session.has_flag("trial_0")).is_true()
	game.handle_interaction("candle_1")
	game.noise.meter=1
	game.routes.update(8.1)
	assert_bool(Session.has_flag("trial_1")).is_false()
	assert_bool(Session.has_flag("trial_0")).is_true()

func test_checkpoint_restores_route_without_repeating_seen_scares() -> void:
	Session.commit_route(Session.Route.RELEASE)
	Session.seen_scares["crawl_hand"]=true
	Session.set_flag("bindings_done")
	Session.restore_checkpoint()
	assert_int(Session.route).is_equal(Session.Route.RELEASE)
	assert_bool(Session.has_flag("bindings_done")).is_false()
	assert_bool(Session.seen_scares.has("crawl_hand")).is_true()

func test_old_save_migrates_without_inventing_an_ending_choice() -> void:
	var data:=Session.migrate_v1({"version":1,"checkpoint":{"flags":{"arrival":true,"fuse":true,"rules":true,"title":true,"candles":true,"memory_letter":true},"spawn":"final"},"endings":["seal"]})
	assert_bool(Session.valid_save(data)).is_true()
	assert_int(data.checkpoint.route).is_equal(0)
	assert_bool(data.checkpoint.flags.has("title")).is_false()
	assert_bool(data.checkpoint.flags.memory_letter).is_true()
	assert_array(data.endings).contains(["seal"])

func test_replay_fork_restores_uncommitted_progress() -> void:
	Session.commit_route(Session.Route.RELEASE)
	Session.set_flag("bindings_done")
	Session.replay_branch()
	assert_int(Session.route).is_equal(0)
	assert_bool(Session.has_flag("bindings_done")).is_false()
	assert_bool(Session.has_flag("rules")).is_true()

func test_stair_navigation_contains_vertical_waypoints() -> void:
	for stair in HouseLayout.STAIRS:
		var a:int=game.entity._nearest_cell(Vector3(stair.x,0.05,stair.z+0.5))
		var b:int=game.entity._nearest_cell(Vector3(stair.x,3.65,stair.z-6.5))
		var path:PackedVector3Array=game.entity.grid.get_point_path(a,b)
		assert_bool(path.is_empty()).is_false()
		var has_ramp:=false
		for point in path:
			if point.y>0.1 and point.y<3.5:has_ramp=true
		assert_bool(has_ramp).is_true()

func test_crouching_changes_collision_and_is_forced_below() -> void:
	game.player.teleport(Vector3(-4.5,-1.51,-8))
	assert_bool(game.player.crouching).is_true()
	assert_float(game.player.collider.shape.height).is_equal(1.0)
	assert_bool(game.player.can_stand()).is_false()
	game.player.toggle_crouch()
	assert_bool(game.player.crouching).is_true()

func test_scared_once_and_cooldown_prevents_major_stacking() -> void:
	game.scares.grace=0
	assert_bool(game.scares.trigger("window",true)).is_true()
	assert_bool(game.scares.trigger("chair",true)).is_false()
	game.scares.cooldown=0
	assert_bool(game.scares.trigger("window",true)).is_false()
	assert_bool(game.scares.trigger("chair",true)).is_true()

func test_cinematic_pause_skip_and_gallery_leave_progress_alone() -> void:
	Session.endings=["seal"]
	var before:=Session.checkpoint.duplicate(true)
	game.replay_ending("seal")
	assert_bool(game.player.controlled).is_false()
	game.pause_game()
	var time:float=game.endings.elapsed
	game.endings.update(10)
	assert_float(game.endings.elapsed).is_equal(time)
	game.resume_game()
	game.endings.update(3)
	assert_float(game.endings.elapsed).is_greater(time)
	game.endings.finish()
	assert_bool(game.endings.active).is_false()
	assert_dict(Session.checkpoint).is_equal(before)

func test_added_narrative_has_english_and_filipino_parity() -> void:
	for id in ["keeper","release","tomas_clue","crawl_lore","restored"]:
		Session.language="en"
		var en:Dictionary=Story.note(id)
		Session.language="fil"
		assert_str(Story.note(id).body).is_not_empty()
		assert_str(Story.note(id).body).is_not_equal(en.body)

func test_corrupt_nested_save_records_are_rejected() -> void:
	var good:={"version":2,"checkpoint":{"flags":{"rules":true},"spawn":"sala","route":0},"branch":{},"scares":{},"records":{},"endings":[]}
	assert_bool(Session.valid_save(good)).is_true()
	for invalid in [{"branch":{"flags":[],"spawn":"sala"}},{"scares":{"window":[]}},{"records":{"break":[]}}]:
		var broken:Dictionary=good.duplicate(true)
		broken.merge(invalid,true)
		assert_bool(Session.valid_save(broken)).is_false()

func test_v2_save_survives_actual_json_number_roundtrip() -> void:
	var saved:={"version":2,"checkpoint":{"flags":{"rules":true},"spawn":"sala","route":1,"play_seconds":3.5},"branch":{"flags":{"rules":true},"spawn":"sala","route":0,"play_seconds":2.0},"scares":{"window":true},"records":{"seal":{"memories":0,"seconds":15.2,"catches":0}},"pending":"seal","endings":["seal"]}
	var parsed:Dictionary=JSON.parse_string(JSON.stringify(saved))
	assert_bool(Session.valid_save(parsed)).is_true()

func test_room_culling_never_relights_candles_or_unlit_fire() -> void:
	game.player.teleport(Vector3(7,0.05,-7))
	game.world.visibility_clock=0
	game.world.update_visibility(game.player.camera,1)
	for candle in game.world.candles:
		assert_bool(candle.get_meta("flame").visible).is_false()
	for flame in game.world.fire_nodes:assert_bool(flame.visible).is_false()

func test_readable_items_do_not_get_hidden_behind_large_hotspots() -> void:
	Session.set_flag("title")
	assert_bool(game.world.interactables.baul.enabled).is_false()
	assert_bool(game.world.interactables.pact.enabled).is_true()
	assert_bool(game.world.interactables.altar.get_child(0).shape.size.x<1).is_true()

func test_gallery_stages_its_own_ending_without_mutating_other_route() -> void:
	Session.set_flag("pact_burned")
	Session.endings=["seal","break"]
	game.replay_ending("seal")
	game.world.visibility_clock=0
	game.world.update_visibility(game.endings.camera,1)
	for flame in game.world.fire_nodes:assert_bool(flame.visible).is_false()
	assert_bool(game.world.offering.visible).is_true()
	assert_bool(game.world.candles[0].visible).is_true()
	assert_bool(Session.has_flag("pact_burned")).is_true()
	game.endings.finish()

func test_headless_tests_do_not_allocate_ambient_playback() -> void:
	assert_int(game.sound.ambient.size()).is_equal(4)
	if DisplayServer.get_name()=="headless":
		for voice in game.sound.ambient:assert_bool(voice.playing).is_false()
