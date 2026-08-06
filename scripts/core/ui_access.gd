class_name UiAccess
extends RefCounted

## หา UIManager จาก node ใดก็ได้ใน scene tree — ลดการซ้ำ get_first_node_in_group("ui")
static func get_ui(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group("ui")
