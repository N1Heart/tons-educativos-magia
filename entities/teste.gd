extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -400.0
@onready var char: AnimatedSprite2D = $CollisionShape2D/AnimatedSprite2D
@onready var zona_interacao: Area2D = $ZonaInteracao

## NPC mais próximo (grupo "interagivel") que o jogador pode interagir agora,
## ou null se nenhum estiver no alcance. Vários podem se sobrepor; fica
## guardado o mais recente que entrou, é suficiente pro tamanho das salas.
var _interagivel_proximo: Node = null


func _ready() -> void:
	# A ação "interagir" não existe por padrão no InputMap do projeto —
	# registra em código pra não depender de editar project.godot.
	if not InputMap.has_action("interagir"):
		InputMap.add_action("interagir")
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		InputMap.action_add_event("interagir", tecla)

	zona_interacao.area_entered.connect(_on_zona_interacao_area_entered)
	zona_interacao.area_exited.connect(_on_zona_interacao_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interagir") and _interagivel_proximo != null:
		_interagivel_proximo.interagir()


func _on_zona_interacao_area_entered(area: Area2D) -> void:
	if area.is_in_group("interagivel"):
		_interagivel_proximo = area.get_parent()


func _on_zona_interacao_area_exited(area: Area2D) -> void:
	if area.is_in_group("interagivel") and area.get_parent() == _interagivel_proximo:
		_interagivel_proximo = null


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	
	if is_on_floor():
		if direction < 0:
			char.play("run")
			char.flip_h = true
		elif direction > 0:
			char.play("run")
			char.flip_h = false
		else:
			char.play("idle")
	else:
		char.play("jump")
