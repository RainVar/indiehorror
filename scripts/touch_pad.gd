extends Control
var direction:Vector2=Vector2.ZERO:
	set(value):
		direction=value
		queue_redraw()

func _draw() -> void:
	var center:=size/2.0
	draw_circle(center,53.0,Color(0.8,0.8,0.7,0.06))
	draw_arc(center,53.0,0,TAU,48,Color(0.8,0.8,0.7,0.22),1.5,true)
	draw_circle(center+direction*30.0,19.0,Color(0.8,0.8,0.7,0.25))
	draw_arc(center+direction*30.0,19.0,0,TAU,32,Color(0.8,0.8,0.7,0.4),1.0,true)
