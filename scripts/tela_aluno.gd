extends Control

var _perfil_atual: AlunoModel = null

func _ready():
	# Conecta os botões
	%btnEntrarTurma.pressed.connect(_on_btn_entrar_turma_pressed)
	%btnLogout.pressed.connect(_on_btn_logout_pressed)
	%btnMagias.pressed.connect(_on_btn_magias_pressed)
	%btnEntrarMundo.pressed.connect(_on_btn_entrar_mundo_pressed)

	var uid := LocalDB.get_user_id_ativo()

	# Restaura o loadout salvo do jogador assim que ele chega no saguão —
	# assim o combate já usa o equipamento certo mesmo se ele nunca abrir
	# a tela de magias nesta sessão.
	SpellLoadout.carregar_equipado(uid)

	_verificar_perfil_existente(uid)


## Se o jogador já tem personagem salvo localmente, pula direto pra tela de
## "bem-vindo de volta" em vez de pedir nick+turma de novo. Sem isso, todo
## login recriava o personagem do zero mesmo pra quem já tinha um.
func _verificar_perfil_existente(uid: String) -> void:
	_perfil_atual = LocalDB.carregar_perfil(uid)
	LocalDB.garantir_kit_inicial(uid)
	if _perfil_atual != null and _perfil_atual.nome != "":
		%CenterContainer.visible = false
		%PainelRetornando.visible = true
		%labelNomePersonagem.text = "Bem-vindo de volta, %s!" % _perfil_atual.nome
		%labelTurma.text = "Turma: %s" % (_perfil_atual.codigo_turma if _perfil_atual.codigo_turma != "" else "-")
	else:
		%CenterContainer.visible = true
		%PainelRetornando.visible = false


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
		print("Acesso liberado! Salvando personagem...")

		var uid := LocalDB.get_user_id_ativo()
		var aluno := AlunoModel.new()
		aluno.id = uid
		aluno.nome = nick
		aluno.codigo_turma = codigo
		aluno.tipo_perfil = "Aluno"
		aluno.nivel_atual = 1
		LocalDB.salvar_perfil(aluno)  # também concede o kit inicial (forma+elemento) se for perfil novo

		SpellLoadout.carregar_equipado(uid)
		_verificar_perfil_existente(uid)
	else:
		print("Não foi possível entrar. Verifique o código.")
		%btnEntrarTurma.disabled = false


func _on_btn_entrar_mundo_pressed():
	get_tree().change_scene_to_file("res://scenes/salas/academia.tscn")


func _on_btn_magias_pressed():
	get_tree().change_scene_to_file("res://scenes/Login/TelaLoadout.tscn")


func _on_btn_logout_pressed():
	NakamaManager.fazer_logout()
	get_tree().change_scene_to_file("res://scenes/Login/TelaAutenticacao.tscn")
