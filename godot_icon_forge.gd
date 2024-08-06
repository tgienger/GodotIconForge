@tool
extends EditorPlugin

const MainPanel = preload("res://addons/godot-icon-forge/GodotIconForge.tscn")

var main_instance: Node

func _enter_tree() -> void:
	main_instance = MainPanel.instantiate()
	EditorInterface.get_editor_main_screen().add_child(main_instance)
	_make_visible(false)


func _exit_tree() -> void:
	if main_instance:
		main_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(is_visible: bool) -> void:
	if main_instance:
		main_instance.visible = is_visible

func _get_plugin_name() -> String:
	return "Godo Icon Forge"
