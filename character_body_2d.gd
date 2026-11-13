extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = 2000.0

@onready var personagem: AnimatedSprite2D = %personagem

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	var direction := Input.get_axis("ui_left", "ui_right")
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept"):
		if direction > 0:
			velocity.x = JUMP_VELOCITY
		elif direction <0:
			velocity.x = JUMP_VELOCITY*-1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.

	if direction > 0:
		velocity.x = direction * SPEED
		personagem.flip_h = false
		personagem.play("default")
	elif direction < 0:
		velocity.x = direction * SPEED
		personagem.flip_h = true
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
