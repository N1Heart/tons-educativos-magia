class_name PartidaMatch3Model
extends RefCounted

var nivel_dificuldade: int = 1
var pontuacao: int = 0
var tempo_decorrido: float = 0.0

func exportar_para_dicionario() -> Dictionary:
	return {
		"nivelDificuldade": nivel_dificuldade,
		"pontuacao": pontuacao,
		"tempoDecorrido": tempo_decorrido
	}
