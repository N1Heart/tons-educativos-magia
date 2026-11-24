extends HBoxContainer
class_name UnitRoster

## Fileira de ícones (um lado do combate). Reconstrói os ícones inteiros a
## cada chamada — simples e suficiente pra um jogo por turno (a lista muda
## pouquíssimas vezes por turno, não vale a pena fazer diffing).

@export var unit_icon_scene: PackedScene

## Largura máxima da fileira, em px (0 = sem limite). Com mais ícones do que
## cabem, eles encolhem em vez de a fileira crescer e empurrar o painel pra
## cima do tabuleiro (ex.: o adversário do PvP, com as 5 formas).
@export var largura_maxima: float = 0.0
const LARGURA_ICONE := 40.0
const LARGURA_ICONE_MIN := 22.0


func set_units(units: Array) -> void:
	for c in get_children():
		c.queue_free()

	var largura := LARGURA_ICONE
	if largura_maxima > 0.0 and not units.is_empty():
		var separacao := get_theme_constant("separation")
		largura = clampf(floorf((largura_maxima - separacao * (units.size() - 1)) / units.size()),
				LARGURA_ICONE_MIN, LARGURA_ICONE)

	for u in units:
		var icon = unit_icon_scene.instantiate()
		add_child(icon)
		if largura < LARGURA_ICONE:
			icon.definir_largura(largura)
		icon.set_unit(u)
