extends Control

## Tela de entrada: login, cadastro e "jogar como convidado".
## Montada por código com o TemaUI (mesmo visual das outras telas), sobre a
## arte da torre. O servidor (IP do professor) fica numa faixa no rodapé.

const FUNDO := "res://assets/Telalogin.png"
const LARGURA_CARTAO := 230

var _campo_servidor: LineEdit

# Cartão da direita
var _caixa_login: VBoxContainer
var _caixa_cadastro: VBoxContainer
var _aviso: Label
var _email_login: LineEdit
var _senha_login: LineEdit
var _btn_entrar: Button
var _btn_convidado: Button
var _nome_cadastro: LineEdit
var _email_cadastro: LineEdit
var _senha_cadastro: LineEdit
var _perfil: OptionButton
var _btn_cadastrar: Button

# Janela "Escolha seu personagem": só pode existir uma por vez.
var _janela_convidado: CanvasLayer = null


func _ready() -> void:
	theme = TemaUI.tema()
	_montar_fundo()
	_montar_titulo()
	_montar_cartao()
	_montar_campo_servidor()
	_mostrar_login()


# ---------------------------------------------------------------- construção

func _montar_fundo() -> void:
	var tex := load(FUNDO) as Texture2D
	var fundo := TextureRect.new()
	fundo.texture = tex
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)


func _montar_titulo() -> void:
	var caixa := VBoxContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 0)
	add_child(caixa)

	var titulo := Label.new()
	titulo.text = "Tons Educativos de Magia"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", TemaUI.OURO)
	titulo.add_theme_color_override("font_outline_color", Color("1a1233"))
	titulo.add_theme_constant_override("outline_size", 8)
	caixa.add_child(titulo)

	var sub := Label.new()
	sub.text = "Aprenda formas e cores com magia"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color("1a1233"))
	sub.add_theme_constant_override("outline_size", 5)
	caixa.add_child(sub)
	# Centraliza de verdade depois de o texto ter tamanho.
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)


func _montar_cartao() -> void:
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(TemaUI.PAINEL, 0.94)
	estilo.border_color = TemaUI.BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.shadow_color = Color(0, 0, 0, 0.45)
	estilo.shadow_size = 8
	cartao.add_theme_stylebox_override("panel", estilo)
	cartao.custom_minimum_size = Vector2(LARGURA_CARTAO, 0)
	# Posição: encostado à direita, centrado na vertical (abaixo do título).
	var moldura := MarginContainer.new()
	moldura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_theme_constant_override("margin_right", 24)
	moldura.add_theme_constant_override("margin_top", 68)
	moldura.add_theme_constant_override("margin_bottom", 40)
	add_child(moldura)
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(linha)
	var vao := Control.new()
	vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(vao)
	cartao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(cartao)
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	cartao.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	margem.add_child(coluna)

	# --- Login ---
	_caixa_login = VBoxContainer.new()
	_caixa_login.add_theme_constant_override("separation", 6)
	coluna.add_child(_caixa_login)
	_caixa_login.add_child(TemaUI.rotulo("ENTRAR", "Subtitulo"))
	_email_login = _campo("E-mail")
	_caixa_login.add_child(_email_login)
	_senha_login = _campo("Senha", true)
	_caixa_login.add_child(_senha_login)
	_btn_entrar = TemaUI.botao("Entrar", _on_btn_entrar_pressed, "BotaoPrimario")
	_caixa_login.add_child(_btn_entrar)
	_caixa_login.add_child(HSeparator.new())
	_btn_convidado = TemaUI.botao("Jogar como convidado", _on_btn_convidado_pressed)
	_caixa_login.add_child(_btn_convidado)
	_caixa_login.add_child(TemaUI.botao("Criar conta", _mostrar_cadastro, "BotaoBarra"))
	_email_login.text_submitted.connect(func(_t): _senha_login.grab_focus())
	_senha_login.text_submitted.connect(func(_t): _on_btn_entrar_pressed())

	# --- Cadastro ---
	_caixa_cadastro = VBoxContainer.new()
	_caixa_cadastro.add_theme_constant_override("separation", 6)
	coluna.add_child(_caixa_cadastro)
	_caixa_cadastro.add_child(TemaUI.rotulo("CRIAR CONTA", "Subtitulo"))
	_nome_cadastro = _campo("Nome")
	_caixa_cadastro.add_child(_nome_cadastro)
	_email_cadastro = _campo("E-mail")
	_caixa_cadastro.add_child(_email_cadastro)
	_senha_cadastro = _campo("Senha", true)
	_caixa_cadastro.add_child(_senha_cadastro)
	_perfil = OptionButton.new()
	_perfil.add_item("Aluno")
	_perfil.add_item("Professor")
	_perfil.custom_minimum_size = Vector2(0, TemaUI.ALTURA_BOTAO)
	_caixa_cadastro.add_child(_perfil)
	_btn_cadastrar = TemaUI.botao("Finalizar cadastro", _on_btn_cadastrar_pressed, "BotaoPrimario")
	_caixa_cadastro.add_child(_btn_cadastrar)
	_caixa_cadastro.add_child(TemaUI.botao("‹ Voltar ao login", _mostrar_login, "BotaoBarra"))
	_senha_cadastro.text_submitted.connect(func(_t): _on_btn_cadastrar_pressed())

	# Mensagens (erros e andamento), comum às duas telas
	_aviso = TemaUI.rotulo("", "Aviso")
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 11)
	_aviso.visible = false
	coluna.add_child(_aviso)


