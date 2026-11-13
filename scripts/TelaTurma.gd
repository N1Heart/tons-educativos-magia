extends Control

## Tela 2 do painel do professor (mockup "Página 7"): detalhe de uma turma —
## lista de alunos + gestão (remover aluno, apagar turma) + abrir estatísticas.
##
## Recebe qual turma abrir via NakamaManager.turma_selecionada_id/nome,
## setado pela TelaProfessor antes de trocar de cena (Godot não passa
## parâmetro direto em change_scene_to_file).

var _alunos_atuais: Array = []  # cache da última lista carregada, pra achar o id pelo índice selecionado

var _lista_alunos: ItemList
var _btn_remover: Button
var _btn_apagar: Button
var _confirmando_apagar := false


func _ready() -> void:
	var t := TemaUI.preparar(self, NakamaManager.turma_selecionada_nome, "‹ Turmas", _on_btn_voltar_pressed)
	var colunas := TemaUI.duas_colunas(t["corpo"], "ALUNOS DA TURMA", "AÇÕES", 220)

	var esq := TemaUI.conteudo(colunas[0])
	_lista_alunos = TemaUI.lista()
	_lista_alunos.item_activated.connect(_on_aluno_ativado)
	esq.add_child(_lista_alunos)
	esq.add_child(TemaUI.rotulo("Duplo clique num aluno abre as estatísticas dele.", "Discreto"))

	var dir := TemaUI.conteudo(colunas[1])
	dir.add_child(TemaUI.botao("Abrir sala (PvE / PvP)", _on_btn_abrir_sala_pressed, "BotaoPrimario"))
	dir.add_child(TemaUI.rotulo("Alunos entram com um código e jogam em grupo ou em duelo.", "Discreto"))
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dir.add_child(espaco)
	dir.add_child(TemaUI.rotulo("GESTÃO", "Subtitulo"))
	_btn_remover = TemaUI.botao("Remover aluno selecionado", _on_btn_remover_aluno_pressed)
	dir.add_child(_btn_remover)
	_btn_apagar = TemaUI.botao("Apagar turma", _on_btn_apagar_turma_pressed, "BotaoPerigo")
	dir.add_child(_btn_apagar)

	_atualizar_lista_alunos()


func _on_btn_voltar_pressed() -> void:
	Transicao.ir_para("res://scenes/Login/TelaProfessor.tscn")


func _on_btn_abrir_sala_pressed() -> void:
	Engine.set_meta("lobby_modo", "professor")
	Transicao.ir_para("res://scenes/Login/TelaLobby.tscn")


func _atualizar_lista_alunos() -> void:
	_lista_alunos.clear()
	_lista_alunos.add_item("Carregando alunos...")

	var id_turma := NakamaManager.turma_selecionada_id
	var membros: Array = await NakamaManager.listar_alunos_da_turma(id_turma)

	# Painel do professor só mostra alunos — o próprio professor também é
	# membro (superadmin) do grupo, então ele é filtrado da lista.
	_alunos_atuais = membros.filter(func(m): return not m["is_professor"])

	_lista_alunos.clear()
	if _alunos_atuais.is_empty():
		_lista_alunos.add_item("Nenhum aluno nesta turma ainda.")
		_lista_alunos.set_item_disabled(0, true)
	else:
		for aluno in _alunos_atuais:
			_lista_alunos.add_item(aluno["username"])
		_marcar_alertas()


## Depois de mostrar a lista, consulta as estatísticas de cada aluno e marca
## com ⚠ quem está com alerta de dificuldade de aprendizado (RF4). Roda em
## segundo plano pra não atrasar a tela.
func _marcar_alertas() -> void:
	var alunos := _alunos_atuais
	for i in alunos.size():
		var dados: Dictionary = await NakamaManager.obter_estatisticas_aluno(alunos[i]["id"])
		# A tela pode ter sido fechada ou a lista recarregada enquanto esperava
		if not is_instance_valid(_lista_alunos) or alunos != _alunos_atuais or i >= _lista_alunos.item_count:
			return
		if dados.get("alerta_dificuldade", false):
			_lista_alunos.set_item_text(i, "⚠ " + alunos[i]["username"])


func _on_aluno_ativado(index: int) -> void:
	if index < 0 or index >= _alunos_atuais.size():
		return
	var aluno: Dictionary = _alunos_atuais[index]
	NakamaManager.aluno_selecionado_id = aluno["id"]
	NakamaManager.aluno_selecionado_nome = aluno["username"]
	Transicao.ir_para("res://scenes/Login/TelaEstatisticasAluno.tscn")


func _on_btn_remover_aluno_pressed() -> void:
	var indices: PackedInt32Array = _lista_alunos.get_selected_items()
	if indices.is_empty():
		return

	var aluno: Dictionary = _alunos_atuais[indices[0]]
	_btn_remover.disabled = true

	var sucesso: bool = await NakamaManager.remover_aluno_da_turma(NakamaManager.turma_selecionada_id, aluno["id"])
	if sucesso:
		_atualizar_lista_alunos()
	else:
		print("Falha ao remover aluno da turma.")

	_btn_remover.disabled = false


func _on_btn_apagar_turma_pressed() -> void:
	# Duas etapas: o primeiro clique pede confirmação (volta ao normal em 4 s).
	if not _confirmando_apagar:
		_confirmando_apagar = true
		_btn_apagar.text = "Clique de novo para apagar"
		await get_tree().create_timer(4.0).timeout
		if is_inside_tree() and _confirmando_apagar:
			_confirmando_apagar = false
			_btn_apagar.text = "Apagar turma"
		return

	_confirmando_apagar = false
	_btn_apagar.disabled = true

	var sucesso: bool = await NakamaManager.apagar_turma(NakamaManager.turma_selecionada_id)
	if sucesso:
		Transicao.ir_para("res://scenes/Login/TelaProfessor.tscn")
	else:
		print("Falha ao apagar turma.")
		_btn_apagar.text = "Apagar turma"
		_btn_apagar.disabled = false
