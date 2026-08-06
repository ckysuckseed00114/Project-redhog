class_name PartySync
extends RefCounted

# party_sync.gd — Realtime sync ปาร์ตี้


static func broadcast_update(party_id: String, members: Array) -> void:
	if party_id == "" or party_id == "local_party" or not OnlineSession.is_logged_in():
		return
	BroadcastRouter.send_party(RealtimeEvents.PARTY_UPDATE, {
		RealtimeEvents.KEY_PARTY_ID: party_id,
		RealtimeEvents.KEY_MEMBERS: members,
	}, party_id)


static func broadcast_leave(party_id: String, character_id: String) -> void:
	if party_id == "" or not OnlineSession.is_logged_in():
		return
	BroadcastRouter.send_party(RealtimeEvents.PARTY_LEAVE, {
		RealtimeEvents.KEY_PARTY_ID: party_id,
		RealtimeEvents.KEY_CHARACTER_ID: character_id,
	}, party_id)


static func send_invite(party_id: String, target_character_id: String, inviter_name: String) -> void:
	if party_id == "" or target_character_id == "" or not OnlineSession.is_logged_in():
		return
	BroadcastRouter.send_global(RealtimeEvents.PARTY_INVITE, {
		RealtimeEvents.KEY_PARTY_ID: party_id,
		RealtimeEvents.KEY_TARGET_CHARACTER_ID: target_character_id,
		RealtimeEvents.KEY_INVITER_NAME: inviter_name,
		RealtimeEvents.KEY_CHARACTER_ID: GlobalData.character_id,
	})
