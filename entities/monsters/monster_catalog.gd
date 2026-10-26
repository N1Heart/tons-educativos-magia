class_name MonsterCatalog
extends RefCounted

## Catálogo das criaturas: todas as cenas de entities/monsters/ que usam o
## script Monster (menos o molde). Cada cena informa o nome (nome_exibicao) e a
## faixa (LOW / MID / HIGH); criar uma criatura nova basta salvar a cena na
## pasta, sem lista para atualizar. Cenas sem nome_exibicao são tratadas como
## incompletas e ignoradas (com um aviso no console).

const PASTA := "res://entities/monsters/"
const MOLDE := "monsterTemplate.tscn"

## Provisório: nível de dificuldade (1..LocalDB.NIVEL_DIFICULDADE_MAX) -> faixa.
## É o único lugar a mudar quando a progressão do quintal for revista.
const NIVEL_ATE_LOW := 2
const NIVEL_ATE_MID := 4

static var _cache: Array = []   # [{cena: PackedScene, nome: String, faixa: int}]
static var _carregado := false


static func faixa_para_nivel(nivel: int) -> int:
	if nivel <= NIVEL_ATE_LOW:
		return Monster.Faixa.LOW
	if nivel <= NIVEL_ATE_MID:
		return Monster.Faixa.MID
	return Monster.Faixa.HIGH


## Todas as criaturas válidas, ordenadas pelo caminho da cena (ordem estável,
## igual em todos os computadores).
static func listar() -> Array:
	if _carregado:
		return _cache
	_cache = []
	var caminhos: Array[String] = []
	var dir := DirAccess.open(PASTA)
	if dir != null:
		for arquivo in dir.get_files():
			# No jogo exportado as cenas aparecem como "x.tscn.remap".
			var nome_arquivo := arquivo.trim_suffix(".remap")
			if nome_arquivo.ends_with(".tscn") and nome_arquivo != MOLDE:
				caminhos.append(PASTA + nome_arquivo)
	caminhos.sort()
	for caminho in caminhos:
		var cena := load(caminho) as PackedScene
		if cena == null:
			continue
		var amostra := cena.instantiate()
		if amostra is Monster:
			var m := amostra as Monster
			if m.nome_exibicao.strip_edges() == "":
				push_warning("Criatura sem nome_exibicao, ignorada: " + caminho)
			else:
				_cache.append({"cena": cena, "nome": m.nome_exibicao.strip_edges(), "faixa": int(m.faixa)})
		amostra.free()
	_carregado = true
	return _cache


## Escolhe uma criatura para o nível. 'semente' >= 0 dá sempre a mesma escolha
## (usado no PvE em equipe, para todos verem o mesmo monstro); -1 sorteia.
## Se a faixa do nível não tem criatura, usa a mais próxima que tiver.
## Devolve {} se não houver nenhuma criatura cadastrada.
static func escolher(nivel: int, semente: int = -1) -> Dictionary:
	var todas := listar()
	if todas.is_empty():
		return {}
	var alvo := faixa_para_nivel(nivel)
	var melhor_dist := 99
	for c in todas:
		melhor_dist = mini(melhor_dist, absi(int(c["faixa"]) - alvo))
	var candidatas := todas.filter(func(c): return absi(int(c["faixa"]) - alvo) == melhor_dist)
	var i := randi() % candidatas.size() if semente < 0 else semente % candidatas.size()
	return candidatas[i]
