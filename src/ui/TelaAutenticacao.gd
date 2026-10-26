extends Node

# Referências aos contêineres principais
@onready var login_box = $CenterContainer/PanelContainer/LoginBox
@onready var cadastro_box = $CenterContainer/PanelContainer/CadastroBox	

## Campo "Servidor" (IP do computador do professor no laboratório). Montado
## por código pra não mexer na cena; vazio/127.0.0.1 = servidor na própria máquina.
var _campo_servidor: LineEdit

func _ready():
	# Garante que começa na tela de login
	login_box.visible = true
	cadastro_box.visible = false
	
	# Conecta os sinais dos botões (você também pode fazer isso via interface do Godot)
	%Cadastro.pressed.connect(_on_btn_ir_cadastro_pressed)
	%BtnVoltarLogin.pressed.connect(_on_btn_voltar_login_pressed)
	
	%BtnConvidado.pressed.connect(_on_btn_convidado_pressed)
	%BtnEntrar.pressed.connect(_on_btn_entrar_pressed)
	%BtnCadastro.pressed.connect(_on_btn_cadastrar_pressed)
	_montar_campo_servidor()


func _montar_campo_servidor() -> void:
	# Faixa fixa no rodapé da tela (a caixa de login já ocupa a altura toda de
	# 640x360, então um campo dentro dela ficava para fora da janela).
	var camada := CanvasLayer.new()
	add_child(camada)
	var painel := PanelContainer.new()
	camada.add_child(painel)
	var linha := HBoxContainer.new()
	painel.add_child(linha)

	var rotulo := Label.new()
	rotulo.text = "Servidor (IP do professor):"
	rotulo.add_theme_font_size_override("font_size", 11)
	linha.add_child(rotulo)

	_campo_servidor = LineEdit.new()
	_campo_servidor.text = NakamaManager.carregar_servidor()
	_campo_servidor.placeholder_text = NakamaManager.SERVIDOR_PADRAO
	_campo_servidor.custom_minimum_size = Vector2(130, 0)
	_campo_servidor.add_theme_font_size_override("font_size", 11)
	linha.add_child(_campo_servidor)
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 6)


## Aplica o endereço digitado antes de qualquer chamada ao servidor.
func _aplicar_servidor() -> void:
	if _campo_servidor == null:
		return
	var digitado := _campo_servidor.text.strip_edges()
	if digitado == "":
		digitado = NakamaManager.SERVIDOR_PADRAO
	if digitado != NakamaManager.carregar_servidor():
		NakamaManager.definir_servidor(digitado)
# --- NAVEGAÇÃO ENTRE TELAS ---

func _on_btn_ir_cadastro_pressed():
	print("Botão de ir para cadastro clicado!") # <- O terminal mostra isso?
	login_box.visible = false
	cadastro_box.visible = true

func _on_btn_voltar_login_pressed():
	cadastro_box.visible = false
	login_box.visible = true

# --- INTEGRAÇÃO COM NAKAMA ---

func _on_btn_convidado_pressed():
	_abrir_escolha_personagem()


## Janela "Escolha seu personagem": quem já jogou neste computador retoma o
## seu; quem é novo digita um nome. Funciona sem servidor — se não houver
## conexão o jogo segue offline e sincroniza depois.
func _abrir_escolha_personagem() -> void:
	_aplicar_servidor()

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)

	var painel := PanelContainer.new()
	centro.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	painel.add_child(margem)
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(260, 0)
	caixa.add_theme_constant_override("separation", 6)
	margem.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "Escolha seu personagem"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(titulo)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)

	var botoes: Array[Button] = []
	var existentes := LocalDB.listar_personagens_convidado(NakamaManager.prefixo_convidado())
	for p in existentes:
		var b := Button.new()
		b.text = str(p["nome"])
		caixa.add_child(b)
		botoes.append(b)
		b.pressed.connect(_entrar_convidado.bind(str(p["nome"]), botoes, status))

	if not existentes.is_empty():
		caixa.add_child(HSeparator.new())

	var campo := LineEdit.new()
	campo.placeholder_text = "Nome do novo personagem"
	campo.max_length = 20
	caixa.add_child(campo)

	var criar := Button.new()
	criar.text = "Criar e jogar"
	caixa.add_child(criar)
	botoes.append(criar)
	criar.pressed.connect(func():
		var nome := campo.text.strip_edges()
		if nome.length() < 2:
			status.text = "Digite um nome com pelo menos 2 letras."
			return
		_entrar_convidado(nome, botoes, status))

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(fundo.queue_free)
	caixa.add_child(cancelar)

	caixa.add_child(status)
	campo.grab_focus()


func _entrar_convidado(nome: String, botoes: Array[Button], status: Label) -> void:
	for b in botoes:
		b.disabled = true
	status.text = "Conectando..."
	var online: bool = await NakamaManager.entrar_como_convidado(nome)
	if not online:
		print("Sem conexão com o servidor: jogando offline (o progresso é salvo neste computador).")
	get_tree().change_scene_to_file("res://scenes/Login/TelaAluno.tscn")


func _on_btn_entrar_pressed():
	var email = %EmailLogin.text
	var senha = %SenhaLogin.text
	
	if email == "" or senha == "":
		print("Preencha email e senha!")
		return
		
	%BtnEntrar.disabled = true
	_aplicar_servidor()
	var sucesso = await NakamaManager.login_conta(email, senha)
	
	if sucesso == "professor":
		print("acesso de professor liberado!")
		get_tree().change_scene_to_file("res://scenes/Login/TelaProfessor.tscn")
		# Muda de cena
	elif sucesso =="aluno":
		print("acesso de aluno liberado")
		get_tree().change_scene_to_file("res://scenes/Login/TelaAluno.tscn")
	
	
	else:
		print("Credenciais incorretas.")
		%BtnEntrar.disabled = false

func _on_btn_cadastrar_pressed():
	var nome = %NomeCadastro.text
	var email = %EmailCadastro.text
	var senha = %SenhaCadastro.text
	
	# Pega o texto do item selecionado no Dropdown ("Aluno" ou "Professor")
	var tipo_conta = %PerfilDropdown.get_item_text(%PerfilDropdown.selected).to_lower()
	
	if nome == "" or email == "" or senha == "":
		print("Preencha todos os campos!")
		return
		
	%Cadastro.disabled = true
	_aplicar_servidor()
	
	# Usa a função de cadastro que criamos no gerenciador
	var sucesso = await NakamaManager.cadastrar_conta(email, senha, nome, tipo_conta)
	
	if sucesso:
		print("Cadastro realizado com sucesso como: ", tipo_conta)
		login_box.visible = true
		cadastro_box.visible = false
	else:
		print("Erro ao cadastrar.")
		%Cadastro.disabled = false
