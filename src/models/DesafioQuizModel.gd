class_name DesafioQuizModel
extends RefCounted

## Uma pergunta isolada (usada tanto sozinha — teste do módulo 3 — quanto
## como item de uma QuizModel — prova de verdade do módulo 2).

## "objetiva" (múltipla escolha, ver 'alternativas') ou "vf" (verdadeiro/falso,
## onde resposta_correta é sempre "Verdadeiro" ou "Falso" e alternativas fica vazio).
var tipo: String = "objetiva"
var pergunta: String = ""
var alternativas: Array[String] = []   # só usado quando tipo == "objetiva"
var resposta_correta: String = ""
## "Por quê?" mostrado pelo professor depois da resposta (gabarito comentado).
var explicacao: String = ""

## Recompensa de UMA pergunta avulsa (fluxo antigo/teste, ver LocalDB.registrar_resposta_desafio).
## Perguntas dentro de uma QuizModel NÃO usam isso — a recompensa da prova
## inteira vive em QuizModel.tipo_recompensa/alvo_recompensa e só é aplicada
## se o aluno passar na prova toda (ver LocalDB.registrar_resultado_quiz).
var recompensa_magia: String = ""

func exportar_para_dicionario() -> Dictionary:
	return {
		"tipo": tipo,
		"pergunta": pergunta,
		"alternativas": alternativas,
		"respostaCorreta": resposta_correta,
		"explicacao": explicacao,
		"recompensaMagia": recompensa_magia
	}
