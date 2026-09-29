extends Node2D

## Cena de teste isolada: só pra validar tabuleiro + Combat multi-unidade
## juntos, sem depender da tela de combate visual (fase seguinte).
## Acompanhe pelo painel Output enquanto joga peças no tabuleiro.

@onready var board = $combate/grid


func _ready() -> void:
	Combat.bind_board(board)

	Combat.log_message.connect(func(text): print("[LOG] ", text))
	Combat.tics_changed.connect(func(r, m): print("[TICS] %d/%d" % [r, m]))
	Combat.turn_started.connect(func(is_player): print("[TURNO] ", "jogador" if is_player else "oponente"))
	Combat.units_changed.connect(_on_units_changed)
	Combat.combat_ended.connect(func(won): print(">>> ", "VITÓRIA" if won else "DERROTA"))

	# Time do jogador: as 5 formas, cada uma com o elemento atualmente equipado.
	var player_types: Array[TileType] = []
	for shape_name in SpellLoadout.SHAPES:
		player_types.append(SpellLoadout.get_equipped_type(shape_name))

	# Time do oponente: só 3 formas (quantidade variável) e elementos fixos, pra
	# simular um inimigo mais fraco/menor sem depender do loadout do jogador.
	var enemy_types: Array[TileType] = [
		SpellLoadout.get_tile_type("Triangulo", "Fogo"),
		SpellLoadout.get_tile_type("Pentagono", "Terra"),
		SpellLoadout.get_tile_type("Circulo", "Agua"),
	]

	Combat.start_combat(player_types, 30, enemy_types, 20, 3)


func _on_units_changed(player_units: Array, enemy_units: Array) -> void:
	print("--- STATUS ---")
	for u in player_units:
		print("  Você/%s: %d/%d HP (escudo %d)%s" % [u.shape_name, u.current_hp, u.max_hp, u.shield, "" if u.is_alive() else " [MORTO]"])
	for u in enemy_units:
		print("  Oponente/%s: %d/%d HP (escudo %d)%s" % [u.shape_name, u.current_hp, u.max_hp, u.shield, "" if u.is_alive() else " [MORTO]"])
