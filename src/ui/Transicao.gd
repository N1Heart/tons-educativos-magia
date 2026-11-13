extends CanvasLayer

## Autoload "Transicao" — troca de cena com fade out / fade in.
##
## Em vez de get_tree().change_scene_to_file(caminho), use:
##   Transicao.ir_para(caminho)
## A tela escurece, a cena muda e a nova cena aparece clareando. Durante o
## fade os cliques ficam bloqueados (não dá para apertar duas vezes), e uma
## segunda chamada enquanto uma troca está em andamento é ignorada.

const DURACAO_SAIDA := 0.25
const DURACAO_ENTRADA := 0.35
const COR := Color(0.04, 0.03, 0.08)  # quase preto, levemente arroxeado

var _cortina: ColorRect
var _ocupado := false


func _ready() -> void:
	layer = 200  # acima do MenuPausa (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cortina = ColorRect.new()
	_cortina.color = COR
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.modulate.a = 0.0
	add_child(_cortina)


func ocupado() -> bool:
	return _ocupado


## Fade out → troca de cena → fade in.
## com_saida = false: escurece de uma vez e troca já no próximo quadro. Usado
## na entrada dos duelos em rede, onde mensagens do outro jogador podem chegar
## logo depois da troca e não podem esperar o fade out.
func ir_para(caminho: String, com_saida: bool = true) -> void:
	if _ocupado:
		return
	_ocupado = true
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	if com_saida:
		await _fade(1.0, DURACAO_SAIDA)
	else:
		_cortina.modulate.a = 1.0

	var erro := get_tree().change_scene_to_file(caminho)
	if erro != OK:
		push_warning("Transicao: não foi possível abrir %s (erro %d)" % [caminho, erro])
	# A cena nova só existe depois de alguns quadros.
	await get_tree().process_frame
	await get_tree().process_frame

	await _fade(0.0, DURACAO_ENTRADA)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupado = false


func _fade(alvo: float, duracao: float) -> void:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_cortina, "modulate:a", alvo, duracao)
	await t.finished
