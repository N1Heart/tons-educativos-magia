class_name AulaModel
extends RefCounted

## Conteúdo da "aula" da sala de aula (interação com a cadeira) — repetível
## à vontade, sem custo. "tipo"/"alvo" identificam QUAL forma ou elemento essa
## aula ensina, e são o elo com a QuizModel correspondente (mesmo tipo+alvo).

var id: String = ""          # ex: "aula_forma_pentagono", "aula_elemento_fogo"
var tipo: String = "forma"   # "forma" ou "elemento"
var alvo: String = ""        # ex: "Pentagono" ou "Fogo"
var titulo: String = ""
var conteudo: String = ""    # texto da aula; pode virar Array[String] (páginas) depois se precisar

func exportar_para_dicionario() -> Dictionary:
	return {
		"id": id,
		"tipo": tipo,
		"alvo": alvo,
		"titulo": titulo,
		"conteudo": conteudo,
	}


static func importar_de_dicionario(d: Dictionary) -> AulaModel:
	var a := AulaModel.new()
	a.id = d.get("id", "")
	a.tipo = d.get("tipo", "forma")
	a.alvo = d.get("alvo", "")
	a.titulo = d.get("titulo", "")
	a.conteudo = d.get("conteudo", "")
	return a
