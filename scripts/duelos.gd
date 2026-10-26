extends Node2D

## Tela de combate visual — junta o tabuleiro (grid.gd) com os dois lados
## (jogador/oponente), cada um mostrado como uma fileira de ícones-forma com
## barra de HP, atualizada via Combat.units_changed.
##
## Por enquanto o time do jogador e o encontro inimigo são fixos aqui
## (@export), só pra validar a tela. Quando a exploração/inventário existir,
## isso passa a vir de fora (roster do jogador salvo + dados do encontro).

@onready var board = $Combate/grid
@onready var player_units_row: UnitRoster = $HUD/PlayerPanel/PlayerUnits
@onready var enemy_units_row: UnitRoster = $HUD/EnemyPanel/EnemyUnits
@onready var tics_label: Label = $HUD/TicsLabel
@onready var turn_label: Label = $HUD/TurnLabel
@onready var log_label: Label = $HUD/LogLabel

## Formas que o jogador leva pra esse combate (por enquanto, sempre as 5;
## no futuro isso vem do que o jogador já desbloqueou em exploração).
@export var player_shapes: Array[String] = []
@export var player_hp_each: int = 30

## Encontro de teste — troque livremente pra simular oponentes diferentes.
## HP base no nível 1 (sobe 25% por nível). Com 2 Tics por turno o jogador age
## menos que antes, então o valor padrão é bem menor que o antigo 20.
@export var enemy_hp_each: int = 10

## Quantas jogadas (trocas de peças) o jogador faz por turno. Era 3; o
## encadeamento de ações ficava longo e o roxo (Tempo) soma mais por cima.
@export var tics_por_turno: int = 2

## Cada nível de dificuldade acima do 1 aumenta o HP dos inimigos nessa fração
## (ajuste automático, sem configuração do professor — ver LocalDB.proximo_nivel_dificuldade).
const HP_POR_NIVEL := 0.25
## Uma pausa maior que isso (aluno distraído/ausente) não conta inteira na
## média de reação, senão uma única pausa distorce o alerta do professor.
const LATENCIA_MAX_REGISTRADA := 60.0

## Pra onde o jogador volta quando o combate termina, e onde ele reaparece
## (em frente à porta dos duelos, não no começo da sala).
const CENA_RETORNO := "res://scenes/salas/fundosDoCastelo.tscn"
const SPAWN_RETORNO := Vector2(405, 330)

## Multiplayer: HP do time cresce com o tamanho da equipe (coop) e o monstro
## ganha HP proporcional ao número de jogadores.
const HP_TIME_POR_MEMBRO := 0.25
const HP_PVP := 30
## Se o jogador demorar mais que isso, o turno dele termina sozinho (a
## partida em grupo não pode ficar esperando um aluno parado).
const TEMPO_MAX_TURNO := 90.0
const CENA_LOBBY := "res://scenes/Login/TelaLobby.tscn"
const CENA_ARENA := "res://scenes/Login/TelaArena.tscn"
const CENA_MENU_ALUNO := "res://scenes/Login/TelaAluno.tscn"

var log_lines: Array[String] = []
var _botao_voltar: Button
var _timer_turno: Timer = null
var _em_rede := false   # esta partida é PvE cooperativo ou PvP (ver DueloRede)

# --- Métricas da partida (gravadas em LocalDB ao fim do combate) ---
var _nivel: int = 1
var _inicio_ms: int = 0
var _pronto_ms: int = -1  # quando o tabuleiro ficou livre pra o jogador jogar
var _latencias: Array[float] = []
var _pontuacao: int = 0
var _registrada := false

# --- Lutadores no retrato (criatura do PvE e personagem do jogador) ---
var _monstro: Monster = null
var _vis_monstro: CombatSprite = null
var _vis_jogador: CombatSprite = null            # o meu personagem
var _vis_time: Array[CombatSprite] = []          # todos os do meu time (inclui o meu)
var _vis_por_nome := {}                          # nome do jogador -> CombatSprite (equipe)
const COR_OPONENTE := Color(1.0, 0.7, 0.75)
const CORES_COLEGAS := [Color(0.75, 1.0, 0.8), Color(1.0, 0.9, 0.7), Color(0.8, 0.85, 1.0)]
var _hp_inimigo_antes := -1
var _hp_time_antes := -1


