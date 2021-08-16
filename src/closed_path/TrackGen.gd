extends Spatial

var max_radius:float = 50.0
var rng:RandomNumberGenerator = RandomNumberGenerator.new()
var max_points:int = 12

func _ready():
	pass

func _process(delta):
	if Input.is_action_just_pressed("ui_up"):
		_generate()

func _generate():
	max_radius = 50.0
	$Camera.global_transform.origin.y = max_radius
	rng.randomize()
	for child in $Ref.get_children():
		child.queue_free()
	$Path.curve.clear_points()
	
	var points:Array = []
	for i in range(0, max_points):
		points.append(add_point(i))

	points = _get_sharp(points)

	for i in range(0, points.size()):
		var curved:bool = rng.randi_range(1, 2) == 1
		var point:Vector3 = points[i][0]
		var point_n:Vector3
		if i == points.size() - 1:
			point_n = points[0][0]
		else:
			point_n = points[i + 1][0]
		var point_p:Vector3
		if i == 0:
			point_p = points[points.size() - 1][0]
		else:
			point_p = points[i - 1][0]
		
		var point_in:Vector3 = Vector3(point_p.x, 0, point.z)
		var point_out:Vector3 = Vector3(point.x, 0, point_n.z)
		
		var angle = round(
			rad2deg(
				point_p.direction_to(
					point).angle_to(
						point.direction_to(point_n)
					)
				)
			)
		print("Angle: " + str(angle))
		
		point_in = point.direction_to(point_in)*point.distance_to(point_in)
		point_out = point.direction_to(point_out)*point.distance_to(point_out)
		
		if abs(angle) == 90 or abs(angle) == 270:
			points[i-1][1] = point_p.direction_to(point)*point_p.distance_to(point)
			points[i+1][2] = point.direction_to(point_p)*point.distance_to(point_p)
		else:
			points[i][1] = point_in
			points[i][2] = point_out
			
		#_add_mesh(point + point_in, Color.red, 1.0)
		_add_mesh(point, Color.yellow, 1.1)
		#_add_mesh(point + point_out, Color.blue, 1.2)

	for point in points:
		$Path.curve.add_point(
				point[0],
				point[1],
				point[2]
			)
	if points.size() > 4:
		$Path.curve.add_point(points[0][0])
		_add_mesh(points[0][0], Color.black, 2.0)
	else:
		_generate()

func add_point(i)->Vector3:
	var radius:Vector3 = Vector3.RIGHT*rng.randf_range(
		max_radius/2, max_radius)
	radius = radius.rotated(Vector3.UP, i*2*PI/max_points)
	radius.z = radius.z*rng.randf_range(0.3, 0.75)
	return radius.snapped(Vector3.ONE*max_points)

func _get_sharp(points:Array)->Array:
	var to_remove:Array = []
	for i in range(0, points.size()):
		var curved:bool = rng.randi_range(1, 2) == 1
		var point:Vector3 = points[i]
		var point_n:Vector3
		if i == points.size() - 1:
			point_n = points[0]
		else:
			point_n = points[i + 1]
		var point_p:Vector3
		if i == 0:
			point_p = points[points.size() - 1]
		else:
			point_p = points[i - 1]
		
		var point_in:Vector3 = Vector3(point_p.x, 0, point.z)
		var point_out:Vector3 = Vector3(point.x, 0, point_n.z)
		
		var angle = round(
			rad2deg(
				point_p.direction_to(
					point).angle_to(
						point.direction_to(point_n)
					)
				)
			)
		#print(angle)
		if abs(angle) == 90 or abs(angle) == 180 or abs(angle) == 270:
			var p_prev = (point + point_p)/2
			var p_next = (point + point_n)/2
			var angle_new = round(
			rad2deg(
				p_prev.direction_to(
					point).angle_to(
						point.direction_to(p_next)
					)
				)
			)
			if angle_new != 0 and angle_new != 360:
				to_remove.append([p_prev, Vector3.ZERO, Vector3.ZERO])
				to_remove.append([point, Vector3.ZERO, Vector3.ZERO])
				to_remove.append([p_next, Vector3.ZERO, Vector3.ZERO])
		
	return to_remove

func _add_mesh(point:Vector3, color:Color, radius:float):
	var mat:SpatialMaterial = SpatialMaterial.new()
	mat.albedo_color = color
	mat.albedo_color.a = 125
	mat.flags_transparent = true
	var mesh:MeshInstance = MeshInstance.new()
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = radius
	mesh.material_override = mat
	point.y = radius
	mesh.global_transform.origin = point
	$Ref.add_child(mesh)
