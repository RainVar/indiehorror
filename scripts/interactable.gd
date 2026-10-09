class_name HouseInteractable
extends StaticBody3D

var interaction_id: String = ""
var label_en: String = ""
var label_fil: String = ""
var enabled: bool = true
var visual: Node3D

func setup(id: String, en: String, fil: String, size: Vector3) -> void:
	interaction_id = id
	label_en = en
	label_fil = fil
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	add_to_group("interactables")

func get_prompt() -> String:
	if interaction_id=="portrait" and Session.chores_done() and not Session.has_flag("key"):
		return Story.text("Take the key behind the portrait","Kunin ang susi sa likod ng larawan")
	if interaction_id=="altar":
		if Session.route==Session.Route.UNDECIDED:return Story.text("Hold E / USE · offer rice and KEEP the promise","Pindutin nang matagal ang E / GAMITIN · ialay ang kanin at TUPARIN ang pangako")
		if Session.route==Session.Route.RELEASE:return Story.text("Burn the agreement · be ready to run","Sunugin ang kasunduan · maghandang tumakbo")
		if Session.has_flag("sealed"):return Story.text("The promise is sealed","Naiselyo na ang pangako")
		if Session.has_flag("ritual_survived"):
			return Story.text("Seal the agreement beneath the bowl","Iselyo ang kasunduan sa ilalim ng mangkok")
		if Session.has_flag("candles"):
			return Story.text("Light each candle separately, left to right","Sindihan ang bawat kandila mula kaliwa pakanan")
		if Session.has_flag("offering"):
			return Story.text("Light the three candles","Sindihan ang tatlong kandila")
	if interaction_id=="radio":
		if Session.route==Session.Route.UNDECIDED:return Story.text("Hold E / USE · play the tape and REJECT the rules","Pindutin nang matagal ang E / GAMITIN · patugtugin at TANGGIHAN ang bilin")
		if Session.route==Session.Route.RELEASE:return Story.text("Play the twenty-second radio lure","Patugtugin ang dalawampung segundong pang-akit")
	return Story.text(label_en, label_fil)