func _ready() -> void:
	if not SpellLoadout.pode_entrar_em_combate(LocalDB.get_user_id_ativo()):
		push_warning("duelos: " + SpellLoadout.motivo_bloqueio_combate(LocalDB.get_user_id_ativo()))
		get_tree().change_scene_to_file.call_deferred("res://scenes/salas/fundosDoCastelo.tscn")
		return
		
	_em_rede = DueloRede.ativo
	Combat.modo_rede = DueloRede.modo_combate if _em_rede else ""
	Combat.bind_board(board)

	Combat.units_changed.connect(_on_units_changed)
	Combat.tics_changed.connect(_on_tics_changed)
	Combat.turn_started.connect(_on_turn_started)
	Combat.log_message.connect(_on_log_message)
	Combat.combat_ended.connect(_on_combat_ended)

	var player_types: Array[TileType] = []
	var formas: Array[String] = player_shapes if not player_shapes.is_empty() \
		else SpellLoadout.formas_disponiveis(LocalDB.get_user_id_ativo())
	if _em_rede and not DueloRede.formas_equipe.is_empty():
		formas = DueloRede.formas_equipe.duplicate()
	for shape_name in formas:
		player_types.append(SpellLoadout.get_equipped_type(shape_name))

	# Encontro de teste com quantidade variável (3 formas, não 5) — troque
	# aqui por dados reais de encontro quando isso vier da exploração.
	var enemy_types: Array[TileType] = [
		SpellLoadout.get_tile_type("Triangulo", "Fogo"),
		SpellLoadout.get_tile_type("Pentagono", "Terra"),
		SpellLoadout.get_tile_type("Circulo", "Agua"),
	]

	# Dificuldade automática: nível sai do histórico; sobe o HP dos inimigos.
	var hp_time := player_hp_each
	var hp_inimigo: int
	if _em_rede and DueloRede.modo_combate == "pvp":
		enemy_types = DueloRede.tipos_adversario.duplicate()
		hp_time = HP_PVP
		hp_inimigo = HP_PVP
		_nivel = 0
	elif _em_rede:
		var n := DueloRede.membros.size()
		_nivel = DueloRede.nivel_equipe
		hp_time = int(round(player_hp_each * (1.0 + HP_TIME_POR_MEMBRO * (n - 1))))
		hp_inimigo = int(round(enemy_hp_each * (1.0 + HP_POR_NIVEL * (_nivel - 1)) * n))
	else:
		_nivel = LocalDB.proximo_nivel_dificuldade(LocalDB.get_user_id_ativo())
		hp_inimigo = int(round(enemy_hp_each * (1.0 + HP_POR_NIVEL * (_nivel - 1))))

	board.player_moved.connect(_on_player_moved)
	board.board_idle.connect(_on_board_idle)
	board.spell_matched.connect(_on_spell_matched)
	_inicio_ms = Time.get_ticks_msec()

	if _em_rede:
		_preparar_rede()
	if _em_rede and DueloRede.modo_combate == "pvp":
		_montar_oponente()
	else:
		_montar_monstro()
	_montar_jogador()

	Combat.start_combat(player_types, hp_time, enemy_types, hp_inimigo, tics_por_turno)
	if _em_rede:
		_iniciar_rede()
	else:
		_on_log_message("Dificuldade: nível %d" % _nivel)


# ------------------------------------------------------------- multiplayer

func _preparar_rede() -> void:
	Combat.turno_rede_encerrado.connect(_on_turno_rede_encerrado)
	DueloRede.turno_recebido.connect(_on_turno_recebido)
	if DueloRede.modo_combate == "pvp":
		Combat.pvp_anfitriao = DueloRede.sou_anfitriao()
		Combat.feiticos_pvp_prontos.connect(_on_feiticos_pvp_prontos)
		DueloRede.feiticos_recebidos.connect(_tentar_resolver_pvp)
	_timer_turno = Timer.new()
	_timer_turno.one_shot = true
	_timer_turno.wait_time = TEMPO_MAX_TURNO
	_timer_turno.timeout.connect(_on_tempo_turno_esgotado)
	add_child(_timer_turno)
	DueloRede.membro_saiu.connect(_on_membro_saiu)
	DueloRede.atividade_encerrada.connect(_on_atividade_encerrada)
	DueloRede.sala_perdida.connect(_on_sala_perdida)

	var painel_inimigo := $HUD/EnemyPanel/NameLabel as Label
	var painel_time := $HUD/PlayerPanel/NameLabel as Label
	if DueloRede.modo_combate == "pvp":
		painel_inimigo.text = DueloRede.nome_do_adversario()
		painel_time.text = "Você"
	else:
		var nomes: Array[String] = []
		for m in DueloRede.membros:
			nomes.append(str(m["nome"]))
		painel_inimigo.text = "Monstro"  # trocado pelo nome da criatura em _montar_monstro
		painel_time.text = "Equipe: " + ", ".join(nomes)


