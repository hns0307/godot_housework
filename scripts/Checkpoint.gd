extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_spawn_point"):
		body.set_spawn_point(global_position)
		if body.has_method("show_save_message"):
			body.show_save_message()
