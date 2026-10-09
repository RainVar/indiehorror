extends GdUnitTestSuite

const Builder=preload("res://scripts/surface_builder.gd")

func test_priority_removes_losing_coplanar_faces() -> void:
	var builder=Builder.new()
	builder.add_box(Vector3.ZERO,Vector3.ONE*2,"concrete")
	builder.add_box(Vector3.ZERO,Vector3.ONE*2,"tiles")
	builder.resolve()
	assert_int(builder.faces.size()).is_equal(6)
	for face in builder.faces:assert_str(face.material).is_equal("tiles")
	assert_int(builder.conflicts().size()).is_equal(0)

func test_equal_priority_has_one_stable_owner() -> void:
	var builder=Builder.new()
	builder.add_box(Vector3.ZERO,Vector3.ONE,"wood")
	builder.add_box(Vector3.ZERO,Vector3.ONE,"wood")
	builder.resolve()
	assert_int(builder.faces.size()).is_equal(6)
	for face in builder.faces:assert_int(face.source).is_equal(0)

func test_priority_is_independent_of_material_creation_order() -> void:
	var builder=Builder.new()
	builder.add_box(Vector3.ZERO,Vector3.ONE,"paper")
	builder.add_box(Vector3.ZERO,Vector3.ONE,"wood")
	builder.resolve()
	for face in builder.faces:assert_str(face.material).is_equal("paper")

func test_partial_overlap_preserves_uncovered_area() -> void:
	var pieces=Builder.subtract_rect(Rect2(0,0,4,4),Rect2(1,1,2,2))
	var area:=0.0
	for piece in pieces:area+=piece.get_area()
	assert_float(area).is_equal(12.0)
	assert_int(pieces.size()).is_equal(4)

func test_touching_edges_are_not_removed() -> void:
	var pieces=Builder.subtract_rect(Rect2(0,0,1,1),Rect2(1,0,1,1))
	assert_int(pieces.size()).is_equal(1)
	assert_float(pieces[0].get_area()).is_equal(1.0)

func test_shared_internal_faces_are_removed() -> void:
	var builder=Builder.new()
	builder.add_box(Vector3.ZERO,Vector3.ONE,"wood")
	builder.add_box(Vector3.RIGHT,Vector3.ONE,"wood")
	builder.resolve()
	assert_int(builder.faces.size()).is_equal(10)
	assert_int(builder.conflicts().size()).is_equal(0)

func test_buried_box_cannot_show_through_wall_regardless_of_priority() -> void:
	var builder=Builder.new()
	builder.add_box(Vector3.ZERO,Vector3.ONE*3,"concrete")
	builder.add_box(Vector3.ZERO,Vector3.ONE,"paper")
	builder.resolve()
	assert_int(builder.faces.size()).is_equal(6)
	for face in builder.faces:assert_str(face.material).is_equal("concrete")

func test_intersecting_boxes_have_no_competing_faces() -> void:
	var builder=Builder.new()
	for i in range(12):builder.add_box(Vector3(i%3,0,int(i/3)*0.4),Vector3(1.6,2,1.6),"wood" if i%2 else "darkwood")
	builder.resolve()
	assert_int(builder.conflicts().size()).is_equal(0)

func test_world_texture_imports_have_real_mipmaps() -> void:
	for texture_name in ["wood","plaster","mold","tiles","concrete","woven","paper","capiz"]:
		var texture:Texture2D=load("res://assets/textures/"+texture_name+".png")
		assert_bool(texture.get_image().has_mipmaps()).override_failure_message("Missing mipmaps: "+texture_name).is_true()
