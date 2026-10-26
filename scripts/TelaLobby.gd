extends Control

## Tela da sala em tempo real (Módulo 5). Serve para os dois lados:
##   - professor: abre a sala da turma, mostra o CÓDIGO e a lista de alunos que
##     entraram, e tem os botões de iniciar PvE / PvP;
##   - aluno: digita o código, entra e espera o professor iniciar.
## Quem chama define o modo antes de trocar de cena:
##   Engine.set_meta("lobby_modo", "professor")  ou  "aluno"
## A tela é montada por código (como o MenuPausa/CaixaDialogo).

const CENA_PROFESSOR := "res://scenes/Login/TelaTurma.tscn"
const CENA_ALUNO := "res://scenes/Login/TelaAluno.tscn"
const CENA_DUELO := "res://scenes/salas/duelos.tscn"
const MIN_ALUNOS_PVE := 1
const MIN_ALUNOS_PVP := 2

var _professor := false
var _caixa: VBoxContainer
var _status: Label
var _lista: ItemList
var _titulo: Label
var _codigo_label: Label
var _btn_pve: Button
var _btn_pvp: Button
var _btn_encerrar_atividade: Button
var _campo_codigo: LineEdit
var _btn_entrar: Button
var _ocupado := false


func _ready() -> void:
	_professor = Engine.get_meta("lobby_modo", "aluno") == "professor"
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

	LobbyManager.sala_atualizada.connect(_atualizar)
	LobbyManager.atividade_iniciada.connect(_on_atividade_iniciada)
	LobbyManager.sala_encerrada.connect(_on_sala_encerrada)
	DueloRede.estados_atualizados.connect(_atualizar)
	DueloRede.status_mudou.connect(_on_status_mudou)

	if _professor:
		_montar_sala()
		_status.text = "Abrindo a sala..."
		_abrir_sala_professor()
	elif LobbyManager.esta_em_sala():
		_montar_sala()
		_atualizar()
	else:
		_montar_entrada_aluno()


# ---------------------------------------------------------------- construção

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


func _limpar() -> void:
	for c in _caixa.get_children():
		c.queue_free()


func _montar_entrada_aluno() -> void:
	_limpar()
	_caixa.add_child(_rotulo("Entrar em uma sala", 20, Color(1.0, 0.85, 0.4)))
	_caixa.add_child(_rotulo("Digite o código que o professor mostrou na tela dele:"))

	_campo_codigo = LineEdit.new()
	_campo_codigo.max_length = LobbySalaClass.TAMANHO_CODIGO
	_campo_codigo.placeholder_text = "CÓDIGO"
	_campo_codigo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo_codigo.custom_minimum_size = Vector2(160, 40)
	_campo_codigo.add_theme_font_size_override("font_size", 24)
	_campo_codigo.text_submitted.connect(func(_t): _entrar_como_aluno())
	var centro := CenterContainer.new()
	centro.add_child(_campo_codigo)
	_caixa.add_child(centro)

	_status = _rotulo("", 13, Color(1.0, 0.75, 0.4))
	_caixa.add_child(_status)

	var linha := HBoxContainer.new()
	_btn_entrar = _botao("Entrar", _entrar_como_aluno)
	linha.add_child(_btn_entrar)
	linha.add_child(_botao("Voltar", _voltar))
	_caixa.add_child(linha)
	_campo_codigo.grab_focus()


func _montar_sala() -> void:
	_limpar()
	_titulo = _rotulo("", 18, Color(1.0, 0.85, 0.4))
	_caixa.add_child(_titulo)

	_codigo_label = _rotulo("", 30, Color(0.6, 0.9, 1.0))
	_caixa.add_child(_codigo_label)

	_caixa.add_child(_rotulo("Na sala:", 13, Color(0.8, 0.8, 0.8)))
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.select_mode = ItemList.SELECT_SINGLE
	_lista.add_theme_font_size_override("font_size", 14)
	_caixa.add_child(_lista)

	_status = _rotulo("", 13, Color(1.0, 0.75, 0.4))
	_caixa.add_child(_status)

	var linha := HBoxContainer.new()
	if _professor:
		_btn_pve = _botao("Iniciar PvE (cooperativo)", func(): _iniciar("pve"))
		_btn_pvp = _botao("Iniciar PvP (duelo)", func(): _iniciar("pvp"))
		linha.add_child(_btn_pve)
		linha.add_child(_btn_pvp)
		_btn_encerrar_atividade = _botao("Encerrar atividade", func(): LobbyManager.encerrar_atividade())
		linha.add_child(_btn_encerrar_atividade)
		linha.add_child(_botao("Encerrar sala", _voltar))
	else:
		if Engine.has_meta("lobby_retorno"):
			linha.add_child(_botao("Voltar ao jogo (continua na sala)", _voltar_ao_jogo))
		linha.add_child(_botao("Sair da sala", _voltar))
	_caixa.add_child(linha)