## Depois do start_combat: quem não começa fica esperando a vez.
func _iniciar_rede() -> void:
	if not DueloRede.meu_turno():
		Combat.aguardar_turno_rede()
	_atualizar_rotulo_turno()
	_enviar_estado("")


func _atualizar_rotulo_turno() -> void:
	if not _em_rede or not Combat.combat_active:
		return
	if Combat.is_player_turn:
		turn_label.text = "Seu turno"
	elif DueloRede.modo_combate == "pvp":
		turn_label.text = "Aguardando %s..." % DueloRede.nome_do_adversario()
	elif DueloRede.turno_idx == DueloRede.meu_indice:
		turn_label.text = "Resolvendo seu turno..."
	else:
		turn_label.text = "Vez de %s..." % DueloRede.nome_de_quem_joga()


## Passou o tempo do turno: encerra sozinho (se o tabuleiro ainda estiver
## animando, o fim da cascata encerra, pois os Tics já foram zerados).
func _on_tempo_turno_esgotado() -> void:
	if not Combat.combat_active or not Combat.is_player_turn:
		return
	Combat.tics_remaining = 0
	Combat.tics_changed.emit(0, Combat.tics_max)
	if board.can_swipe:
		Combat.end_player_turn()


## PvP: meu turno acabou. Manda meus feitiços; o anfitrião resolve a rodada.
func _on_feiticos_pvp_prontos(lista: Array) -> void:
	DueloRede.enviar_feiticos(lista)
	_atualizar_rotulo_turno()
	_tentar_resolver_pvp()


## Anfitrião: só resolve quando os dois lados já mandaram os feitiços.
func _tentar_resolver_pvp() -> void:
	if Combat.combat_active and DueloRede.pvp_pronto_para_resolver():
		turn_label.text = "Resolvendo a rodada..."
		Combat.resolver_rodada_pvp(DueloRede.consumir_lista_oponente())


## Anfitrião, PvP: a rodada foi resolvida; publica e abre a próxima.
func _on_rodada_pvp_resolvida(snapshot: Dictionary) -> void:
	DueloRede.publicar_rodada_pvp(snapshot)
	if not Combat.combat_active:
		return
	_enviar_estado("")
	if DueloRede.limite_atingido():
		Combat.encerrar_por_limite_de_turnos()
		return
	Combat.start_player_turn()


## Meu turno acabou e foi resolvido: manda o resultado e passa a vez.
func _on_turno_rede_encerrado(snapshot: Dictionary) -> void:
	if DueloRede.modo_combate == "pvp":
		_on_rodada_pvp_resolvida(snapshot)
		return
	var de_novo_eu := DueloRede.enviar_turno(snapshot)
	if Combat.combat_active:
		_enviar_estado("")
	_atualizar_rotulo_turno()
	if Combat.combat_active and DueloRede.limite_atingido():
		Combat.encerrar_por_limite_de_turnos()
		return
	if de_novo_eu and Combat.combat_active:
		Combat.start_player_turn()


## O jogador da vez terminou: aplica o resultado dele (e começa o meu, se for a minha vez).
func _on_turno_recebido(snapshot: Dictionary) -> void:
	if not Combat.combat_active:
		return
	Combat.aplicar_snapshot(snapshot, DueloRede.modo_combate == "pvp", DueloRede.meu_turno(), DueloRede.limite_atingido())
	_animar_colega(snapshot)
	if Combat.combat_active:
		_enviar_estado("")
	_atualizar_rotulo_turno()


func _on_membro_saiu(user_id: String) -> void:
	if not Combat.combat_active:
		return
	if DueloRede.modo_combate == "pvp":
		Combat.encerrar_por_wo()
	else:
		_on_log_message("Um colega saiu da equipe.")
		_atualizar_rotulo_turno()


