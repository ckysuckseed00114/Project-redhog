class_name MapScenery
extends Node2D

const TILE_SIZE := 32
const BORDER_INSET := 40.0
const MIN_SPACING := 52.0

var _rng := RandomNumberGenerator.new()


func setup(theme: String, map_size: Vector2, exclusions: Array[Vector2] = []) -> void:
	_rng.seed = hash(theme + "|" + str(int(map_size.x)) + "x" + str(int(map_size.y)))
	match theme:
		"city":
			_spawn_city_layout(map_size, exclusions)
		_:
			_spawn_field_layout(map_size, exclusions)


func _spawn_field_layout(map_size: Vector2, exclusions: Array[Vector2]) -> void:
	_spawn_border_line(map_size, "decor_tree", 64, 0.85)
	_spawn_scatter(map_size, exclusions, [
		{"key": "decor_bush", "count": 28, "scale_min": 0.9, "scale_max": 1.2, "z": 3},
		{"key": "decor_rock", "count": 16, "scale_min": 0.8, "scale_max": 1.1, "z": 2},
		{"key": "decor_flower", "count": 36, "scale_min": 0.9, "scale_max": 1.0, "z": 1},
	], Vector2(120, 80))
	_spawn_path_stones(map_size, exclusions)


func _spawn_city_layout(map_size: Vector2, exclusions: Array[Vector2]) -> void:
	var center := map_size * 0.5
	_spawn_plaza_ring(center, 110.0)
	_spawn_border_line(map_size, "decor_fence", 48, 0.75, true)
	_spawn_scatter(map_size, exclusions, [
		{"key": "decor_lamp", "count": 10, "scale_min": 1.0, "scale_max": 1.0, "z": 4},
		{"key": "decor_barrel", "count": 8, "scale_min": 0.95, "scale_max": 1.05, "z": 3},
		{"key": "decor_bush", "count": 12, "scale_min": 0.85, "scale_max": 1.0, "z": 2},
	], Vector2(96, 72))


func _spawn_border_line(map_size: Vector2, texture_key: String, spacing: float, sprite_scale: float, inset_only: bool = false) -> void:
	var tex := TextureGenerator.get_texture(texture_key)
	if tex == null:
		return
	var margin := BORDER_INSET
	var x := margin
	while x < map_size.x - margin:
		_add_sprite(tex, Vector2(x, margin), sprite_scale, 1)
		if not inset_only:
			_add_sprite(tex, Vector2(x, map_size.y - margin - 16), sprite_scale, 1)
		x += spacing
	var y := margin + spacing
	while y < map_size.y - margin - spacing:
		_add_sprite(tex, Vector2(margin, y), sprite_scale, 1)
		if not inset_only:
			_add_sprite(tex, Vector2(map_size.x - margin - 16, y), sprite_scale, 1)
		y += spacing


func _spawn_plaza_ring(center: Vector2, radius: float) -> void:
	var tex = TextureGenerator.get_texture("decor_plaza_stone")
	if tex == null:
		return
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		_add_sprite(tex, pos, 1.0, 1, true)


func _spawn_path_stones(map_size: Vector2, exclusions: Array[Vector2]) -> void:
	var tex = TextureGenerator.get_texture("decor_path_stone")
	if tex == null:
		return
	var center_x := map_size.x * 0.5
	for y in range(int(BORDER_INSET) + 48, int(map_size.y) - 80, 40):
		var pos := Vector2(center_x + _rng.randf_range(-8, 8), float(y))
		if _can_place(pos, exclusions, 40.0, map_size):
			_add_sprite(tex, pos, _rng.randf_range(0.85, 1.0), 1, true)


func _spawn_scatter(
	map_size: Vector2,
	exclusions: Array[Vector2],
	layers: Array,
	center_keepout: Vector2
) -> void:
	var center := map_size * 0.5
	for layer in layers:
		var key: String = layer.get("key", "")
		var count: int = int(layer.get("count", 0))
		var tex := TextureGenerator.get_texture(key)
		if tex == null:
			continue
		var placed := 0
		var attempts := 0
		while placed < count and attempts < count * 12:
			attempts += 1
			var pos := Vector2(
				_rng.randf_range(BORDER_INSET + 24, map_size.x - BORDER_INSET - 24),
				_rng.randf_range(BORDER_INSET + 24, map_size.y - BORDER_INSET - 24)
			)
			if pos.distance_to(center) < center_keepout.x:
				continue
			if not _can_place(pos, exclusions, MIN_SPACING, map_size):
				continue
			var sprite_scale := _rng.randf_range(float(layer.get("scale_min", 1.0)), float(layer.get("scale_max", 1.0)))
			_add_sprite(tex, pos, sprite_scale, int(layer.get("z", 2)), _rng.randf() > 0.5)
			placed += 1


func _can_place(pos: Vector2, exclusions: Array[Vector2], min_dist: float, map_size: Vector2) -> bool:
	if pos.x < BORDER_INSET or pos.y < BORDER_INSET:
		return false
	if pos.x > map_size.x - BORDER_INSET or pos.y > map_size.y - BORDER_INSET:
		return false
	for ex in exclusions:
		if pos.distance_squared_to(ex) < min_dist * min_dist:
			return false
	return true


func _add_sprite(tex: Texture2D, pos: Vector2, sprite_scale: float, z: int, centered: bool = false) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(sprite_scale, sprite_scale) 
	spr.centered = centered
	spr.position = pos
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
