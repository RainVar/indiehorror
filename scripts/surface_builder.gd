class_name HouseSurfaceBuilder
extends RefCounted
## Resolve opaque box surfaces once at construction, not every frame.
## Higher layers own coplanar overlap; equal layers use stable creation order.
## The losing face area is removed, so depth-buffer precision cannot flip it.

const EPS:=0.0001
const LAYERS:={"concrete":0,"plaster":10,"mold":10,"wood":20,"darkwood":30,"tiles":40,"woven":50,"cloth":50,"capiz":60,"paper":70,"white":75,"blue":75,"green":75,"red":80,"brass":80,"black":90,"skin":90,"salt":100,"lamp":100,"moon":100,"eyes":100}
var boxes:Array[Dictionary]=[]
var faces:Array[Dictionary]=[]
var stats:Dictionary={}

static func priority(material_name:String) -> int:
	return int(LAYERS.get(material_name,20))

func add_box(pos:Vector3,size:Vector3,material_name:String,rotation_y:float=0.0,layer:int=-1) -> void:
	# Architectural boxes are axis-aligned (quarter turns are also supported).
	assert(absf(sin(rotation_y*2.0))<EPS,"Surface builder requires quarter-turn boxes")
	var extent:=size
	if absf(sin(rotation_y))>0.5:extent=Vector3(size.z,size.y,size.x)
	boxes.append({"bounds":AABB(pos-extent*0.5,extent),"material":material_name,"layer":priority(material_name) if layer<0 else layer,"id":boxes.size()})

static func _rect(bounds:AABB,axis:int) -> Rect2:
	var u:=(axis+1)%3
	var v:=(axis+2)%3
	return Rect2(Vector2(bounds.position[u],bounds.position[v]),Vector2(bounds.size[u],bounds.size[v]))

static func subtract_rect(source:Rect2,cut:Rect2) -> Array[Rect2]:
	var hit:=source.intersection(cut)
	if hit.size.x<=EPS or hit.size.y<=EPS:return [source]
	var result:Array[Rect2]=[]
	for part in [Rect2(source.position,Vector2(hit.position.x-source.position.x,source.size.y)),Rect2(Vector2(hit.end.x,source.position.y),Vector2(source.end.x-hit.end.x,source.size.y)),Rect2(Vector2(hit.position.x,source.position.y),Vector2(hit.size.x,hit.position.y-source.position.y)),Rect2(Vector2(hit.position.x,hit.end.y),Vector2(hit.size.x,source.end.y-hit.end.y))]:
		if part.size.x>EPS and part.size.y>EPS:result.append(part)
	return result

func resolve() -> void:
	faces.clear()
	var trimmed:=0
	var ties:=0
	for source in boxes:
		var bounds:AABB=source.bounds
		var neighbors:Array[Dictionary]=[]
		for other in boxes:
			if source.id!=other.id and bounds.grow(EPS).intersects(other.bounds):neighbors.append(other)
		for axis in range(3):
			for side in [-1,1]:
				var plane:float=bounds.position[axis] if side<0 else bounds.end[axis]
				var original:=_rect(bounds,axis)
				var pieces:Array[Rect2]=[original]
				for other in neighbors:
					var obstacle:AABB=other.bounds
					var low:float=obstacle.position[axis]
					var high:float=obstacle.end[axis]
					var cut:=false
					# Buried faces and back-to-back internal faces are not visible.
					if plane>low+EPS and plane<high-EPS:cut=true
					elif side>0 and absf(plane-low)<=EPS:cut=true
					elif side<0 and absf(plane-high)<=EPS:cut=true
					# Same outward face: a single material deterministically owns it.
					elif absf(plane-(high if side>0 else low))<=EPS:
						cut=other.layer>source.layer or (other.layer==source.layer and other.id<source.id)
						if cut and original.intersects(_rect(obstacle,axis)):ties+=1
					if not cut:continue
					var remainder:Array[Rect2]=[]
					for piece in pieces:remainder.append_array(subtract_rect(piece,_rect(obstacle,axis)))
					pieces=remainder
					if pieces.is_empty():break
				if pieces.size()!=1 or (not pieces.is_empty() and not pieces[0].is_equal_approx(original)):trimmed+=1
				for piece in pieces:
					faces.append({"axis":axis,"side":side,"plane":plane,"rect":piece,"material":source.material,"layer":source.layer,"source":source.id})
	stats={"boxes":boxes.size(),"original_faces":boxes.size()*6,"output_faces":faces.size(),"trimmed_faces":trimmed,"priority_resolutions":ties}

func conflicts() -> Array[Dictionary]:
	# Audit the final, clipped face rectangles. Opposite normals do not compete.
	var result:Array[Dictionary]=[]
	var groups:Dictionary={}
	for face in faces:
		var key:="%s:%s" % [face.axis,face.side]
		if not groups.has(key):groups[key]=[]
		groups[key].append(face)
	for group in groups.values():
		group.sort_custom(func(a,b):return a.plane<b.plane)
		for i in range(group.size()):
			for j in range(i+1,group.size()):
				if group[j].plane-group[i].plane>EPS:break
				var hit:Rect2=group[i].rect.intersection(group[j].rect)
				if hit.size.x>EPS and hit.size.y>EPS:result.append({"a":group[i],"b":group[j]})
	return result

func create_meshes(materials:Dictionary) -> Dictionary:
	var builders:Dictionary={}
	for face in faces:
		var material_name:String=face.material
		var chunk:String=str(boxes[face.source].get("chunk","house"))
		var key:String=chunk+"|"+material_name
		if not builders.has(key):
			var builder:=SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(materials[material_name])
			builders[key]=builder
		var builder:SurfaceTool=builders[key]
		var axis:int=face.axis
		var normal:=Vector3.ZERO
		normal[axis]=face.side
		var rect:Rect2=face.rect
		var corners:=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		# Godot front faces use clockwise winding.
		for index in ([0,2,1,0,3,2] if face.side>0 else [0,1,2,0,2,3]):
			var uv:Vector2=corners[index]
			var vertex:=Vector3.ZERO
			vertex[axis]=face.plane
			vertex[(axis+1)%3]=uv.x
			vertex[(axis+2)%3]=uv.y
			builder.set_normal(normal)
			builder.set_uv(uv)
			builder.add_vertex(vertex)
	var meshes:Dictionary={}
	for material_name in builders:
		builders[material_name].index()
		meshes[material_name]=builders[material_name].commit()
	return meshes
