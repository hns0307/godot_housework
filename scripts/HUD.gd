extends CanvasLayer

@export var heart_full: Texture2D
@export var heart_empty: Texture2D
@export var heart_size: Vector2 = Vector2(32, 32)

@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var save_label: Label = $SaveLabel
@onready var fail_label: Label = $FailLabel
@onready var victory_label: Label = $VicLabel

var hearts: Array[TextureRect] = []
var player: Node = null

func _ready() -> void:
	save_label.visible = false
	fail_label.visible = false
	victory_label.visible = false

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HUD 找不到 player 组节点")
		return

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_died)
	player.save_requested.connect(_on_save_requested)
	player.victory_reached.connect(_on_victory_reached)

	_build_hearts(player.max_health)
	_on_health_changed(player.health, player.max_health)

# ---------- 红心 ----------
func _build_hearts(max_health: int) -> void:
	for child in hearts_container.get_children():
		child.queue_free()
	hearts.clear()
	for i in max_health:
		var heart := TextureRect.new()
		heart.texture = heart_full
		heart.custom_minimum_size = heart_size
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_container.add_child(heart)
		hearts.append(heart)

func _on_health_changed(current: int, max1: int) -> void:
	if hearts.size() != max1:
		_build_hearts(max1)
	for i in hearts.size():
		if i < current:
			hearts[i].texture = heart_full
			hearts[i].modulate = Color.WHITE
		else:
			hearts[i].texture = heart_empty if heart_empty else heart_full
			hearts[i].modulate = Color(1, 1, 1, 0.35) if heart_empty == null else Color.WHITE

# ---------- 提示 ----------
func _on_save_requested() -> void:
	save_label.text = "已存档"
	save_label.visible = true
	await get_tree().create_timer(2.0).timeout
	save_label.visible = false

func _on_died() -> void:
	fail_label.visible = true
	await get_tree().create_timer(1.0).timeout
	fail_label.visible = false

func _on_victory_reached() -> void:
	victory_label.visible = true
