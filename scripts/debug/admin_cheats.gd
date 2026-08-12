class_name AdminCheats
extends RefCounted

## ฟังก์ชันแอดมินสำหรับเทส — เปิดใช้เฉพาะ debug build เท่านั้น

static func is_enabled() -> bool:
	return OS.is_debug_build()


static func grant_levels(player: Player, count: int = 1) -> void:
	if not is_enabled() or player == null or count <= 0:
		return

	for _i in count:
		player.level += 1
		player.max_exp = maxi(1, int(floor(float(player.max_exp) * 1.4)))
		player.stat_points += 1

	StatRegistry.recalculate_max_hp(player)
	player.hp = player.max_hp
	player.sp = player.max_sp
	player.stats_changed.emit()
	_notify(player, "Admin: +%d Level → Lv.%d" % [count, player.level])
	_save(player)


static func grant_stat_points(player: Player, amount: int = 5) -> void:
	if not is_enabled() or player == null or amount <= 0:
		return

	player.stat_points += amount
	player.stats_changed.emit()
	_notify(player, "Admin: +%d Stat Points (รวม %d)" % [amount, player.stat_points])
	_save(player)


static func grant_primary_stats(player: Player, amount: int = 1) -> void:
	if not is_enabled() or player == null or amount <= 0:
		return

	for key: String in StatRegistry.primary_keys():
		var field: String = StatRegistry.PRIMARY[key]
		player.set(field, int(player.get(field)) + amount)

	StatRegistry.recalculate_max_hp(player)
	player.hp = mini(player.hp, player.max_hp)
	player.stats_changed.emit()
	_notify(player, "Admin: +%d ทุก Primary Stat" % amount)
	_save(player)


static func _save(player: Player) -> void:
	if OnlineSession.is_logged_in():
		DatabaseManager.save_game_data(player)


static func _notify(player: Player, message: String) -> void:
	var ui := UiAccess.get_ui(player)
	if ui and ui.has_method("show_notification"):
		ui.show_notification(message, Color8(0x9b, 0x59, 0xb6))
