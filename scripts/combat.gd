extends Node

## Autoload "Combat" — cérebro do combate PvE, versão multi-unidade.
##
## Cada lado (jogador e oponente) é uma LISTA de CombatUnit — uma por forma
## presente naquele combate. Isso permite quantidade variável dos dois lados
## (o jogador ganha formas em exploração; o oponente varia por encontro).
##
## Ciclo do turno (Tics), fila de feitiços com prioridade por forma, e os
## efeitos de status do elemento Tempo (slow/stun/escudos/bônus de Tics) são
## herdados do combat.gd original do tons-educativos-magia — só a base de
## dano/cura/defesa deixou de vir do ELEMENTO e passou a vir da FORMA (como
## definido pelo jogo: triângulo=dano rápido, quadrado=defesa rápida,
## pentágono=dano forte, hexágono=defesa forte, círculo=auto/cura).
##
## Alvo de dano: aleatório entre as unidades vivas do lado oposto. Combos
## maiores atingem mais alvos (3 -> 1 alvo, 4 -> 2 alvos, 5+ -> todos os vivos).

signal units_changed(player_units: Array, enemy_units: Array)
signal tics_changed(remaining: int, max_tics: int)
signal turn_started(is_player_turn: bool)
signal spell_resolving(spell: SpellCast)
signal combat_ended(player_won: bool)
signal log_message(text: String)
## Modo multiplayer: emitido quando o turno local acabou e foi resolvido.
## Leva o estado resultante (ver gerar_snapshot) pra ser enviado aos outros.
signal turno_rede_encerrado(snapshot: Dictionary)
## PvP: o turno local acabou; leva a lista de feitiços (ver _serializar_feiticos)
## pro anfitrião resolver junto com a do outro jogador, por ordem de prioridade.
signal feiticos_pvp_prontos(lista: Array)

## Com poucos Tics por turno (2 por padrão), o efeito de Tempo precisa ser
## proporcional: lento tira 1 Tic (metade do turno) e o círculo roxo dá +1.
const SLOW_TIC_PENALTY: int = 1
const TEMPO_CIRCLE_BONUS_TICS: int = 1

## Combinações da mesma forma e do mesmo tamanho no mesmo turno (cascatas
## incluídas) viram UM feitiço só. Cada repetição extra soma este tanto do
## poder base: 1.0 = soma linear (×N, mesmo poder total de antes, só mais
## rápido); valores menores enfraquecem as cascatas.
const BONUS_POR_REPETICAO := 1.0

## Dano deste elemento ignora o escudo: destrói o escudo inteiro e o dano passa.
const ELEMENTO_QUEBRA_ESCUDO := "Eletricidade"

const CATEGORY_BASE := {
	"dano_rapido": 8,
	"dano_forte": 16,
	"defesa_rapida": 8,
	"defesa_forte": 16,
	"auto": 10,
}

var player_units: Array[CombatUnit] = []
var enemy_units: Array[CombatUnit] = []

var tics_max: int = 3
var tics_remaining: int = 3
var is_player_turn: bool = true
var combat_active: bool = false
var pending_spells: Array[SpellCast] = []

var player_status := {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}
var monster_status := {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}

var _board: Node = null

## --- Multiplayer (ver DueloRede) ---
## "" = PvE solo (inimigo controlado pela IA daqui)
## "pvp"  = o "oponente" é outro jogador; ele joga o turno dele no PC dele
## "coop" = vários jogadores alternam turnos do mesmo time contra um monstro
## Em rede, quem tem o turno resolve os feitiços no PRÓPRIO PC e manda o
## resultado (HP, escudos, status) pros outros, que só aplicam. Assim não
## precisa sincronizar sorteios de alvo.
var modo_rede: String = ""
## PvP: os dois jogam ao mesmo tempo, cada um no seu ritmo. No fim, UM dos
## lados (o anfitrião) junta os feitiços dos dois, resolve por prioridade e
## manda o resultado pro outro.
var pvp_anfitriao: bool = false
## No coop, o monstro só age depois do último jogador da rodada.
var monstro_age_ao_fim: bool = true
## Empate por tempo esgotado (a UI mostra "Empate!" em vez de "Derrota").
var resultado_empate: bool = false
var _log_turno: Array = []
var _coletando_log := false

func _ready() -> void:
	# Guarda as mensagens do turno pra mandar junto com o resultado em rede.
	log_message.connect(func(texto: String):
		if _coletando_log:
			_log_turno.append(texto))


