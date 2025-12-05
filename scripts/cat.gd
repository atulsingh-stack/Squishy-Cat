extends Area2D

# ---------- SPRING MOVEMENT TUNING ----------
@export var spring_stiffness: float = 50.0     # Your custom tuning
@export var damping: float = 25.0              # Your custom tuning
@export var max_speed: float = 3000.0

# ---------- SQUASH & STRETCH TUNING ----------
@export var base_scale: Vector2 = Vector2.ONE
@export var max_stretch: float = 5.0           # You said 5 feels good
@export var stretch_speed_threshold: float = 900.0
@export var squash_factor: float = 0.25

# Impact squish on direction change
@export var direction_change_speed_threshold: float = 700.0
@export var squish_duration: float = 0.12
@export var squish_amount: float = 0.35

var velocity: Vector2 = Vector2.ZERO
var last_velocity: Vector2 = Vector2.ZERO
var squish_timer: float = 0.0


func _physics_process(delta: float) -> void:
	# Get target from Main
	var main := get_parent()
	if main == null:
		return

	var target_pos: Vector2 = main.target_position

	# --- SPRING PHYSICS ---
	var displacement: Vector2 = target_pos - global_position
	var acceleration: Vector2 = spring_stiffness * displacement - damping * velocity
	velocity += acceleration * delta

	# Clamp speed
	var speed: float = velocity.length()
	if speed > max_speed:
		velocity = velocity.normalized() * max_speed

	global_position += velocity * delta

	# --- SQUASH & STRETCH ---
	_update_squash_and_stretch(delta)

	last_velocity = velocity


func _update_squash_and_stretch(delta: float) -> void:
	var speed: float = velocity.length()

	# If nearly not moving → restore shape
	if speed < 5.0:
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)
		scale = scale.lerp(base_scale, 12.0 * delta)
		squish_timer = max(squish_timer - delta, 0.0)
		return

	var direction: Vector2 = velocity.normalized()

	# Rotate cat to face movement
	rotation = direction.angle()

	# Detect strong direction change → squish
	if last_velocity.length() > 5.0:
		var last_dir: Vector2 = last_velocity.normalized()
		var dot: float = direction.dot(last_dir)
		if dot < 0.1 and speed > direction_change_speed_threshold and squish_timer <= 0.0:
			squish_timer = squish_duration

	# Base stretch based on speed
	var t_speed: float = clamp(speed / stretch_speed_threshold, 0.0, 1.0)
	var stretch_x: float = 1.0 + max_stretch * t_speed
	var squash_y: float = 1.0 - squash_factor * t_speed
	var target_scale: Vector2 = Vector2(base_scale.x * stretch_x, base_scale.y * squash_y)

	# Apply temporary squish
	if squish_timer > 0.0:
		var squish_t: float = squish_timer / squish_duration
		var eased: float = squish_t * squish_t     # Ease-out

		var extra_x: float = 1.0 + squish_amount * eased
		var extra_y: float = 1.0 - squish_amount * eased

		target_scale.x *= extra_x
		target_scale.y *= extra_y

		squish_timer -= delta
		if squish_timer < 0.0:
			squish_timer = 0.0

	# Smooth scaling
	scale = scale.lerp(target_scale, 18.0 * delta)
