class_name PlayerSpriteLoader
extends RefCounted

const BASE := "res://animation/player"
const LEGACY_GENDER_BASE := "res://animation/player"

const ANIM_FOLDER_MAP := {
	"idle": "Idle",
	"walking": "Walking",
	"attack": "Slashing",
	"hurt": "Hurt",
	"dying": "Dying",
}

const ALL_JOBS := ["novice", "sword", "mage", "thief", "acolyte", "hunter"]
const ALL_GENDERS := ["male", "female"]

const ATTACK_HIT_FRAMES := {
	"novice_male": 4,
	"novice_female": 4,
}

const HURT_FRAME_INDICES := {
	"novice_male": [1, 2],
}

const MAX_PROBE_FRAMES := 64


static func build_sprite_frames(job: String, gender: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for anim_name in ANIM_FOLDER_MAP:
		var folder_name: String = ANIM_FOLDER_MAP[anim_name]
		var paths := _collect_frame_paths(job, gender, folder_name)
		if anim_name == "hurt":
			paths = _filter_hurt_paths(job, gender, paths)
		if paths.is_empty():
			continue
		var loaded: Array[Texture2D] = []
		for path in paths:
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				loaded.append(tex)
		if loaded.is_empty():
			continue
		frames.add_animation(anim_name)
		var speed := 8.0 if anim_name == "idle" else 10.0
		if anim_name == "walking":
			speed = 12.0
		frames.set_animation_speed(anim_name, speed)
		var loops: bool = anim_name != "attack" and anim_name != "hurt" and anim_name != "dying"
		frames.set_animation_loop(anim_name, loops)
		for tex in loaded:
			frames.add_frame(anim_name, tex)
	return frames


static func _collect_frame_paths(job: String, gender: String, folder_name: String) -> PackedStringArray:
	var candidates := [
		"%s/%s/%s/PNG/PNG Sequences/%s" % [BASE, job, gender, folder_name],
		"%s/%s/PNG/PNG Sequences/%s" % [LEGACY_GENDER_BASE, gender, folder_name],
	]
	for dir_path in candidates:
		var paths := _list_pngs(dir_path, job, gender, folder_name)
		if not paths.is_empty():
			return paths
	return PackedStringArray()


static func _list_pngs(dir_path: String, job: String, gender: String, folder_name: String) -> PackedStringArray:
	if DirAccess.dir_exists_absolute(dir_path):
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		if not files.is_empty():
			var names: Array[String] = []
			for file_name in files:
				if file_name.ends_with(".png"):
					names.append(file_name)
			names.sort()
			if not names.is_empty():
				var listed: PackedStringArray = []
				for n in names:
					listed.append("%s/%s" % [dir_path, n])
				return listed

	for prefix in _probe_prefixes(job, gender, folder_name):
		var probed := _probe_sequence(dir_path, prefix)
		if not probed.is_empty():
			return probed
	return PackedStringArray()


static func _probe_prefixes(job: String, gender: String, folder_name: String) -> Array[String]:
	var prefixes: Array[String] = []
	if job == "novice" and gender == "male":
		prefixes.append("novice_male_%s_" % folder_name.to_lower())
	if job == "novice" and gender == "female":
		prefixes.append("0_Fallen_Angels_%s_" % folder_name)
	prefixes.append("0_Fallen_Angels_%s_" % folder_name)
	return prefixes


static func _probe_sequence(dir_path: String, prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(MAX_PROBE_FRAMES):
		var path := "%s/%s%03d.png" % [dir_path, prefix, i]
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
	const LEGACY_SCALE := 0.03
	var target_height := LEGACY_FRAME_HEIGHT * LEGACY_SCALE
	for anim_name in ANIM_FOLDER_MAP:
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
		var s := target_height / h
		return Vector2(s, s)
	return Vector2(LEGACY_SCALE, LEGACY_SCALE)


static func ensure_folder_structure() -> void:
	var anims := ANIM_FOLDER_MAP.values()
	for job in ALL_JOBS:
		for gender in ALL_GENDERS:
			for anim_folder in anims:
				var path := "%s/%s/%s/PNG/PNG Sequences/%s" % [BASE, job, gender, anim_folder]
				DirAccess.make_dir_recursive_absolute(path)
