extends Area2D

## Porta/transição entre salas: o jogador precisa ENTRAR na área E apertar E
## (ação "interagir") para trocar de cena — assim não troca sozinho só de
## passar perto, só quando o jogador realmente confirma.

@export_file("*.tscn") var cena_destino: String = ""
@export var requer_combate: bool = false
## Nome mostrado no balão "[E] Entrar". Vazio = deduzido da cena de destino.
@export var rotulo: String = ""
@export var acao: String = "Entrar"

const Indicador := preload("res://entities/IndicadorInteracao.gd")
const NOMES_DESTINO := {
	"saguao": "Saguão",
	"saladeaula": "Sala de Formas",
	"saladearte": "Sala de Cores",
	"saladeduelos": "Sala de Duelos",
	"fundosdocastelo": "Quintal dos Fundos",
	"duelos": "Arena de Duelos",
	"academia": "Academia",
}
var _indicador: Node = null
## Guarda o corpo do jogador enquanto ele estiver dentro da área. "body_entered"
## e "body_exited" só mandam o Node do corpo — nunca um InputEvent — então a
## tecla precisa ser checada separadamente, em _unhandled_input, e não dentro
## do callback do sinal.
var _jogador_dentro: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# O balão substitui o rótulo provisório "PORTA".
	var provisorio := get_node_or_null("Label")
	if provisorio != null:
		provisorio.visible = false
	_indicador = Indicador.new()
	add_child(_indicador)
	_indicador.configurar(_nome_do_destino(), acao, 44.0)

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
		_indicador.definir_ativo(true)


func _on_body_exited(body: Node) -> void:
	if body == _jogador_dentro:
		_jogador_dentro = null
		_indicador.definir_ativo(false)


func _trocar_de_cena() -> void:
	if cena_destino == "":
		push_warning("Porta sem cena_destino configurada: %s" % get_path())
		return

	if requer_combate:
		var motivo := SpellLoadout.motivo_bloqueio_combate(LocalDB.get_user_id_ativo())
		if motivo != "":
			print("[Porta] ", motivo)  # vira diálogo quando a CaixaDialogo existir
			return

	Transicao.ir_para(cena_destino)


func _nome_do_destino() -> String:
	if rotulo != "":
		return rotulo
	var caminho := cena_destino
	if caminho.begins_with("uid://"):
		var id := ResourceUID.text_to_id(caminho)
		if ResourceUID.has_id(id):
			caminho = ResourceUID.get_id_path(id)
	var base := caminho.get_file().get_basename()
	return NOMES_DESTINO.get(base.to_lower(), base.capitalize() if base != "" else "Porta")
