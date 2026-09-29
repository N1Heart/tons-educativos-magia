extends HBoxContainer
class_name UnitRoster

## Fileira de ícones (um lado do combate). Reconstrói os ícones inteiros a
## cada chamada — simples e suficiente pra um jogo por turno (a lista muda
## pouquíssimas vezes por turno, não vale a pena fazer diffing).

@export var unit_icon_scene: PackedScene


func set_units(units: Array) -> void:
	for c in get_children():
		c.queue_free()

	for u in units:
		var icon = unit_icon_scene.instantiate()
		add_child(icon)
		icon.set_unit(u)
