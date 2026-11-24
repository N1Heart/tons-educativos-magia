extends Control

## Tela do personagem (menu do aluno). Montada por código no mesmo tema das
## demais telas (TemaUI): à esquerda o personagem; à direita, ou o cadastro do
## personagem novo (nome + código da turma), ou o "bem-vindo de volta" de quem
## já tem personagem salvo neste computador.

var _perfil_atual: AlunoModel = null

# Coluna do personagem
var _lbl_nome: Label
var _lbl_turma: Label

# Personagem novo
var _painel_novo: PanelContainer
var _campo_nome: LineEdit
var _campo_codigo: LineEdit
var _status: Label
var _btn_entrar_turma: Button

# Personagem que volta
var _painel_volta: PanelContainer
var _cartao_formas: PanelContainer
var _cartao_cores: PanelContainer


func _ready() -> void:
	var t := TemaUI.preparar(self, "Meu personagem", "‹ Sair", _on_btn_logout_pressed)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	t["corpo"].add_child(linha)

	_montar_coluna_personagem(linha)
	_montar_painel_novo(linha)
	_montar_painel_volta(linha)

	var uid := LocalDB.get_user_id_ativo()

	# Restaura o loadout salvo do jogador assim que ele chega no saguão —
	# assim o combate já usa o equipamento certo mesmo se ele nunca abrir
	# a tela de magias nesta sessão.
	SpellLoadout.carregar_equipado(uid)

	_verificar_perfil_existente(uid)

	# Convidado: o nome do personagem já foi escolhido na tela de entrada.
	if NakamaManager.convidado_nome != "" and _campo_nome.text == "":
		_campo_nome.text = NakamaManager.convidado_nome
		_atualizar_nome_ao_vivo()

	if _painel_novo.visible:
		(_campo_codigo if _campo_nome.text != "" else _campo_nome).call_deferred("grab_focus")


# --- Montagem da tela ------------------------------------------------------

func _montar_coluna_personagem(linha: HBoxContainer) -> void:
	var esq := TemaUI.painel("PERSONAGEM")
	esq.custom_minimum_size = Vector2(176, 0)
	linha.add_child(esq)
	var v := TemaUI.conteudo(esq)

	var retrato := TemaUI.retrato_personagem(120)
	retrato.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(retrato)

	_lbl_nome = TemaUI.rotulo("", "Titulo")
	_lbl_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lbl_nome)
	_lbl_turma = TemaUI.rotulo("", "Discreto")
	_lbl_turma.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lbl_turma)

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(espaco)
	v.add_child(TemaUI.botao("Minhas Magias", _on_btn_magias_pressed))


func _montar_painel_novo(linha: HBoxContainer) -> void:
	_painel_novo = TemaUI.painel("CRIAR PERSONAGEM")
	_painel_novo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(_painel_novo)
	var v := TemaUI.conteudo(_painel_novo)

	v.add_child(TemaUI.rotulo("Nome do personagem"))
	_campo_nome = _campo("Como você quer ser chamado?")
	_campo_nome.text_changed.connect(func(_t: String): _atualizar_nome_ao_vivo())
	_campo_nome.text_submitted.connect(func(_t: String): _campo_codigo.grab_focus())
	v.add_child(_campo_nome)
	v.add_child(TemaUI.rotulo("É o nome do seu mago dentro do jogo.", "Discreto"))

	v.add_child(TemaUI.rotulo("Código da turma"))
	_campo_codigo = _campo("Ex.: M-1A-731")
	_campo_codigo.text_submitted.connect(func(_t: String): _on_btn_entrar_turma_pressed())
	v.add_child(_campo_codigo)
	v.add_child(TemaUI.rotulo("Peça o código ao seu professor.", "Discreto"))

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(espaco)

	_status = TemaUI.rotulo("", "Aviso")
	_status.visible = false
	v.add_child(_status)
	_btn_entrar_turma = TemaUI.botao("Entrar no Mundo", _on_btn_entrar_turma_pressed, "BotaoPrimario")
	v.add_child(_btn_entrar_turma)


func _montar_painel_volta(linha: HBoxContainer) -> void:
	_painel_volta = TemaUI.painel("BEM-VINDO DE VOLTA")
	_painel_volta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_painel_volta.visible = false
	linha.add_child(_painel_volta)
	var v := TemaUI.conteudo(_painel_volta)

	v.add_child(TemaUI.rotulo("Seu progresso neste computador:", "Discreto"))
	var cartoes := HBoxContainer.new()
	cartoes.add_theme_constant_override("separation", 6)
	v.add_child(cartoes)
	_cartao_formas = TemaUI.cartao_numero("Formas desbloqueadas")
	_cartao_cores = TemaUI.cartao_numero("Cores desbloqueadas")
	cartoes.add_child(_cartao_formas)
	cartoes.add_child(_cartao_cores)

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(espaco)

	v.add_child(TemaUI.botao("Entrar no Mundo", _on_btn_entrar_mundo_pressed, "BotaoPrimario"))
	v.add_child(TemaUI.botao("Entrar em sala (código do professor)", _on_btn_entrar_sala_pressed))
	v.add_child(TemaUI.rotulo("A sala é a atividade em grupo que o professor abre na turma.", "Discreto"))


