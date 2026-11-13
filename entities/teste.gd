extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -400.0
@onready var char: AnimatedSprite2D = $CollisionShape2D/AnimatedSprite2D
@onready var zona_interacao: Area2D = $ZonaInteracao

## Objetos interativos (grupo "interagivel") ao alcance agora. O E aciona o
## mais próximo, e só ele mostra o balão "[E] ação".
var _ao_alcance: Array[Node] = []
var _interagivel_proximo: Node = null

## false enquanto uma caixa de diálogo está aberta (aula/prova): o jogador
## não anda, não pula e não dispara outra interação por baixo do diálogo.
var controle_ativo: bool = true


func _ready() -> void:
	# A ação "interagir" não existe por padrão no InputMap do projeto —
	# registra em código pra não depender de editar project.godot.
	if not InputMap.has_action("interagir"):
		InputMap.add_action("interagir")
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		InputMap.action_add_event("interagir", tecla)

	# Quem trocou de cena pode ter pedido pra o jogador nascer num ponto
	# específico (ex: voltar do combate pra frente da porta dos duelos).
	if Engine.has_meta("spawn_proxima_cena"):
		var pedido: Dictionary = Engine.get_meta("spawn_proxima_cena")
		Engine.remove_meta("spawn_proxima_cena")
		var cena_atual := get_tree().current_scene
		if cena_atual != null and cena_atual.scene_file_path == pedido.get("cena", ""):
			global_position = pedido.get("posicao", global_position)

	zona_interacao.area_entered.connect(_on_zona_interacao_area_entered)
	zona_interacao.area_exited.connect(_on_zona_interacao_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not controle_ativo:
		return
	if event.is_action_pressed("interagir") and _interagivel_proximo != null:
		_interagivel_proximo.interagir()


func _on_zona_interacao_area_entered(area: Area2D) -> void:
	if area.is_in_group("interagivel") and not _ao_alcance.has(area.get_parent()):
		_ao_alcance.append(area.get_parent())
		_escolher_interagivel()


func _on_zona_interacao_area_exited(area: Area2D) -> void:
	if area.is_in_group("interagivel"):
		_ao_alcance.erase(area.get_parent())
		_escolher_interagivel()


## Escolhe o objeto mais próximo e passa o balão para ele.
func _escolher_interagivel() -> void:
	var melhor: Node = null
	var menor := INF
	for o in _ao_alcance:
		if not is_instance_valid(o):
			continue
		var d := global_position.distance_squared_to((o as Node2D).global_position)
		if d < menor:
			menor = d
			melhor = o
	if melhor == _interagivel_proximo:
		return
	if is_instance_valid(_interagivel_proximo) and _interagivel_proximo.has_method("definir_destaque"):
		_interagivel_proximo.definir_destaque(false)
	_interagivel_proximo = melhor
	if melhor != null and melhor.has_method("definir_destaque"):
		melhor.definir_destaque(true)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if controle_ativo and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right") if controle_ativo else 0.0
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if _ao_alcance.size() > 1:
		_escolher_interagivel()  # o mais próximo muda enquanto o jogador anda

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
