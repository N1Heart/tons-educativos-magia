class_name PartidaMatch3Model
extends RefCounted

var nivel_dificuldade: int = 1
var pontuacao: int = 0
var tempo_decorrido: float = 0.0
var venceu: bool = false

## Métricas de reação (RF4): quantas jogadas o aluno fez e quanto tempo levou,
## em média e no máximo, entre o tabuleiro ficar livre e a próxima jogada.
var jogadas: int = 0
var latencia_media: float = 0.0
var latencia_max: float = 0.0

func exportar_para_dicionario() -> Dictionary:
	return {
		"nivelDificuldade": nivel_dificuldade,
		"pontuacao": pontuacao,
		"tempoDecorrido": tempo_decorrido,
		"venceu": venceu,
		"jogadas": jogadas,
		"latenciaMedia": latencia_media,
		"latenciaMax": latencia_max
	}