func _on_atividade_encerrada() -> void:
	# O professor encerrou: sem derrota nem vitória, todo mundo volta pra sala.
	Combat.combat_active = false
	_registrada = true
	_voltar_para_sala()


func _on_sala_perdida(_motivo: String) -> void:
	Combat.combat_active = false
	_registrada = true
	get_tree().change_scene_to_file(CENA_MENU_ALUNO)


func _enviar_estado(fim: String) -> void:
	if not _em_rede or not DueloRede.ativo:
		return
	var hp := 0
	var hp_max := 0
	for u in Combat.player_units:
		hp += u.current_hp
		hp_max += u.max_hp
	DueloRede.enviar_estado(hp, hp_max, fim)


func _voltar_para_sala() -> void:
	if DueloRede.amistoso:
		# Duelo amistoso: volta para a lista da arena.
		DueloRede.limpar_partida()
		ArenaDuelos.duelo_terminado()
		get_tree().change_scene_to_file(CENA_ARENA)
		return
	DueloRede.limpar_partida()
	Engine.set_meta("lobby_modo", "aluno")
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_units_changed(player_units: Array, enemy_units: Array) -> void:
	player_units_row.set_units(player_units)
	enemy_units_row.set_units(enemy_units)
	_animar_lutadores(player_units, enemy_units)


# ------------------------------------------------- lutadores (criatura e jogador)

## Escolhe a criatura pelo nível (no PvE em equipe, pela rodada, para todos da
## equipe verem a mesma) e coloca o sprite no retrato do inimigo.
func _montar_monstro() -> void:
	var semente := -1
	if _em_rede:
		semente = DueloRede.rodada * 31 + maxi(0, DueloRede.grupo)
	var escolhida := MonsterCatalog.escolher(_nivel, semente)
	if escolhida.is_empty():
		return
	_monstro = (escolhida["cena"] as PackedScene).instantiate() as Monster
	var retrato := $HUD/EnemyPanel/Portrait as Control
	retrato.add_child(_monstro)
	_vis_monstro = CombatSprite.new(_monstro, _monstro.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D)
	var encaixar := func(): _vis_monstro.encaixar(retrato, _monstro.escala_combate)
	retrato.resized.connect(encaixar)
	encaixar.call()
	($HUD/EnemyPanel/NameLabel as Label).text = _monstro.nome_exibicao.capitalize()


## Quadros de animação do personagem do mapa (mesmas animações no combate).
## Usa só os quadros, não a cena de movimento.
func _quadros_do_personagem() -> SpriteFrames:
	var cena := load("res://entities/teste.tscn") as PackedScene
	if cena == null:
		return null
	var modelo := cena.instantiate()
	var origem := modelo.find_children("*", "AnimatedSprite2D", true, false)
	var frames: SpriteFrames = null
	if not origem.is_empty():
		frames = (origem[0] as AnimatedSprite2D).sprite_frames
	modelo.free()
	return frames


## Cria um personagem dentro de um retrato. 'fatia'/'total' dividem o retrato
## entre vários personagens (equipe).
func _criar_personagem(frames: SpriteFrames, retrato: Control, espelhar: bool, cor: Color, fatia: int, total: int) -> CombatSprite:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames.duplicate()  # cópia: o combate muda o "loop" das animações
	spr.flip_h = espelhar
	spr.modulate = cor
	retrato.add_child(spr)
	var vis := CombatSprite.new(spr, spr)
	var encaixar := func(): vis.encaixar(retrato, 0.0, fatia, total)
	retrato.resized.connect(encaixar)
	encaixar.call()
	return vis


