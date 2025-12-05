extends Area2D

@export var speed: float = 220.0
@export var move_direction: Vector2 = Vector2.DOWN
@export var lifetime: float = 10.0

var _time_alive: float = 0.0


func _physics_process(delta: float) -> void:
	# Move in the chosen direction
	global_position += move_direction.normalized() * speed * delta

	# Auto-destroy after lifetime
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
