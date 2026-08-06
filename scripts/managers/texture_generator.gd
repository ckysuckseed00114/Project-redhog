extends Node

var textures: Dictionary = {}


func _ready() -> void:
	_generate_all()


func get_texture(key: String) -> Texture2D:
	# 1. เช็คก่อนว่าเคยโหลดเก็บไว้ใน Dictionary แล้วหรือยัง ถ้ามีส่งคืนเลย (เร็วมาก)
	if textures.has(key):
		return textures[key]

	# 2. ค้นหาจากฐานข้อมูลกลาง ItemDatabase อัตโนมัติ
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


func _generate_all() -> void:
	_generate_ground_texture()
	_generate_poring_texture()
	_generate_item_textures()


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


func _generate_ground_texture() -> void:
	var img := _make_image(Vector2i(32, 32))
	img.fill(Color8(0x4a, 0x7c, 0x3f)) # <--- สีพื้นหลังหลัก (เขียว)
	_fill_rect(img, 0, 0, 16, 16, Color(0.329, 0.541, 0.278, 0.5)) # <--- สีลวดลายช่องตาราง
	_fill_rect(img, 16, 16, 16, 16, Color(0.329, 0.541, 0.278, 0.5))
	_image_to_texture(img, "ground_tile")


func _generate_ground_map_texture() -> ImageTexture:
	var tile := textures["ground_tile"] as ImageTexture
	var tile_img := tile.get_image()
	var img := Image.create(
		GameConstants.MAP_WORLD_WIDTH,
		GameConstants.MAP_WORLD_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	for ty in range(0, GameConstants.MAP_WORLD_HEIGHT, 32):
		for tx in range(0, GameConstants.MAP_WORLD_WIDTH, 32):
			img.blit_rect(tile_img, Rect2i(0, 0, 32, 32), Vector2i(tx, ty))
			
	var tex := ImageTexture.create_from_image(img)
	
	# เพิ่มการกำหนดค่า Flag ให้เท็กซ์เจอร์แผนที่เป็น Nearest เสมอ
	# (ถ้า Godot เวอร์ชันของคุณใช้ภาพ ImageTexture โดยตรง ให้กำหนดที่ตัว Sprite2D ตอนเรียกใช้งาน)
	
	textures["ground_map"] = tex
	return tex


func get_ground_map_texture() -> Texture2D:
	if not textures.has("ground_map"):
		return _generate_ground_map_texture()
	return textures["ground_map"]


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
