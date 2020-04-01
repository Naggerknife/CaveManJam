extends Node2D

signal map_done()

const CAVE_TILE = 47

onready var Map = $LevelTiles
onready var FoliageMap = $Foliage

var Room = preload("res://Scenes/RandomMapGenerator/Room.tscn")
var Player = preload("res://Scenes/Player/Player.tscn")
var Rock = preload("res://Scenes/Rock/Rock.tscn")
var Hole = preload("res://Scenes/Hole/Hole.tscn")

var tile_size = 32
export var num_rooms = 30
var min_size = 5
var max_size = 8
var h_spread = 0

var spawned_rocks = []

var path

export var debug_mode = false

var player = null
var start_room = null
var end_room = null

func _ready():
	randomize()
	make_rooms()

func _process(delta):
	update()

func _draw():
	if debug_mode:
		for room in $Rooms.get_children():
			draw_rect(Rect2(room.position - room.size, room.size * 2), Color(32, 238,0), false)
		
		if path:
			for p in path.get_points():
				for c in path.get_point_connections(p):
					var pp = path.get_point_position(p)
					var cp = path.get_point_position(c)
					draw_line(pp, cp, Color(1, 1, 0), 15, true)
	
func _input(event):
	if debug_mode:
		if event.is_action_pressed("ui_select"):
			for room in $Rooms.get_children():
				room.queue_free()
			make_rooms()
			path = null
			Map.clear()
		
		if event.is_action_pressed("ui_focus_next"):
			player = Player.instance()
			add_child(player)
			player.position = start_room.position
	
func make_rooms():
	for i in range(num_rooms):
		var pos = Vector2(rand_range(-h_spread, h_spread), 0)
		var r = Room.instance()
		var w = min_size + randi() % (max_size - min_size)
		var h = min_size + randi() % (max_size - min_size)
		r.make_room(pos, Vector2(w, h) * tile_size)
		$Rooms.add_child(r)
		
	yield(get_tree().create_timer(1), 'timeout')
	
	var room_positions = []
	for room in $Rooms.get_children():
		if randf() < .2:
			room.queue_free()
		else:
			room.mode = RigidBody2D.MODE_STATIC
			room_positions.append(Vector2(room.position.x, room.position.y))
	
	yield(get_tree(), "idle_frame")
	path = find_mst(room_positions)
	make_map()
		
func find_mst(nodes):
	var path = AStar2D.new()
	path.add_point(path.get_available_point_id(), nodes.pop_front())
	
	while nodes:
		var min_distance = INF
		var min_position = null
		var current_position = null
		
		for p1 in path.get_points():
			p1 = path.get_point_position(p1)
			for p2 in nodes:
				if p1.distance_to(p2) < min_distance:
					min_distance = p1.distance_to(p2)
					min_position = p2
					current_position = p1
					
		var n = path.get_available_point_id()
		path.add_point(n, min_position)
		path.connect_points(path.get_closest_point(current_position), n)
		nodes.erase(min_position)
	
	return path
	
func make_map():
	Map.clear()
	find_start_room()
		
	var hallways = []
	#Set room tiles. 
	for room in $Rooms.get_children():
		var s = (room.size / tile_size).floor()
		var pos = Map.world_to_map(room.position)
		var ul = (room.position / tile_size).floor() - s
		for x in range(2, s.x * 2 - 1):
			for y in range(2, s.y * 2 - 1):
				Map.set_cell(ul.x + x, ul.y + y, CAVE_TILE)
				Map.update_bitmask_area(Vector2(ul.x + x, ul.y + y))
				var rand = randf()
				if room.position != start_room.position:
					#Spawn_Rocks
					if rand > .9:
						var x_pos = ul.x + x
						var y_pos = ul.y + y
						spawn_rock(x_pos, y_pos)
					#Spawn_Foliage
					elif rand > .7:
						var x_pos = ul.x + x
						var y_pos = ul.y + y
						spawn_foliage(x_pos, y_pos)
		
		#Set Hallways
		var p = path.get_closest_point(room.position)
		for connection in path.get_point_connections(p):
			if not connection in hallways:
				var start = Map.world_to_map(path.get_point_position(p))
				var end = Map.world_to_map(path.get_point_position(connection))
				carve_path(start, end)	
		hallways.append(p)
		
	spawn_player()
	spawn_hole()
	
	emit_signal("map_done")
	
func carve_path(pos1, pos2):
	var x_diff = sign(pos2.x - pos1.x)
	var y_diff = sign(pos2.y - pos1.y)
	if x_diff == 0: x_diff = pow(-1, randi() % 2)
	if y_diff == 0: y_diff = pow(-1, randi() % 2)
	
	var x_y = pos1
	var y_x = pos2
	
	for x in range(pos1.x, pos2.x, x_diff):
		Map.set_cell(x, x_y.y, CAVE_TILE)
		Map.set_cell(x, x_y.y + y_diff, CAVE_TILE)
		Map.update_bitmask_area(Vector2(x, x_y.y))
		Map.update_bitmask_area(Vector2(x, x_y.y + y_diff))
	for y in range(pos1.y, pos2.y, y_diff):
		Map.set_cell(y_x.x, y, CAVE_TILE)	
		Map.set_cell(y_x.x + x_diff, y, CAVE_TILE)
		Map.update_bitmask_area(Vector2(y_x.x, y))
		Map.update_bitmask_area(Vector2(y_x.x + x_diff, y))
	
func find_start_room():
	var min_x = INF
	for room in $Rooms.get_children():
		if room.position.x < min_x:
			start_room = room
			min_x = room.position.x

func spawn_player():
		player = Player.instance()
		add_child(player)
		player.position = start_room.position

func spawn_hole():
	var random_number = rand_range(0, spawned_rocks.size() + 1)
	var new_hole = Hole.instance()
	add_child(new_hole)
	new_hole.position = spawned_rocks[random_number].position

func spawn_rock(x_pos, y_pos):
	var rock = Rock.instance()
	add_child(rock)
	var current_tile = Map.map_to_world(Vector2(x_pos, y_pos))
	current_tile.x += 16
	current_tile.y += 16
	rock.position = current_tile
	spawned_rocks.append(rock)
	
func spawn_foliage(x_pos, y_pos):
	var foliage_numbers = [4, 5]
	var rand = rand_range(0, foliage_numbers.size())
	FoliageMap.set_cell(x_pos, y_pos, foliage_numbers[rand])
	