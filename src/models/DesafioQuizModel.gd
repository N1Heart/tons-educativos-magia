class_name DesafioQuizModel
extends RefCounted

var pergunta: String = ""
var resposta_correta: String = ""
var recompensa_magia: String = ""

func exportar_para_dicionario() -> Dictionary:
	return {
		"pergunta": pergunta,
		"respostaCorreta": resposta_correta,
		"recompensaMagia": recompensa_magia
	}
