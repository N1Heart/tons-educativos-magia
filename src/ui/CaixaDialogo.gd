class_name CaixaDialogo
extends CanvasLayer

## Caixa de diálogo reutilizável (estilo RPG) para aulas e provas: retrato +
## nome do professor + texto com efeito de digitação, e uma lista de botões
## de escolha para menus e perguntas.
##
## Toda a interface é montada por código (sem .tscn) e a API é assíncrona:
##
##   var d := CaixaDialogo.new()
##   add_child(d)
##   d.abrir("Mestre das Formas", retrato_ou_null)
##   await d.falar("Olá, aprendiz!")                      # espera o jogador avançar
##   var i: int = await d.escolher("Qual forma?", ["Triângulo", "Círculo"])
##   d.fechar()
##
## Fala longa é dividida automaticamente em páginas (o jogo roda em 640x360,
## a caixa é pequena). Avançar: tecla E, Enter/Espaço ou clique do mouse;
## avançar durante a digitação completa o texto na hora.

## Máximo de caracteres por página de fala (~3 linhas na caixa).
const MAX_CHARS_PAGINA := 240
const SEGUNDOS_POR_CARACTERE := 0.015
const FONTE := 14

signal _avancou
signal _escolheu(indice: int)

var _painel: PanelContainer
var _retrato_fundo: ColorRect
var _retrato_textura: TextureRect
var _retrato_inicial: Label
var _nome: Label
var _texto: RichTextLabel
var _opcoes: VBoxContainer
var _dica: Label

var _tween: Tween
var _digitando := false
var _aguardando_avanco := false


## A ação "interagir" (tecla E) é registrada em código, igual no jogador e na porta.
static func garantir_acao_interagir() -> void:
	if not InputMap.has_action("interagir"):
		InputMap.add_action("interagir")
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		InputMap.action_add_event("interagir", tecla)


func _init() -> void:
	layer = 50
	garantir_acao_interagir()
	_montar()


func _montar() -> void:
	# Escurece o jogo e bloqueia cliques que cairiam no que está atrás.
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.35)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	# Painel colado embaixo; altura = conteúdo (cresce pra cima).
	_painel = PanelContainer.new()
	_painel.anchor_left = 0.0
	_painel.anchor_right = 1.0
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_left = 10
	_painel.offset_right = -10
	_painel.offset_top = -8
	_painel.offset_bottom = -8
	_painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_painel)

	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 8)
	_painel.add_child(margem)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	margem.add_child(linha)

	# --- Retrato (textura real, ou um placeholder colorido com a inicial) ---
	var moldura := Control.new()
	moldura.custom_minimum_size = Vector2(72, 72)
	moldura.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha.add_child(moldura)

	_retrato_fundo = ColorRect.new()
	_retrato_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	moldura.add_child(_retrato_fundo)

	_retrato_inicial = Label.new()
	_retrato_inicial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_retrato_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retrato_inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_retrato_inicial.add_theme_font_size_override("font_size", 36)
	moldura.add_child(_retrato_inicial)

	_retrato_textura = TextureRect.new()
	_retrato_textura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_retrato_textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.add_child(_retrato_textura)

	# --- Coluna de texto ---
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 4)
	linha.add_child(coluna)

	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", FONTE)
	_nome.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	coluna.add_child(_nome)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.custom_minimum_size = Vector2(0, 54)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_size_override("normal_font_size", FONTE)
	coluna.add_child(_texto)

	_opcoes = VBoxContainer.new()
	_opcoes.add_theme_constant_override("separation", 3)
	coluna.add_child(_opcoes)

	_dica = Label.new()
	_dica.text = "[E] continuar"
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.add_theme_font_size_override("font_size", 10)
	_dica.modulate = Color(1, 1, 1, 0.6)
	coluna.add_child(_dica)


## Define quem está falando. 'retrato' null = placeholder (cor + inicial).
func abrir(nome: String, retrato: Texture2D = null) -> void:
	_nome.text = nome
	if retrato != null:
		_retrato_textura.texture = retrato
		_retrato_textura.visible = true
		_retrato_fundo.visible = false
		_retrato_inicial.visible = false
	else:
		var partes := nome.split(" ", false)
		var inicial := partes[partes.size() - 1].substr(0, 1).to_upper() if partes.size() > 0 else "?"
		_retrato_fundo.color = Color.from_hsv(float(abs(nome.hash()) % 360) / 360.0, 0.45, 0.65)
		_retrato_inicial.text = inicial
		_retrato_textura.visible = false
		_retrato_fundo.visible = true
		_retrato_inicial.visible = true


