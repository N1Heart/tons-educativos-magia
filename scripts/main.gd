extends Node2D

@export_subgroup("Properties")
@export var width: int = 8
@export var height: int = 5
@export var offset: int = 68

@export_subgroup("Scenes")
@export var tile_scene: PackedScene 
@export var sparkles_scene: PackedScene

@export_subgroup("Tiles")
@export var tile_types: Array[TileType]  # Cada item = uma forma geométrica + cor/elemento

@export_subgroup("Cursors")
@export var open_hand_cursor: Texture2D
@export var closed_hand_cursor: Texture2D

@onready var container = $Board
@onready var hud_player_hp = $HUD/PlayerHP
@onready var hud_monster_hp = $HUD/MonsterHP
@onready var hud_tics = $HUD/TicsLabel
@onready var hud_turn = $HUD/TurnLabel
@onready var hud_log = $HUD/LogLabel

var log_lines: Array[String] = []

# State

var grid = []
var first_touch = Vector2i(-1, -1)
var is_swapping = false
var combo_count: int = 0

# Functions

func _ready():
	
	set_cursor(open_hand_cursor)
	
	randomize()
	
	setup_grid_array() 
	center_grid_on_screen() 
	
	get_viewport().size_changed.connect(center_grid_on_screen)
	
	Combat.hp_changed.connect(_on_hp_changed)
	Combat.tics_changed.connect(_on_tics_changed)
	Combat.turn_started.connect(_on_turn_started)
	Combat.log_message.connect(_on_log_message)
	Combat.combat_ended.connect(_on_combat_ended)
	
	await process_board_state() # limpeza silenciosa inicial (com cascatas) antes do combate começar
	
	Combat.start_combat(100, 100, 3) # HP jogador, HP monstro, Tics por turno

# --- HUD ---

func _on_hp_changed(player_hp: int, monster_hp: int):
	hud_player_hp.text = "Você: %d HP" % player_hp
	hud_monster_hp.text = "Monstro: %d HP" % monster_hp

func _on_tics_changed(remaining: int, max_tics: int):
	hud_tics.text = "Tics: %d/%d" % [remaining, max_tics]

func _on_turn_started(is_player: bool):
	hud_turn.text = "Seu turno" if is_player else "Turno do monstro..."

func _on_log_message(text: String):
	log_lines.append(text)
	if log_lines.size() > 5:
		log_lines.pop_front()
	hud_log.text = "\n".join(log_lines)

func _on_combat_ended(player_won: bool):
	hud_turn.text = "Vitória!" if player_won else "Derrota..."

# Centers the board on-screen, the above conection ensures the board is centered after resizing the window

func center_grid_on_screen():
	
	container.position = get_viewport_rect().size / 2.0 - Vector2(width - 1, height - 1) * offset / 2.0

# Initialize grid

func setup_grid_array():
	
	grid = []
	for x in width:
		grid.append([])
		grid[x].resize(height)
		grid[x].fill(null)
		
	# Spawn initial pieces
	
	for x in width:
		for y in height:
			spawn_at(x, y)

# Spawn a new tile at a certain grid position

func spawn_at(x, y):
	
	var created_piece = tile_scene.instantiate() 
	var random_index = randi_range(0, tile_types.size() - 1)
	
	container.add_child(created_piece) 
	
	created_piece.set_tile_type(tile_types[random_index]) 
	created_piece.tile_pressed.connect(_on_tile_pressed) 
	created_piece.grid_position = Vector2i(x, y) 
	created_piece.position = grid_to_pixel(x, y) 
	
	grid[x][y] = created_piece

# Interaction

func _on_tile_pressed(grid_position: Vector2i):
	
	if not is_swapping and Combat.can_player_act():
		first_touch = grid_position
		set_cursor(closed_hand_cursor)

func _input(event):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if first_touch != Vector2i(-1, -1):
				var local_mouse_pos = container.get_local_mouse_position()
				calculate_swipe(local_mouse_pos)

func calculate_swipe(final_pos: Vector2):
	
	var difference = final_pos - grid_to_pixel(first_touch.x, first_touch.y)
	
	if difference.length() > 16:
		var other_touch = first_touch
		if abs(difference.x) > abs(difference.y): # Horizontal dragging
			other_touch.x += 1 if difference.x > 0 else -1
		else: # Vertical dragging
			other_touch.y += 1 if difference.y > 0 else -1
		
		if is_within_grid(other_touch):
			handle_swap_logic(first_touch, other_touch)
			Audio.play("res://sounds/tile-swap.ogg", false, randf_range(0.8, 1.2), 0.3)
	
	set_cursor(open_hand_cursor)
	first_touch = Vector2i(-1, -1)