func _campo(dica: String) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = dica
	c.custom_minimum_size = Vector2(0, TemaUI.ALTURA_BOTAO)
	return c


# --- Estado ----------------------------------------------------------------

## Se o jogador já tem personagem salvo localmente, pula direto pra tela de
## "bem-vindo de volta" em vez de pedir nick+turma de novo. Sem isso, todo
## login recriava o personagem do zero mesmo pra quem já tinha um.
func _verificar_perfil_existente(uid: String) -> void:
	_perfil_atual = LocalDB.carregar_perfil(uid)
	LocalDB.garantir_kit_inicial(uid)
	var voltando := _perfil_atual != null and _perfil_atual.nome != ""
	_painel_novo.visible = not voltando
	_painel_volta.visible = voltando
	if voltando:
		_lbl_nome.text = _perfil_atual.nome
		_lbl_turma.text = "Turma: %s" % (_perfil_atual.codigo_turma if _perfil_atual.codigo_turma != "" else "-")
		_atualizar_progresso(uid)
	else:
		_lbl_turma.text = ""
		_atualizar_nome_ao_vivo()


## Enquanto o aluno digita, o nome já aparece embaixo do personagem.
func _atualizar_nome_ao_vivo() -> void:
	if _painel_novo.visible:
		var nome := _campo_nome.text.strip_edges()
		_lbl_nome.text = nome if nome != "" else "Novo mago"


func _atualizar_progresso(uid: String) -> void:
	var formas := LocalDB.listar_formas_desbloqueadas(uid).size()
	var cores := LocalDB.listar_elementos_desbloqueados(uid).size()
	(_cartao_formas.get_meta("valor") as Label).text = "%d de %d" % [formas, SpellLoadout.SHAPES.size()]
	(_cartao_cores.get_meta("valor") as Label).text = "%d de %d" % [cores, SpellLoadout.ELEMENTS.size()]


func _mostrar_status(texto: String, erro: bool = true) -> void:
	_status.text = texto
	_status.theme_type_variation = "Aviso" if erro else "Discreto"
	_status.visible = texto != ""


# --- Ações -----------------------------------------------------------------

func _on_btn_entrar_turma_pressed() -> void:
	if _btn_entrar_turma.disabled:
		return
	var nick := _campo_nome.text.strip_edges()
	var codigo := _campo_codigo.text.strip_edges()

	if nick == "" or codigo == "":
		_mostrar_status("Preencha o nome do personagem e o código da turma.")
		return

	_btn_entrar_turma.disabled = true
	_mostrar_status("Procurando a turma...", false)

	# Sem conexão (convidado offline): aceita o código agora e confirma na
	# turma depois, quando o servidor aparecer (SyncManager).
	var online: bool = NakamaManager.session != null
	var sucesso: bool = true
	if online:
		sucesso = await NakamaManager.entrar_turma(codigo)

	if sucesso:
		_mostrar_status("")

		var uid := LocalDB.get_user_id_ativo()
		var aluno := AlunoModel.new()
		aluno.id = uid
		aluno.nome = nick
		aluno.codigo_turma = codigo
		aluno.tipo_perfil = "Aluno"
		aluno.nivel_atual = 1
		aluno.is_convidado = NakamaManager.convidado_id_ativo != ""
		LocalDB.salvar_perfil(aluno)  # também concede o kit inicial (forma+elemento) se for perfil novo
		if not online:
			LocalDB.marcar_turma_pendente(uid, true)

		SpellLoadout.carregar_equipado(uid)
		_verificar_perfil_existente(uid)
	else:
		_mostrar_status("Não foi possível entrar. Verifique o código da turma.")
		_btn_entrar_turma.disabled = false


func _on_btn_entrar_mundo_pressed() -> void:
	Transicao.ir_para("res://scenes/salas/academia.tscn")


func _on_btn_entrar_sala_pressed() -> void:
	Engine.set_meta("lobby_modo", "aluno")
	Transicao.ir_para("res://scenes/Login/TelaLobby.tscn")


func _on_btn_magias_pressed() -> void:
	Transicao.ir_para("res://scenes/Login/TelaLoadout.tscn")


func _on_btn_logout_pressed() -> void:
	NakamaManager.fazer_logout()
	Transicao.ir_para("res://scenes/Login/TelaAutenticacao.tscn")
