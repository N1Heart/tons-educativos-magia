class_name TileType
extends Resource

## Representa um "feitiço" no tabuleiro: uma forma geométrica associada a uma cor/elemento.
## Cada combinação (forma + cor) é um tipo de peça diferente para fins de match-3.

@export var element_name: String = ""      # Ex: "Fogo", "Gelo", "Raio", "Cura", "Terra", "Tempo"
@export var shape_name: String = ""        # Ex: "Triangulo", "Quadrado", "Pentagono", "Hexagono", "Circulo"
@export var shape_texture: Texture2D
@export var color: Color = Color.WHITE

## Ordem de resolução no fim do turno: 0 age primeiro, valores maiores agem por último.
## Fixo por FORMA (não depende da cor): Quadrado=0, Círculo=0, Triângulo=1, Pentágono=2, Hexágono=3.
@export var priority: int = 0

## Categoria da forma, usada pra saber se o efeito mira o oponente, protege o próprio lado,
## ou é uma auto-conjuração (ex: círculo).
@export_enum("Ofensivo", "Defensivo", "Auto") var category: String = "Ofensivo"

## Identificador único usado pelo match-3 pra saber se duas peças "combinam"
func get_type_id() -> String:
	return "%s_%s" % [shape_name, element_name]
