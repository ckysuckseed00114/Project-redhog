class_name PlayerSpriteLoader
extends RefCounted

## โหลด sprite ผู้เล่นจากโครงสร้างเดียว:
## res://animation/player/{job}/{gender}/{folder}/000.png, 001.png, ...

const BASE := "res://animation/player"

const ANIM_FOLDER_MAP := {
	"idle": "idle",
	"walk_side": "walking_side",
	"walk_down": "walking_down",
	"walk_down_right": "walking_down_right",
	"walk_upright": "walking_up_right",
	"walk_up": "walking_up",
	"attack": "attack",
	"hurt": "hurt",
	"dying": "dying",
}

const ALL_JOBS := ["novice", "sword", "mage", "thief", "acolyte", "hunter"]
const ALL_GENDERS := ["male", "female"]

const ATTACK_HIT_FRAMES := {
	"novice_male": 4,
	"novice_female": 5,
}

const HURT_FRAME_INDICES := {
	"novice_male": [1, 2],
	"novice_female": [1, 2],
}

const ANIM_SPEEDS := {
	"idle": 8.0,
	"walking_side": 12.0,
	"walking_down": 12.0,
	"walking_down_right": 12.0,
	"walking_up_right": 12.0,
	"walking_up": 12.0,
	"walking": 12.0,
	"attack": 10.0,
	"hurt": 10.0,
	"dying": 10.0,
}

const MAX_PROBE_FRAMES := 64


static func anim_dir(job: String, gender: String, folder: String) -> String:
	return "%s/%s/%s/%s" % [BASE, job, gender, folder]


static func frame_path(job: String, gender: String, folder: String, index: int = 0) -> String:
	return "%s/%03d.png" % [anim_dir(job, gender, folder), index]


static func has_frames(job: String, gender: String, folder: String) -> bool:
	return ResourceLoader.exists(frame_path(job, gender, folder, 0))


static func load_preview(job: String, gender: String, folder: String = "idle", index: int = 0) -> Texture2D:
	var path := frame_path(job, gender, folder, index)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func build_sprite_frames(job: String, gender: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for folder in ANIM_FOLDER_MAP:
		var anim_name: String = ANIM_FOLDER_MAP[folder]
		var paths := collect_frame_paths(job, gender, folder)
		if anim_name == "hurt":
			paths = _filter_hurt_paths(job, gender, paths)
		if paths.is_empty():
			continue
		_add_animation(frames, anim_name, paths)

	if frames.has_animation("walking_side") and not frames.has_animation("walking"):
		_duplicate_animation(frames, "walking_side", "walking")

	return frames


static func collect_frame_paths(job: String, gender: String, folder: String) -> PackedStringArray:
	return _probe_indexed_frames(anim_dir(job, gender, folder))


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


static func _duplicate_animation(frames: SpriteFrames, from_anim: String, to_anim: String) -> void:
	if not frames.has_animation(from_anim):
		return
	frames.add_animation(to_anim)
	frames.set_animation_speed(to_anim, frames.get_animation_speed(from_anim))
	frames.set_animation_loop(to_anim, frames.get_animation_loop(from_anim))
	var count := frames.get_frame_count(from_anim)
	for i in range(count):
		frames.add_frame(to_anim, frames.get_frame_texture(from_anim, i))


static func _probe_indexed_frames(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(MAX_PROBE_FRAMES):
		var path := "%s/%03d.png" % [dir_path, i]
		if ResourceLoader.exists(path):
			out.append(path)
		elif not out.is_empty():
			break
	return out


static func get_attack_hit_frame(job: String, gender: String, frames: SpriteFrames) -> int:
	var key := "%s_%s" % [job, gender]
	if ATTACK_HIT_FRAMES.has(key) and frames.has_animation("attack"):
		var frame: int = ATTACK_HIT_FRAMES[key]
		return clampi(frame, 0, frames.get_frame_count("attack") - 1)
	if frames.has_animation("attack"):
		var count := frames.get_frame_count("attack")
		return clampi(int(floor(float(count) * 0.45)), 0, count - 1)
	return 2


static func _filter_hurt_paths(job: String, gender: String, paths: PackedStringArray) -> PackedStringArray:
	var key := "%s_%s" % [job, gender]
	if not HURT_FRAME_INDICES.has(key):
		return paths
	var filtered := PackedStringArray()
	for idx in HURT_FRAME_INDICES[key]:
		if idx >= 0 and idx < paths.size():
			filtered.append(paths[idx])
	return filtered


static func get_sprite_scale(frames: SpriteFrames) -> Vector2:
	const LEGACY_FRAME_HEIGHT := 900.0
	const LEGACY_SCALE := 0.045
	var target_height := LEGACY_FRAME_HEIGHT * LEGACY_SCALE
	for anim_name in ANIM_FOLDER_MAP.values():
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


static func ensure_folder_structure() -> void:
	for job in ALL_JOBS:
		for gender in ALL_GENDERS:
			for folder in ANIM_FOLDER_MAP:
				DirAccess.make_dir_recursive_absolute(anim_dir(job, gender, folder))