# ------------------------------------------------------------------- ações

func _abrir_sala_professor() -> void:
	var erro: String = await LobbyManager.abrir_sala(NakamaManager.turma_selecionada_nome)
	if not is_inside_tree():
		return
	if erro != "":
		_status.text = erro
		_btn_pve.disabled = true
		_btn_pvp.disabled = true
		return
	_atualizar()


func _entrar_como_aluno() -> void:
	if _ocupado:
		return
	var cod := LobbySalaClass.normalizar_codigo(_campo_codigo.text)
	if cod.length() != LobbySalaClass.TAMANHO_CODIGO:
		_status.text = "O código tem %d caracteres." % LobbySalaClass.TAMANHO_CODIGO
		return
	_ocupado = true
	_btn_entrar.disabled = true
	_status.text = "Entrando na sala..."
	var perfil := LocalDB.carregar_perfil(LocalDB.get_user_id_ativo())
	var nome: String = perfil.nome if perfil != null and perfil.nome != "" else NakamaManager.convidado_nome
	var erro: String = await LobbyManager.entrar_na_sala(cod, nome if nome != "" else "Aluno")
	if not is_inside_tree():
		return
	_ocupado = false
	if erro != "":
		_status.text = erro
		_btn_entrar.disabled = false
		return
	_montar_sala()
	_atualizar()


func _iniciar(modo: String) -> void:
	await LobbyManager.iniciar_atividade(modo)


func _voltar() -> void:
	await LobbyManager.sair()
	if is_inside_tree():
		if _professor:
			get_tree().change_scene_to_file(CENA_PROFESSOR)
		else:
			_ir_para_retorno()


## Sai da tela de espera mas continua na sala: o aluno anda pelo jogo e, se o
## professor iniciar uma atividade, é levado direto pra partida.
func _voltar_ao_jogo() -> void:
	_ir_para_retorno()


## Volta ao ponto do jogo de onde veio (ou ao menu do aluno).
func _ir_para_retorno() -> void:
	var destino := CENA_ALUNO
	if Engine.has_meta("lobby_retorno"):
		var pedido: Dictionary = Engine.get_meta("lobby_retorno")
		Engine.remove_meta("lobby_retorno")
		destino = pedido.get("cena", destino)
		if pedido.has("posicao"):
			Engine.set_meta("spawn_proxima_cena", {"cena": destino, "posicao": pedido["posicao"]})
	get_tree().change_scene_to_file(destino)


# ------------------------------------------------------------------ eventos

func _atualizar() -> void:
	if _lista == null or not is_instance_valid(_lista) or not LobbyManager.esta_em_sala():
		return
	_codigo_label.text = "CÓDIGO: " + LobbyManager.codigo
	if _professor:
		_titulo.text = "Sala da turma: " + LobbyManager.nome_turma
	else:
		_titulo.text = "Sala de %s (prof. %s)" % [LobbyManager.nome_turma, LobbyManager.nome_professor]

	_lista.clear()
	for a in LobbyManager.alunos:
		var eu: bool = a["id"] == LobbyManager.meu_id
		var linha := str(a["nome"]) + ("  (você)" if eu else "")
		if _professor:
			var estado := DueloRede.texto_estado(str(a["id"]))
			if estado != "":
				linha += "  —  " + estado
		_lista.add_item(linha)
	if LobbyManager.alunos.is_empty():
		_lista.add_item("Ninguém entrou ainda...")
		_lista.set_item_disabled(0, true)

	var n: int = LobbyManager.alunos.size()
	var em_atividade: bool = LobbyManager.atividade != ""
	if _professor:
		_btn_pve.disabled = n < MIN_ALUNOS_PVE or em_atividade
		_btn_pvp.disabled = n < MIN_ALUNOS_PVP or em_atividade
		_btn_encerrar_atividade.visible = em_atividade
		if em_atividade:
			_status.text = "Atividade em andamento: %s." % _nome_atividade(LobbyManager.atividade)
		else:
			_status.text = "%d aluno(s) na sala. Compartilhe o código com a turma." % n
	elif not em_atividade:
		_status.text = "Aguardando o professor iniciar a atividade..."
	elif _status.text == "" or _status.text.begins_with("Aguardando"):
		_status.text = "Atividade em andamento. Aguarde o professor."


func _nome_atividade(modo: String) -> String:
	return "PvE cooperativo" if modo == "pve" else "PvP (duelo)"


func _on_atividade_iniciada(_modo: String) -> void:
	# Quem entra na partida (e mostra os avisos) é o DueloRede, de qualquer tela.
	if _professor and _status != null and is_instance_valid(_status):
		_atualizar()


func _on_status_mudou(texto: String) -> void:
	if not _professor and _status != null and is_instance_valid(_status):
		_status.text = texto


func _on_sala_encerrada(motivo: String) -> void:
	if _professor:
		return
	_montar_entrada_aluno()
	_status.text = motivo
