extends SceneTree

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	root.get_node("Session").persistence_enabled=false
	var house=load("res://scripts/expanded_world.gd").new()
	house.baking=true
	root.add_child(house)
	print("WORLD_BAKED ",JSON.stringify(house.surface_audit))
	quit(0 if house.surface_audit.get("remaining_conflicts",1)==0 else 1)
