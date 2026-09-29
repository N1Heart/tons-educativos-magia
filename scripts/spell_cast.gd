class_name SpellCast
extends RefCounted

## Um "feitiço" gerado por uma combinação no tabuleiro, esperando a fase de resolução do turno.

var caster: String            # "player" ou "monster"
var tile_type: TileType       # forma + cor/elemento que gerou o feitiço
var match_size: int           # tamanho da combinação (3, 4, 5+)

func _init(p_caster: String, p_tile_type: TileType, p_match_size: int):
	caster = p_caster
	tile_type = p_tile_type
	match_size = p_match_size

## Prioridade de resolução: vem direto da forma (0 age primeiro, valores maiores por último)
func get_priority() -> int:
	return tile_type.priority

## Multiplicador de efeito conforme o tamanho da combinação.
## 3 peças = 1 alvo aleatório | 4 peças = alvo + adjacente | 5+ = todos os alvos.
## Em combate 1v1 (PvE simples) não há múltiplos alvos, então isso vira um multiplicador de intensidade.
func get_scale() -> float:
	if match_size >= 5:
		return 2.0
	elif match_size == 4:
		return 1.5
	else:
		return 1.0
