# 继承CharacterBody2D，2D角色物理体
extends CharacterBody2D

# ========== 移动参数面板 ==========
@export_category("移动参数")
@export var double_press_interval := 0.3        # 双击切换飞行的时间间隔(秒)
@export var move_speed: float = 75.0           # 水平移动最大速度
@export var acceleration: float = 600.0        # 加速力度
@export var deceleration: float = 800.0        # 减速/刹车力度
@export var jump_velocity: float = -190.0      # 起跳竖直速度

# ========== 生命值面板 ==========
@export_category("生命值")
@export var max_health: int = 3                # 最大生命值
@export var invincible_time: float = 1.0       # 受伤后无敌时长

var health: int                                 # 当前生命值
var invincible := false                         # 是否处于无敌状态
signal health_changed(current: int, max: int)   # 生命值变化信号，传出当前/最大生命
signal died                                     # 死亡信号

@onready var sprite: Sprite2D = $Sprite2D       # 绑定节点下的Sprite2D精灵
var flying : bool = false                       # 飞行开关标记
var last_space_press_time := -1000              # 上一次按键时间戳，用于判断双击
@export var fail_label: Label
@export var victory_label: Label
# 初始化
func _ready() -> void:
	health = max_health# 开局生命值设为最大值
	fail_label.visible = false 
	victory_label.visible = false 
#受伤判定
func take_damage(amount: int) -> void:
	if invincible or health <= 0:
		return
	
	health -= amount
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()
		return
	# 进入无敌时间
	invincible = true
	# 受伤时闪烁变红
	modulate = Color(1.0, 0.3, 0.3, 0.6)
	
	await get_tree().create_timer(invincible_time).timeout
	
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	invincible = false

func die() -> void:
	fail_label.visible = true
	died.emit()
	queue_free()
# 物理帧更新（固定帧率，处理移动、物理）
func _physics_process(delta: float) -> void:
	if !flying:
		apply_gravity(delta)    # 非飞行状态：应用重力
		handle_jump()           # 非飞行状态：处理跳跃
	else:
		handle_vertical_movement(delta) # 飞行状态：上下操控
	
	handle_horizontal_movement(delta) # 统一处理水平移动
	update_sprite_direction()         # 更新精灵左右翻转
	move_and_slide()                  # CharacterBody2D物理移动

# 应用重力，离开地面时增加向下速度
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

# 飞行模式下的竖直方向移动（上下按键控制）
func handle_vertical_movement(delta:float) -> void:
	var direction := Input.get_axis("squat", "jump") # 获取上下输入 -1~1
	var target_speed := direction * jump_velocity
	
	if direction != 0.0:
		# 有输入：向目标速度加速
		velocity.y = move_toward(
				velocity.y,
				target_speed,
				acceleration * delta
		)
	else:
		# 无输入：竖直速度平滑归零
		velocity.y = move_toward(
				velocity.y,
				0.0,
				acceleration * delta
		)

# 水平移动逻辑，左右按键控制
func handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right") # 获取左右输入 -1~1
	var target_speed := direction * move_speed
	if direction != 0.0:
		# 有左右输入：加速到目标速度
		velocity.x = move_toward(
				velocity.x,
				target_speed,
				acceleration * delta
		)
	else:
		# 无输入：平滑减速到0
		velocity.x = move_toward(
				velocity.x,
				0.0,
				deceleration * delta
		)

# 普通跳跃逻辑，仅地面可用
func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

# 根据水平速度翻转精灵朝向
func update_sprite_direction() -> void:
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
		
# 输入事件回调，检测飞行切换按键
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fly") and !event.is_echo():
		handle_space_pressed()

# 处理双击切换飞行状态
func handle_space_pressed() -> void:
	var current_time := Time.get_ticks_msec()          # 获取当前毫秒时间
	var elapsed_time := current_time - last_space_press_time # 和上次按键时间差
	if elapsed_time <= double_press_interval * 1000.0:
		flying = not flying           # 在间隔内双击：翻转飞行开关
		last_space_press_time = -1000 # 重置时间，防止连续触发
	else:
		last_space_press_time = current_time # 第一次按下，记录时间
func victory() ->void:
	victory_label.visible = true
