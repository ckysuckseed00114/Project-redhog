extends Node

var textures: Dictionary = {}


func _ready() -> void:
	_generate_all()


func get_texture(key: String) -> Texture2D:
	if textures.has(key):
		return textures[key]

	if key.begins_with("decor_"):
		_generate_decor_textures()
		if textures.has(key):
			return textures[key]

	# ค้นหาจากฐานข้อมูลกลาง ItemDatabase อัตโนมัติ
	var item_data = ItemDatabase.get_item(key)
	if item_data.has("texture_path") and ResourceLoader.exists(item_data["texture_path"]):
		var custom_tex = load(item_data["texture_path"])
		if custom_tex:
			textures[key] = custom_tex # <--- บันทึกเก็บไว้ใช้รอบหน้า
			return custom_tex

	# 3. สำรองกรณีเรียกชื่อเดิมๆ
	if key in ["wood_sword", "sword01", "item_sword"]:
		var custom_sword = load("res://weapon/sword01.tres")
		if custom_sword:
			textures[key] = custom_sword # <--- บันทึกเก็บไว้
			return custom_sword
	elif key in ["armor01", "item_armor", "armor"]:
		var custom_armor = load("res://armor/armor01.tres")
		if custom_armor:
			textures[key] = custom_armor # <--- บันทึกเก็บไว้
			return custom_armor
			
	return null

func _make_image(size: Vector2i) -> Image:
	return Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, color)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var x0 := int(cx - rx)
	var x1 := int(cx + rx)
	var y0 := int(cy - ry)
	var y1 := int(cy + ry)
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var dx := (px - cx) / rx
			var dy := (py - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, color)


func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	_fill_ellipse(img, cx, cy, r, r, color)


func _image_to_texture(img: Image, key: String) -> ImageTexture:
	var tex := ImageTexture.create_from_image(img)
	textures[key] = tex
	return tex


func _generate_all() -> void:
	_generate_ground_textures()
	_generate_decor_textures()
	_generate_poring_texture()
	_generate_item_textures()


func _generate_ground_textures() -> void:
	_generate_field_ground_tile()
	_generate_city_ground_tile()


func _generate_field_ground_tile() -> void:
	var img := _make_image(Vector2i(32, 32))
	var base := Color8(0x4a, 0x7c, 0x3f)
	var dark := Color8(0x3d, 0x6a, 0x34)
	var light := Color8(0x58, 0x8f, 0x4a)
	img.fill(base)
	_fill_rect(img, 0, 0, 16, 16, dark)
	_fill_rect(img, 16, 16, 16, 16, light)
	for i in range(6):
		var px := 4 + i * 5
		var py := 6 + (i % 3) * 8
		img.set_pixel(px, py, Color8(0x6f, 0xa3, 0x55))
	_image_to_texture(img, "ground_tile_field")


func _generate_city_ground_tile() -> void:
	var img := _make_image(Vector2i(32, 32))
	var mortar := Color8(0x4a, 0x44, 0x3c)
	var stone_a := Color8(0x7a, 0x72, 0x66)
	var stone_b := Color8(0x6a, 0x63, 0x58)
	var stone_c := Color8(0x8a, 0x82, 0x74)
	img.fill(mortar)
	_fill_rect(img, 1, 1, 14, 14, stone_a)
	_fill_rect(img, 17, 1, 14, 14, stone_b)
	_fill_rect(img, 1, 17, 14, 14, stone_c)
	_fill_rect(img, 17, 17, 14, 14, stone_a)
	_image_to_texture(img, "ground_tile_city")


func _generate_ground_map_texture(theme: String = "field") -> ImageTexture:
	var cache_key := "ground_map_" + theme
	if textures.has(cache_key):
		return textures[cache_key]

	var tile_key := "ground_tile_city" if theme == "city" else "ground_tile_field"
	if not textures.has(tile_key):
		_generate_ground_textures()

	var tile := textures[tile_key] as ImageTexture
	var tile_img := tile.get_image()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ground|" + theme)

	var img := Image.create(
		GameConstants.MAP_WORLD_WIDTH,
		GameConstants.MAP_WORLD_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)

	for ty in range(0, GameConstants.MAP_WORLD_HEIGHT, 32):
		for tx in range(0, GameConstants.MAP_WORLD_WIDTH, 32):
			img.blit_rect(tile_img, Rect2i(0, 0, 32, 32), Vector2i(tx, ty))
			if theme == "field" and rng.randf() < 0.18:
				var patch := Rect2i(tx + rng.randi_range(4, 12), ty + rng.randi_range(4, 12), 8, 8)
				for py in range(patch.position.y, patch.position.y + patch.size.y):
					for px in range(patch.position.x, patch.position.x + patch.size.x):
						if px < img.get_width() and py < img.get_height():
							img.set_pixel(px, py, Color8(0x65, 0x9a, 0x48))
			elif theme == "city" and rng.randf() < 0.08:
				var px := tx + rng.randi_range(2, 26)
				var py := ty + rng.randi_range(2, 26)
				img.set_pixel(px, py, Color8(0x55, 0x4f, 0x46))

	if theme == "field":
		_paint_field_paths(img)
	elif theme == "city":
		_paint_city_plaza(img)

	var tex := ImageTexture.create_from_image(img)
	textures[cache_key] = tex
	return tex


