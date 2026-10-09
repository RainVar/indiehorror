class_name HouseLayout
extends RefCounted
## One source of truth for architecture, room names, stairs and safe spawns.
const UPPER := 3.6
const CRAWL := -1.56
const BOUNDS := Rect2(-11, -12, 22, 20)
const COURT := Rect2(-1.5, -4, 3, 4)
const ROOMS := [
	["foyer",0,Rect2(-3,3,6,5),"FOYER","BUNGAD"],
	["sala",0,Rect2(-11,2,8,6),"SALA","SALA"],
	["dining",0,Rect2(-11,-4,8,6),"DINING ROOM","SILID-KAINAN"],
	["kitchen",0,Rect2(-11,-12,5,6),"KITCHEN","KUSINA"],
	["pantry",0,Rect2(-6,-12,3,6),"PANTRY","PAMINGGALAN"],
	["store",0,Rect2(-3,-12,6,5),"STOREROOM","BODEGA"],
	["altar",0,Rect2(3,-12,8,8),"OLD ALTAR","LUMANG ALTAR"],
	["family",1,Rect2(-11,2,8,6),"FAMILY BEDROOM","KUWARTO NG PAMILYA"],
	["guest",1,Rect2(6,2,5,6),"GUEST BEDROOM","KUWARTO NG BISITA"],
	["wash",1,Rect2(-11,-4,4,6),"WASHROOM","PALIGUAN"],
	["study",1,Rect2(-7,-4,4,6),"LOLA'S STUDY","SILID-ARALAN"],
	["lola",1,Rect2(-11,-12,6,8),"LOLA'S BEDROOM","KUWARTO NI LOLA"],
	["sewing",1,Rect2(-5,-12,3.5,5),"SEWING ROOM","SILID-TAHIAN"],
	["tomas",1,Rect2(3,-12,8,8),"TOMAS'S ROOM","KUWARTO NI TOMAS"]
]
# axis x = wall running along x, axis z = wall running along z.
const DOORS := [
	["service_stairs","x",-9.6,-6.0,0],
	["front","x",0,8,0],["foyer_gallery","x",0,3,0],["foyer_stairs","z",3,7,0],["sala","z",-3,5,0],["dining","x",-7,2,0],
	["dining_hall","z",-3,-1,0],["kitchen","x",-7.4,-6,0],
	["pantry","z",-6,-9,0],["pantry_hall","x",-4.5,-6,0],
	["store","x",0,-7,0],["altar","z",3,-5.4,0],["service","z",-11,-7.4,0],
	["family","z",-3,5,1],["guest","z",6,5,1],["study","z",-3,-1,1],
	["wash","z",-7,-1,1],["wash_family","x",-9,2,1],
	["lola","z",-5,-5.5,1],["sewing","x",-3.9,-7,1],
	["tomas","z",3,-8,1],["tomas_hall","x",7,-4,1]
]
const STAIRS := [
	{"id":"main","x":4.4,"z":7.0,"width":1.8,"run":6.0},
	{"id":"service","x":-9.6,"z":-5.0,"width":1.8,"run":6.0}
]
const HATCHES := {"pantry":Vector3(-4.5,0,-8),"store":Vector3(0,0,-9)}
const CRAWL_RECTS := [Rect2(-5.5,-10,2,5),Rect2(-5.5,-10,6.5,2),Rect2(-8,-7,4.5,2)]
const SPAWNS := {
	"entry":Vector3(0,0.05,14.5),"sala":Vector3(-5,0.05,4.6),
	"final":Vector3(2,0.05,-5.4),"store":Vector3(0,0.05,-8),
	"upper":Vector3(1,3.65,1),"crawl":Vector3(-4.5,-1.51,-8)
}

static func floor_of(pos:Vector3) -> int:
	return -1 if pos.y < -0.6 else (1 if pos.y > 2.8 else 0)

static func room_id(pos:Vector3) -> String:
	var floor_id := floor_of(pos)
	if floor_id == -1:return "crawl"
	for room in ROOMS:
		if room[1] == floor_id and room[2].has_point(Vector2(pos.x,pos.z)):return room[0]
	if not BOUNDS.has_point(Vector2(pos.x,pos.z)):return "yard"
	if COURT.has_point(Vector2(pos.x,pos.z)):return "courtyard"
	return "gallery_%s" % floor_id

static func room_name(pos:Vector3) -> String:
	var id := room_id(pos)
	for room in ROOMS:
		if room[0] == id:return Story.text(room[3],room[4])
	if id == "crawl":return Story.text("BENEATH THE HOUSE","SA ILALIM NG BAHAY")
	if id == "yard":return Story.text("VERANDA & YARD","BERANDA AT BAKURAN")
	if id == "courtyard":return Story.text("THE COURTYARD","LOOBANG BAKURAN")
	return Story.text("UPPER GALLERY" if floor_of(pos)==1 else "COURTYARD GALLERY","PASILYO SA ITAAS" if floor_of(pos)==1 else "PASILYO NG BAKURAN")

static func stair_height(pos:Vector3) -> float:
	for stair in STAIRS:
		if absf(pos.x-stair.x)<stair.width*0.5 and pos.z<=stair.z and pos.z>=stair.z-stair.run:
			return (stair.z-pos.z)/stair.run*UPPER
	return UPPER if pos.y>2.8 else (CRAWL if pos.y < -0.6 else 0.0)
