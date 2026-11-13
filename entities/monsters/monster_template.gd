extends CharacterBody2D

class_name Monster

enum Faixa { LOW, MID, HIGH }

@export var nome_exibicao: String = ""
@export var faixa: Faixa

## Tamanho do sprite no retrato do inimigo durante o combate (1 = tamanho
## original). 0 = automático: o combate mede o desenho e ajusta ao retrato.
@export var escala_combate: float = 0.0


## Área ocupada pelo desenho (ver CombatSprite.area_visivel).
func area_visivel() -> Rect2:
	return CombatSprite.area_visivel(get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D)
