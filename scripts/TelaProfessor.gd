extends Control

## Painel do professor, tela 1: lista das turmas e criação de turma nova.
## Montada por código com o TemaUI (mesmo visual das outras telas de gestão).

var codigo_gerado := ""
var _turmas_atuais: Array = []  # cache {id, nome} da última lista carregada

var _lista_turmas: ItemList
var _btn_atualizar: Button
var _opcao_periodo: OptionButton
var _campo_ano: SpinBox
var _campo_letra: LineEdit
var _display_codigo: Label
var _btn_gerar: Button
var _btn_salvar: Button


func _ready() -> void:
	var t := TemaUI.preparar(self, "Minhas turmas", "", Callable(), "Sair", _on_btn_logout_pressed)
	var colunas := TemaUI.duas_colunas(t["corpo"], "TURMAS CADASTRADAS", "NOVA TURMA", 250)
	_montar_lista(TemaUI.conteudo(colunas[0]))
	_montar_formulario(TemaUI.conteudo(colunas[1]))
	_atualizar_lista_turmas()


func _montar_lista(v: VBoxContainer) -> void:
	_lista_turmas = TemaUI.lista()
	_lista_turmas.item_activated.connect(_on_turma_ativada)
	v.add_child(_lista_turmas)
	v.add_child(TemaUI.rotulo("Duplo clique numa turma para abrir.", "Discreto"))
	_btn_atualizar = TemaUI.botao("Atualizar turmas", _on_btn_atualizar_lista_pressed)
	v.add_child(_btn_atualizar)


func _rotulo_curto(texto: String) -> Label:
	var l := TemaUI.rotulo(texto)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _montar_formulario(v: VBoxContainer) -> void:
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 6)
	v.add_child(grade)

	grade.add_child(_rotulo_curto("Período"))
	_opcao_periodo = OptionButton.new()
	for p in ["Matutino", "Vespertino", "Integral", "Noturno"]:
		_opcao_periodo.add_item(p)
	_opcao_periodo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.add_child(_opcao_periodo)

	grade.add_child(_rotulo_curto("Ano"))
	_campo_ano = SpinBox.new()
	_campo_ano.min_value = 1
	_campo_ano.max_value = 9
	_campo_ano.value = 1
	_campo_ano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.add_child(_campo_ano)

	grade.add_child(_rotulo_curto("Turma"))
	_campo_letra = LineEdit.new()
	_campo_letra.placeholder_text = "A, B ou C"
	_campo_letra.max_length = 2
	_campo_letra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.add_child(_campo_letra)

	_btn_gerar = TemaUI.botao("Gerar código", _on_btn_gerar_codigo_pressed)
	v.add_child(_btn_gerar)

	_display_codigo = TemaUI.rotulo("", "Aviso")
	_display_codigo.custom_minimum_size = Vector2(0, 34)
	v.add_child(_display_codigo)

	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(espaco)

	_btn_salvar = TemaUI.botao("Salvar turma", _on_btn_salvar_turma_pressed, "BotaoPrimario")
	v.add_child(_btn_salvar)


func _on_btn_gerar_codigo_pressed() -> void:
	# Primeira letra do período (M, V, I ou N)
	var inicial_periodo := _opcao_periodo.get_item_text(_opcao_periodo.selected).substr(0, 1).to_upper()
	var ano := str(int(_campo_ano.value))
	var letra := _campo_letra.text.strip_edges().to_upper()

	if letra == "":
		_display_codigo.theme_type_variation = "Aviso"
		_display_codigo.text = "Informe a letra da turma."
		return

	# Identificador aleatório de 3 dígitos para o código ser único
	var hash_unico := str(randi() % 899 + 100)

	# Código final (ex.: M-6A-452)
	codigo_gerado = inicial_periodo + "-" + ano + letra + "-" + hash_unico
	_display_codigo.theme_type_variation = "Codigo"
	_display_codigo.add_theme_font_size_override("font_size", 20)
	_display_codigo.text = codigo_gerado


func _on_btn_salvar_turma_pressed() -> void:
	if codigo_gerado == "":
		_display_codigo.theme_type_variation = "Aviso"
		_display_codigo.text = "Gere o código primeiro."
		return

	_btn_salvar.disabled = true
	var sucesso: bool = await NakamaManager.criar_turmas(codigo_gerado)
	_btn_salvar.disabled = false
	if not is_inside_tree():
		return

	if sucesso:
		_display_codigo.text = "Salva: " + codigo_gerado
		codigo_gerado = ""
		_atualizar_lista_turmas()
	else:
		_display_codigo.theme_type_variation = "Aviso"
		_display_codigo.text = "Erro ao salvar a turma."


func _on_btn_logout_pressed() -> void:
	NakamaManager.fazer_logout()
	Transicao.ir_para("res://scenes/Login/TelaAutenticacao.tscn")


func _on_btn_atualizar_lista_pressed() -> void:
	_atualizar_lista_turmas()


func _atualizar_lista_turmas() -> void:
	_btn_atualizar.disabled = true
	_lista_turmas.clear()
	_lista_turmas.add_item("Carregando turmas...")

	# Vem como {id, nome} por turma
	_turmas_atuais = await NakamaManager.listar_minhas_turmas()
	if not is_inside_tree():
		return

	_lista_turmas.clear()
	if _turmas_atuais.is_empty():
		_lista_turmas.add_item("Nenhuma turma criada ainda.")
		_lista_turmas.set_item_disabled(0, true)
	else:
		for turma in _turmas_atuais:
			_lista_turmas.add_item(turma["nome"])
	_btn_atualizar.disabled = false


func _on_turma_ativada(index: int) -> void:
	if index < 0 or index >= _turmas_atuais.size():
		return
	var turma: Dictionary = _turmas_atuais[index]
	NakamaManager.turma_selecionada_id = turma["id"]
	NakamaManager.turma_selecionada_nome = turma["nome"]
	Transicao.ir_para("res://scenes/Login/TelaTurma.tscn")
