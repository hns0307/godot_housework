extends CharacterBody2D
# ========== 移动参数面板 ==========
@export_category("移动参数")
@export var double_press_interval := 0.3        # 双击切换飞行的时间间隔(秒)
@export var move_speed: float = 75.0           # 水平移动最大速度
@export var acceleration: float = 600.0        # 加速力度
@export var deceleration: float = 800.0        # 减速/刹车力度
@export var jump_velocity: float = -210.0      # 起跳竖直速度
# ========== 冲刺参数面板 ==========
@export_category("冲刺参数")
@export var dash_speed: float = 300.0          # 冲刺速度
@export var dash_duration: float = 0.15        # 冲刺持续时间(秒)
@export var dash_cooldown: float = 0.6         # 冲刺冷却时间(秒)
@export var dash_allow_in_air: bool = true     # 是否允许空中冲刺
var is_dashing := false                        # 是否正在冲刺
var dash_timer := 0.0                          # 剩余冲刺时间
var dash_cooldown_timer := 0.0                 # 剩余冷却时间
var dash_direction := Vector2.ZERO             # 冲刺方向
# ========== 爬梯参数面板 ==========
@export_category("爬梯参数")
@export var climb_speed: float = 60.0       # 爬梯速度
@export var ladder_exit_cooldown: float = 0.2  # 脱离梯子后的冷却，防止立刻重新吸附
var ladder_count := 0
var on_ladder: bool:
	get: return ladder_count > 0        # 是否与梯子区域重叠
var climbing := false         # 是否处于攀爬状态
var _ladder_cooldown := 0.0   # 冷却计时
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
signal save_requested                           # 请求显示“已存档”
signal victory_reached                          # 请求显示胜利
var spawn_position: Vector2 
# 初始化
func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	spawn_position = global_position# 开局生命值设为最大值 
#受伤判定
func take_damage(amount: int) -> void:
	if invincible or health <= 0:
		return
	
	health -= amount
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()
		return
	_play_hurt_effect()
#受伤特效
func _play_hurt_effect() -> void:
	invincible = true
	
	# 变红
	sprite.modulate = Color(1.0, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color.WHITE
	
	# 剩余无敌时间闪烁
	var elapsed := 0.15
	while elapsed < invincible_time:
		sprite.visible = !sprite.visible
		await get_tree().create_timer(0.08).timeout
		elapsed += 0.08
	
	sprite.visible = true
	sprite.modulate = Color.WHITE
	invincible = false
#死亡
func die() -> void:
	died.emit()
	await get_tree().create_timer(1.0).timeout
	respawn()
#弹簧弹跳
func bounce(height: float) -> void:
	# 根据重力反推需要的初速度，让玩家刚好弹到 height 像素高
	var g := get_gravity().length()
	if g <= 0.0:
		g = 980.0   # 保险值，防止除 0
	# 如果正在飞行，先退出飞行状态，避免弹起后又悬停
	flying = false
	velocity.y = -sqrt(2.0 * g * height)
#复活
func respawn() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	global_position = spawn_position
	velocity = Vector2.ZERO
	flying = false
	invincible = false
	climbing = false
	climbing = false
	ladder_count = 0
	_ladder_cooldown = 0.0
	_ladder_cooldown = 0.0
	sprite.visible = true
	sprite.modulate = Color.WHITE
# 物理帧更新（固定帧率，处理移动、物理）
func _physics_process(delta: float) -> void:
	if _ladder_cooldown > 0.0:
		_ladder_cooldown -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if is_dashing:
		handle_dash_movement(delta)
	elif climbing:
		handle_climbing(delta)
	else:
		handle_dash_input()
		if !flying:
			apply_gravity(delta)
			handle_jump()
		else:
			handle_vertical_movement(delta)
		handle_horizontal_movement(delta)
		handle_ladder_input()
	update_sprite_direction()
	move_and_slide()
# 检测是否要开始攀爬
func handle_ladder_input() -> void:
	if not on_ladder:
		return
	if climbing:
		return
	if _ladder_cooldown > 0.0:
		return
	if Input.is_action_pressed("fly"):
		start_climb()
# 开始攀爬
func start_climb() -> void:
	climbing = true
	flying = false          # 如果在飞行，先退出飞行
	velocity = Vector2.ZERO # 清空速度，防止瞬间上冲/下坠
	# 朝向可以保留，也可以按需求调整
	if sprite:
		sprite.modulate = Color.WHITE
# 攀爬中的物理更新
func handle_climbing(_delta: float) -> void:
	# 离开梯子区域就自动脱离
	if not on_ladder:
		stop_climb()
		return
	# 按左右方向键主动脱离
	var dir_x := Input.get_axis("move_left", "move_right")
	if dir_x != 0.0:
		stop_climb()
		velocity.x = dir_x * move_speed * 0.8
		return
	# 竖直移动：jump=上，squat=下
	velocity.x = 0.0
	var dir_y := Input.get_axis("fly", "squat")  # 上返回 -1，下返回 +1
	velocity.y = dir_y * climb_speed
# 结束攀爬
func stop_climb() -> void:
	if not climbing:
		return
	climbing = false
	_ladder_cooldown = ladder_exit_cooldown
# 梯子区域调用：进入
func enter_ladder() -> void:
	ladder_count += 1
# 梯子区域调用：离开
func exit_ladder() -> void:
	ladder_count = max(ladder_count - 1, 0)
	if ladder_count == 0 and climbing:
		stop_climb()
# 检测冲刺按键
func handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash"):
		try_start_dash()
# 检查是否满足起冲条件
func try_start_dash() -> void:
	if is_dashing:
		return
	if dash_cooldown_timer > 0.0:
		return
	if not dash_allow_in_air and not is_on_floor():
		return
	start_dash()
# 开始冲刺
func start_dash() -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var dir_x := 0.0
	if input_dir != 0.0:
		dir_x = sign(input_dir)
	else:
		# 没输入时按当前面向冲刺
		dir_x = -1.0 if sprite.flip_h else 1.0
	dash_direction = Vector2(dir_x, 0.0).normalized()
	is_dashing = true
	dash_timer = dash_duration
	velocity = dash_direction * dash_speed
# 冲刺中的物理更新
func handle_dash_movement(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed  # 保持冲刺速度，忽略重力和输入
	if dash_timer <= 0.0:
		end_dash()
# 结束冲刺
func end_dash() -> void:
	is_dashing = false
	dash_cooldown_timer = dash_cooldown
	velocity.x *= 0.5   # 冲刺结束时保留部分惯性，不会突然停住
#冲刺残影效果
func spawn_dash_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1, 1, 1, 0.5)
	get_parent().add_child(ghost)
	
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
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
	if on_ladder:
		return   # 在梯子上不跳跃，按上键交给爬梯逻辑处理
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
func victory() -> void:
	victory_reached.emit()
func set_spawn_point(pos: Vector2) -> void:
	spawn_position = pos
	save_requested.emit()      # 发出信号让 HUD 显示“已存档”
