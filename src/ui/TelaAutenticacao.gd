extends Node

# Referências aos contêineres principais
@onready var login_box = $CenterContainer/PanelContainer/LoginBox
@onready var cadastro_box = $CenterContainer/PanelContainer/CadastroBox	

func _ready():
	# Garante que começa na tela de login
	login_box.visible = true
	cadastro_box.visible = false
	
	# Conecta os sinais dos botões (você também pode fazer isso via interface do Godot)
	%Cadastro.pressed.connect(_on_btn_ir_cadastro_pressed)
	%BtnVoltarLogin.pressed.connect(_on_btn_voltar_login_pressed)
	
	%BtnConvidado.pressed.connect(_on_btn_convidado_pressed)
	%BntEntrar.pressed.connect(_on_btn_entrar_pressed)
	%BtnCadastro.pressed.connect(_on_btn_cadastrar_pressed)

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
	# Bloqueia o botão para evitar cliques duplos
	%BtnConvidado.disabled = true 
	
	var device_id = OS.get_unique_id()
	# Chama a função que você já tem no NakamaManager
	var sucesso = await NakamaManager.login_convidado(device_id)
	
	if sucesso:
		print("Convidado logado! Carregando menu do aluno...")
		get_tree().change_scene_to_file("res://scenes/Login/TelaAluno.tscn")
	else:
		print("Falha ao entrar como convidado.")
		%BtnConvidado.disabled = false

func _on_btn_entrar_pressed():
	var email = %EmailLogin.text
	var senha = %SenhaLogin.text
	
	if email == "" or senha == "":
		print("Preencha email e senha!")
		return
		
	%BntEntrar.disabled = true
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
	
	# Usa a função de cadastro que criamos no gerenciador
	var sucesso = await NakamaManager.cadastrar_conta(email, senha, nome, tipo_conta)
	
	if sucesso:
		print("Cadastro realizado com sucesso como: ", tipo_conta)
		login_box.visible = true
		cadastro_box.visible = false
	else:
		print("Erro ao cadastrar.")
		%Cadastro.disabled = false
