extends Area2D
@export var damage: int = 3

func _on_body_entered(body: Node2D) -> void:
	print("body进入刺：", body.name)
	if body is CharacterBody2D:
		if body.has_method("take_damage"):
			body.take_damage(damage)
