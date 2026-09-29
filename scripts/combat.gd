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

const SLOW_TIC_PENALTY: int = 2
const TEMPO_CIRCLE_BONUS_TICS: int = 2

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

	_queue_enemy_actions()
	await resolve_turn()

	if combat_active:
		start_player_turn()


## IA simples: cada unidade inimiga viva age uma vez por turno, com combo
## fixo de 3 (1 alvo). Trocar por algo mais elaborado depois é só mudar aqui.
func _queue_enemy_actions() -> void:
	if monster_status["stunned"]:
		log_message.emit("O oponente está atordoado e não age!")
		monster_status["stunned"] = false
		return
	for unit in enemy_units:
		if unit.is_alive():
			queue_spell("monster", unit.tile_type, 3)

# --- Resolução do turno ---

func resolve_turn() -> void:
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

	var scale = spell.get_scale()
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
				caster_status["bonus_tics"] += TEMPO_CIRCLE_BONUS_TICS
				log_message.emit("+%d Tics no próximo turno!" % TEMPO_CIRCLE_BONUS_TICS)
		return

	var category: String = SpellLoadout.get_category(shape)
	var amount = int(CATEGORY_BASE.get(category, 8) * scale)

	match category:
		"dano_rapido", "dano_forte":
			var targets = _random_targets(target_units, _target_count(spell.match_size, target_units.size()))
			for t in targets:
				t.take_damage(amount)
			log_message.emit("%d de dano em %d alvo(s) (%s)" % [amount, targets.size(), element])
		"defesa_rapida", "defesa_forte":
			caster_unit.add_shield(amount)
			log_message.emit("+%d de escudo (%s)" % [amount, element])
		"auto":
			caster_unit.heal(amount)
			log_message.emit("+%d de cura (%s)" % [amount, element])


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