# --- Ligação com o tabuleiro (grid.gd) ---

## Conecta esse Combat aos sinais do tabuleiro ativo. Chame isso no _ready()
## da cena que hospeda o grid (ex: "board.gd" ou o futuro duelos.gd),
## passando o nó que tem o script grid.gd: Combat.bind_board($Combate/grid)
func bind_board(board: Node) -> void:
	if _board == board:
		return
	if _board != null:
		if _board.spell_matched.is_connected(_on_board_spell_matched):
			_board.spell_matched.disconnect(_on_board_spell_matched)
		if _board.player_moved.is_connected(spend_tic):
			_board.player_moved.disconnect(spend_tic)
		if _board.board_idle.is_connected(_on_board_idle):
			_board.board_idle.disconnect(_on_board_idle)

	_board = board
	_board.spell_matched.connect(_on_board_spell_matched)
	_board.player_moved.connect(spend_tic)
	_board.board_idle.connect(_on_board_idle)


func _on_board_spell_matched(tile_type: TileType, match_size: int) -> void:
	queue_spell("player", tile_type, match_size)


func _on_board_idle() -> void:
	if is_player_turn and tics_remaining <= 0:
		end_player_turn()

# --- Início de combate ---

func start_combat(player_types: Array[TileType], player_hp_each: int, enemy_types: Array[TileType], enemy_hp_each: int, p_tics_max: int = 3) -> void:
	player_units = []
	for t in player_types:
		player_units.append(CombatUnit.new(t, player_hp_each))

	enemy_units = []
	for t in enemy_types:
		enemy_units.append(CombatUnit.new(t, enemy_hp_each))

	resultado_empate = false
	tics_max = p_tics_max
	player_status = {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}
	monster_status = {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}

	combat_active = true
	units_changed.emit(player_units, enemy_units)
	start_player_turn()

# --- Turno do jogador ---

func start_player_turn() -> void:
	pending_spells.clear()
	tics_remaining = tics_max

	if player_status["stunned"]:
		tics_remaining = 0
		log_message.emit("Você está atordoado e perde o turno!")
		player_status["stunned"] = false
	elif player_status["slow"]:
		tics_remaining = max(0, tics_remaining - SLOW_TIC_PENALTY)
		log_message.emit("Você está lento: -%d Tics neste turno." % SLOW_TIC_PENALTY)
		player_status["slow"] = false

	tics_remaining += player_status["bonus_tics"]
	if player_status["bonus_tics"] > 0:
		log_message.emit("Bônus de tempo: +%d Tics!" % player_status["bonus_tics"])
	player_status["bonus_tics"] = 0

	is_player_turn = true
	tics_changed.emit(tics_remaining, tics_max)
	turn_started.emit(true)

	if tics_remaining <= 0:
		end_player_turn()


func can_player_act() -> bool:
	return combat_active and is_player_turn and tics_remaining > 0


## Chamado a cada troca no tabuleiro (com ou sem match) — a troca NUNCA é
## desfeita, então o Tic é gasto de qualquer forma.
func spend_tic() -> void:
	if not can_player_act():
		return
	tics_remaining -= 1
	tics_changed.emit(tics_remaining, tics_max)


## Chamado pelo tabuleiro pra cada GRUPO de combinação encontrado. Só entra
## na fila se o lado que conjura ainda tiver aquela forma viva.
func queue_spell(caster_side: String, tile_type: TileType, match_size: int) -> void:
	var caster_units = player_units if caster_side == "player" else enemy_units
	var caster_unit = _find_unit(caster_units, tile_type.shape_name)
	if caster_unit == null or not caster_unit.is_alive():
		return

	var spell = SpellCast.new(caster_side, tile_type, match_size)
	pending_spells.append(spell)
	log_message.emit("%s conjura %s (%s, combo de %d)" % [
		"Você" if caster_side == "player" else "O oponente",
		tile_type.shape_name, tile_type.element_name, match_size
	])


func _find_unit(units: Array[CombatUnit], shape_name: String) -> CombatUnit:
	for u in units:
		if u.shape_name == shape_name and u.is_alive():
			return u
	return null

# --- Fim do turno do jogador / IA do oponente ---