func _paint_field_paths(img: Image) -> void:
	var dirt := Color8(0x8b, 0x6b, 0x43)
	var cx := int(GameConstants.MAP_WORLD_WIDTH / 2.0)
	for y in range(40, GameConstants.MAP_WORLD_HEIGHT - 40, 2):
		for dx in range(-10, 11):
			var px := cx + dx
			if px >= 0 and px < img.get_width() and y < img.get_height():
				img.set_pixel(px, y, dirt.lerp(img.get_pixel(px, y), 0.35))


func _paint_city_plaza(img: Image) -> void:
	var plaza := Color8(0x9a, 0x8f, 0x78)
	var cx := int(GameConstants.MAP_WORLD_WIDTH / 2.0)
	var cy := int(GameConstants.MAP_WORLD_HEIGHT / 2.0)
	var radius := 96
	for py in range(max(0, cy - radius), min(img.get_height(), cy + radius)):
		for px in range(max(0, cx - radius), min(img.get_width(), cx + radius)):
			if Vector2(px, py).distance_to(Vector2(cx, cy)) <= float(radius):
				var existing := img.get_pixel(px, py)
				img.set_pixel(px, py, plaza.lerp(existing, 0.55))


func get_ground_map_texture(theme: String = "field") -> Texture2D:
	var cache_key := "ground_map_" + theme
	if not textures.has(cache_key):
		return _generate_ground_map_texture(theme)
	return textures[cache_key]


func get_backdrop_texture(theme: String = "field") -> Texture2D:
	var key := "backdrop_" + theme
	if textures.has(key):
		return textures[key]

	var img := Image.create(
		GameConstants.MAP_WORLD_WIDTH,
		GameConstants.MAP_WORLD_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	var top := Color8(0x2a, 0x4a, 0x62) if theme == "field" else Color8(0x3a, 0x34, 0x30)
	var bottom := Color8(0x6b, 0x9a, 0x72) if theme == "field" else Color8(0x6a, 0x62, 0x58)
	for y in range(img.get_height()):
		var t := float(y) / float(img.get_height())
		var row_color := top.lerp(bottom, t)
		for x in range(img.get_width()):
			img.set_pixel(x, y, row_color)
	return _image_to_texture(img, key)


func _generate_decor_textures() -> void:
	_generate_tree_texture()
	_generate_bush_texture()
	_generate_rock_texture()
	_generate_lamp_texture()
	_generate_flower_texture()
	_generate_barrel_texture()
	_generate_fence_texture()
	_generate_plaza_stone_texture()
	_generate_path_stone_texture()


func _generate_tree_texture() -> void:
	var img := _make_image(Vector2i(24, 40))
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 10, 24, 4, 14, Color8(0x6d, 0x4c, 0x33))
	_fill_ellipse(img, 12, 16, 11, 10, Color8(0x2f, 0x7a, 0x3a))
	_fill_ellipse(img, 12, 12, 9, 8, Color8(0x3f, 0x9a, 0x48))
	_fill_ellipse(img, 12, 8, 6, 5, Color8(0x52, 0xb5, 0x58))
	_image_to_texture(img, "decor_tree")


func _generate_bush_texture() -> void:
	var img := _make_image(Vector2i(20, 14))
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 10, 9, 9, 5, Color8(0x3a, 0x8a, 0x42))
	_fill_ellipse(img, 6, 8, 4, 3, Color8(0x48, 0xa0, 0x50))
	_fill_ellipse(img, 14, 8, 4, 3, Color8(0x48, 0xa0, 0x50))
	_image_to_texture(img, "decor_bush")


func _generate_rock_texture() -> void:
	var img := _make_image(Vector2i(16, 12))
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 8, 8, 7, 5, Color8(0x7a, 0x7a, 0x82))
	_fill_ellipse(img, 6, 7, 3, 2, Color8(0x9a, 0x9a, 0xa8))
	_image_to_texture(img, "decor_rock")


