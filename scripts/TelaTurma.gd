extends Control

## Tela 2 do painel do professor (mockup "Página 7"): detalhe de uma turma —
## lista de alunos + gestão (remover aluno, apagar turma) + abrir estatísticas.
##
## Recebe qual turma abrir via NakamaManager.turma_selecionada_id/nome,
## setado pela TelaProfessor antes de trocar de cena (Godot não passa
## parâmetro direto em change_scene_to_file).

var _alunos_atuais: Array = []  # cache da última lista carregada, pra achar o id pelo índice selecionado


func _ready() -> void:
	%labelNomeTurma.text = NakamaManager.turma_selecionada_nome

	%btnVoltar.pressed.connect(_on_btn_voltar_pressed)
	%btnApagarTurma.pressed.connect(_on_btn_apagar_turma_pressed)
	%btnRemoverAluno.pressed.connect(_on_btn_remover_aluno_pressed)
	%listaAlunos.item_activated.connect(_on_aluno_ativado)

	_atualizar_lista_alunos()


func _on_btn_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Login/TelaProfessor.tscn")


func _atualizar_lista_alunos() -> void:
	%listaAlunos.clear()
	%listaAlunos.add_item("Carregando alunos...")

	var id_turma := NakamaManager.turma_selecionada_id
	var membros: Array = await NakamaManager.listar_alunos_da_turma(id_turma)

	# Painel do professor só mostra alunos — o próprio professor também é
	# membro (superadmin) do grupo, então ele é filtrado da lista.
	_alunos_atuais = membros.filter(func(m): return not m["is_professor"])

	%listaAlunos.clear()
	if _alunos_atuais.is_empty():
		%listaAlunos.add_item("Nenhum aluno nesta turma ainda.")
	else:
		for aluno in _alunos_atuais:
			%listaAlunos.add_item(aluno["username"])


func _on_aluno_ativado(index: int) -> void:
	if index < 0 or index >= _alunos_atuais.size():
		return
	var aluno: Dictionary = _alunos_atuais[index]
	NakamaManager.aluno_selecionado_id = aluno["id"]
	NakamaManager.aluno_selecionado_nome = aluno["username"]
	get_tree().change_scene_to_file("res://scenes/Login/TelaEstatisticasAluno.tscn")


func _on_btn_remover_aluno_pressed() -> void:
	var indices := %listaAlunos.get_selected_items()
	if indices.is_empty():
		return

	var aluno: Dictionary = _alunos_atuais[indices[0]]
	%btnRemoverAluno.disabled = true

	var sucesso: bool = await NakamaManager.remover_aluno_da_turma(NakamaManager.turma_selecionada_id, aluno["id"])
	if sucesso:
		_atualizar_lista_alunos()
	else:
		print("Falha ao remover aluno da turma.")

	%btnRemoverAluno.disabled = false


func _on_btn_apagar_turma_pressed() -> void:
	%btnApagarTurma.disabled = true

	var sucesso: bool = await NakamaManager.apagar_turma(NakamaManager.turma_selecionada_id)
	if sucesso:
		get_tree().change_scene_to_file("res://scenes/Login/TelaProfessor.tscn")
	else:
		print("Falha ao apagar turma.")
		%btnApagarTurma.disabled = false
