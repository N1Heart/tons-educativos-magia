extends Control

func _ready():
	# Conecta os botões
	%btnEntrarTurma.pressed.connect(_on_btn_entrar_turma_pressed)
	%btnLogout.pressed.connect(_on_btn_logout_pressed)

func _on_btn_entrar_turma_pressed():
	var nick = %nomePersonagem.text.strip_edges()
	var codigo = %codTurma.text.strip_edges()
	
	if nick == "" or codigo == "":
		print("Preencha seu nick e o código da turma!")
		return
		
	%btnEntrarTurma.disabled = true
	print("Procurando turma...")
	
	var sucesso = await NakamaManager.entrar_turma(codigo)
	
	if sucesso:
		print("Acesso liberado! Carregando Mundo Mágico...")
		
		# Opcional para o futuro: Salvar o 'nick' no storage do usuário antes de mudar de cena
		
		# get_tree().change_scene_to_file("res://CenaDoJogo.tscn")
	else:
		print("Não foi possível entrar. Verifique o código.")
		%btnEntrarTurma.disabled = false

func _on_btn_logout_pressed():
	NakamaManager.fazer_logout()
	get_tree().change_scene_to_file("res://TelaAutenticacao.tscn")