func end_player_turn() -> void:
	if not is_player_turn:
		return
	is_player_turn = false
	turn_started.emit(false)

	if modo_rede == "pvp":
		_encerrar_turno_pvp()
		return
	if modo_rede != "":
		await _encerrar_turno_rede()
		return

	_queue_enemy_actions()
	await resolve_turn()

	if combat_active:
		start_player_turn()


# --- Multiplayer ---

func _encerrar_turno_rede() -> void:
	_log_turno = []
	_coletando_log = true
	if modo_rede == "coop" and monstro_age_ao_fim:
		_queue_enemy_actions()
	await resolve_turn()
	_coletando_log = false
	turno_rede_encerrado.emit(gerar_snapshot())


## PvP: manda meus feitiços e espera o resultado da rodada.
func _encerrar_turno_pvp() -> void:
	_juntar_feiticos_iguais()
	var lista := _serializar_feiticos(pending_spells)
	if not pvp_anfitriao:
		pending_spells.clear()  # o anfitrião é quem resolve (e manda o estado)
	feiticos_pvp_prontos.emit(lista)


func _serializar_feiticos(feiticos: Array) -> Array:
	var r := []
	for sp in feiticos:
		r.append({"f": sp.tile_type.shape_name, "e": sp.tile_type.element_name,
			"t": sp.match_size, "c": sp.repeticoes})
	return r


## Anfitrião: junta os feitiços do outro jogador (viram "monster" aqui) aos
## meus, resolve tudo por prioridade e publica o estado resultante.
func resolver_rodada_pvp(lista_oponente: Array) -> void:
	for d in lista_oponente:
		var tt := SpellLoadout.get_tile_type(str(d.get("f", "")), str(d.get("e", "")))
		var sp := SpellCast.new("monster", tt, int(d.get("t", 3)))
		sp.repeticoes = maxi(1, int(d.get("c", 1)))
		pending_spells.append(sp)
	_log_turno = []
	_coletando_log = true
	await resolve_turn()
	_coletando_log = false
	turno_rede_encerrado.emit(gerar_snapshot())


func _dados_unidades(unidades: Array[CombatUnit]) -> Array:
	var r := []
	for u in unidades:
		r.append({"f": u.shape_name, "hp": u.current_hp, "sh": u.shield})
	return r


func _aplicar_unidades(unidades: Array[CombatUnit], dados: Array) -> void:
	for d in dados:
		for u in unidades:
			if u.shape_name == str(d.get("f", "")):
				u.current_hp = int(d.get("hp", u.current_hp))
				u.shield = int(d.get("sh", u.shield))
				break


func _status_limpo(d: Dictionary) -> Dictionary:
	return {
		"stunned": bool(d.get("stunned", false)),
		"slow": bool(d.get("slow", false)),
		"shield_slow": bool(d.get("shield_slow", false)),
		"shield_stun": bool(d.get("shield_stun", false)),
		"bonus_tics": int(d.get("bonus_tics", 0)),
	}


## Estado completo depois do turno local: "mi" = meu lado, "ou" = o outro lado
## (oponente/monstro), mais os status de cada um e o que aconteceu no turno.
func gerar_snapshot() -> Dictionary:
	return {
		"mi": _dados_unidades(player_units),
		"ou": _dados_unidades(enemy_units),
		"sm": player_status.duplicate(),
		"so": monster_status.duplicate(),
		"log": _log_turno.duplicate(),
	}


## Aplica o estado enviado por quem jogou. `espelhar` = PvP: o "meu lado" de
## quem mandou é o "oponente" aqui. `minha_vez` = o próximo turno é meu.
func aplicar_snapshot(s: Dictionary, espelhar: bool, minha_vez: bool, tempo_esgotado: bool = false) -> void:
	if not combat_active:
		return
	var meus: Array = s.get("ou", []) if espelhar else s.get("mi", [])
	var outros: Array = s.get("mi", []) if espelhar else s.get("ou", [])
	_aplicar_unidades(player_units, meus)
	_aplicar_unidades(enemy_units, outros)
	player_status = _status_limpo(s.get("so", {}) if espelhar else s.get("sm", {}))
	monster_status = _status_limpo(s.get("sm", {}) if espelhar else s.get("so", {}))
	for linha in s.get("log", []):
		log_message.emit(str(linha))
	units_changed.emit(player_units, enemy_units)
	if _check_combat_end():
		return
	if tempo_esgotado:
		encerrar_por_limite_de_turnos()
		return
	if minha_vez:
		start_player_turn()
	else:
		aguardar_turno_rede()


