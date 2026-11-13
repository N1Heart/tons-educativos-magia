class_name ConteudoLoader
extends RefCounted

## Carrega o conteúdo pedagógico (aula + prova) de cada forma/elemento a
## partir de res://data/conteudo/<tipo>_<alvo>.json — um arquivo por tema.
##
## Para editar uma aula ou uma pergunta basta mexer no JSON, sem tocar em
## código. ATENÇÃO ao exportar o jogo: em Project > Export > Resources, inclua
## "data/*" em "Filters to export non-resource files", senão os JSONs não vão
## pro executável.

const PASTA := "res://data/conteudo/"

## Qual tipo de conteúdo cada sala ensina (e em que ordem aparece no menu).
const ALVOS_POR_SALA := {
	"formas": ["Triangulo", "Circulo", "Quadrado", "Pentagono", "Hexagono"],
	"cores": ["Fogo", "Agua", "Eletricidade", "Terra", "Cura", "Tempo"],
}
const TIPO_POR_SALA := {
	"formas": "forma",
	"cores": "elemento",
}


static func caminho(tipo: String, alvo: String) -> String:
	return "%s%s_%s.json" % [PASTA, tipo, alvo.to_lower()]


## Dicionário cru do JSON ({} se não existir ou estiver quebrado).
static func carregar(tipo: String, alvo: String) -> Dictionary:
	var path := caminho(tipo, alvo)
	if not FileAccess.file_exists(path):
		push_error("ConteudoLoader: arquivo não encontrado: %s" % path)
		return {}

	var dados = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(dados) != TYPE_DICTIONARY:
		push_error("ConteudoLoader: JSON inválido em %s" % path)
		return {}
	return dados


static func aula(dados: Dictionary) -> AulaModel:
	return AulaModel.importar_de_dicionario(dados.get("aula", {}))


static func prova(dados: Dictionary) -> QuizModel:
	return QuizModel.importar_de_dicionario(dados.get("prova", {}))


## Nome que aparece nos menus (ex: "Vermelho (Fogo)"); cai no alvo se faltar.
static func nome_menu(dados: Dictionary, alvo: String) -> String:
	return str(dados.get("nome_menu", alvo))


## Confere a estrutura de um conteúdo; devolve a lista de problemas (vazia = ok).
static func validar(dados: Dictionary) -> Array[String]:
	var problemas: Array[String] = []
	if dados.is_empty():
		problemas.append("conteúdo vazio")
		return problemas

	var a := aula(dados)
	if a.falas.is_empty():
		problemas.append("aula sem falas")

	var q := prova(dados)
	if q.perguntas.is_empty():
		problemas.append("prova sem perguntas")
	if q.alvo == "" or q.tipo == "":
		problemas.append("prova sem tipo/alvo")

	for i in q.perguntas.size():
		var p := q.perguntas[i]
		var n := i + 1
		if p.pergunta == "":
			problemas.append("pergunta %d sem texto" % n)
		if p.tipo == "vf":
			if p.resposta_correta != "Verdadeiro" and p.resposta_correta != "Falso":
				problemas.append("pergunta %d (V/F): resposta deve ser Verdadeiro ou Falso" % n)
		elif p.tipo == "objetiva":
			if p.alternativas.size() < 2:
				problemas.append("pergunta %d: menos de 2 alternativas" % n)
			if not p.alternativas.has(p.resposta_correta):
				problemas.append("pergunta %d: resposta correta não está nas alternativas" % n)
		else:
			problemas.append("pergunta %d: tipo desconhecido '%s'" % [n, p.tipo])
	return problemas
