class_name AulaModel
extends RefCounted

## Conteúdo da "aula" da sala de aula (interação com a cadeira) — repetível
## à vontade, sem custo. "tipo"/"alvo" identificam QUAL forma ou elemento essa
## aula ensina, e são o elo com a QuizModel correspondente (mesmo tipo+alvo).

var id: String = ""          # ex: "aula_forma_pentagono", "aula_elemento_fogo"
var tipo: String = "forma"   # "forma" ou "elemento"
var alvo: String = ""        # ex: "Pentagono" ou "Fogo"
var titulo: String = ""
var conteudo: String = ""    # texto corrido (legado); a UI nova usa 'falas'
## A aula como sequência de falas do professor (uma caixa de diálogo cada).
## Falas muito longas são divididas em páginas pela própria CaixaDialogo.
var falas: Array[String] = []

func exportar_para_dicionario() -> Dictionary:
	return {
		"id": id,
		"tipo": tipo,
		"alvo": alvo,
		"titulo": titulo,
		"conteudo": conteudo,
		"falas": falas,
	}


static func importar_de_dicionario(d: Dictionary) -> AulaModel:
	var a := AulaModel.new()
	a.id = d.get("id", "")
	a.tipo = d.get("tipo", "forma")
	a.alvo = d.get("alvo", "")
	a.titulo = d.get("titulo", "")
	a.conteudo = d.get("conteudo", "")
	var falas_lidas: Array[String] = []
	for f in d.get("falas", []):
		falas_lidas.append(str(f))
	a.falas = falas_lidas
	return a