## Personagens do meu time no retrato de baixo: só o meu no solo e no PvP; no
## PvE em equipe, todos os membros lado a lado (os colegas com um tom diferente).
func _montar_jogador() -> void:
	var frames := _quadros_do_personagem()
	if frames == null:
		return
	var retrato := $HUD/PlayerPanel/Portrait as Control
	var equipe := _em_rede and DueloRede.modo_combate == "coop" and DueloRede.membros.size() > 1
	if equipe:
		var n := DueloRede.membros.size()
		for i in n:
			var eu := i == DueloRede.meu_indice
			var cor: Color = Color.WHITE if eu else CORES_COLEGAS[i % CORES_COLEGAS.size()]
			var vis := _criar_personagem(frames, retrato, false, cor, i, n)
			_vis_time.append(vis)
			_vis_por_nome[str(DueloRede.membros[i]["nome"])] = vis
			if eu:
				_vis_jogador = vis
	else:
		_vis_jogador = _criar_personagem(frames, retrato, false, Color.WHITE, 0, 1)
		_vis_time.append(_vis_jogador)
	Combat.spell_resolving.connect(_on_feitico_resolvido)


## PvP: o adversário aparece no retrato de cima com o mesmo personagem,
## espelhado e com outra cor, e usa as mesmas reações de vida do monstro.
func _montar_oponente() -> void:
	var frames := _quadros_do_personagem()
	if frames == null:
		return
	var retrato := $HUD/EnemyPanel/Portrait as Control
	_vis_monstro = _criar_personagem(frames, retrato, true, COR_OPONENTE, 0, 1)


## Animação de ataque quando uma magia é resolvida: a minha move o meu
## personagem; a do monstro (ou do adversário, no PvP) move o lado de cima.
func _on_feitico_resolvido(feitico: SpellCast) -> void:
	if feitico.caster == "player":
		if _vis_jogador != null:
			_vis_jogador.tocar(&"ataque")
	elif _vis_monstro != null:
		_vis_monstro.tocar(&"ataque")


## Equipe: um colega jogou o turno, então o personagem dele ataca (nas outras
## máquinas só chega o resultado do turno, sem as magias uma a uma).
func _animar_colega(snapshot: Dictionary) -> void:
	var vis: CombatSprite = _vis_por_nome.get(str(snapshot.get("nome", "")), null)
	if vis != null and vis != _vis_jogador:
		vis.tocar(&"ataque")


## Reage às mudanças de HP: quem perde vida leva dano (ou morre, se zerar) e o
## outro lado ataca. Vale para todos os jogadores da equipe, já que todos
## recebem as mesmas atualizações de HP.
func _animar_lutadores(player_units: Array, enemy_units: Array) -> void:
	var hp_inimigo := 0
	for u in enemy_units:
		hp_inimigo += u.current_hp
	var hp_time := 0
	for u in player_units:
		hp_time += u.current_hp
	if _hp_inimigo_antes >= 0:
		var inimigo_perdeu := hp_inimigo < _hp_inimigo_antes
		var time_perdeu := hp_time < _hp_time_antes
		if _vis_monstro != null:
			if hp_inimigo <= 0 and _hp_inimigo_antes > 0:
				_vis_monstro.tocar(&"morte")
			elif inimigo_perdeu:
				_vis_monstro.tocar(&"dano")
			elif time_perdeu:
				_vis_monstro.tocar(&"ataque")
		var equipe := _vis_time.size() > 1
		for vis in _vis_time:
			if hp_time <= 0 and _hp_time_antes > 0:
				vis.tocar(&"morte")
			elif time_perdeu:
				vis.tocar(&"dano")
			elif inimigo_perdeu and not equipe and not vis.tocando(&"ataque"):
				vis.tocar(&"ataque")
	_hp_inimigo_antes = hp_inimigo
	_hp_time_antes = hp_time


func _on_tics_changed(remaining: int, max_tics: int) -> void:
	tics_label.text = "Tics: %d/%d" % [remaining, max_tics]


func _on_turn_started(is_player: bool) -> void:
	if _em_rede:
		if is_player:
			Combat.monstro_age_ao_fim = DueloRede.sou_ultimo()
			_timer_turno.start()
		else:
			_timer_turno.stop()
		_atualizar_rotulo_turno()
	else:
		turn_label.text = "Seu turno" if is_player else "Turno do oponente..."
	_pronto_ms = Time.get_ticks_msec() if is_player else -1


## Tabuleiro livre de novo no turno do jogador: começa a contar o tempo de reação.
func _on_board_idle() -> void:
	if Combat.is_player_turn and Combat.combat_active:
		_pronto_ms = Time.get_ticks_msec()


