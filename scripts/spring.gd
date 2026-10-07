extends Area2D

# 弹起高度（像素），从弹簧到最高点
@export var bounce_height: float = 100.0
# 只在玩家下落时触发
@export var only_when_falling: bool = true
# 压缩动画参数
@export var compress_offset: float = 6.0
@export var compress_time: float = 0.05
@export var release_time: float = 0.15

@onready var sprite: Sprite2D = $Sprite

var _original_sprite_y: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite:
		_original_sprite_y = sprite.position.y

func _on_body_entered(body: Node2D) -> void:
	# 只对 CharacterBody2D 且实现了 bounce() 的节点生效
	if not body is CharacterBody2D:
		return
	if not body.has_method("bounce"):
		return
	# 只在下落时触发（避免玩家从侧面 / 上方碰到时乱弹）
	if only_when_falling and body.velocity.y < 0.0:
		return
	body.bounce(bounce_height)
	_play_bounce_animation()
func _play_bounce_animation() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	# 先压下去
	tween.tween_property(sprite, "position:y",
			_original_sprite_y + compress_offset, compress_time)
	# 再弹回来
	tween.tween_property(sprite, "position:y",
			_original_sprite_y, release_time)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
