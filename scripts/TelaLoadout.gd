extends Control

## Tela de loadout de magias (mockup "Página X" — Personagem + Disposição das
## peças). Deixa o jogador escolher, PRA CADA FORMA DESBLOQUEADA, qual
## ELEMENTO DESBLOQUEADO equipar nela.
##
## Forma e elemento são eixos independentes (decisão do módulo 2): o aluno
## desbloqueia uma forma na sala das formas e um elemento na sala das cores,
## e pode recombinar os dois livremente aqui — por isso a tela só mostra uma
## linha por forma JÁ DESBLOQUEADA, e cada dropdown só lista elementos JÁ
## DESBLOQUEADOS (nunca os 5x6 = 30 combos inteiros de uma vez).

## Uma linha (forma) da tela: os três controles que a representam.
class _Linha:
	var icone: TextureRect
	var opcoes: OptionButton
	var forma: String

var _linhas: Array = []
var _elementos_desbloqueados: Array[String] = []


func _ready() -> void:
	%btnVoltar.pressed.connect(_on_btn_voltar_pressed)

	var uid := LocalDB.get_user_id_ativo()

	# Garante que o loadout salvo do jogador (se algum) já está aplicado
	# antes de montar a tela, senão ela mostraria o padrão hardcoded.
	SpellLoadout.carregar_equipado(uid)

	_elementos_desbloqueados = LocalDB.listar_elementos_desbloqueados(uid)
	var formas_desbloqueadas := LocalDB.listar_formas_desbloqueadas(uid)

	if formas_desbloqueadas.is_empty() or _elementos_desbloqueados.is_empty():
		%avisoVazio.text = "Você ainda não desbloqueou nenhuma forma ou elemento — vá pra sala de aula!"
		%avisoVazio.visible = true
		return

	%avisoVazio.visible = false
	_montar_linhas(formas_desbloqueadas)
	_atualizar_todos_os_icones()


func _montar_linhas(formas_desbloqueadas: Array) -> void:
	for forma in formas_desbloqueadas:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)

		var icone := TextureRect.new()
		icone.custom_minimum_size = Vector2(48, 48)
		icone.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(icone)

		var nome := Label.new()
		nome.text = forma
		nome.custom_minimum_size = Vector2(90, 0)
		nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		linha.add_child(nome)

		var opcoes := OptionButton.new()
		for elemento in _elementos_desbloqueados:
			opcoes.add_item(elemento)
		linha.add_child(opcoes)

		%listaFormas.add_child(linha)

		var registro := _Linha.new()
		registro.icone = icone
		registro.opcoes = opcoes
		registro.forma = forma
		_linhas.append(registro)

		opcoes.item_selected.connect(_on_elemento_selecionado.bind(registro))


func _atualizar_todos_os_icones() -> void:
	for registro in _linhas:
		var elemento_atual: String = SpellLoadout.equipped.get(registro.forma, "")

		# O elemento equipado pode não estar mais entre os desbloqueados
		# (ex: valor padrão hardcoded de uma forma recém-desbloqueada que
		# ainda não tinha elemento nenhum escolhido) — nesse caso cai pro
		# primeiro elemento desbloqueado disponível, e já corrige/persiste.
		var indice: int = _elementos_desbloqueados.find(elemento_atual)
		if indice == -1:
			indice = 0
			elemento_atual = _elementos_desbloqueados[0]
			SpellLoadout.set_equipped(registro.forma, elemento_atual)

		registro.opcoes.select(indice)
		_atualizar_icone(registro, elemento_atual)


func _atualizar_icone(registro: _Linha, elemento: String) -> void:
	var tipo := SpellLoadout.get_tile_type(registro.forma, elemento)
	registro.icone.texture = tipo.shape_texture
	registro.icone.modulate = tipo.color


func _on_elemento_selecionado(indice: int, registro: _Linha) -> void:
	var elemento: String = _elementos_desbloqueados[indice]
	SpellLoadout.set_equipped(registro.forma, elemento)
	_atualizar_icone(registro, elemento)


func _on_btn_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Login/TelaAluno.tscn")
