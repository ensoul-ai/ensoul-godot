@tool
extends EditorPlugin

func _enable_plugin() -> void:
	add_autoload_singleton("Ensoul", "res://addons/ensoul/ensoul_client.gd")

func _disable_plugin() -> void:
	remove_autoload_singleton("Ensoul")
