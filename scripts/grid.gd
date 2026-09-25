extends Node2D

## Tabuleiro (visual e interação do protótipo match-3), agora gerando peças a
## partir do SpellLoadout (matriz forma x elemento) e detectando combinações
## como GRUPOS (não um total agregado) — isso preserva o tamanho real de cada
## combo (3, 4, 5+) pra alimentar o multiplicador de efeito em combat.gd.

#variaveis do grid
@export var width: int = 9
@export var height: int = 11
@export var x_start: int = 440
@export var y_start: int = 280
@export var offset: int = 20

#peças do array — pink_piece fica de fora por enquanto (ainda sem papel definido)
var possible_pieces = [
	preload("res://scenes/pecas/quadrado.tscn"),
	preload("res://scenes/pecas/triangulo.tscn"),
	preload("res://scenes/pecas/pentagono.tscn"),
	preload("res://scenes/pecas/hexagono.tscn"),
	preload("res://scenes/pecas/circulo.tscn"),
]

var piece_shape_map: Dictionary = {
	possible_pieces[0]: "Quadrado",
	possible_pieces[1]: "Triangulo",
	possible_pieces[2]: "Pentagono",
	possible_pieces[3]: "Hexagono",
	possible_pieces[4]: "Circulo",
}

## Emitido uma vez por GRUPO de match encontrado (não uma vez por resolução
## inteira) — cada grupo já sai pronto pra virar um SpellCast em combat.gd.
signal spell_matched(tile_type: TileType, match_size: int)

## Sinais de turno — combat.gd escuta os dois pra saber quando gastar 1 Tic
## (a cada troca) e quando o tabuleiro ficou parado sem match (fim da cascata).
signal player_moved
signal board_idle

#peças na cena
var all_pieces = []

#variavel do toque
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controling = false
var can_swipe = true


func _ready() -> void:
	all_pieces = make_2d_array()
	spawn_pices()


func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array


func spawn_pices() -> void:
	for i in width:
		for j in height:
			var rand = randi() % possible_pieces.size()
			var piece_scene = possible_pieces[rand]
			var piece = piece_scene.instantiate()

			var shape_name: String = piece_shape_map[piece_scene]
			piece.set_tile_type(SpellLoadout.get_equipped_type(shape_name))

			var loops = 0
			while match_at(i, j, piece.shape) and loops < 100:
				piece.queue_free()
				rand = randi() % possible_pieces.size()
				piece_scene = possible_pieces[rand]
				piece = piece_scene.instantiate()

				shape_name = piece_shape_map[piece_scene]
				piece.set_tile_type(SpellLoadout.get_equipped_type(shape_name))
				loops += 1

			add_child(piece)
			piece.position = grid_to_pixel(i, j)
			piece.grid_position = Vector2i(i, j)
			all_pieces[i][j] = piece


func match_at(i, j, shape):
	if i > 1:
		if all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].shape == shape and all_pieces[i - 2][j].shape == shape:
				return true
	if j > 1:
		if all_pieces[i][j - 1] != null and all_pieces[i][j - 2] != null:
			if all_pieces[i][j - 1].shape == shape and all_pieces[i][j - 2].shape == shape:
				return true


func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)


func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)


func is_in_grid(column, row):
	if column >= 0 and column < width:
		if row >= 0 and row < height:
			return true
	return false


func touch_input():
	if not can_swipe:
		return
	if Input.is_action_just_pressed("ui_touch"):
		first_touch = get_global_mouse_position()
		var grid_position = pixel_to_grid(first_touch.x, first_touch.y)
		if is_in_grid(grid_position.x, grid_position.y):
			controling = true
	if Input.is_action_just_released("ui_touch"):
		final_touch = get_global_mouse_position()
		var grid_position = pixel_to_grid(final_touch.x, final_touch.y)
		if is_in_grid(grid_position.x, grid_position.y) and controling:
			touch_difference(pixel_to_grid(first_touch.x, first_touch.y), grid_position)
			controling = false


