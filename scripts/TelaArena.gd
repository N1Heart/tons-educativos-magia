extends Control

## Arena de duelos amistosos (Módulo 5): lista dos colegas da turma que estão
## na arena, com convite (desafiar / aceitar / recusar). O duelo em si é aberto
## pelo ArenaDuelos + DueloRede. Montada por código, como a TelaLobby.
## Quem chama (FluxoSala) guarda o ponto do jogo em Engine.meta "arena_retorno".

const CENA_ALUNO := "res://scenes/Login/TelaAluno.tscn"

var _caixa: VBoxContainer
var _titulo: Label
var _lista: ItemList
var _status: Label
var _btn_desafiar: Button
var _btn_cancelar: Button
var _painel_convite: PanelContainer
var _texto_convite: Label
var _ids: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0.1, 0.1, 0.16)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	add_child(margem)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 6)
	margem.add_child(_caixa)

	_titulo = _rotulo("Arena de duelos amistosos", 18, Color(1.0, 0.85, 0.4))
	_caixa.add_child(_titulo)
	_caixa.add_child(_rotulo("Colegas na arena (duelo amistoso: não vale nota nem muda a dificuldade):", 12, Color(0.8, 0.8, 0.8)))

	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.select_mode = ItemList.SELECT_SINGLE
	_lista.add_theme_font_size_override("font_size", 14)
	_lista.item_selected.connect(func(_i): _atualizar_botoes())
	_lista.item_activated.connect(func(_i): _desafiar())
	_caixa.add_child(_lista)

	_status = _rotulo("", 13, Color(1.0, 0.75, 0.4))
	_caixa.add_child(_status)

	# Convite recebido
	_painel_convite = PanelContainer.new()
	var vb := VBoxContainer.new()
	_texto_convite = _rotulo("", 15, Color(0.6, 0.9, 1.0))
	vb.add_child(_texto_convite)
	var l2 := HBoxContainer.new()
	l2.add_child(_botao("Aceitar", func(): ArenaDuelos.responder(true)))
	l2.add_child(_botao("Recusar", func(): ArenaDuelos.responder(false)))
	vb.add_child(l2)
	_painel_convite.add_child(vb)
	_painel_convite.visible = false
	_caixa.add_child(_painel_convite)

	var linha := HBoxContainer.new()
	_btn_desafiar = _botao("Desafiar", _desafiar)
	_btn_cancelar = _botao("Cancelar desafio", func(): ArenaDuelos.cancelar_desafio())
	_btn_cancelar.visible = false
	linha.add_child(_btn_desafiar)
	linha.add_child(_btn_cancelar)
	linha.add_child(_botao("Sair da arena", _sair))
	_caixa.add_child(linha)

	ArenaDuelos.lista_mudou.connect(_atualizar)
	ArenaDuelos.desafio_recebido.connect(_on_desafio_recebido)
	ArenaDuelos.desafio_encerrado.connect(_on_desafio_encerrado)
	ArenaDuelos.arena_perdida.connect(_on_arena_perdida)
	ArenaDuelos.duelo_falhou.connect(_on_duelo_falhou)

	if ArenaDuelos.esta_na_arena():
		_atualizar()
	else:
		_entrar()


func _rotulo(texto: String, tamanho: int = 14, cor: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(acao)
	return b


func _entrar() -> void:
	_status.text = "Entrando na arena..."
	_btn_desafiar.disabled = true
	var perfil := LocalDB.carregar_perfil(LocalDB.get_user_id_ativo())
	var nome: String = perfil.nome if perfil != null and perfil.nome != "" else NakamaManager.convidado_nome
	var erro: String = await ArenaDuelos.entrar(nome if nome != "" else "Aluno")
	if not is_inside_tree():
		return
	if erro != "":
		_status.text = erro
		return
	_atualizar()


func _atualizar() -> void:
	if _lista == null or not ArenaDuelos.esta_na_arena():
		return
	var turma: String = ArenaDuelos.nome_turma
	_titulo.text = "Arena de duelos — turma %s" % turma if turma != "" else "Arena de duelos amistosos"
	var selecionado := ""
	var sel := _lista.get_selected_items()
	if not sel.is_empty() and sel[0] < _ids.size():
		selecionado = _ids[sel[0]]
	_lista.clear()
	_ids = []
	for j in ArenaDuelos.lista_outros():
		_ids.append(j["id"])
		_lista.add_item("%s  —  %s" % [j["nome"], "em duelo" if j["ocupado"] else "livre"])
		if j["id"] == selecionado:
			_lista.select(_lista.item_count - 1)
	if _ids.is_empty():
		_lista.add_item("Nenhum colega na arena agora...")
		_lista.set_item_disabled(0, true)
		if not ArenaDuelos.convite_enviado() and not ArenaDuelos.convite_recebido():
			_status.text = "Chame um colega para entrar na arena também."
	elif _status.text.begins_with("Chame") or _status.text.begins_with("Entrando"):
		_status.text = "Escolha um colega livre e clique em Desafiar."
	_atualizar_botoes()


func _atualizar_botoes() -> void:
	var sel := _lista.get_selected_items()
	var alvo_livre := false
	if not sel.is_empty() and sel[0] < _ids.size():
		var j: Dictionary = ArenaDuelos.jogadores.get(_ids[sel[0]], {})
		alvo_livre = not j.is_empty() and not j["ocupado"]
	var enviado := ArenaDuelos.convite_enviado()
	_btn_desafiar.disabled = not alvo_livre or enviado or ArenaDuelos.convite_recebido() or ArenaDuelos.ocupado
	_btn_desafiar.visible = not enviado
	_btn_cancelar.visible = enviado


func _desafiar() -> void:
	var sel := _lista.get_selected_items()
	if sel.is_empty() or sel[0] >= _ids.size() or _btn_desafiar.disabled:
		return
	var id: String = _ids[sel[0]]
	var erro: String = await ArenaDuelos.desafiar(id)
	if not is_inside_tree():
		return
	if erro != "":
		_status.text = erro
	else:
		_status.text = "Desafio enviado. Aguardando %s responder..." % ArenaDuelos.jogadores.get(id, {}).get("nome", "o colega")
	_atualizar_botoes()


func _on_desafio_recebido(_id: String, nome: String) -> void:
	_texto_convite.text = "%s desafiou você para um duelo amistoso!" % nome
	_painel_convite.visible = true
	_atualizar_botoes()


func _on_desafio_encerrado(motivo: String) -> void:
	_painel_convite.visible = false
	_status.text = motivo
	_atualizar_botoes()


func _on_duelo_falhou(motivo: String) -> void:
	_painel_convite.visible = false
	_status.text = motivo
	_atualizar_botoes()


func _on_arena_perdida(motivo: String) -> void:
	_painel_convite.visible = false
	_lista.clear()
	_status.text = motivo
	_btn_desafiar.disabled = true


func _sair() -> void:
	await ArenaDuelos.sair()
	if not is_inside_tree():
		return
	var destino := CENA_ALUNO
	if Engine.has_meta("arena_retorno"):
		var pedido: Dictionary = Engine.get_meta("arena_retorno")
		Engine.remove_meta("arena_retorno")
		destino = pedido.get("cena", destino)
		if pedido.has("posicao"):
			Engine.set_meta("spawn_proxima_cena", {"cena": destino, "posicao": pedido["posicao"]})
	get_tree().change_scene_to_file(destino)
