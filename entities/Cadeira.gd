extends Node2D

## Cadeira da sala de aula: interagir (E) abre o menu de AULAS (repetível,
## não vale nota). A prova é feita falando com o professor.
## O ColorRect + Label são só marcadores visuais até existir o sprite.

@export var tipo: String = "formas"  # "formas" ou "cores"
@export var nome_exibicao: String = "Professor"
@export var retrato: Texture2D


func interagir() -> void:
	FluxoSala.iniciar(self, "aula", tipo, {"nome": nome_exibicao, "retrato": retrato})
