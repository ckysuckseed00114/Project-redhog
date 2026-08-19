@tool
extends EditorScript
## One-click push: local ITEMS / MONSTERS → Supabase.
## Godot Editor → open this file → Script menu → Run.


func _run() -> void:
	SyncDatabase.run_from_editor(EditorInterface.get_base_control())