func fechar() -> void:
	if _tween:
		_tween.kill()
	queue_free()


## Mostra uma fala (dividida em páginas se for longa) e espera o jogador avançar
## em cada página.
func falar(texto: String) -> void:
	_limpar_opcoes()
	_dica.visible = true
	for pagina in _paginar(texto):
		await _mostrar_pagina(pagina)


## Mostra 'pergunta' + botões e devolve o índice do botão escolhido.
func escolher(pergunta: String, opcoes: Array[String]) -> int:
	_limpar_opcoes()
	_dica.visible = false
	_texto.text = _escapar(pergunta)
	_texto.visible_ratio = 1.0

	for i in opcoes.size():
		var botao := Button.new()
		botao.text = opcoes[i]
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.custom_minimum_size = Vector2(0, 22)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.add_theme_font_size_override("font_size", FONTE)
		botao.pressed.connect(func(): _escolheu.emit(i))
		_opcoes.add_child(botao)

	if _opcoes.get_child_count() > 0:
		_opcoes.get_child(0).grab_focus()

	var indice: int = await _escolheu
	_limpar_opcoes()
	return indice


func _mostrar_pagina(pagina: String) -> void:
	_texto.text = _escapar(pagina)
	_texto.visible_ratio = 0.0
	_digitando = true
	_aguardando_avanco = true

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_texto, "visible_ratio", 1.0, maxf(0.15, pagina.length() * SEGUNDOS_POR_CARACTERE))
	_tween.finished.connect(func(): _digitando = false)

	await _avancou
	_aguardando_avanco = false


func _input(event: InputEvent) -> void:
	if not _aguardando_avanco:
		return  # em modo de escolha, quem trata o teclado são os próprios botões

	var confirmou := event.is_action_pressed("interagir") or event.is_action_pressed("ui_accept")
	if not confirmou and event is InputEventMouseButton:
		confirmou = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not confirmou:
		return

	get_viewport().set_input_as_handled()
	if _digitando:
		if _tween:
			_tween.kill()
		_texto.visible_ratio = 1.0
		_digitando = false
	else:
		_avancou.emit()


func _limpar_opcoes() -> void:
	for filho in _opcoes.get_children():
		_opcoes.remove_child(filho)
		filho.queue_free()


## "[" em texto de conteúdo não pode virar tag BBCode.
func _escapar(texto: String) -> String:
	return texto.replace("[", "[lb]")


## Divide em páginas de até MAX_CHARS_PAGINA, quebrando preferencialmente no fim de frase.
func _paginar(texto: String) -> Array[String]:
	var paginas: Array[String] = []
	texto = texto.strip_edges()
	if texto.length() <= MAX_CHARS_PAGINA:
		paginas.append(texto)
		return paginas

	var frases: Array[String] = []
	var atual := ""
	for i in texto.length():
		atual += texto[i]
		var fim_de_frase := texto[i] in [".", "!", "?"] and (i + 1 >= texto.length() or texto[i + 1] == " ")
		if fim_de_frase:
			frases.append(atual.strip_edges())
			atual = ""
	if atual.strip_edges() != "":
		frases.append(atual.strip_edges())

	var pagina := ""
	for frase in frases:
		if frase.length() > MAX_CHARS_PAGINA:
			if pagina != "":
				paginas.append(pagina)
				pagina = ""
			paginas.append_array(_quebrar_por_palavras(frase))
		elif pagina == "":
			pagina = frase
		elif pagina.length() + 1 + frase.length() <= MAX_CHARS_PAGINA:
			pagina += " " + frase
		else:
			paginas.append(pagina)
			pagina = frase
	if pagina != "":
		paginas.append(pagina)
	return paginas


func _quebrar_por_palavras(frase: String) -> Array[String]:
	var partes: Array[String] = []
	var atual := ""
	for palavra in frase.split(" ", false):
		if atual != "" and atual.length() + 1 + palavra.length() > MAX_CHARS_PAGINA:
			partes.append(atual)
			atual = palavra
		else:
			atual = palavra if atual == "" else atual + " " + palavra
	if atual != "":
		partes.append(atual)
	return partes
