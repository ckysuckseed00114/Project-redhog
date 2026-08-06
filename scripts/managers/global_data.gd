extends Node

var player_name: String = "Novice"
var player_class: String = "novice"
var player_gender: String = "male"

# 🌟 เพิ่มตัวแปรเก็บพิกัดตอนล็อกอิน
var spawn_x: float = 0.0
var spawn_y: float = 0.0
var has_saved_position: bool = false
var character_id: String = ""
var current_slot_index: int = 0
var warp_grace_until_msec: int = 0
var warp_spawn_pending: bool = false
var pending_warp_scene: String = ""

var pending_active_quests: Dictionary = {}
var pending_finished_quests: Array = []
var has_pending_quest_state: bool = false

var save_point_scene: String = ""
var save_point_x: float = 0.0
var save_point_y: float = 0.0
var has_save_point: bool = false
var pending_revive_at_save: bool = false


func stash_quest_state(player: Player) -> void:
	if player == null:
		return
	pending_active_quests = player.active_quests.duplicate(true)
	pending_finished_quests = player.finished_quests.duplicate()
	has_pending_quest_state = true


func apply_quest_state(player: Player) -> void:
	if player == null or not has_pending_quest_state:
		return
	player.active_quests = pending_active_quests.duplicate(true)
	player.finished_quests = []
	for qid in pending_finished_quests:
		player.finished_quests.append(str(qid))
	has_pending_quest_state = false
	pending_active_quests = {}
	pending_finished_quests = []


func clear_pending_quest_state() -> void:
	has_pending_quest_state = false
	pending_active_quests = {}
	pending_finished_quests = []


func prepare_warp(spawn_pos: Vector2, target_scene: String = "") -> void:
	spawn_x = spawn_pos.x
	spawn_y = spawn_pos.y
	has_saved_position = spawn_pos != Vector2.ZERO
	warp_spawn_pending = has_saved_position
	pending_warp_scene = target_scene
	activate_warp_grace(2.5)


func take_warp_spawn_position() -> Variant:
	if not warp_spawn_pending:
		return null
	warp_spawn_pending = false
	has_saved_position = false
	pending_warp_scene = ""
	return Vector2(spawn_x, spawn_y)


func take_pending_warp_scene() -> String:
	var scene := pending_warp_scene
	pending_warp_scene = ""
	return scene


func activate_warp_grace(duration_sec: float = 2.0) -> void:
	warp_grace_until_msec = Time.get_ticks_msec() + int(duration_sec * 1000.0)


func is_warp_grace_active() -> bool:
	return Time.get_ticks_msec() < warp_grace_until_msec
