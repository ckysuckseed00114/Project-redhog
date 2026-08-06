class_name MonsterManager
extends Node2D

@export var player: CharacterBody2D

func setup(p_player: CharacterBody2D) -> void:
	player = p_player

func update_monsters_ai(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	var time_sec := Time.get_ticks_msec() / 1000.0
	var player_pos := player.global_position # ดึงตำแหน่งผู้เล่นส่งให้มอนสเตอร์
	
	for child in get_children():
		if is_instance_valid(child) and child.has_method("update_ai"):
			child.update_ai(delta, player, player_pos, time_sec) # ส่งครบ 4 อาร์กิวเมนต์แล้ว
