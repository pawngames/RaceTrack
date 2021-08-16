extends Spatial

var width:int = 80
var height:int = 80

#Map with values for each position of possible tiles
var map:Array = []
#Rules generated from tile analysis
var constraints:Dictionary

#Our RNG, using this ensures we get same tracks for
#same seed and state values, making our tracks reproductible
var rng:RandomNumberGenerator = RandomNumberGenerator.new()

#Default values for tiles.
#Contains all available tiles from the constraints file
#Removing items from this array skips the calculations
#for positioning
var def_pos:Array = []

#Table for conversion between tile orientation
#on constraints and gridmap values
const orthogonal_angles = [
	Vector3(0, 0, 0),
	Vector3(0, 0, PI/2),
	Vector3(0, 0, PI),
	Vector3(0, 0, -PI/2),
	Vector3(PI/2, 0, 0),
	Vector3(PI, -PI/2, -PI/2),
	Vector3(-PI/2, PI, 0),
	Vector3(0, -PI/2, -PI/2),
	Vector3(-PI, 0, 0),
	Vector3(PI, 0, -PI/2),
	Vector3(0, PI, 0),
	Vector3(0, PI, -PI/2),
	Vector3(-PI/2, 0, 0),
	Vector3(0, -PI/2, PI/2),
	Vector3(PI/2, 0, PI),
	Vector3(0, PI/2, -PI/2),
	Vector3(0, PI/2, 0),
	Vector3(-PI/2, PI/2, 0),
	Vector3(PI, PI/2, 0),
	Vector3(PI/2, PI/2, 0),
	Vector3(PI, -PI/2, 0),
	Vector3(-PI/2, -PI/2, 0),
	Vector3(0, -PI/2, 0),
	Vector3(PI/2, -PI/2, 0)
]

#Initializations
func _ready():
	$Camera.global_transform.origin = Vector3(width, width + height, height)
	($Ground.mesh as PlaneMesh).size = Vector2(width*5, height*5)
	$Ground.global_transform.origin = Vector3(width, 0.0, height)
	constraints = _load_constraints()
	for i in range(constraints["parts"].size()):
		def_pos.append(i)
	#def_pos.remove(def_pos.find(8))
	print(def_pos)
	pass

#Recalculates upon button press
func _on_Button_pressed():
	rng.seed = $CanvasLayer/seed.value
	rng.state = $CanvasLayer/seed.value
	width = $CanvasLayer/width.value
	height = $CanvasLayer/height.value
	_generate()
	pass

#Starts generation process
func _generate():
	#Adjusts Camera positioning and clears gridmap and map
	$Camera.global_transform.origin = Vector3(width, width + height, height)
	($Ground.mesh as PlaneMesh).size = Vector2(width*5, height*5)
	$Ground.global_transform.origin = Vector3(width, 0.0, height)
	$TrackParts.clear()
	map.clear()
	#initializes map with all positions
	for _i in range(width):
		var line:Array = []
		for _j in range(height):
			var possible:Array = def_pos.duplicate(true)
			possible.invert()
			line.append(possible)
		map.append(line)
		
	print("entering")
	#Starts first walk on a random position
	var le_pos:Vector2 = Vector2(
		rng.randi_range(0, width),
		rng.randi_range(0, height))
	#The whole process consists on 3 steps:
	#Collapsing:
	#Collapsing a tile, selects one of the possible options.
	#On the first tile all options are available so one is selected
	#to start the process
	_collapse(_calc_entropy()[1])
	#Propagation:
	#Based on the current tile, propagates (applies the constraints)
	#to adjacent tiles, the algorithm chooses then to proceed to the
	#adjacent tile with lesser entropy (which has better chance to collapse)
	_propagate(_calc_entropy()[1], 0)
	#Update:
	#Update valies on the gridmap
	#_update_map()
	
	#We then repeat the process until all tiles are collapsed
	#(Indicated by the smaller entropy possible, which is 
	#width*height, which states that all tiles have one possible
	#state)
	var ent:Array = _calc_entropy()
	#Rinse and repeat
	while ent[0] > width*height:
		#Yield is here to help visualization, whithout it
		#the algorithm only shows results when done
		yield(get_tree().create_timer(0.01), "timeout")
		ent = _calc_entropy()
		_collapse(ent[1])
		_propagate(ent[1], 0)
		_update_map()
	pass

#Updates Gridmap showing values
func _update_map():
	#Uncommenting this slows the process a lot on larger grids
	#It shows available tiles for each position, adding one
	#label per position on the grid.
	#_print_Values()
	
	#For each tile on the grid, get selected tile from map
	#and grid orientation from constraints
	for i in range(width):
		for j in range(height):
			var possible_tiles = map[i][j]
			if possible_tiles.size() == 1:
				var orientation_tile:int = constraints["parts"][possible_tiles[0]]["orientation"]
				var tile_id:int = constraints["parts"][possible_tiles[0]]["tile_id"]
				var orientation:int = _orthogonal_to_index(
					Vector3(
						0,orientation_tile*PI/2,0
					)
				)
				$TrackParts.set_cell_item(
					i, 
					0,
					j,
					tile_id,
					orientation)
			else:
				#Last element is empty
				$TrackParts.set_cell_item(
					i, 
					0,
					j,
					def_pos.back())
	pass

