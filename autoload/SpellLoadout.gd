extends Node

## Autoload "SpellLoadout" — substitui o antigo PlayerLoadout do protótipo.
##
## Gera, sob demanda, um TileType (forma + elemento) para qualquer uma das
## 5 formas x 6 elementos = 30 combinações possíveis, sem precisar de 30
## arquivos .tres feitos à mão. O jogador troca o elemento equipado em cada
## forma pela tela de inventário (set_equipped) — o tabuleiro sempre usa o
## elemento ATUALMENTE equipado ao spawnar/repor peças daquela forma.
##
## Prioridade e categoria continuam fixas por FORMA (não dependem do elemento
## equipado), replicando o que já estava definido nos resources originais do
## tons-educativos-magia: Quadrado/Círculo=0, Triângulo=1, Pentágono=2, Hexágono=3.

signal loadout_changed(shape_name: String, element_name: String)

const SHAPES: Array[String] = ["Quadrado", "Triangulo", "Pentagono", "Hexagono", "Circulo"]
const ELEMENTS: Array[String] = ["Fogo", "Agua", "Eletricidade", "Terra", "Cura", "Tempo"]

const MIN_FORMAS_COMBATE := 3
const MIN_ELEMENTOS_COMBATE := 3

const SHAPE_TEXTURE_PATHS := {
	"Quadrado": "res://assets/pecasEditaveis/quadrado.png",
	"Triangulo": "res://assets/pecasEditaveis/triangulo.png",
	"Pentagono": "res://assets/pecasEditaveis/pentagono.png",
	"Hexagono": "res://assets/pecasEditaveis/hexagono.png",
	"Circulo": "res://assets/pecasEditaveis/circulo.png",
}

const SHAPE_PRIORITY := {
	"Quadrado": 0, "Circulo": 0, "Triangulo": 1, "Pentagono": 2, "Hexagono": 3,
}

## Categoria da FORMA — decide o que o feitiço faz (exceto quando o elemento é
## "Tempo", que sobrescreve tudo com efeitos de status próprios — ver combat.gd).
const SHAPE_CATEGORY := {
	"Triangulo": "dano_rapido",
	"Quadrado": "defesa_rapida",
	"Pentagono": "dano_forte",
	"Hexagono": "defesa_forte",
	"Circulo": "auto",
}

const ELEMENT_COLORS := {
	"Fogo": Color(0.9, 0.15, 0.15),
	"Agua": Color(0.2, 0.55, 0.95),
	"Eletricidade": Color(0.95, 0.8, 0.15),
	"Terra": Color(0.9, 0.55, 0.15),
	"Cura": Color(0.25, 0.75, 0.35),
	"Tempo": Color(0.55, 0.25, 0.75),
}

## Loadout inicial — pode ser trocado livremente depois pela tela de inventário.
## Tempo (roxo) fica de fora do padrão inicial de propósito: é um elemento
## estratégico pra equipar quando o jogador quiser, não um "sexto elemento" comum.
var equipped: Dictionary = {
	"Quadrado": "Agua",
	"Triangulo": "Fogo",
	"Pentagono": "Eletricidade",
	"Hexagono": "Cura",
	"Circulo": "Terra",
}

var _cache: Dictionary = {}  # "Forma_Elemento" -> TileType

func pode_entrar_em_combate(user_id: String) -> bool:
	return motivo_bloqueio_combate(user_id) == ""


## Texto vazio = liberado. Pensado pra virar fala de NPC quando tivermos o diálogo.
func motivo_bloqueio_combate(user_id: String) -> String:
	var n_formas := formas_disponiveis(user_id).size()
	var n_elementos := elementos_disponiveis(user_id).size()
	if n_formas < MIN_FORMAS_COMBATE:
		return "Você precisa de pelo menos %d formas (tem %d). Assista às aulas na sala das formas." % [MIN_FORMAS_COMBATE, n_formas]
	if n_elementos < MIN_ELEMENTOS_COMBATE:
		return "Você precisa de pelo menos %d cores (tem %d). Assista às aulas na sala das cores." % [MIN_ELEMENTOS_COMBATE, n_elementos]
	return ""

