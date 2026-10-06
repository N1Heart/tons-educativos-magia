extends Area2D

## Porta/transição entre salas: o jogador precisa ENTRAR na área E apertar E
## (ação "interagir") para trocar de cena — assim não troca sozinho só de
## passar perto, só quando o jogador realmente confirma.

@export_file("*.tscn") var cena_destino: String = ""
@export var requer_combate: bool = false
## Guarda o corpo do jogador enquanto ele estiver dentro da área. "body_entered"
## e "body_exited" só mandam o Node do corpo — nunca um InputEvent — então a
## tecla precisa ser checada separadamente, em _unhandled_input, e não dentro
## do callback do sinal.
var _jogador_dentro: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if not InputMap.has_action("interagir"):
		InputMap.add_action("interagir")
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		InputMap.action_add_event("interagir", tecla)


func _unhandled_input(event: InputEvent) -> void:
	if _jogador_dentro != null and event.is_action_pressed("interagir"):
		_trocar_de_cena()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("jogador"):
		_jogador_dentro = body


func _on_body_exited(body: Node) -> void:
	if body == _jogador_dentro:
		_jogador_dentro = null


func _trocar_de_cena() -> void:
	if cena_destino == "":
		push_warning("Porta sem cena_destino configurada: %s" % get_path())
		return

	if requer_combate:
		var motivo := SpellLoadout.motivo_bloqueio_combate(LocalDB.get_user_id_ativo())
		if motivo != "":
			print("[Porta] ", motivo)  # vira diálogo quando a CaixaDialogo existir
			return

	get_tree().change_scene_to_file(cena_destino)
