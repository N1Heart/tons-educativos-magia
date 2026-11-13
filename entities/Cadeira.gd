extends Node2D

## Cadeira da sala de aula: interagir (E) abre o menu de AULAS (repetível,
## não vale nota). A prova é feita falando com o professor.
## O ColorRect + Label são só marcadores visuais até existir o sprite.

@export var tipo: String = "formas"  # "formas" ou "cores"
@export var nome_exibicao: String = "Professor"
@export var retrato: Texture2D

const Indicador := preload("res://entities/IndicadorInteracao.gd")
var _indicador: Node = null


func _ready() -> void:
	var provisorio := get_node_or_null("Label")  # o balão substitui o rótulo provisório
	if provisorio != null:
		provisorio.visible = false
	_indicador = Indicador.new()
	add_child(_indicador)
	_indicador.configurar("Cadeira", "Assistir à aula de %s" % tipo, 30.0)


## Chamado pelo jogador: este é (ou deixou de ser) o objeto que o E aciona.
func definir_destaque(ativo: bool) -> void:
	_indicador.definir_ativo(ativo)


func interagir() -> void:
	FluxoSala.iniciar(self, "aula", tipo, {"nome": nome_exibicao, "retrato": retrato})
