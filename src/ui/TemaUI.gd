class_name TemaUI
extends RefCounted

## Tema visual único das telas de gestão (professor, turmas, sala, arena,
## loadout). Tudo é montado por código: paleta, estilos de botão/lista/campo e
## alguns blocos prontos (barra de título, painel, cartão de número). Assim as
## telas ficam iguais entre si e qualquer ajuste de cor se faz num lugar só.
##
## Uso típico, no _ready() de uma tela (Control em tela cheia):
##   var t := TemaUI.preparar(self, "Título", "‹ Voltar", _voltar)
##   var corpo: Control = t["corpo"]
##   ...adiciona painéis em 'corpo'...

# --- Paleta ---------------------------------------------------------------
const FUNDO := Color("14162b")
const FUNDO_BARRA := Color("0f1122")
const PAINEL := Color("1e2140")
const PAINEL_CLARO := Color("272b52")
const BORDA := Color("343a6b")
const TEXTO := Color("e8eaf6")
const TEXTO_SUAVE := Color("9aa0c8")
const DESTAQUE := Color("7c5cff")
const DESTAQUE_HOVER := Color("957bff")
const DESTAQUE_PRESSIONADO := Color("6347e0")
const OURO := Color("ffd479")
const CIANO := Color("7fdcff")
const AVISO := Color("ffb454")
const PERIGO := Color("e5484d")
const SUCESSO := Color("4cc38a")

const TAMANHO_TEXTO := 13
const MARGEM_TELA := 12
const ALTURA_BOTAO := 28

static var _tema: Theme = null


## Tema compartilhado (criado uma vez).
static func tema() -> Theme:
	if _tema == null:
		_tema = _criar_tema()
	return _tema