func _campo(dica: String, secreto: bool = false) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = dica
	c.secret = secreto
	c.custom_minimum_size = Vector2(0, TemaUI.ALTURA_BOTAO)
	return c


func _montar_campo_servidor() -> void:
	# Faixa fixa no rodapé: a janela do convidado fica numa camada acima dela.
	var camada := CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	var painel := PanelContainer.new()
	painel.theme = TemaUI.tema()
	camada.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 5)
	painel.add_child(margem)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	margem.add_child(linha)

	var rotulo := TemaUI.rotulo("Servidor (IP do professor)", "Discreto")
	rotulo.autowrap_mode = TextServer.AUTOWRAP_OFF
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo)

	_campo_servidor = LineEdit.new()
	_campo_servidor.text = NakamaManager.carregar_servidor()
	_campo_servidor.placeholder_text = NakamaManager.SERVIDOR_PADRAO
	_campo_servidor.custom_minimum_size = Vector2(120, 0)
	_campo_servidor.add_theme_font_size_override("font_size", 11)
	linha.add_child(_campo_servidor)
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)


## Aplica o endereço digitado antes de qualquer chamada ao servidor.
func _aplicar_servidor() -> void:
	if _campo_servidor == null:
		return
	var digitado := _campo_servidor.text.strip_edges()
	if digitado == "":
		digitado = NakamaManager.SERVIDOR_PADRAO
	if digitado != NakamaManager.carregar_servidor():
		NakamaManager.definir_servidor(digitado)


# ---------------------------------------------------------------- navegação

func _mostrar_login() -> void:
	_caixa_cadastro.visible = false
	_caixa_login.visible = true
	_mensagem("")
	_email_login.grab_focus()


func _mostrar_cadastro() -> void:
	_caixa_login.visible = false
	_caixa_cadastro.visible = true
	_mensagem("")
	_nome_cadastro.grab_focus()


func _mensagem(texto: String, erro: bool = true) -> void:
	_aviso.visible = texto != ""
	_aviso.text = texto
	_aviso.theme_type_variation = "Aviso" if erro else "Discreto"


# ---------------------------------------------------------------- convidado

func _on_btn_convidado_pressed() -> void:
	# Um clique só: enquanto a janela está aberta o botão fica travado e
	# qualquer outra chamada é ignorada.
	if _janela_convidado != null and is_instance_valid(_janela_convidado):
		return
	_abrir_escolha_personagem()


