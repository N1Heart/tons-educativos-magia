class_name CombatUnit
extends RefCounted

## Uma unidade individual de combate — UMA forma (ex: "o triângulo do jogador"),
## com HP e escudo próprios. Tanto o jogador quanto o oponente são uma LISTA
## dessas, o que permite quantidade variável dos dois lados.

var shape_name: String
var tile_type: TileType
var max_hp: int
var current_hp: int
var shield: int = 0


func _init(p_tile_type: TileType, p_max_hp: int = 20) -> void:
	tile_type = p_tile_type
	shape_name = p_tile_type.shape_name
	max_hp = p_max_hp
	current_hp = p_max_hp


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> void:
	var absorbed = min(shield, amount)
	shield -= absorbed
	current_hp = max(0, current_hp - (amount - absorbed))


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)


func add_shield(amount: int) -> void:
	shield += amount
