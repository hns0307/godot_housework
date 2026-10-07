extends Area2D
@export var damage: int = 3

func _on_body_entered(body: Node2D) -> void:
	print("body", body.name)
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
