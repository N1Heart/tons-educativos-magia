class_name QuizModel
extends RefCounted

## A "prova" da sala de aula (interação com o professor) — um conjunto de
## perguntas (objetiva + V/F). Passar desbloqueia UM alvo (uma forma OU um
## elemento — nunca os dois juntos: são eixos independentes que o aluno
## recombina livremente depois na tela de loadout).

var id: String = ""          # ex: "prova_forma_pentagono", "prova_elemento_fogo"
var tipo: String = "forma"   # "forma" ou "elemento" — o que passar desbloqueia
var alvo: String = ""        # ex: "Pentagono" ou "Fogo"
var perguntas: Array[DesafioQuizModel] = []
var nota_de_corte: float = 0.7   # fração de acertos pra passar (padrão: 70%)


## Resultado de uma tentativa: {acertos, total, percentual, passou}.
## 'respostas_corretas' é um Array[bool], uma entrada por pergunta, NA MESMA
## ORDEM de 'perguntas' — quem chama já resolveu resposta_dada == resposta_correta
## pergunta a pergunta (a UI/tela de prova é quem compara, isso aqui só soma).
func calcular_resultado(respostas_corretas: Array) -> Dictionary:
	var total := perguntas.size()
	var acertos := 0
	for correta in respostas_corretas:
		if correta:
			acertos += 1

	var percentual := 0.0
	if total > 0:
		percentual = float(acertos) / float(total)

	return {
		"acertos": acertos,
		"total": total,
		"percentual": percentual,
		"passou": percentual >= nota_de_corte,
	}


func exportar_para_dicionario() -> Dictionary:
	var perguntas_dict := []
	for p in perguntas:
		perguntas_dict.append(p.exportar_para_dicionario())
	return {
		"id": id,
		"tipo": tipo,
		"alvo": alvo,
		"perguntas": perguntas_dict,
		"notaDeCorte": nota_de_corte,
	}


static func importar_de_dicionario(d: Dictionary) -> QuizModel:
	var q := QuizModel.new()
	q.id = d.get("id", "")
	q.tipo = d.get("tipo", "forma")
	q.alvo = d.get("alvo", "")
	q.nota_de_corte = d.get("notaDeCorte", 0.7)

	q.perguntas = []
	for pd in d.get("perguntas", []):
		var p := DesafioQuizModel.new()
		p.tipo = pd.get("tipo", "objetiva")
		p.pergunta = pd.get("pergunta", "")
		var alternativas: Array[String] = []
		for alt in pd.get("alternativas", []):
			alternativas.append(alt)
		p.alternativas = alternativas
		p.resposta_correta = pd.get("respostaCorreta", "")
		p.explicacao = pd.get("explicacao", "")
		q.perguntas.append(p)

	return q