func swap_pieces(column: int, row: int, direction: Vector2i) -> void:
	var target_column = column + direction.x
	var target_row = row + direction.y

	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[target_column][target_row]

	if not first_piece or not other_piece:
		return

	can_swipe = false
	player_moved.emit()  # sempre conta como 1 ação/Tic gasto, mesmo sem match

	all_pieces[column][row] = other_piece
	all_pieces[target_column][target_row] = first_piece

	if "column" in first_piece and "row" in first_piece:
		first_piece.column = target_column
		first_piece.row = target_row
		other_piece.column = column
		other_piece.row = row

	first_piece.grid_position = Vector2i(target_column, target_row)
	other_piece.grid_position = Vector2i(column, row)

	var first_target_pos = grid_to_pixel(target_column, target_row)
	var other_target_pos = grid_to_pixel(column, row)

	var tween = create_tween().set_parallel(true)

	tween.tween_property(first_piece, "position", first_target_pos, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(other_piece, "position", other_target_pos, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	find_matches()


func touch_difference(grid_1, grid_2):
	var difference = grid_1 - grid_2
	if abs(difference.x) > abs(difference.y):
		if difference.x < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(-1, 0))
	elif abs(difference.y) > abs(difference.x):
		if difference.y < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, -1))


## Detecta combinações como GRUPOS (varredura única, sem sobreposição) —
## cada grupo preserva o tamanho real do combo (3, 4, 5+).
func find_matches() -> void:
	var groups: Array = []
	var matched_pieces: Array = []

	# Horizontal
	for j in range(height):
		var run: Array = [all_pieces[0][j]]
		for i in range(1, width):
			var prev = all_pieces[i - 1][j]
			var curr = all_pieces[i][j]
			if prev and curr and prev.shape == curr.shape:
				run.append(curr)
			else:
				if run.size() >= 3:
					groups.append(run.duplicate())
				run = [curr]
		if run.size() >= 3:
			groups.append(run.duplicate())

	# Vertical
	for i in range(width):
		var run: Array = [all_pieces[i][0]]
		for j in range(1, height):
			var prev = all_pieces[i][j - 1]
			var curr = all_pieces[i][j]
			if prev and curr and prev.shape == curr.shape:
				run.append(curr)
			else:
				if run.size() >= 3:
					groups.append(run.duplicate())
				run = [curr]
		if run.size() >= 3:
			groups.append(run.duplicate())

	for group in groups:
		for piece in group:
			if piece != null and not matched_pieces.has(piece):
				matched_pieces.append(piece)

	if matched_pieces.size() > 0:
		process_matches(groups)

		for piece in matched_pieces:
			piece.matched = true
			if piece.has_method("dim"):
				piece.dim()
		get_parent().get_node("destroy_timer").start()
	else:
		can_swipe = true
		board_idle.emit()


func process_matches(groups: Array) -> void:
	print("--- COMBINAÇÃO REALIZADA (%d grupo(s)) ---" % groups.size())
	for group in groups:
		var piece = group[0]
		if piece == null or piece.tile_type == null:
			continue
		var match_size = group.size()
		print("Forma: %s | Elemento: %s | Peças: %d" % [piece.tile_type.shape_name, piece.tile_type.element_name, match_size])
		spell_matched.emit(piece.tile_type, match_size)


func _process(delta: float) -> void:
	touch_input()


func destroy_matched():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					all_pieces[i][j].queue_free()
					all_pieces[i][j] = null
	get_parent().get_node("colapse_timer").start()


func colapse_columns() -> void:
	var move_tween = create_tween().set_parallel(true)
	var has_animations = false

	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						var piece = all_pieces[i][k]
						all_pieces[i][j] = piece
						all_pieces[i][k] = null

						if "row" in piece:
							piece.row = j
						piece.grid_position = Vector2i(i, j)

						var target_pos = grid_to_pixel(i, j)
						move_tween.tween_property(piece, "position", target_pos, 0.25) \
							.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

						has_animations = true
						break

	var refilled = refill_grid(move_tween)
	if refilled:
		has_animations = true

	if has_animations:
		move_tween.finished.connect(func(): find_matches())
	else:
		move_tween.kill()
		find_matches()


func refill_grid(tween: Tween) -> bool:
	var created_pieces = false
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				created_pieces = true
				var rand = randi() % possible_pieces.size()
				var piece_scene = possible_pieces[rand]
				var piece = piece_scene.instantiate()

				var shape_name: String = piece_shape_map[piece_scene]
				piece.set_tile_type(SpellLoadout.get_equipped_type(shape_name))

				add_child(piece)

				var start_pos = grid_to_pixel(i, height + 1)
				var target_pos = grid_to_pixel(i, j)

				piece.position = start_pos
				piece.grid_position = Vector2i(i, j)
				all_pieces[i][j] = piece

				if "column" in piece and "row" in piece:
					piece.column = i
					piece.row = j

				tween.tween_property(piece, "position", target_pos, 0.3) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	return created_pieces


func _on_destroy_timer_timeout() -> void:
	destroy_matched()


func _on_colapse_timer_timeout() -> void:
	colapse_columns()
	find_matches()