func _generate_lamp_texture() -> void:
	var img := _make_image(Vector2i(12, 32))
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 5, 10, 2, 20, Color8(0x4a, 0x44, 0x3c))
	_fill_rect(img, 3, 4, 6, 6, Color8(0xd9, 0xc4, 0x6a))
	_fill_rect(img, 4, 5, 4, 4, Color8(0xff, 0xef, 0x9a))
	_fill_rect(img, 4, 28, 4, 2, Color8(0x5a, 0x52, 0x48))
	_image_to_texture(img, "decor_lamp")


func _generate_flower_texture() -> void:
	var img := _make_image(Vector2i(8, 8))
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 4, 5, 1, Color8(0x3d, 0x7a, 0x34))
	_fill_circle(img, 4, 3, 2, Color8(0xf1, 0xc4, 0x0f))
	_fill_circle(img, 3, 4, 1, Color8(0xe7, 0x4c, 0x3c))
	_fill_circle(img, 5, 4, 1, Color8(0xe7, 0x4c, 0x3c))
	_image_to_texture(img, "decor_flower")


func _generate_barrel_texture() -> void:
	var img := _make_image(Vector2i(14, 16))
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 2, 3, 10, 11, Color8(0x8b, 0x5a, 0x2b))
	_fill_rect(img, 2, 6, 10, 1, Color8(0x6d, 0x45, 0x22))
	_fill_rect(img, 2, 10, 10, 1, Color8(0x6d, 0x45, 0x22))
	_image_to_texture(img, "decor_barrel")


func _generate_fence_texture() -> void:
	var img := _make_image(Vector2i(32, 16))
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 2, 4, 28, 2, Color8(0x7a, 0x5a, 0x36))
	_fill_rect(img, 2, 10, 28, 2, Color8(0x7a, 0x5a, 0x36))
	for x in range(4, 28, 6):
		_fill_rect(img, x, 2, 2, 12, Color8(0x8b, 0x65, 0x3d))
	_image_to_texture(img, "decor_fence")


func _generate_plaza_stone_texture() -> void:
	var img := _make_image(Vector2i(12, 12))
	img.fill(Color8(0x9a, 0x8f, 0x78))
	_fill_rect(img, 1, 1, 10, 10, Color8(0xaa, 0xa0, 0x88))
	_image_to_texture(img, "decor_plaza_stone")


func _generate_path_stone_texture() -> void:
	var img := _make_image(Vector2i(10, 8))
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, 5, 5, 4, 3, Color8(0x9a, 0x82, 0x62))
	_image_to_texture(img, "decor_path_stone")


func _generate_poring_texture() -> void:
	var img := _make_image(Vector2i(20, 20))
	_fill_ellipse(img, 10, 17, 6, 2, Color(0, 0, 0, 0.2))
	_fill_ellipse(img, 10, 10, 8, 7, Color8(0xc0, 0x39, 0x2b))
	_fill_circle(img, 7, 8, 2, Color8(0xff, 0xff, 0xff))
	_fill_circle(img, 13, 8, 2, Color8(0xff, 0xff, 0xff))
	_fill_circle(img, 7, 8, 1, Color8(0x00, 0x00, 0x00))
	_fill_circle(img, 13, 8, 1, Color8(0x00, 0x00, 0x00))
	_image_to_texture(img, "poring")


func _generate_item_textures() -> void:
	var potion := _make_image(Vector2i(16, 16))
	_fill_rect(potion, 3, 5, 10, 9, Color8(0xe7, 0x4c, 0x3c))
	_fill_rect(potion, 6, 2, 4, 3, Color8(0xec, 0xf0, 0xf1))
	_image_to_texture(potion, "item_red_potion")

	var blue := _make_image(Vector2i(16, 16))
	_fill_rect(blue, 3, 5, 10, 9, Color8(0x34, 0x98, 0xdb))
	_fill_rect(blue, 6, 2, 4, 3, Color8(0xec, 0xf0, 0xf1))
	_image_to_texture(blue, "item_blue_potion")

	var white := _make_image(Vector2i(16, 16))
	_fill_rect(white, 3, 5, 10, 9, Color8(0xec, 0xf0, 0xf1))
	_fill_rect(white, 6, 2, 4, 3, Color8(0xbd, 0xc3, 0xc7))
	_image_to_texture(white, "item_white_potion")

	var apple := _make_image(Vector2i(16, 16))
	_fill_rect(apple, 7, 2, 2, 4, Color8(0x27, 0xae, 0x60))
	_fill_circle(apple, 8, 10, 5, Color8(0xd9, 0x53, 0x4f))
	_image_to_texture(apple, "item_apple")

	var dagger := _make_image(Vector2i(16, 16))
	_fill_rect(dagger, 7, 2, 2, 10, Color8(0x95, 0xa5, 0xa6))
	_fill_rect(dagger, 6, 12, 4, 3, Color8(0xd3, 0x54, 0x00))
	_image_to_texture(dagger, "item_dagger")