## Fica esperando a vez (não é o turno deste jogador).
func aguardar_turno_rede() -> void:
	is_player_turn = false
	tics_remaining = 0
	tics_changed.emit(tics_remaining, tics_max)
	turn_started.emit(false)


## Limite de turnos (evita partida eterna, p.ex. quando ninguém mais tem
## unidade de dano): PvP vence quem tem mais HP total (igual = empate);
## coop, o monstro resistiu e o time perde. Os dois lados chegam ao mesmo
## resultado porque o estado aplicado é o mesmo.
func encerrar_por_limite_de_turnos() -> void:
	if not combat_active:
		return
	combat_active = false
	var meu_hp := 0
	var outro_hp := 0
	for u in player_units:
		meu_hp += u.current_hp
	for u in enemy_units:
		outro_hp += u.current_hp
	if modo_rede == "pvp":
		if meu_hp > outro_hp:
			log_message.emit("Tempo esgotado: você venceu pelos pontos de vida!")
			combat_ended.emit(true)
		elif meu_hp < outro_hp:
			log_message.emit("Tempo esgotado: o adversário venceu pelos pontos de vida.")
			combat_ended.emit(false)
		else:
			resultado_empate = true
			log_message.emit("Tempo esgotado: empate!")
			combat_ended.emit(false)
	else:
		log_message.emit("Tempo esgotado: o monstro resistiu.")
		combat_ended.emit(false)


## O outro jogador saiu: quem ficou vence por W.O. (PvP).
func encerrar_por_wo() -> void:
	if not combat_active:
		return
	combat_active = false
	log_message.emit("O adversário saiu: vitória por W.O.!")
	combat_ended.emit(true)


## IA simples: cada unidade inimiga viva age uma vez por turno, com combo
## fixo de 3 (1 alvo). Trocar por algo mais elaborado depois é só mudar aqui.
func _queue_enemy_actions() -> void:
	if monster_status["stunned"]:
		log_message.emit("O oponente está atordoado e não age!")
		monster_status["stunned"] = false
		return

	var agindo: Array[CombatUnit] = []
	for unit in enemy_units:
		if unit.is_alive():
			agindo.append(unit)

	# Lento (Triângulo de Tempo): metade das unidades do oponente (arredondando
	# pra baixo, mínimo 1 agindo) perde a ação neste turno.
	if monster_status["slow"]:
		monster_status["slow"] = false
		agindo.shuffle()
		var perdem := agindo.size() / 2
		if perdem > 0:
			agindo = agindo.slice(perdem)
			log_message.emit("O oponente está lento: %d unidade(s) não agem!" % perdem)

	for unit in agindo:
		queue_spell("monster", unit.tile_type, 3)

# --- Resolução do turno ---

## Junta feitiços iguais (lado + forma + elemento + tamanho) em um só.
func _juntar_feiticos_iguais() -> void:
	var juntos: Array[SpellCast] = []
	var por_chave := {}
	for sp in pending_spells:
		var chave := "%s|%s|%s|%d" % [sp.caster, sp.tile_type.shape_name, sp.tile_type.element_name, sp.match_size]
		if por_chave.has(chave):
			por_chave[chave].repeticoes += sp.repeticoes
		else:
			por_chave[chave] = sp
			juntos.append(sp)
	pending_spells = juntos


func resolve_turn() -> void:
	_juntar_feiticos_iguais()
	# Menor prioridade resolve primeiro; no empate, ordem sorteada (assim
	# nenhum dos lados leva vantagem fixa quando os dois jogam ao mesmo tempo).
	pending_spells.shuffle()
	pending_spells.sort_custom(func(a, b): return a.get_priority() < b.get_priority())

	for spell in pending_spells:
		spell_resolving.emit(spell)
		_apply_spell(spell)
		units_changed.emit(player_units, enemy_units)

		if _check_combat_end():
			pending_spells.clear()
			return

		await get_tree().create_timer(0.4).timeout

	pending_spells.clear()


func _target_count(match_size: int, pool_size: int) -> int:
	if match_size >= 5:
		return pool_size
	elif match_size == 4:
		return min(2, pool_size)
	return min(1, pool_size)


