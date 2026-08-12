class_name MonsterSpriteLoader
extends RefCounted

const BASE := "res://animation/monster"
const MAX_FRAMES := 64

const ANIM_MAP := {
	"idle": "Idle",
	"walking": "Walking",
	"attack": "Slashing",
	"hurt": "Hurt",
	"dying": "Dying",
}

const ANIM_SPEEDS := {
	"idle": 10.0,
	"walking": 10.0,
	"attack": 10.0,
	"hurt": 10.0,
	"dying": 10.0,
}


static func seq_dir(creature: String, folder: String) -> String:
	return "%s/%s/PNG/PNG Sequences/%s" % [BASE, creature, folder]


static func frame_path(creature: String, folder: String, index: int) -> String:
	return "%s/0_%s_%s_%03d.png" % [seq_dir(creature, folder), creature, folder, index]


static func collect_frame_paths(creature: String, folder: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(MAX_FRAMES):
		var path := frame_path(creature, folder, i)
		if ResourceLoader.exists(path):
			out.append(path)
		elif not out.is_empty():
			break
	return out


static func build_sprite_frames(creature: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_name in ANIM_MAP:
		var folder: String = ANIM_MAP[anim_name]
		var paths := collect_frame_paths(creature, folder)
		if paths.is_empty():
			continue
		_add_animation(frames, anim_name, paths)
	return frames


static func get_sprite_scale(frames: SpriteFrames) -> Vector2:
	const LEGACY_FRAME_HEIGHT := 900.0
	const LEGACY_SCALE := 0.03
	var target_height := LEGACY_FRAME_HEIGHT * LEGACY_SCALE
	for anim_name in ANIM_MAP:
		if not frames.has_animation(anim_name):
			continue
		if frames.get_frame_count(anim_name) <= 0:
			continue
		var tex: Texture2D = frames.get_frame_texture(anim_name, 0)
		if tex == null:
			continue
		var h := float(tex.get_height())
		if h <= 0.0:
			continue
		return Vector2(target_height / h, target_height / h)
	return Vector2(LEGACY_SCALE, LEGACY_SCALE)


static func _add_animation(frames: SpriteFrames, anim_name: String, paths: PackedStringArray) -> void:
	var loaded: Array[Texture2D] = []
	for path in paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			loaded.append(tex)
	if loaded.is_empty():
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, ANIM_SPEEDS.get(anim_name, 10.0))
	var loops := anim_name != "attack" and anim_name != "hurt" and anim_name != "dying"
	frames.set_animation_loop(anim_name, loops)
	for tex in loaded:
		frames.add_frame(anim_name, tex)
