extends CharacterBody2D

@export var current_speed := 120.0
@export var paddle_accel := 400.0
@export var max_speed := 350.0
@export var water_drag := 1.5
@export var bounce_strength := 1.6

signal bounced(strength : float)
func _physics_process(delta):
	var input := Input.get_vector("left","right", "up" , "down")
	velocity += input * paddle_accel * delta
	
	velocity += Vector2(0, current_speed) * delta 
	
	
	velocity = velocity.lerp(Vector2.ZERO, water_drag * delta)
	velocity = velocity.limit_length(max_speed)
	
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider := collision.get_collider()
		var strength := bounce_strength
		if collider and collider.get("bounciness") != null:
			strength = collider.bounciness
		velocity = velocity.bounce(collision.get_normal()) * strength
		bounced.emit(strength)
	if velocity.length() > 10.0:
		rotation = lerp_angle(rotation,velocity.angle() - PI / 2, 8.0 * delta)
