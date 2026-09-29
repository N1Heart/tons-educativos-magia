extends VBoxContainer
class_name UnitIconView

## Um ícone de unidade de combate: forma (tingida pelo elemento) + barra de HP.
## Reflete o estado de UM CombatUnit — é reconstruído a cada Combat.units_changed
## (ver unit_roster.gd), não fica "vivo" entre atualizações.

@onready var icon_rect: TextureRect = $Icon
@onready var hp_bar: ProgressBar = $HPBar


func set_unit(unit: CombatUnit) -> void:
	if unit.tile_type:
		if unit.tile_type.shape_texture:
			icon_rect.texture = unit.tile_type.shape_texture
		icon_rect.modulate = unit.tile_type.color

	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp

	modulate.a = 1.0 if unit.is_alive() else 0.35
