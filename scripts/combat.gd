extends Node

## Autoload "Combat" — cérebro do combate PvE (jogador vs monstro).
##
## Ciclo do turno:
## 1) start_player_turn(): reseta Tics, libera o tabuleiro pro jogador jogar.
## 2) A cada troca no tabuleiro, o Main chama spend_tic() (SEMPRE gasta 1 Tic,
##    a troca não é desfeita mesmo sem match — decisão de design pra permitir
##    alinhamentos estratégicos ao longo de várias jogadas).
## 3) Cada combinação encontrada vira um SpellCast em fila via queue_spell() —
##    o efeito NÃO é aplicado na hora, só quando o turno acaba.
## 4) Quando os Tics do jogador zeram, end_player_turn() é chamado automaticamente:
##    a IA do monstro enfileira sua própria ação, e resolve_turn() processa
##    TODOS os feitiços pendentes (dos dois lados) em ordem de prioridade da forma
##    (0 primeiro, valores maiores por último).
## 5) Depois de resolver, start_player_turn() começa o próximo turno.

# --- Sinais (pra UI e para o tabuleiro escutarem) ---
signal hp_changed(player_hp: int, monster_hp: int)
signal tics_changed(remaining: int, max_tics: int)
signal turn_started(is_player_turn: bool)
signal spell_resolving(spell: SpellCast)
signal combat_ended(player_won: bool)
signal log_message(text: String)

# --- Constantes de balanceamento (placeholders — ajustar quando a matriz de cores fechar) ---
const BASE_DAMAGE: int = 10
const BASE_HEAL: int = 8
const SLOW_TIC_PENALTY: int = 2          # Tics a menos no turno afetado por slow
const TEMPO_CIRCLE_BONUS_TICS: int = 2   # Tics extras concedidos por Roxo+Círculo

# --- Estado de combate ---
var player_max_hp: int = 100
var monster_max_hp: int = 100
var player_hp: int = 100
var monster_hp: int = 100

var tics_max: int = 3
var tics_remaining: int = 3

var is_player_turn: bool = true
var combat_active: bool = false

var pending_spells: Array[SpellCast] = []

# status = { stunned: bool, slow: bool, shield_slow: bool, shield_stun: bool, bonus_tics: int }
var player_status := {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}
var monster_status := {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}

# --- Início de combate ---

func start_combat(p_player_max_hp: int = 100, p_monster_max_hp: int = 100, p_tics_max: int = 3):
	player_max_hp = p_player_max_hp
	monster_max_hp = p_monster_max_hp
	player_hp = player_max_hp
	monster_hp = monster_max_hp
	tics_max = p_tics_max
	
	player_status = {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}
	monster_status = {"stunned": false, "slow": false, "shield_slow": false, "shield_stun": false, "bonus_tics": 0}
	
	combat_active = true
	hp_changed.emit(player_hp, monster_hp)
	start_player_turn()

# --- Turno do jogador ---

func start_player_turn():
	
	pending_spells.clear()
	
	tics_max = 3 # valor base do turno — pode virar @export/config depois
	tics_remaining = tics_max
	
	# Aplica status que afetam o INÍCIO deste turno (calculados no fim do turno anterior)
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
	
	# Se o jogador já começa sem Tics (ex: atordoado), pula direto pra resolução
	if tics_remaining <= 0:
		end_player_turn()

func can_player_act() -> bool:
	return combat_active and is_player_turn and tics_remaining > 0

## Chamado pelo tabuleiro a cada troca (com ou sem match) — a troca NUNCA é desfeita.
func spend_tic():
	
	if not can_player_act():
		return
	
	tics_remaining -= 1
	tics_changed.emit(tics_remaining, tics_max)

## Chamado pelo tabuleiro pra cada combinação encontrada (o efeito só entra na fila)
func queue_spell(caster: String, tile_type: TileType, match_size: int):
	
	var spell = SpellCast.new(caster, tile_type, match_size)
	pending_spells.append(spell)
	log_message.emit("%s conjurou %s (%s, combo de %d)" % [
		"Você" if caster == "player" else "O monstro",
		tile_type.shape_name, tile_type.element_name, match_size
	])