# Game loop

func handle_swap_logic(pos_a: Vector2i, pos_b: Vector2i):
	
	is_swapping = true
	swap_pieces(pos_a, pos_b)
	
	Combat.spend_tic() # Sempre gasta 1 Tic — a troca NUNCA é desfeita, mesmo sem match
	
	await get_tree().create_timer(0.3).timeout
	
	await process_board_state() # Limpa e enfileira feitiços se houve match; se não, só libera o tabuleiro
	
	# Só agora (com a última jogada já enfileirada, cascatas incluídas) é seguro fechar o turno.
	if Combat.is_player_turn and Combat.tics_remaining <= 0:
		Combat.end_player_turn()

func swap_pieces(a: Vector2i, b: Vector2i):
	
	var piece_a = grid[a.x][a.y]
	var piece_b = grid[b.x][b.y]
	
	if piece_a and piece_b:
		grid[a.x][a.y] = piece_b
		grid[b.x][b.y] = piece_a
		
		piece_a.grid_position = b
		piece_b.grid_position = a
		
		piece_a.move_to(grid_to_pixel(b.x, b.y), false)
		piece_b.move_to(grid_to_pixel(a.x, a.y), false)

## Detecta as combinações como GRUPOS (cada grupo = uma linha/coluna de mesmo tipo),
## preservando o tamanho real do combo (3, 4, 5+) pra virar um SpellCast correto.
func find_match_groups() -> Array:
	
	var groups = []
	
	# Horizontal
	for y in height:
		var run = [grid[0][y]]
		for x in range(1, width):
			var prev = grid[x - 1][y]
			var curr = grid[x][y]
			if prev and curr and prev.type == curr.type:
				run.append(curr)
			else:
				if run.size() >= 3:
					groups.append(run.duplicate())
				run = [curr]
		if run.size() >= 3:
			groups.append(run.duplicate())
	
	# Vertical
	for x in width:
		var run = [grid[x][0]]
		for y in range(1, height):
			var prev = grid[x][y - 1]
			var curr = grid[x][y]
			if prev and curr and prev.type == curr.type:
				run.append(curr)
			else:
				if run.size() >= 3:
					groups.append(run.duplicate())
				run = [curr]
		if run.size() >= 3:
			groups.append(run.duplicate())
	
	return groups

## Conjunto (sem repetição) de todas as peças que fazem parte de algum grupo — usado pra limpeza visual.
func find_matches() -> Array:
	
	var matched_dict = {}
	for group in find_match_groups():
		for p in group:
			matched_dict[p] = true
	
	return matched_dict.keys()

func process_board_state():
	
	combo_count = 0 
	var groups = find_match_groups()
	
	while groups.size() > 0:
		combo_count += 1
		Audio.play("res://sounds/tile-match.ogg", true, 1.0 + (combo_count * 0.1))
		
		var matched_pieces = {}
		for group in groups:
			# Cada grupo vira um feitiço na fila de resolução (não aplica efeito na hora)
			if Combat.combat_active:
				Combat.queue_spell("player", group[0].tile_type, group.size())
			for p in group:
				matched_pieces[p] = true
		
		for piece in matched_pieces.keys():
			var effect = sparkles_scene.instantiate()
			effect.position = piece.position
			container.add_child(effect)
			
			grid[piece.grid_position.x][piece.grid_position.y] = null
			
			var tween = piece.create_tween()
			tween.tween_property(piece, "scale", Vector2.ZERO, 0.2)
			tween.finished.connect(piece.queue_free)
		
		await get_tree().create_timer(0.3).timeout
		await collapse_columns()
		await refill_board()
		
		groups = find_match_groups()
	
	is_swapping = false

func collapse_columns():
	
	for x in width:
		for y in range(height - 1, -1, -1):
			if grid[x][y] == null:
				for k in range(y - 1, -1, -1):
					if grid[x][k] != null:
						grid[x][y] = grid[x][k]
						grid[x][k] = null
						grid[x][y].grid_position = Vector2i(x, y)
						grid[x][y].move_to(grid_to_pixel(x, y))
						break
	await get_tree().create_timer(0.3).timeout

func refill_board():
	
	for x in width:
		for y in height:
			if grid[x][y] == null:
				spawn_at(x, y)
				grid[x][y].position.y -= offset * 2 
				grid[x][y].move_to(grid_to_pixel(x, y))
	await get_tree().create_timer(0.3).timeout

# Utilities for coordinates

func grid_to_pixel(column: int, row: int) -> Vector2:
	
	return Vector2(offset * column, offset * row)

func is_within_grid(pos: Vector2i) -> bool:
	
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

# Utilities

func set_cursor(cursor_texture: Texture2D):
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
