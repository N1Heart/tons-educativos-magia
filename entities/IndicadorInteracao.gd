extends Node

## Balão "[E] ação" que aparece sobre um objeto interativo quando o jogador
## está ao alcance. Cada objeto (porta, cadeira, professor) cria o seu e liga/
## desliga com definir_ativo(). Mostra o nome do objeto e o que o E faz:
##
##     Sala de Formas
##     [E] Entrar
##
## Fica sempre com o tamanho da tela (compensa o zoom da câmera) e some
## enquanto o jogador está travado num diálogo.
##
## Este nó é um Node comum (não um CanvasItem) de propósito: o balão vive num
## Node2D interno que NÃO herda a visibilidade do objeto, então aparece mesmo
## quando o dono é um marcador provisório escondido (como as cadeiras).

const TemaUIRef := preload("res://src/ui/TemaUI.gd")

var _ativo := false
var _altura := 40.0
var _raiz: Node2D
var _painel: PanelContainer
var _titulo: Label
var _acao: Label
var _opacidade := 0.0
var _tempo := 0.0


func _init() -> void:
	_raiz = Node2D.new()
	_raiz.top_level = true  # não herda escala/rotação do objeto (os NPCs têm escala 0.7)
	_raiz.z_index = 100
	_raiz.visible = false
	add_child(_raiz)


func _ready() -> void:
	_montar()


## titulo: nome do objeto. acao: verbo da tecla ("Entrar"). altura: distância
## acima da origem do objeto, em pixels do mundo.
func configurar(titulo: String, acao: String, altura: float = 40.0) -> void:
	_altura = altura
	if _titulo == null:
		_montar()
	_titulo.text = titulo
	_titulo.visible = titulo != ""
	_acao.text = acao


func definir_ativo(ativo: bool) -> void:
	_ativo = ativo
	if ativo:
		_raiz.visible = true


func _montar() -> void:
	if _painel != null:
		return
	_painel = PanelContainer.new()
	_painel.theme = TemaUIRef.tema()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(TemaUIRef.FUNDO, 0.92)
	estilo.border_color = TemaUIRef.DESTAQUE
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 7
	estilo.content_margin_right = 7
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	_painel.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 1)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 10)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_titulo)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 4)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(linha)

	var tecla := PanelContainer.new()
	var estilo_tecla := StyleBoxFlat.new()
	estilo_tecla.bg_color = TemaUIRef.OURO
	estilo_tecla.set_corner_radius_all(3)
	estilo_tecla.content_margin_left = 4
	estilo_tecla.content_margin_right = 4
	estilo_tecla.content_margin_top = 0
	estilo_tecla.content_margin_bottom = 0
	tecla.add_theme_stylebox_override("panel", estilo_tecla)
	tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letra := Label.new()
	letra.text = _nome_da_tecla()
	letra.add_theme_font_size_override("font_size", 10)
	letra.add_theme_color_override("font_color", TemaUIRef.FUNDO)
	tecla.add_child(letra)
	linha.add_child(tecla)

	_acao = Label.new()
	_acao.add_theme_font_size_override("font_size", 10)
	_acao.add_theme_color_override("font_color", TemaUIRef.OURO)
	linha.add_child(_acao)

	# Centraliza o balão na horizontal, com a base encostada na origem.
	_painel.resized.connect(func():
		_painel.position = Vector2(-_painel.size.x / 2.0, -_painel.size.y))
	_raiz.modulate.a = 0.0


## Nome da tecla da ação "interagir" (E por padrão).
func _nome_da_tecla() -> String:
	if InputMap.has_action("interagir"):
		for ev in InputMap.action_get_events("interagir"):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var cod: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				return OS.get_keycode_string(cod)
	return "E"


func _process(delta: float) -> void:
	var dono := get_parent() as Node2D
	if dono == null:
		return

	# Trava durante diálogos (o jogador está com controle_ativo = false).
	var mostrar := _ativo
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador != null and jogador.get("controle_ativo") == false:
		mostrar = false

	_opacidade = move_toward(_opacidade, 1.0 if mostrar else 0.0, delta * 8.0)
	_raiz.modulate.a = _opacidade
	if _opacidade <= 0.0 and not mostrar:
		_raiz.visible = false
		return

	_tempo += delta
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom.x if cam != null else 1.0
	_raiz.scale = Vector2.ONE / zoom
	var balanco := sin(_tempo * 4.0) * 1.5
	_raiz.global_position = dono.global_position + Vector2(0, -_altura + balanco)