# --- Fim do turno do jogador / IA do monstro ---

func end_player_turn():
	
	if not is_player_turn:
		return
	
	is_player_turn = false
	turn_started.emit(false)
	
	_queue_monster_action()
	
	await resolve_turn()
	
	if combat_active:
		start_player_turn()

## IA simples pro monstro em PvE: por enquanto, sempre conjura um ataque genérico.
## TODO: variar a forma/elemento por tipo de monstro quando a matriz de cores fechar.
func _queue_monster_action():
	
	if monster_status["stunned"]:
		log_message.emit("O monstro está atordoado e não age!")
		monster_status["stunned"] = false
		return
	
	var monster_attack := TileType.new()
	monster_attack.element_name = "Ataque"
	monster_attack.shape_name = "Garra"
	monster_attack.priority = 1
	monster_attack.category = "Ofensivo"
	
	queue_spell("monster", monster_attack, 3)

# --- Resolução do turno ---

func resolve_turn():
	
	pending_spells.sort_custom(func(a, b): return a.get_priority() < b.get_priority())
	
	for spell in pending_spells:
		spell_resolving.emit(spell)
		_apply_spell(spell)
		hp_changed.emit(player_hp, monster_hp)
		
		if _check_combat_end():
			pending_spells.clear()
			return
		
		await get_tree().create_timer(0.4).timeout
	
	pending_spells.clear()

func _apply_spell(spell: SpellCast):
	
	var caster_status = player_status if spell.caster == "player" else monster_status
	var target_status = monster_status if spell.caster == "player" else player_status
	var scale = spell.get_scale()
	var element = spell.tile_type.element_name
	var shape = spell.tile_type.shape_name
	
	match element:
		
		"Tempo": # Totalmente definido pelo usuário — roxo muda de efeito conforme a forma
			match shape:
				"Triangulo":
					target_status["slow"] = not target_status["shield_slow"]
					if target_status["shield_slow"]:
						log_message.emit("O escudo bloqueou o slow!")
						target_status["shield_slow"] = false
					else:
						log_message.emit("Efeito: slow aplicado!")
				"Pentagono":
					target_status["stunned"] = not target_status["shield_stun"]
					if target_status["shield_stun"]:
						log_message.emit("O escudo bloqueou o stun!")
						target_status["shield_stun"] = false
					else:
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
		
		"Cura":
			_heal(spell.caster, int(BASE_HEAL * scale))
		
		"Ataque": # feitiço genérico do monstro (placeholder de IA)
			_deal_damage(spell.caster, int(BASE_DAMAGE * scale))
		
		_: # Fogo, Gelo, Raio, Terra — dano genérico até a matriz de cores/formas fechar
			# TODO: substituir por valores reais definidos na tabela Elemento x Forma
			_deal_damage(spell.caster, int(BASE_DAMAGE * scale))

func _deal_damage(caster: String, amount: int):
	
	if caster == "player":
		monster_hp = max(0, monster_hp - amount)
		log_message.emit("Dano ao monstro: %d" % amount)
	else:
		player_hp = max(0, player_hp - amount)
		log_message.emit("Dano recebido: %d" % amount)

func _heal(caster: String, amount: int):
	
	if caster == "player":
		player_hp = min(player_max_hp, player_hp + amount)
		log_message.emit("Cura em você: %d" % amount)
	else:
		monster_hp = min(monster_max_hp, monster_hp + amount)
		log_message.emit("Cura no monstro: %d" % amount)

func _check_combat_end() -> bool:
	
	if monster_hp <= 0:
		combat_active = false
		combat_ended.emit(true)
		log_message.emit("Vitória!")
		return true
	
	if player_hp <= 0:
		combat_active = false
		combat_ended.emit(false)
		log_message.emit("Derrota...")
		return true
	
	return false
