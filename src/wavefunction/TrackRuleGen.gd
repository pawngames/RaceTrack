extends Spatial

#Positions
enum POS{
	RIGHT,
	TOP,
	LEFT,
	DOWN
}

func _ready():
	_analyze()
	pass

#Evaluates possible orientations and possible neighbors
func _analyze():
	var output:Dictionary = {}
	var tiles:Array = []
	var index:int = 0
	var tile_id:int = 0
	#For all children on Track node, evaluates name and slots
	#1 means has slot on position and 0 otherwise
	#order is as follows:
	#   Right, top, left, down
	#For example, a tile that has only one slot at angle 90
	#would be named T0010
	#Further analysis could be made on the mesh to map slots automatically
	for child in get_children():
		var _name:String = child.get_name()
		var labelsStr:String = _name.substr(1, _name.length())
		print(labelsStr)
		var positions:Array = []
		for letter in labelsStr.to_utf8():
			var label:int = letter - 48
			positions.append(label)
		#Map all orientations
		tiles.append([index, _rotate_array(positions, 0), 0, tile_id,[],[],[],[]])
		index += 1
		if !labelsStr.begins_with("1111") and !labelsStr.begins_with("0000"):
			print(labelsStr)
			tiles.append([index, _rotate_array(positions, 1), 1, tile_id,[],[],[],[]])
			index += 1
			tiles.append([index, _rotate_array(positions, 2), 2, tile_id,[],[],[],[]])
			index += 1
			tiles.append([index, _rotate_array(positions, 3), 3, tile_id,[],[],[],[]])
			index += 1
		tile_id += 1
		print("----------------")
	#print(tiles)
	#Evaluate for each direction which tiles and directions connect
	for tile in tiles:
		for pos in POS.values():
			for tile_check in tiles:
				#Checks opposing direction label of tile to check
				var opposing:int = POS.DOWN
				var current:int = pos
				match current:
					POS.RIGHT: 	opposing = POS.LEFT
					POS.TOP: 	opposing = POS.DOWN
					POS.LEFT: 	opposing = POS.RIGHT
					POS.DOWN: 	opposing = POS.TOP
				
				if tile[1][pos] == tile_check[1][opposing]:
					#Stores index of compatible tile
					tile[4 + pos].append(tile_check[0])
	
	#Generates JSON structure from dictionary
	var _out:Dictionary = {}
	_out["parts"] = []
	for tile in tiles:
		var _tile:Dictionary = {
			"index":tile[0],
			"name":str(tile[1]),
			"orientation":tile[2],
			"tile_id":tile[3],
			"rules":{
				"right":tile[4 + POS.RIGHT],
				"top":tile[4 + POS.TOP],
				"left":tile[4 + POS.LEFT],
				"down":tile[4 + POS.DOWN]
			}
		}
		_out["parts"].append(_tile)
	#Generate json with values
	print("----------------")
	var jsonStr = JSON.print(_out)
	#print(jsonStr)
	_save_constraints(jsonStr)
	pass

#Rotates the slot array (mainly by shifting positions)
func _rotate_array(_in:Array, iter:int)->Array:
	var rotated:Array = _in.duplicate(true)
	for i in range(iter):
		rotated.push_front(rotated.pop_back())
	return rotated

#Stores file
func _save_constraints(json:String):
	var file:File = File.new()
	file.open("res://src/test3/constraints2.json", File.WRITE)
	file.store_string(json)
	file.close()
	pass
