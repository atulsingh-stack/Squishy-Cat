extends Node2D

enum GameState { MENU, RUNNING, GAME_OVER }

var target_position: Vector2
var is_dragging: bool = false

var state: int = GameState.MENU
var elapsed_time: float = 0.0
var best_time: float = 0.0

var difficulty: float = 1.0
@export var difficulty_growth_rate: float = 0.12
@export var base_spawn_interval: float = 1.5
@export var min_spawn_interval: float = 0.35

const BEST_TIME_SAVE_PATH := "user://best_time.save"

# Make sure the file name is lowercase to match your actual file: scenes/obstacle.tscn
var ObstacleScene: PackedScene = preload("res://scenes/obstacle.tscn")

var shake_time: float = 0.0
var shake_strength: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	randomize()

	_load_best_time()
	_position_cat()

	if $ObstacleTimer is Timer:
		var t := $ObstacleTimer as Timer
		t.autostart = false
		t.stop()
		t.wait_time = base_spawn_interval

	state = GameState.MENU
	_update_ui_for_state()
	_update_score_labels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_position_cat()


func _position_cat() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size

	var pos_x: float = viewport_size.x * 0.5
	var pos_y: float = viewport_size.y * 0.85

	if has_node("Cat"):
		$Cat.global_position = Vector2(pos_x, pos_y)
		target_position = $Cat.global_position


func _process(delta: float) -> void:
	_update_screen_shake(delta)

	if state == GameState.RUNNING:
		elapsed_time += delta
		difficulty += difficulty_growth_rate * delta

		if $ObstacleTimer is Timer:
			var t := $ObstacleTimer as Timer
			t.wait_time = max(base_spawn_interval / difficulty, min_spawn_interval)

		_update_score_labels()


func _update_screen_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var x_offset = rng.randf_range(-shake_strength, shake_strength)
		var y_offset = rng.randf_range(-shake_strength, shake_strength)
		$Camera2D.offset = Vector2(x_offset, y_offset)
	else:
		$Camera2D.offset = Vector2.ZERO


func _trigger_screen_shake(time: float, strength: float) -> void:
	shake_time = time
	shake_strength = strength


func _unhandled_input(event: InputEvent) -> void:
	# Only handle drag input when RUNNING.
	if state != GameState.RUNNING:
		return

	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			is_dragging = true
			target_position = t.position
		else:
			is_dragging = false

	elif event is InputEventScreenDrag:
		is_dragging = true
		target_position = event.position

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mb.pressed
			target_position = mb.position

	elif event is InputEventMouseMotion and is_dragging:
		target_position = event.position


func _update_score_labels() -> void:
	if has_node("UI/ScoreLabel"):
		$UI/ScoreLabel.text = "Time: %.2f" % elapsed_time
	if has_node("UI/BestLabel"):
		$UI/BestLabel.text = "Best: %.2f" % best_time


func _update_ui_for_state() -> void:
	if has_node("UI/ScoreLabel"):
		$UI/ScoreLabel.visible = true
	if has_node("UI/BestLabel"):
		$UI/BestLabel.visible = true
	if has_node("UI/GameOverLabel"):
		$UI/GameOverLabel.visible = false
	if has_node("UI/StartButton"):
		$UI/StartButton.visible = false

	match state:
		GameState.MENU:
			if has_node("UI/StartButton"):
				$UI/StartButton.text = "Start Game"
				$UI/StartButton.visible = true

		GameState.RUNNING:
			pass

		GameState.GAME_OVER:
			if has_node("UI/GameOverLabel"):
				$UI/GameOverLabel.visible = true
			if has_node("UI/StartButton"):
				$UI/StartButton.text = "Retry"
				$UI/StartButton.visible = true


func game_over() -> void:
	if state != GameState.RUNNING:
		return

	state = GameState.GAME_OVER

	_trigger_screen_shake(0.2, 16.0)

	if elapsed_time > best_time:
		best_time = elapsed_time
		_save_best_time()

	if $ObstacleTimer is Timer:
		($ObstacleTimer as Timer).stop()

	_update_ui_for_state()


func _start_run() -> void:
	elapsed_time = 0.0
	difficulty = 1.0
	state = GameState.RUNNING

	if has_node("Obstacles"):
		for child in $Obstacles.get_children():
			child.queue_free()

	_position_cat()

	if $ObstacleTimer is Timer:
		var t := $ObstacleTimer as Timer
		t.wait_time = base_spawn_interval
		t.start()

	_update_ui_for_state()
	_update_score_labels()


func _on_StartButton_pressed() -> void:
	if state == GameState.MENU or state == GameState.GAME_OVER:
		_start_run()


func _on_Cat_area_entered(_area: Area2D) -> void:
	if state == GameState.RUNNING:
		game_over()


func _on_ObstacleTimer_timeout() -> void:
	if state != GameState.RUNNING:
		return

	var obstacle_instance: Area2D = ObstacleScene.instantiate() as Area2D
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size

	var spawn_x: float = randf_range(50.0, viewport_size.x - 50.0)
	var spawn_y: float = -120.0
	obstacle_instance.global_position = Vector2(spawn_x, spawn_y)

	var scale_factor: float = randf_range(0.5, 2.2)
	obstacle_instance.scale = Vector2(scale_factor, scale_factor)

	var speed_multiplier: float = 1.0 + min((difficulty - 1.0) * 0.35, 2.0)
	obstacle_instance.speed *= speed_multiplier

	var is_fast_bullet: bool = randf() < 0.30
	if is_fast_bullet:
		obstacle_instance.speed *= 1.8 + min((difficulty - 1.0) * 0.25, 1.2)
		for child in obstacle_instance.get_children():
			if child is CanvasItem:
				child.modulate = Color(1.0, 0.3, 0.3)
				break

	obstacle_instance.move_direction = Vector2.DOWN

	if has_node("Obstacles"):
		$Obstacles.add_child(obstacle_instance)
	else:
		add_child(obstacle_instance)


func _load_best_time() -> void:
	best_time = 0.0
	if FileAccess.file_exists(BEST_TIME_SAVE_PATH):
		var f := FileAccess.open(BEST_TIME_SAVE_PATH, FileAccess.READ)
		if f:
			best_time = f.get_var(0.0)


func _save_best_time() -> void:
	var f := FileAccess.open(BEST_TIME_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(best_time)
