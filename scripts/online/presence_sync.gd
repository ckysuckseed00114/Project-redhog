class_name PresenceSync
extends RefCounted

# presence_sync.gd — sync ตำแหน่ง + ข้อมูลตัวละคร local player


static func sync_player(player: Player) -> void:
	if player == null or not OnlineSession.is_online():
		return
	var scene_path := SceneContext.from_player(player)
	var payload := {
		RealtimeEvents.KEY_CHARACTER_ID: GlobalData.character_id,
		RealtimeEvents.KEY_NAME: GlobalData.player_name,
		RealtimeEvents.KEY_GENDER: GlobalData.player_gender,
		RealtimeEvents.KEY_CURRENT_JOB: player.current_job,
		RealtimeEvents.KEY_POS_X: float(player.global_position.x),
		RealtimeEvents.KEY_POS_Y: float(player.global_position.y),
		RealtimeEvents.KEY_CURRENT_SCENE: scene_path,
	}
	BroadcastRouter.send(RealtimeEvents.POS_UPDATE, payload, scene_path)
	if OS.is_debug_build():
		print("[PresenceSync] pos_update scene=", scene_path, " id=", GlobalData.character_id)


static func send_chat(message: String) -> void:
	if not OnlineSession.is_logged_in() or message.strip_edges() == "":
		return
	BroadcastRouter.send(RealtimeEvents.CHAT_MSG, {
		RealtimeEvents.KEY_CHARACTER_ID: GlobalData.character_id,
		RealtimeEvents.KEY_SENDER_NAME: GlobalData.player_name if GlobalData.player_name != "" else "Player",
		RealtimeEvents.KEY_TEXT: message,
	})