## Quem recebe o escudo: combinação de 3 protege só a própria unidade; de 4,
## ela e mais uma aliada sorteada; de 5 ou mais, todas as aliadas vivas.
func _escudo_alvos(aliadas: Array[CombatUnit], propria: CombatUnit, match_size: int) -> Array[CombatUnit]:
	var vivas: Array[CombatUnit] = []
	for u in aliadas:
		if u.is_alive():
			vivas.append(u)
	if match_size >= 5:
		return vivas
	var alvos: Array[CombatUnit] = [propria]
	if match_size == 4:
		var outras: Array[CombatUnit] = vivas.filter(func(u): return u != propria)
		outras.shuffle()
		if not outras.is_empty():
			alvos.append(outras[0])
	return alvos


func _random_targets(units: Array[CombatUnit], count: int) -> Array[CombatUnit]:
	var alive: Array[CombatUnit] = []
	for u in units:
		if u.is_alive():
			alive.append(u)
	alive.shuffle()
	return alive.slice(0, count)


func _apply_spell(spell: SpellCast) -> void:
	var caster_units = player_units if spell.caster == "player" else enemy_units
	var target_units = enemy_units if spell.caster == "player" else player_units
	var caster_status = player_status if spell.caster == "player" else monster_status
	var target_status = monster_status if spell.caster == "player" else player_status

	var caster_unit = _find_unit(caster_units, spell.tile_type.shape_name)
	if caster_unit == null:
		return  # a unidade morreu entre a fila e a resolução — feitiço não sai

	var scale = spell.get_scale() * (1.0 + BONUS_POR_REPETICAO * (spell.repeticoes - 1))
	var rotulo := "" if spell.repeticoes <= 1 else " ×%d" % spell.repeticoes
	var element = spell.tile_type.element_name
	var shape = spell.tile_type.shape_name

	if element == "Tempo":
		match shape:
			"Triangulo":
				var targets = _random_targets(target_units, _target_count(spell.match_size, target_units.size()))
				for t in targets:
					if target_status["shield_slow"]:
						log_message.emit("Escudo bloqueou o slow!")
						target_status["shield_slow"] = false
					else:
						target_status["slow"] = true
						log_message.emit("Efeito: slow aplicado!")
			"Pentagono":
				if target_status["shield_stun"]:
					log_message.emit("Escudo bloqueou o stun!")
					target_status["shield_stun"] = false
				else:
					target_status["stunned"] = true
					log_message.emit("Efeito: stun aplicado!")
			"Quadrado":
				caster_status["shield_slow"] = true
				log_message.emit("Proteção contra slow ativada.")
			"Hexagono":
				caster_status["shield_stun"] = true
				log_message.emit("Proteção contra stun ativada.")
			"Circulo":
				caster_status["bonus_tics"] += TEMPO_CIRCLE_BONUS_TICS * spell.repeticoes
				log_message.emit("+%d Tics no próximo turno!" % (TEMPO_CIRCLE_BONUS_TICS * spell.repeticoes))
		return

	var category: String = SpellLoadout.get_category(shape)
	var amount = int(CATEGORY_BASE.get(category, 8) * scale)

	match category:
		"dano_rapido", "dano_forte":
			var targets = _random_targets(target_units, _target_count(spell.match_size, target_units.size()))
			var quebra: bool = element == ELEMENTO_QUEBRA_ESCUDO
			var escudo_destruido: int = 0
			for t in targets:
				escudo_destruido += t.take_damage(amount, quebra)
			log_message.emit("%d de dano em %d alvo(s) (%s%s)" % [amount, targets.size(), element, rotulo])
			if escudo_destruido > 0:
				log_message.emit("A Eletricidade destruiu %d de escudo!" % escudo_destruido)
		"defesa_rapida", "defesa_forte":
			var protegidos := _escudo_alvos(caster_units, caster_unit, spell.match_size)
			for u in protegidos:
				u.add_shield(amount)
			log_message.emit("+%d de escudo em %d unidade(s) (%s%s)" % [amount, protegidos.size(), element, rotulo])
		"auto":
			caster_unit.heal(amount)
			log_message.emit("+%d de cura (%s%s)" % [amount, element, rotulo])


func _check_combat_end() -> bool:
	var enemy_alive = false
	for u in enemy_units:
		if u.is_alive():
			enemy_alive = true
			break
	if not enemy_alive:
		combat_active = false
		combat_ended.emit(true)
		log_message.emit("Vitória!")
		return true

	var player_alive = false
	for u in player_units:
		if u.is_alive():
			player_alive = true
			break
	if not player_alive:
		combat_active = false
		combat_ended.emit(false)
		log_message.emit("Derrota...")
		return true

	return false
