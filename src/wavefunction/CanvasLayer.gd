extends CanvasLayer

func _ready():
	pass

func clear():
	for child in $Labels.get_children():
		child.queue_free()
	pass

func update(pos:Vector3, text:String):
	var camera = get_viewport().get_camera()
	if !camera.is_position_behind(pos):
		var position = camera.unproject_position(pos)
		var lbl:Label = Label.new()
		lbl.text = str(pos.x/2) + "," + str(pos.z/2) + "\n" + text
		lbl.align = Label.ALIGN_CENTER
		lbl.valign = Label.ALIGN_CENTER
		lbl.rect_scale = Vector2(.75,.75)
		$Labels.add_child(lbl)
		lbl.set_position(position)
	pass
