class_name RealtimeChannel
extends RefCounted

# realtime_channel.gd — ชื่อ Realtime channel ตาม scene / party

const GLOBAL := "room:global"
const SCENE_PREFIX := "room:scene:"
const PARTY_PREFIX := "room:party:"


static func for_scene(scene_path: String) -> String:
	var norm := SceneContext.normalize(scene_path)
	if norm == "":
		return GLOBAL
	var slug := norm.get_file().get_basename()
	if slug == "":
		return GLOBAL
	return SCENE_PREFIX + slug


static func for_party(party_id: String) -> String:
	if party_id == "" or party_id == "local_party":
		return ""
	return PARTY_PREFIX + party_id


static func topic_for(channel_name: String) -> String:
	return "realtime:%s" % channel_name
