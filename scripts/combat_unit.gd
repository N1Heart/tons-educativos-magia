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
## Verdadeiro quando o escudo acabou de ser destruído por Eletricidade; a UI
## lê (e limpa) isso pra piscar a barra de escudo.
var escudo_quebrado: bool = false


func _init(p_tile_type: TileType, p_max_hp: int = 20) -> void:
	tile_type = p_tile_type
	shape_name = p_tile_type.shape_name
	max_hp = p_max_hp
	current_hp = p_max_hp


func is_alive() -> bool:
	return current_hp > 0


## `quebra_escudo` (Eletricidade): destrói o escudo inteiro e o dano passa
## cheio para o HP. Devolve quanto de escudo foi destruído.
func take_damage(amount: int, quebra_escudo: bool = false) -> int:
	if quebra_escudo:
		var destruido := shield
		if destruido > 0:
			shield = 0
			escudo_quebrado = true
		current_hp = max(0, current_hp - amount)
		return destruido
	var absorbed = min(shield, amount)
	shield -= absorbed
	current_hp = max(0, current_hp - (amount - absorbed))
	return 0


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)


func add_shield(amount: int) -> void:
	shield += amount
