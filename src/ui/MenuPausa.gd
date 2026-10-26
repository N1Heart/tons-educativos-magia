extends CanvasLayer

## Autoload "MenuPausa" — menu centralizado que abre com ESC dentro do jogo
## (salas e combate) e o atalho [I] para o inventário de magias.
##
## Opções: Continuar, Magias (inventário), Desistir do combate (só em
## combate), Configurações (volume, mudo, tela cheia), Sair para o menu e
## Sair do jogo. Enquanto está aberto o jogo fica pausado.
##
## Qualquer cena com um método `abandonar()` (hoje o duelos.gd) é tratada como
## combate: sair ou desistir grava a partida como derrota antes de ir embora.

const PREFIXO_CENAS_JOGO := "res://scenes/salas/"
const CENA_INVENTARIO := "res://scenes/Login/TelaLoadout.tscn"
const CENA_MENU_ALUNO := "res://scenes/Login/TelaAluno.tscn"
const ARQUIVO_CONFIG := "user://config.cfg"
const FONTE := 14

var _indicador: Label = null
var _raiz: Control = null
var _caixa: VBoxContainer = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_garantir_acoes()
	_aplicar_config(_ler_config())
	_montar_indicador_sala()


## Aviso discreto no canto: o aluno está numa sala do professor enquanto anda pelo jogo.
func _montar_indicador_sala() -> void:
	_indicador = Label.new()
	_indicador.add_theme_font_size_override("font_size", 10)
	_indicador.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_indicador.add_theme_color_override("font_outline_color", Color.BLACK)
	_indicador.add_theme_constant_override("outline_size", 3)
	_indicador.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_indicador.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_indicador.offset_top = 4
	_indicador.offset_right = -6
	_indicador.visible = false
	add_child(_indicador)
	var relogio := Timer.new()
	relogio.wait_time = 0.5
	relogio.autostart = true
	relogio.timeout.connect(_atualizar_indicador_sala)
	add_child(relogio)


func _atualizar_indicador_sala() -> void:
	var mostrar: bool = LobbyManager.esta_em_sala() and not LobbyManager.sou_professor \
		and _pode_abrir() and not DueloRede.ativo
	_indicador.visible = mostrar
	if mostrar:
		_indicador.text = "Sala %s — aguardando o professor" % LobbyManager.codigo


func _garantir_acoes() -> void:
	if not InputMap.has_action("inventario"):
		InputMap.add_action("inventario")
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_I
		InputMap.action_add_event("inventario", tecla)


func esta_aberto() -> bool:
	return _raiz != null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if esta_aberto():
			fechar()
			get_viewport().set_input_as_handled()
		elif _pode_abrir():
			abrir()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventario") and not esta_aberto() and _pode_abrir() and not _em_combate():
		_abrir_inventario()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ contexto

func _cena() -> Node:
	return get_tree().current_scene


## O menu só existe dentro do jogo (salas/combate), não nas telas de login,
## e não abre por cima de uma aula ou prova em andamento.
func _pode_abrir() -> bool:
	var cena := _cena()
	if cena == null or not cena.scene_file_path.begins_with(PREFIXO_CENAS_JOGO):
		return false
	return not FluxoSala._em_andamento


func _em_combate() -> bool:
	var cena := _cena()
	return cena != null and cena.has_method("abandonar") and Combat.combat_active


# --------------------------------------------------------------- abrir/fechar

func abrir() -> void:
	if esta_aberto():
		return
	get_tree().paused = true
	_montar_painel_principal()


func fechar() -> void:
	if _raiz != null:
		_raiz.queue_free()
		_raiz = null
		_caixa = null
	get_tree().paused = false


func _nova_janela() -> void:
	if _raiz != null:
		_raiz.queue_free()

	_raiz = ColorRect.new()
	_raiz.color = Color(0, 0, 0, 0.55)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)

	var painel := PanelContainer.new()
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	painel.add_child(margem)

	_caixa = VBoxContainer.new()
	_caixa.custom_minimum_size = Vector2(250, 0)
	_caixa.add_theme_constant_override("separation", 6)
	margem.add_child(_caixa)