#Calculates map entropy
#Returns whole map entropy and the position with
#lesser entropy
func _calc_entropy()->Array:
	var entropy:int = 0
	var lowest:Vector2 = Vector2.ZERO
	var positions:Array = []
	for i in range(width):
		for j in range(height):
			var possible_tiles:Array = map[i][j]
			if possible_tiles.size() > 1:
				positions.append(Vector2(i, j))
			entropy += possible_tiles.size()
	
	var lowest_en:int = 100.0
	for pos in positions:
		var possible_tiles:Array = map[pos.x][pos.y]
		if possible_tiles.size() < lowest_en:
			lowest = Vector2(pos.x, pos.y)
			lowest_en = possible_tiles.size()
	return [entropy, lowest]

#Applies rules on the desired position to all neighbors
#For now only horizontal rules (NORTH, SOUTH, EAST and WEST)
#Top and bottom are actually NORTH and SOUTH
func _propagate(pos:Vector2, level:int):
	#There could be deadlocks on rule calculation,
	#Level cap avoids that
	if level > 250:
		return
	
	#For each tile rule
	#Apply tile to neighbor and stores possible directions
	#(if a tile is collapsed or out of bounds, it's discarded)
	var rules:Dictionary = constraints["parts"][map[pos.x][pos.y][0]]["rules"]
	var possible_dirs:Array = []
	for  rule in rules:
		match rule:
			"top":
				if pos.y - 1 >= 0:
					var pos_l:Vector2 = Vector2(pos.x, pos.y - 1)
					_apply_rules(rules["top"], pos_l)
					possible_dirs.append(pos_l)
			"down":
				if pos.y + 1 < height:
					var pos_l:Vector2 = Vector2(pos.x, pos.y + 1)
					_apply_rules(rules["down"], pos_l)
					possible_dirs.append(pos_l)
			"left":
				if pos.x - 1 >= 0:
					var pos_l:Vector2 = Vector2(pos.x - 1, pos.y)
					_apply_rules(rules["left"], pos_l)
					possible_dirs.append(pos_l)
			"right":
				if pos.x + 1 < width:
					var pos_l:Vector2 = Vector2(pos.x + 1, pos.y)
					_apply_rules(rules["right"], pos_l)
					possible_dirs.append(pos_l)
	
	#Propagates rules to the lowest entropy
	#non-collapsed tile
	if possible_dirs.size() > 0:
		var lowest_en:int = 100
		var lowest_en_pos = Vector2.ZERO
		var found:bool = false
		for pos_dir in possible_dirs:
			var possible_tiles:Array = map[pos_dir.x][pos_dir.y]
			if lowest_en > possible_tiles.size() and possible_tiles.size() > 1:
				lowest_en = possible_tiles.size()
				lowest_en_pos = pos_dir
				found = true
		if found:
			_collapse(lowest_en_pos)
			_propagate(lowest_en_pos, level + 1)
			#print(str(pos) + "|" + str(lowest_en_pos))
	pass

#It shows available tiles for each position, adding one
#label per position on the grid. Adds a lot of nodes, be aware
func _print_Values():
	$CanvasLayer.clear()
	for i in range(width):
		for j in range(height):
			var possible_tiles = map[i][j]
			$CanvasLayer.update(Vector3(i, 0.0, j)*2, str(possible_tiles))
	pass

#Collapses a tile, using a random possible tile from
#possible remaining tiles
func _collapse(le_pos:Vector2):
	var select:Array = map[le_pos.x][le_pos.y]
	map[le_pos.x][le_pos.y] = [select[rng.randi_range(0, select.size()-1)]]
	pass

#Remove all non-possible tiles from current at position
#If all tiles are removed, defaults to all possible for
#new calculation
func _apply_rules(rules:Array, pos:Vector2):
	var possible_tiles:Array = map[pos.x][pos.y]
	if possible_tiles.size() == 1:
		return
	
	var to_remove:Array = []
	for i in range(possible_tiles.size()):
		var value = possible_tiles[i]
		if !(value in rules):
			to_remove.append(value)
	
	if to_remove.size() == 0:
		return
	
	for i in range(to_remove.size()):
		map[pos.x][pos.y].remove(possible_tiles.find(to_remove[i]))
	
	if possible_tiles.size() == 0:
		map[pos.x][pos.y] = def_pos.duplicate(true)
		return
	
	return

#Loads constraints from json file
#The file is generated from the scehe:
#res://src/wavefunction/Track.tscn
func _load_constraints():
	var file:File = File.new()
	file.open("res://src/wavefunction/constraints2.json", File.READ)
	var json_raw = file.get_as_text()
	var json:Dictionary = JSON.parse(json_raw).result
	return json

#Translates Rotation input to gridmap values
#(only in )
func _orthogonal_to_index(input:Vector3)->int:
	#Gridmap orientatation values range [-180, 180]
	if round(rad2deg(input.y)) == 270:
		input.y = -PI/2
	if round(rad2deg(input.x)) == 270:
		input.x = -PI/2
	if round(rad2deg(input.z)) == 270:
		input.z = -PI/2
	
	for i in range(orthogonal_angles.size()):
		if input == orthogonal_angles[i]:
			return i
	return -1

