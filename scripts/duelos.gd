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
@export var player_shapes: Array[String] = ["Quadrado", "Triangulo", "Pentagono", "Hexagono", "Circulo"]
@export var player_hp_each: int = 30

## Encontro de teste — troque livremente pra simular oponentes diferentes.
@export var enemy_hp_each: int = 20

var log_lines: Array[String] = []


func _ready() -> void:
	Combat.bind_board(board)

	Combat.units_changed.connect(_on_units_changed)
	Combat.tics_changed.connect(_on_tics_changed)
	Combat.turn_started.connect(_on_turn_started)
	Combat.log_message.connect(_on_log_message)
	Combat.combat_ended.connect(_on_combat_ended)

	var player_types: Array[TileType] = []
	for shape_name in player_shapes:
		player_types.append(SpellLoadout.get_equipped_type(shape_name))

	# Encontro de teste com quantidade variável (3 formas, não 5) — troque
	# aqui por dados reais de encontro quando isso vier da exploração.
	var enemy_types: Array[TileType] = [
		SpellLoadout.get_tile_type("Triangulo", "Fogo"),
		SpellLoadout.get_tile_type("Pentagono", "Terra"),
		SpellLoadout.get_tile_type("Circulo", "Agua"),
	]

	Combat.start_combat(player_types, player_hp_each, enemy_types, enemy_hp_each, 3)


func _on_units_changed(player_units: Array, enemy_units: Array) -> void:
	player_units_row.set_units(player_units)
	enemy_units_row.set_units(enemy_units)


func _on_tics_changed(remaining: int, max_tics: int) -> void:
	tics_label.text = "Tics: %d/%d" % [remaining, max_tics]


func _on_turn_started(is_player: bool) -> void:
	turn_label.text = "Seu turno" if is_player else "Turno do oponente..."


func _on_log_message(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func _on_combat_ended(player_won: bool) -> void:
	turn_label.text = "Vitória!" if player_won else "Derrota..."
	board.can_swipe = false
