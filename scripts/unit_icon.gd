extends VBoxContainer
class_name UnitIconView

## Um ícone de unidade de combate: forma (tingida pelo elemento) + barra de HP.
## Reflete o estado de UM CombatUnit — é reconstruído a cada Combat.units_changed
## (ver unit_roster.gd), não fica "vivo" entre atualizações.

@onready var icon_rect: TextureRect = $Icon
@onready var hp_bar: ProgressBar = $HPBar
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var shield_label: Label = $ShieldBar/Valor

## Escudo acima disso enche a barra; o número continua mostrando o valor real.
const ESCUDO_MAX_BARRA := 32


func set_unit(unit: CombatUnit) -> void:
	if unit.tile_type:
		if unit.tile_type.shape_texture:
			icon_rect.texture = unit.tile_type.shape_texture
		icon_rect.modulate = unit.tile_type.color

	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp

	shield_bar.max_value = ESCUDO_MAX_BARRA
	shield_bar.value = unit.shield
	shield_bar.visible = unit.shield > 0 and unit.is_alive()
	shield_label.text = str(unit.shield)
	if unit.escudo_quebrado:
		unit.escudo_quebrado = false
		_piscar_escudo_quebrado()

	modulate.a = 1.0 if unit.is_alive() else 0.35


## Escudo destruído pela Eletricidade: a barra aparece amarela por um instante e some.
func _piscar_escudo_quebrado() -> void:
	shield_bar.visible = true
	shield_bar.value = ESCUDO_MAX_BARRA
	shield_label.text = "!"
	shield_bar.modulate = Color(1.0, 0.9, 0.2)
	var t := create_tween()
	t.tween_property(shield_bar, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): shield_bar.visible = false)