static func _caixa(cor: Color, borda: Color = Color(0, 0, 0, 0), raio: int = 6,
		margem_h: int = 10, margem_v: int = 5, largura_borda: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(largura_borda if borda.a > 0.0 else 0)
	s.set_corner_radius_all(raio)
	s.content_margin_left = margem_h
	s.content_margin_right = margem_h
	s.content_margin_top = margem_v
	s.content_margin_bottom = margem_v
	return s


static func _criar_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = TAMANHO_TEXTO

	# Label
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	# Botão padrão
	t.set_stylebox("normal", "Button", _caixa(PAINEL_CLARO, BORDA))
	t.set_stylebox("hover", "Button", _caixa(Color("31366a"), DESTAQUE))
	t.set_stylebox("pressed", "Button", _caixa(Color("20244a"), DESTAQUE))
	t.set_stylebox("disabled", "Button", _caixa(Color("1a1d38"), Color("262a50")))
	t.set_stylebox("focus", "Button", _caixa(Color(0, 0, 0, 0), DESTAQUE_HOVER))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5d6390"))
	t.set_constant("h_separation", "Button", 6)

	# Botão primário (ação principal da tela)
	t.set_type_variation("BotaoPrimario", "Button")
	t.set_stylebox("normal", "BotaoPrimario", _caixa(DESTAQUE, DESTAQUE_HOVER))
	t.set_stylebox("hover", "BotaoPrimario", _caixa(DESTAQUE_HOVER, Color.WHITE))
	t.set_stylebox("pressed", "BotaoPrimario", _caixa(DESTAQUE_PRESSIONADO, DESTAQUE_HOVER))
	t.set_stylebox("disabled", "BotaoPrimario", _caixa(Color("2c2a55"), Color("38366a")))
	t.set_color("font_color", "BotaoPrimario", Color.WHITE)
	t.set_color("font_disabled_color", "BotaoPrimario", Color("6d6a9c"))

	# Botão de ação destrutiva
	t.set_type_variation("BotaoPerigo", "Button")
	t.set_stylebox("normal", "BotaoPerigo", _caixa(Color("3a1d2c"), PERIGO))
	t.set_stylebox("hover", "BotaoPerigo", _caixa(Color("55222f"), Color("ff6b70")))
	t.set_stylebox("pressed", "BotaoPerigo", _caixa(Color("2a1420"), PERIGO))
	t.set_stylebox("disabled", "BotaoPerigo", _caixa(Color("241822"), Color("3a2a38")))
	t.set_color("font_color", "BotaoPerigo", Color("ffb3b6"))
	t.set_color("font_hover_color", "BotaoPerigo", Color.WHITE)

	# Botão da barra de título (discreto)
	t.set_type_variation("BotaoBarra", "Button")
	t.set_stylebox("normal", "BotaoBarra", _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "BotaoBarra", _caixa(PAINEL_CLARO, BORDA))
	t.set_stylebox("pressed", "BotaoBarra", _caixa(PAINEL, BORDA))
	t.set_color("font_color", "BotaoBarra", TEXTO_SUAVE)
	t.set_color("font_hover_color", "BotaoBarra", Color.WHITE)

	# Campos de texto / número
	t.set_stylebox("normal", "LineEdit", _caixa(Color("12142a"), BORDA))
	t.set_stylebox("focus", "LineEdit", _caixa(Color("12142a"), DESTAQUE))
	t.set_stylebox("read_only", "LineEdit", _caixa(Color("181a33"), BORDA))
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", Color("5d6390"))
	t.set_color("caret_color", "LineEdit", DESTAQUE_HOVER)
	t.set_color("selection_color", "LineEdit", Color(DESTAQUE, 0.5))

	# Lista
	t.set_stylebox("panel", "ItemList", _caixa(Color("12142a"), BORDA, 6, 4, 4))
	t.set_stylebox("focus", "ItemList", _caixa(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	t.set_stylebox("selected", "ItemList", _caixa(Color(DESTAQUE, 0.55), Color(0, 0, 0, 0), 4))
	t.set_stylebox("selected_focus", "ItemList", _caixa(Color(DESTAQUE, 0.7), Color(0, 0, 0, 0), 4))
	t.set_stylebox("hovered", "ItemList", _caixa(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 4))
	t.set_color("font_color", "ItemList", TEXTO)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_hovered_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 5)
	t.set_constant("h_separation", "ItemList", 6)

	# Caixa de seleção (OptionButton) e menu aberto
	t.set_stylebox("normal", "OptionButton", _caixa(Color("12142a"), BORDA))
	t.set_stylebox("hover", "OptionButton", _caixa(Color("181b38"), DESTAQUE))
	t.set_stylebox("pressed", "OptionButton", _caixa(Color("181b38"), DESTAQUE))
	t.set_stylebox("focus", "OptionButton", _caixa(Color(0, 0, 0, 0), DESTAQUE_HOVER))
	t.set_color("font_color", "OptionButton", TEXTO)
	t.set_stylebox("panel", "PopupMenu", _caixa(PAINEL, DESTAQUE, 6, 4, 4))
	t.set_stylebox("hover", "PopupMenu", _caixa(Color(DESTAQUE, 0.55), Color(0, 0, 0, 0), 4))
	t.set_color("font_color", "PopupMenu", TEXTO)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Painéis
	t.set_stylebox("panel", "PanelContainer", _caixa(PAINEL, BORDA, 8, 0, 0))
	t.set_type_variation("Barra", "PanelContainer")
	t.set_stylebox("panel", "Barra", _caixa(FUNDO_BARRA, BORDA, 8, 8, 4))
	t.set_type_variation("Cartao", "PanelContainer")
	t.set_stylebox("panel", "Cartao", _caixa(PAINEL_CLARO, BORDA, 6, 8, 6))
	t.set_type_variation("Alerta", "PanelContainer")
	t.set_stylebox("panel", "Alerta", _caixa(Color("3a2a1a"), AVISO, 6, 8, 6))

	t.set_stylebox("separator", "HSeparator", _caixa(BORDA, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 8)

	# Variações de rótulo
	t.set_type_variation("Titulo", "Label")
	t.set_font_size("font_size", "Titulo", 17)
	t.set_color("font_color", "Titulo", OURO)
	t.set_type_variation("Subtitulo", "Label")
	t.set_font_size("font_size", "Subtitulo", 12)
	t.set_color("font_color", "Subtitulo", TEXTO_SUAVE)
	t.set_type_variation("Discreto", "Label")
	t.set_font_size("font_size", "Discreto", 11)
	t.set_color("font_color", "Discreto", TEXTO_SUAVE)
	t.set_type_variation("Aviso", "Label")
	t.set_color("font_color", "Aviso", AVISO)
	t.set_type_variation("Codigo", "Label")
	t.set_font_size("font_size", "Codigo", 28)
	t.set_color("font_color", "Codigo", CIANO)
	t.set_type_variation("Numero", "Label")
	t.set_font_size("font_size", "Numero", 20)
	t.set_color("font_color", "Numero", Color.WHITE)
	return t


# --- Blocos prontos --------------------------------------------------------

static func rotulo(texto: String, variacao: String = "") -> Label:
	var l := Label.new()
	l.text = texto
	if variacao != "":
		l.theme_type_variation = variacao
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func botao(texto: String, acao: Callable = Callable(), variacao: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
	if variacao != "":
		b.theme_type_variation = variacao
	if acao.is_valid():
		b.pressed.connect(acao)
	return b


## Painel com título opcional. Devolve o PanelContainer; o conteúdo vai em
## 'conteudo(painel)' (um VBoxContainer já com margens).
static func painel(titulo: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var m := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 10)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	p.set_meta("conteudo", v)
	if titulo != "":
		v.add_child(rotulo(titulo, "Subtitulo"))
	return p


static func conteudo(p: PanelContainer) -> VBoxContainer:
	return p.get_meta("conteudo")


## Cartão de estatística: número grande em cima, descrição pequena embaixo.
## Devolve o cartão; o rótulo do número fica em meta "valor".
static func cartao_numero(descricao: String, valor: String = "-") -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = "Cartao"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	c.add_child(v)
	var n := rotulo(valor, "Numero")
	v.add_child(n)
	v.add_child(rotulo(descricao, "Discreto"))
	c.set_meta("valor", n)
	return c


## Prepara uma tela em tela cheia: aplica o tema, pinta o fundo e cria a barra
## de título (voltar à esquerda, título no meio, ação opcional à direita).
## Devolve {corpo, titulo, voltar, acao}: 'corpo' é onde a tela monta o conteúdo.
static func preparar(raiz: Control, titulo: String, texto_voltar: String = "",
		ao_voltar: Callable = Callable(), texto_acao: String = "",
		ao_acao: Callable = Callable()) -> Dictionary:
	raiz.theme = tema()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fundo := ColorRect.new()
	fundo.color = FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, MARGEM_TELA)
	raiz.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	margem.add_child(coluna)

	var barra := PanelContainer.new()
	barra.theme_type_variation = "Barra"
	coluna.add_child(barra)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	barra.add_child(linha)

	var btn_voltar := botao(texto_voltar, ao_voltar, "BotaoBarra")
	btn_voltar.custom_minimum_size = Vector2(96, ALTURA_BOTAO)
	btn_voltar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if texto_voltar != "":
		linha.add_child(btn_voltar)

	var rot := rotulo(titulo, "Titulo")
	rot.autowrap_mode = TextServer.AUTOWRAP_OFF
	rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if texto_voltar == "" else HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(rot)

	var btn_acao := botao(texto_acao, ao_acao, "BotaoBarra")
	btn_acao.custom_minimum_size = Vector2(96, ALTURA_BOTAO)
	btn_acao.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if texto_acao == "":
		if texto_voltar != "":
			# Espaço do mesmo tamanho do botão de voltar para centralizar o título.
			btn_acao.text = ""
			btn_acao.disabled = true
			btn_acao.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_acao.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
			linha.add_child(btn_acao)
	else:
		linha.add_child(btn_acao)

	var corpo := MarginContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(corpo)

	return {"corpo": corpo, "titulo": rot, "voltar": btn_voltar, "acao": btn_acao}


## Duas colunas: esquerda larga (lista) e direita estreita (ações).
## Devolve [PanelContainer esquerdo, PanelContainer direito] já dentro de 'corpo'.
static func duas_colunas(corpo: Control, titulo_esq: String, titulo_dir: String,
		largura_dir: int = 230) -> Array:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	corpo.add_child(linha)
	var esq := painel(titulo_esq)
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(esq)
	var dir := painel(titulo_dir)
	dir.custom_minimum_size = Vector2(largura_dir, 0)
	linha.add_child(dir)
	return [esq, dir]


## Lista dentro de um painel: expande na vertical.
static func lista() -> ItemList:
	var l := ItemList.new()
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.select_mode = ItemList.SELECT_SINGLE
	l.allow_search = false
	return l


## Retrato do personagem do jogador (animação "idle" da cena do mapa) dentro de
## um cartão quadrado. Substitui os quadrados cinzas de placeholder.
static func retrato_personagem(lado: int = 110) -> PanelContainer:
	var cartao := PanelContainer.new()
	cartao.theme_type_variation = "Cartao"
	cartao.custom_minimum_size = Vector2(lado, lado)
	var area := Control.new()
	area.clip_contents = true
	cartao.add_child(area)

	var cena := load("res://entities/teste.tscn") as PackedScene
	if cena == null:
		return cartao
	var modelo := cena.instantiate()
	var origem := modelo.find_children("*", "AnimatedSprite2D", true, false)
	var frames: SpriteFrames = null
	if not origem.is_empty():
		frames = (origem[0] as AnimatedSprite2D).sprite_frames
	modelo.free()
	if frames == null or not frames.has_animation("idle"):
		return cartao

	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames.duplicate()
	spr.animation = "idle"
	spr.play("idle")
	area.add_child(spr)
	var tex := frames.get_frame_texture("idle", 0)
	var altura := tex.get_height() if tex != null else 32
	spr.scale = Vector2.ONE * maxf(1.0, floorf(float(lado - 20) / float(altura)))
	var centrar := func(): spr.position = area.size * 0.5
	area.resized.connect(centrar)
	centrar.call()
	return cartao