func get_tile_type(shape_name: String, element_name: String) -> TileType:
	var key := "%s_%s" % [shape_name, element_name]
	if _cache.has(key):
		return _cache[key]

	var t := TileType.new()
	t.shape_name = shape_name
	t.element_name = element_name
	t.color = ELEMENT_COLORS.get(element_name, Color.WHITE)
	t.priority = SHAPE_PRIORITY.get(shape_name, 0)
	# category no TileType é o enum antigo (Ofensivo/Defensivo/Auto); mantemos
	# preenchido por compatibilidade, mas quem decide o efeito real agora é
	# SHAPE_CATEGORY (dano_rapido/dano_forte/defesa_rapida/defesa_forte/auto).
	t.category = "Auto" if shape_name == "Circulo" else ("Ofensivo" if SHAPE_CATEGORY.get(shape_name, "").begins_with("dano") else "Defensivo")

	var tex_path: String = SHAPE_TEXTURE_PATHS.get(shape_name, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		t.shape_texture = load(tex_path)

	_cache[key] = t
	return t


func get_equipped_type(shape_name: String) -> TileType:
	return get_tile_type(shape_name, equipped.get(shape_name, ELEMENTS[0]))


func set_equipped(shape_name: String, element_name: String, persistir: bool = true) -> void:
	if not SHAPES.has(shape_name) or not ELEMENTS.has(element_name):
		push_warning("SpellLoadout: forma ou elemento inválido (%s / %s)" % [shape_name, element_name])
		return
	equipped[shape_name] = element_name
	loadout_changed.emit(shape_name, element_name)

	# persistir=false é usado só por carregar_equipado(), pra não regravar
	# no banco o mesmo dado que acabou de ler de lá.
	if persistir:
		LocalDB.salvar_equipado(LocalDB.get_user_id_ativo(), shape_name, element_name)


## Chame depois do login (ou ao abrir a tela de loadout) pra restaurar o que
## o jogador tinha equipado da última vez. Formas sem registro salvo mantêm
## o valor padrão de 'equipped' definido acima.
func carregar_equipado(user_id: String) -> void:
	var salvo := LocalDB.carregar_loadout(user_id)
	for forma in salvo:
		if SHAPES.has(forma) and ELEMENTS.has(salvo[forma]):
			set_equipped(forma, salvo[forma], false)


func get_category(shape_name: String) -> String:
	return SHAPE_CATEGORY.get(shape_name, "dano_rapido")

const MIN_FORMAS_TABULEIRO := 3

## Atalho de teste: true ignora os desbloqueios (libera as 5 formas e os 6 elementos).
var debug_liberar_tudo := false


func formas_disponiveis(user_id: String) -> Array[String]:
	var resultado: Array[String] = []
	var desbloqueadas := LocalDB.listar_formas_desbloqueadas(user_id)
	for forma in SHAPES:  # mantém a ordem canônica
		if debug_liberar_tudo or desbloqueadas.has(forma):
			resultado.append(forma)

	# Rede de segurança: com menos de 3 formas o tabuleiro vira um laço de
	# cascatas. Não deveria acontecer com o kit inicial, mas evita travar o jogo.
	if resultado.size() < MIN_FORMAS_TABULEIRO:
		push_warning("SpellLoadout: só %d forma(s) desbloqueada(s); completando até %d." % [resultado.size(), MIN_FORMAS_TABULEIRO])
		for forma in SHAPES:
			if not resultado.has(forma):
				resultado.append(forma)
			if resultado.size() >= MIN_FORMAS_TABULEIRO:
				break
	return resultado


func elementos_disponiveis(user_id: String) -> Array[String]:
	var resultado: Array[String] = []
	var desbloqueados := LocalDB.listar_elementos_desbloqueados(user_id)
	for elemento in ELEMENTS:
		if debug_liberar_tudo or desbloqueados.has(elemento):
			resultado.append(elemento)
	return resultado


## Se a forma estiver com um elemento que o jogador ainda não desbloqueou (ex:
## o padrão "Triangulo = Fogo"), troca pelo primeiro elemento disponível.
func normalizar_equipados(user_id: String) -> void:
	var elementos := elementos_disponiveis(user_id)
	if elementos.is_empty():
		return
	for forma in formas_disponiveis(user_id):
		if not elementos.has(equipped.get(forma, "")):
			set_equipped(forma, elementos[0])


## Chame ao entrar em qualquer cena de combate: restaura o salvo e corrige o inválido.
func preparar_para_jogo(user_id: String) -> void:
	carregar_equipado(user_id)
	normalizar_equipados(user_id)
