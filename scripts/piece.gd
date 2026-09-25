extends Node2D

## Peça do tabuleiro (protótipo) — agora carrega um TileType (forma + elemento)
## em vez de strings soltas de forma/cor. O grid ainda compara por "shape"
## (string), então mantemos esse campo como um cache conveniente sincronizado
## com tile_type.shape_name — o elemento (cor) NÃO entra no critério de match,
## só decide o efeito quando o feitiço é resolvido em combate.

var tile_type: TileType
var shape: String = ""          # cache de tile_type.shape_name, usado pelo grid.gd
var grid_position: Vector2i = Vector2i.ZERO
var matched: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D


func set_tile_type(new_type: TileType) -> void:
	tile_type = new_type
	shape = new_type.shape_name

	if sprite_2d == null:
		sprite_2d = $Sprite2D

	# A textura da forma já vem definida na própria cena (quadrado.tscn etc.);
	# só sobrescrevemos se o TileType trouxer uma (ex: gerado via SpellLoadout
	# sem passar pelas cenas fixas). O elemento tinge a peça via modulate.
	if new_type.shape_texture:
		sprite_2d.texture = new_type.shape_texture
	sprite_2d.modulate = new_type.color


func dim() -> void:
	if sprite_2d == null:
		sprite_2d = $Sprite2D
	sprite_2d.modulate.a = 0.5


func move_to(target_position: Vector2, play_sound: bool = true) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", target_position, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if sprite_2d:
		sprite_2d.scale = Vector2(1.2, 0.8)
		tween.tween_property(sprite_2d, "scale", Vector2(1, 1), 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