func _rotulo(texto: String, tamanho: int = FONTE, cor: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	_caixa.add_child(l)
	return l


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", FONTE)
	b.pressed.connect(acao)
	_caixa.add_child(b)
	return b


## Botão que pede confirmação: o primeiro clique troca o texto, o segundo executa.
func _botao_com_confirmacao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", FONTE)
	var armado := [false]
	b.pressed.connect(func():
		if armado[0]:
			acao.call()
		else:
			armado[0] = true
			b.text = "Tem certeza? (clique de novo)")
	_caixa.add_child(b)
	return b


# ------------------------------------------------------------ painel principal

func _montar_painel_principal() -> void:
	_nova_janela()
	var uid := LocalDB.get_user_id_ativo()
	var perfil := LocalDB.carregar_perfil(uid)

	_rotulo("Menu", 20, Color(1.0, 0.85, 0.4))
	if perfil != null and perfil.nome != "":
		_rotulo(perfil.nome, 12)
	if NakamaManager.session != null:
		_rotulo("Conectado ao servidor", 11, Color(0.5, 0.9, 0.5))
	else:
		_rotulo("Sem conexão — progresso salvo neste computador", 11, Color(1.0, 0.75, 0.4))

	var continuar := _botao("Continuar", fechar)
	var inventario := _botao("Magias / Inventário  [I]", _abrir_inventario)
	if DueloRede.ativo:
		inventario.disabled = true
		inventario.text = "Magias (indisponível em grupo)"
	if _em_combate():
		inventario.disabled = true
		inventario.text = "Magias (indisponível em combate)"
		_botao_com_confirmacao("Desistir do combate", _desistir)
	_botao("Configurações", _montar_painel_config)
	_botao_com_confirmacao("Sair para o menu", _sair_para_menu)
	_botao_com_confirmacao("Sair do jogo", _sair_do_jogo)
	continuar.grab_focus()


# ----------------------------------------------------------------- inventário

func _abrir_inventario() -> void:
	var cena := _cena()
	if cena == null:
		return
	# TelaLoadout lê isso no botão Voltar pra reaparecer no mesmo lugar.
	var pedido := {"cena": cena.scene_file_path}
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador is Node2D:
		pedido["posicao"] = (jogador as Node2D).global_position
	Engine.set_meta("voltar_para", pedido)
	fechar()
	get_tree().change_scene_to_file(CENA_INVENTARIO)


# ------------------------------------------------------------------- saídas

func _abandonar_combate_se_houver() -> void:
	var cena := _cena()
	if cena != null and cena.has_method("abandonar"):
		cena.abandonar()


func _desistir() -> void:
	var cena := _cena()
	fechar()
	if cena != null and cena.has_method("desistir"):
		cena.desistir()


func _sair_para_menu() -> void:
	_abandonar_combate_se_houver()
	if LobbyManager.esta_em_sala():
		LobbyManager.sair()  # sai da sala do professor também
	if ArenaDuelos.esta_na_arena():
		ArenaDuelos.sair()
	fechar()
	get_tree().change_scene_to_file(CENA_MENU_ALUNO)


func _sair_do_jogo() -> void:
	_abandonar_combate_se_houver()
	fechar()
	get_tree().quit()


# ------------------------------------------------------------- configurações

func _montar_painel_config() -> void:
	var cfg := _ler_config()
	_nova_janela()
	_rotulo("Configurações", 20, Color(1.0, 0.85, 0.4))

	_rotulo("Volume", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = cfg["volume"]
	_caixa.add_child(slider)

	var mudo := CheckBox.new()
	mudo.text = "Sem som"
	mudo.button_pressed = cfg["mudo"]
	_caixa.add_child(mudo)

	var tela_cheia := CheckBox.new()
	tela_cheia.text = "Tela cheia"
	tela_cheia.button_pressed = cfg["tela_cheia"]
	_caixa.add_child(tela_cheia)

	var atualizar := func(_v = null):
		var novo := {"volume": slider.value, "mudo": mudo.button_pressed, "tela_cheia": tela_cheia.button_pressed}
		_aplicar_config(novo)
		_salvar_config(novo)
	slider.value_changed.connect(atualizar)
	mudo.toggled.connect(atualizar)
	tela_cheia.toggled.connect(atualizar)

	var voltar := _botao("Voltar", _montar_painel_principal)
	voltar.grab_focus()


func _ler_config() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO_CONFIG)  # arquivo ausente = valores padrão
	return {
		"volume": float(cfg.get_value("som", "volume", 1.0)),
		"mudo": bool(cfg.get_value("som", "mudo", false)),
		"tela_cheia": bool(cfg.get_value("video", "tela_cheia", false)),
	}


func _salvar_config(c: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("som", "volume", c["volume"])
	cfg.set_value("som", "mudo", c["mudo"])
	cfg.set_value("video", "tela_cheia", c["tela_cheia"])
	cfg.save(ARQUIVO_CONFIG)


func _aplicar_config(c: Dictionary) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(c["volume"], 0.0001)))
		AudioServer.set_bus_mute(bus, c["mudo"] or c["volume"] <= 0.0)
	if DisplayServer.get_name() != "headless":
		var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if c["tela_cheia"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo:
			DisplayServer.window_set_mode(modo)
