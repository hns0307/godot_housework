extends CharacterBody2D
# ========== 移动参数 ==========
@export_category("怪物参数")
@export var move_speed: float = 40.0        # 左右移动速度
@export var gravity_scale: float = 1.0      # 重力倍率
@export var turn_at_cliff: bool = true      # 是否在悬崖边翻转
@export var turn_at_wall: bool = true       # 是否在墙前翻转
@export var start_facing_right: bool = true # 初始朝向
var direction: int = 1                      # 1=右，-1=左
@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_detector: RayCast2D = $FloorDetector
@onready var wall_detector: RayCast2D = $WallDetector
func _ready() -> void:
	direction = 1 if start_facing_right else -1
	_apply_direction()
func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta
	# 水平移动
	velocity.x = direction * move_speed
	# 前方有墙 → 翻转
	if turn_at_wall and wall_detector.is_colliding():
		_flip()
	# 前方没有地面 → 翻转（悬崖边）
	if turn_at_cliff and is_on_floor() and not floor_detector.is_colliding():
		_flip()
	move_and_slide()
	# 撞到墙也翻转
	if turn_at_wall and is_on_wall():
		_flip()
func _flip() -> void:
	direction *= -1
	_apply_direction()
func _apply_direction() -> void:
	# 射线跟着朝向镜像
	floor_detector.position.x = abs(floor_detector.position.x) * direction
	wall_detector.position.x = abs(wall_detector.position.x) * direction
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * direction
	# 精灵翻转
	if sprite:
		sprite.flip_h = direction < 0
