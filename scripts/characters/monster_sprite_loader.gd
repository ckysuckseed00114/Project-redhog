class_name MonsterSpriteLoader
extends RefCounted

const BASE := "res://animation/monster"
const DIAGONAL_BLEND := 0.45

# 000=ล่าง(หน้า), 001=บน(หลัง), 002=ซ้าย, 003=ขวา
const DIRECTION_FRAMES := {
	"walk_down": 0,
	"walk_up": 1,
	"walk_left": 2,
	"walk_right": 3,
}


static func frame_path(folder: String, index: int) -> String:
	return "%s/%s/%03d.png" % [BASE, folder, index]


static func has_folder(folder: String) -> bool:
	return ResourceLoader.exists(frame_path(folder, 0))


static func build_sprite_frames(folder: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_name in DIRECTION_FRAMES:
		var idx: int = DIRECTION_FRAMES[anim_name]
		var path := frame_path(folder, idx)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		frames.add_frame(anim_name, tex)
	return frames


static func resolve_walk_anim(dir: Vector2, fallback: String = "walk_down") -> String:
	if dir.length_squared() < 0.0001:
		return fallback

	var ax := absf(dir.x)
	var ay := absf(dir.y)

	if ax > 0.01 and ay > 0.01 and minf(ax, ay) / maxf(ax, ay) >= DIAGONAL_BLEND:
		if ax >= ay:
			return "walk_left" if dir.x < 0.0 else "walk_right"
		return "walk_up" if dir.y < 0.0 else "walk_down"

	if ax > ay:
		return "walk_left" if dir.x < 0.0 else "walk_right"
	return "walk_up" if dir.y < 0.0 else "walk_down"


static func compute_sprite_scale(frames: SpriteFrames, display_height: float, scale_mul: float = 1.0) -> Vector2:
	var h := _first_frame_height(frames)
	if h <= 0.0:
		return Vector2(scale_mul, scale_mul)
	var s := (display_height / h) * scale_mul
	return Vector2(s, s)


static func apply_visual(sprite: AnimatedSprite2D, visual: Dictionary) -> bool:
	if sprite == null:
		return false
	var folder := str(visual.get("sprite_folder", ""))
	if folder.is_empty():
		return false
	var frames := build_sprite_frames(folder)
	if frames.get_animation_names().is_empty():
		return false

	var display_height := float(visual.get("display_height", MonsterDB.DEFAULT_DISPLAY_HEIGHT))
	var scale_mul := float(visual.get("sprite_scale_mul", 1.0))

	sprite.sprite_frames = frames
	sprite.scale = compute_sprite_scale(frames, display_height, scale_mul)
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = Vector2.ZERO
	sprite.flip_h = false
	sprite.flip_v = false

	if frames.has_animation("walk_down"):
		sprite.play("walk_down")
	else:
		sprite.play(String(frames.get_animation_names()[0]))
	return true


static func play_facing(sprite: AnimatedSprite2D, dir: Vector2, fallback: String = "walk_down") -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	sprite.flip_h = false
	sprite.flip_v = false
	var anim := resolve_walk_anim(dir, fallback)
	if not sprite.sprite_frames.has_animation(anim):
		anim = fallback
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


static func _first_frame_height(frames: SpriteFrames) -> float:
	for anim_name in DIRECTION_FRAMES:
		if not frames.has_animation(anim_name):
			continue
		if frames.get_frame_count(anim_name) <= 0:
			continue
		var tex: Texture2D = frames.get_frame_texture(anim_name, 0)
		if tex == null:
			continue
		return float(tex.get_height())
	return 0.0
