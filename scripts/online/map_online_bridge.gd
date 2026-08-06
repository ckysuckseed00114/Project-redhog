class_name MapOnlineBridge
extends RefCounted

# map_online_bridge.gd — ลงทะเบียนแมพกับระบบออนไลน์


static func register_map(map: BaseMap) -> void:
	if map == null:
		return
	OnlinePresenceManager.register_world(map)
	RealtimeChannelService.switch_scene_for_map(map)
	if map is World:
		BossManager.register_world(map as World)


static func unregister_map(map: BaseMap) -> void:
	if map == null:
		return
	OnlinePresenceManager.unregister_world()
	RealtimeChannelService.clear_scene_channel()
	if map is World:
		BossManager.unregister_world()