## Janela "Escolha seu personagem": quem já jogou neste computador retoma o
## seu; quem é novo digita um nome. Funciona sem servidor — se não houver
## conexão o jogo segue offline e sincroniza depois.
func _abrir_escolha_personagem() -> void:
	_aplicar_servidor()
	_btn_convidado.disabled = true

	# Camada acima da faixa do servidor (layer 1) e de todo o resto.
	_janela_convidado = CanvasLayer.new()
	_janela_convidado.layer = 50
	add_child(_janela_convidado)

	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.02, 0.08, 0.72)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP  # bloqueia cliques no que está atrás
	fundo.theme = TemaUI.tema()
	_janela_convidado.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)

	var painel := TemaUI.painel("ESCOLHA SEU PERSONAGEM")
	painel.custom_minimum_size = Vector2(290, 0)
	centro.add_child(painel)
	var caixa := TemaUI.conteudo(painel)

	var status := TemaUI.rotulo("", "Aviso")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)

	var botoes: Array[Button] = []
	var existentes := LocalDB.listar_personagens_convidado(NakamaManager.prefixo_convidado())
	if not existentes.is_empty():
		caixa.add_child(TemaUI.rotulo("Continuar com:", "Discreto"))
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", 4)
		var rolagem := ScrollContainer.new()
		rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rolagem.custom_minimum_size = Vector2(0, mini(existentes.size(), 4) * 32)
		rolagem.add_child(lista)
		lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caixa.add_child(rolagem)
		for p in existentes:
			var b := TemaUI.botao(str(p["nome"]), Callable())
			lista.add_child(b)
			botoes.append(b)
			b.pressed.connect(_entrar_convidado.bind(str(p["nome"]), botoes, status))
		caixa.add_child(HSeparator.new())

	caixa.add_child(TemaUI.rotulo("Novo personagem:", "Discreto"))
	var campo := LineEdit.new()
	campo.placeholder_text = "Nome do personagem"
	campo.max_length = 20
	campo.custom_minimum_size = Vector2(0, TemaUI.ALTURA_BOTAO)
	caixa.add_child(campo)

	var criar := TemaUI.botao("Criar e jogar", Callable(), "BotaoPrimario")
	caixa.add_child(criar)
	botoes.append(criar)
	var tentar_criar := func():
		var nome := campo.text.strip_edges()
		if nome.length() < 2:
			status.text = "Digite um nome com pelo menos 2 letras."
			return
		_entrar_convidado(nome, botoes, status)
	criar.pressed.connect(tentar_criar)
	campo.text_submitted.connect(func(_t): tentar_criar.call())

	var cancelar := TemaUI.botao("Cancelar", _fechar_escolha_personagem, "BotaoBarra")
	caixa.add_child(cancelar)
	botoes.append(cancelar)

	caixa.add_child(status)
	campo.grab_focus()


func _fechar_escolha_personagem() -> void:
	if _janela_convidado != null and is_instance_valid(_janela_convidado):
		_janela_convidado.queue_free()
	_janela_convidado = null
	_btn_convidado.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _janela_convidado != null and is_instance_valid(_janela_convidado):
		_fechar_escolha_personagem()
		get_viewport().set_input_as_handled()


func _entrar_convidado(nome: String, botoes: Array[Button], status: Label) -> void:
	for b in botoes:
		b.disabled = true
	status.theme_type_variation = "Discreto"
	status.text = "Conectando..."
	var online: bool = await NakamaManager.entrar_como_convidado(nome)
	if not online:
		print("Sem conexão com o servidor: jogando offline (o progresso é salvo neste computador).")
	Transicao.ir_para("res://scenes/Login/TelaAluno.tscn")


# ---------------------------------------------------------------- login e cadastro

func _on_btn_entrar_pressed() -> void:
	if _btn_entrar.disabled:
		return
	var email := _email_login.text.strip_edges()
	var senha := _senha_login.text

	if email == "" or senha == "":
		_mensagem("Preencha e-mail e senha.")
		return

	_btn_entrar.disabled = true
	_mensagem("Entrando...", false)
	_aplicar_servidor()
	var sucesso = await NakamaManager.login_conta(email, senha)

	if sucesso == "professor":
		Transicao.ir_para("res://scenes/Login/TelaProfessor.tscn")
	elif sucesso == "aluno":
		Transicao.ir_para("res://scenes/Login/TelaAluno.tscn")
	else:
		_mensagem("E-mail ou senha incorretos, ou servidor indisponível.")
		_btn_entrar.disabled = false


func _on_btn_cadastrar_pressed() -> void:
	if _btn_cadastrar.disabled:
		return
	var nome := _nome_cadastro.text.strip_edges()
	var email := _email_cadastro.text.strip_edges()
	var senha := _senha_cadastro.text
	var tipo_conta := _perfil.get_item_text(_perfil.selected).to_lower()  # "aluno" ou "professor"

	if nome == "" or email == "" or senha == "":
		_mensagem("Preencha todos os campos.")
		return

	_btn_cadastrar.disabled = true
	_mensagem("Criando conta...", false)
	_aplicar_servidor()

	var sucesso = await NakamaManager.cadastrar_conta(email, senha, nome, tipo_conta)

	if sucesso:
		_btn_cadastrar.disabled = false
		_mostrar_login()
		_email_login.text = email
		_senha_login.text = ""
		_mensagem("Conta criada! Entre com o seu e-mail e senha.", false)
	else:
		_mensagem("Não foi possível criar a conta (e-mail já usado ou servidor indisponível).")
		_btn_cadastrar.disabled = false