## Jogada feita: guarda quanto tempo o aluno levou desde o tabuleiro ficar livre.
func _on_player_moved() -> void:
	if _pronto_ms < 0:
		return
	var segundos := (Time.get_ticks_msec() - _pronto_ms) / 1000.0
	_latencias.append(minf(segundos, LATENCIA_MAX_REGISTRADA))
	_pronto_ms = -1


func _on_spell_matched(_tile_type: TileType, match_size: int) -> void:
	_pontuacao += match_size


func _on_log_message(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func _on_combat_ended(player_won: bool) -> void:
	turn_label.text = "Empate!" if Combat.resultado_empate else ("Vitória!" if player_won else "Derrota...")
	board.can_swipe = false
	_registrar_partida(player_won)
	_enviar_estado("empate" if Combat.resultado_empate else ("venceu" if player_won else "perdeu"))
	_mostrar_resultado(player_won)


func _registrar_partida(player_won: bool) -> void:
	if _registrada or _em_rede:
		return
	_registrada = true

	var partida := PartidaMatch3Model.new()
	partida.nivel_dificuldade = _nivel
	partida.pontuacao = _pontuacao
	partida.tempo_decorrido = (Time.get_ticks_msec() - _inicio_ms) / 1000.0
	partida.venceu = player_won
	partida.jogadas = _latencias.size()
	if not _latencias.is_empty():
		var soma := 0.0
		for l in _latencias:
			soma += l
			partida.latencia_max = maxf(partida.latencia_max, l)
		partida.latencia_media = soma / _latencias.size()

	LocalDB.registrar_partida(LocalDB.get_user_id_ativo(), partida)


## Painel de fim de combate: resultado, resumo e botão pra voltar ao quintal.
## Espera um instante antes, pra última animação de dano terminar de aparecer.
func _mostrar_resultado(player_won: bool) -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return

	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	$HUD.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 14)
	painel.add_child(margem)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	margem.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "Empate!" if Combat.resultado_empate else ("Vitória!" if player_won else "Derrota...")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	caixa.add_child(titulo)

	var resumo := Label.new()
	if _em_rede and DueloRede.modo_combate == "pvp":
		resumo.text = "Duelo contra %s  •  Jogadas: %d" % [DueloRede.nome_do_adversario(), _latencias.size()]
	elif _em_rede:
		resumo.text = "Equipe de %d  •  Suas jogadas: %d" % [DueloRede.membros.size(), _latencias.size()]
	else:
		resumo.text = "Dificuldade: nível %d  •  Jogadas: %d" % [_nivel, _latencias.size()]
	resumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(resumo)

	_botao_voltar = Button.new()
	_botao_voltar.text = ("Voltar à arena  [E]" if DueloRede.amistoso else "Voltar à sala  [E]") if _em_rede else "Voltar ao quintal  [E]"
	_botao_voltar.pressed.connect(_voltar_ao_quintal)
	caixa.add_child(_botao_voltar)
	_botao_voltar.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _botao_voltar != null and event.is_action_pressed("interagir"):
		_voltar_ao_quintal()


func _voltar_ao_quintal() -> void:
	if _botao_voltar == null:
		return
	_botao_voltar = null  # evita voltar duas vezes (clique + tecla)
	if _em_rede:
		_voltar_para_sala()
	else:
		_ir_para_o_quintal()


func _ir_para_o_quintal() -> void:
	# O jogador (entities/teste.gd) lê isso ao nascer na cena de destino.
	Engine.set_meta("spawn_proxima_cena", {"cena": CENA_RETORNO, "posicao": SPAWN_RETORNO})
	get_tree().change_scene_to_file(CENA_RETORNO)


## Encerra o combate em andamento sem vencedor: conta como derrota e fica nas
## estatísticas. Usado pelo menu ESC (desistir / sair) e ao fechar a janela.
func abandonar() -> void:
	if _registrada or not Combat.combat_active:
		return
	Combat.combat_active = false
	if _em_rede:
		# Os outros ficam sabendo: no PvP o adversário vence por W.O.
		_registrada = true
		DueloRede.avisar_saida()
		_enviar_estado("perdeu")
		return
	_registrar_partida(false)


## "Desistir do combate" do menu ESC: grava a derrota e volta pro quintal
## (ou pra sala, se for uma atividade em grupo).
func desistir() -> void:
	abandonar()
	if _em_rede:
		_voltar_para_sala()
	else:
		_ir_para_o_quintal()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		abandonar()
