extends Node

## Autoload "LocalDB" — persistência local em SQLite (addon godot-sqlite).
##
## Toda escrita aqui é SÍNCRONA e imediata (disco local, rápido) — chame
## direto do jogo, sem "await". A sincronização com o Nakama é separada
## (ver SyncManager) e roda em segundo plano, sem travar o jogo: cada
## escrita marca a linha como synced=0, e o SyncManager cuida do resto.
##
## Todo dado fica associado a um user_id. Use sempre get_user_id_ativo()
## pra obter esse id — funciona tanto logado (id do Nakama) quanto
## offline/convidado antes de qualquer login (id de dispositivo local
## persistido em user://device_id.txt).

var db: SQLite
const DB_PATH := "user://progresso.db"


func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()
	_criar_tabelas()


func _criar_tabelas() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS aluno_perfil (
			user_id TEXT PRIMARY KEY,
			email TEXT,
			nome TEXT,
			tipo_perfil TEXT,
			is_convidado INTEGER,
			nivel_atual INTEGER,
			codigo_turma TEXT,
			updated_at INTEGER,
			synced INTEGER DEFAULT 0
		)
	""")
	# Turma digitada sem conexão: o vínculo com o servidor fica pendente até
	# o SyncManager conseguir entrar na turma (ver SyncManager._tentar_vincular_turma).
	db.query("PRAGMA table_info(aluno_perfil)")
	var colunas_perfil: Array[String] = []
	for col in db.query_result:
		colunas_perfil.append(col["name"])
	if not colunas_perfil.has("turma_pendente"):
		db.query("ALTER TABLE aluno_perfil ADD COLUMN turma_pendente INTEGER DEFAULT 0")

	db.query("""
		CREATE TABLE IF NOT EXISTS magias_desbloqueadas (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			magia TEXT,
			desbloqueada_em INTEGER,
			synced INTEGER DEFAULT 0,
			UNIQUE(user_id, magia)
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS partidas_match3 (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			nivel_dificuldade INTEGER,
			pontuacao INTEGER,
			tempo_decorrido REAL,
			venceu INTEGER DEFAULT 0,
			jogadas INTEGER DEFAULT 0,
			latencia_media REAL DEFAULT 0,
			latencia_max REAL DEFAULT 0,
			jogado_em INTEGER,
			synced INTEGER DEFAULT 0
		)
	""")
	# Migração pra quem já tinha o banco antigo sem colunas novas
	# (CREATE TABLE IF NOT EXISTS não adiciona coluna em tabela existente).
	db.query("PRAGMA table_info(partidas_match3)")
	var colunas_partida: Array[String] = []
	for col in db.query_result:
		colunas_partida.append(col["name"])
	if not colunas_partida.has("venceu"):
		db.query("ALTER TABLE partidas_match3 ADD COLUMN venceu INTEGER DEFAULT 0")
	if not colunas_partida.has("jogadas"):
		db.query("ALTER TABLE partidas_match3 ADD COLUMN jogadas INTEGER DEFAULT 0")
	if not colunas_partida.has("latencia_media"):
		db.query("ALTER TABLE partidas_match3 ADD COLUMN latencia_media REAL DEFAULT 0")
	if not colunas_partida.has("latencia_max"):
		db.query("ALTER TABLE partidas_match3 ADD COLUMN latencia_max REAL DEFAULT 0")
	
	db.query("""
		CREATE TABLE IF NOT EXISTS desafios_respondidos (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			desafio_id TEXT,
			pergunta TEXT,
			resposta_dada TEXT,
			correta INTEGER,
			recompensa_magia TEXT,
			respondido_em INTEGER,
			synced INTEGER DEFAULT 0
		)
	""")
	# Loadout equipado (Módulo 2): qual elemento está equipado em cada forma.
	# Diferente de partidas/desafios, aqui não é histórico — é ESTADO ATUAL,
	# uma linha por forma (UNIQUE user_id+forma), sobrescrita a cada troca.
	db.query("""
		CREATE TABLE IF NOT EXISTS loadout_equipado (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			forma TEXT,
			elemento TEXT,
			atualizado_em INTEGER,
			synced INTEGER DEFAULT 0,
			UNIQUE(user_id, forma)
		)
	""")
	# Formas e elementos desbloqueados (Módulo 2) — EIXOS INDEPENDENTES de
	# propósito: o aluno desbloqueia uma forma na sala das formas e um
	# elemento na sala das cores, e depois recombina os dois livremente
	# na tela de loadout (ver TelaLoadout.gd).
	db.query("""
		CREATE TABLE IF NOT EXISTS formas_desbloqueadas (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			forma TEXT,
			desbloqueada_em INTEGER,
			synced INTEGER DEFAULT 0,
			UNIQUE(user_id, forma)
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS elementos_desbloqueados (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			elemento TEXT,
			desbloqueado_em INTEGER,
			synced INTEGER DEFAULT 0,
			UNIQUE(user_id, elemento)
		)
	""")
	# Histórico de provas respondidas (uma linha por TENTATIVA, não por
	# pergunta — perguntas individuais não têm valor de longo prazo aqui;
	# quem quiser esse detalhe usa desafios_respondidos).
	db.query("""
		CREATE TABLE IF NOT EXISTS quizzes_respondidos (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id TEXT,
			quiz_id TEXT,
			tipo TEXT,
			alvo TEXT,
			acertos INTEGER,
			total INTEGER,
			passou INTEGER,
			respondido_em INTEGER,
			synced INTEGER DEFAULT 0
		)
	""")

# --- Identidade ativa (logado ou convidado offline) ---

## Identidade usada como chave de TODO o banco local. Convidado: id derivado
## do computador + nome do personagem (vale online e offline, então o
## progresso não muda de dono quando a conexão vai e volta). Conta
## cadastrada: o id do usuário no Nakama.
func get_user_id_ativo() -> String:
	if NakamaManager.convidado_id_ativo != "":
		return NakamaManager.convidado_id_ativo
	if NakamaManager.session != null:
		return NakamaManager.session.user_id
	return _get_ou_criar_device_id()


## Id estável deste computador (arquivo user://device_id.txt).
func get_id_dispositivo() -> String:
	return _get_ou_criar_device_id()


## Personagens de convidado já criados neste computador (id começa com 'prefixo').
func listar_personagens_convidado(prefixo: String) -> Array:
	db.query_with_bindings(
		"SELECT user_id, nome FROM aluno_perfil WHERE is_convidado = 1 AND substr(user_id, 1, ?) = ? ORDER BY updated_at DESC",
		[prefixo.length(), prefixo])
	var lista: Array = []
	for row in db.query_result:
		lista.append({"id": row["user_id"], "nome": row["nome"]})
	return lista


func marcar_turma_pendente(user_id: String, pendente: bool) -> void:
	db.query_with_bindings("UPDATE aluno_perfil SET turma_pendente = ? WHERE user_id = ?", [1 if pendente else 0, user_id])


func turma_pendente(user_id: String) -> bool:
	db.query_with_bindings("SELECT turma_pendente FROM aluno_perfil WHERE user_id = ?", [user_id])
	return not db.query_result.is_empty() and db.query_result[0]["turma_pendente"] == 1


func _get_ou_criar_device_id() -> String:
	var path := "user://device_id.txt"
	if FileAccess.file_exists(path):
		return FileAccess.open(path, FileAccess.READ).get_as_text().strip_edges()

	var novo_id := "convidado_%d_%d" % [Time.get_unix_time_from_system(), randi()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(novo_id)
	return novo_id

# --- Perfil do aluno ---

func salvar_perfil(aluno: AlunoModel) -> void:
	db.query_with_bindings("SELECT user_id FROM aluno_perfil WHERE user_id = ?", [aluno.id])
	var eh_perfil_novo := db.query_result.is_empty()

	db.query_with_bindings("""
		INSERT INTO aluno_perfil (user_id, email, nome, tipo_perfil, is_convidado, nivel_atual, codigo_turma, updated_at, synced)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
		ON CONFLICT(user_id) DO UPDATE SET
			email = excluded.email,
			nome = excluded.nome,
			tipo_perfil = excluded.tipo_perfil,
			is_convidado = excluded.is_convidado,
			nivel_atual = excluded.nivel_atual,
			codigo_turma = excluded.codigo_turma,
			updated_at = excluded.updated_at,
			synced = 0
	""", [
		aluno.id, aluno.email, aluno.nome, aluno.tipo_perfil,
		1 if aluno.is_convidado else 0, aluno.nivel_atual, aluno.codigo_turma,
		Time.get_unix_time_from_system()
	])

	for magia in aluno.magias_desbloqueadas:
		desbloquear_magia(aluno.id, magia)

	if eh_perfil_novo:
		garantir_kit_inicial(aluno.id)

	SyncManager.request_sync()

const KIT_INICIAL_FORMAS: Array[String] = ["Quadrado", "Triangulo", "Circulo"]
const KIT_INICIAL_ELEMENTOS: Array[String] = ["Agua", "Fogo", "Terra"]

## Idempotente (INSERT OR IGNORE): pode chamar quantas vezes quiser. Também
## serve de "migração" pra perfis que já existiam com o kit antigo.
func garantir_kit_inicial(user_id: String) -> void:
	for forma in KIT_INICIAL_FORMAS:
		desbloquear_forma(user_id, forma)
	for elemento in KIT_INICIAL_ELEMENTOS:
		desbloquear_elemento(user_id, elemento)

func carregar_perfil(user_id: String) -> AlunoModel:
	db.query_with_bindings("SELECT * FROM aluno_perfil WHERE user_id = ?", [user_id])
	if db.query_result.is_empty():
		return null

	var row: Dictionary = db.query_result[0]
	var aluno := AlunoModel.new()
	aluno.id = row["user_id"]
	aluno.email = row["email"]
	aluno.nome = row["nome"]
	aluno.tipo_perfil = row["tipo_perfil"]
	aluno.is_convidado = row["is_convidado"] == 1
	aluno.nivel_atual = row["nivel_atual"]
	aluno.codigo_turma = row["codigo_turma"]
	aluno.magias_desbloqueadas = listar_magias_desbloqueadas(user_id)
	return aluno

# --- Magias desbloqueadas ---

func desbloquear_magia(user_id: String, magia: String) -> void:
	db.query_with_bindings("""
		INSERT OR IGNORE INTO magias_desbloqueadas (user_id, magia, desbloqueada_em, synced)
		VALUES (?, ?, ?, 0)
	""", [user_id, magia, Time.get_unix_time_from_system()])
	SyncManager.request_sync()


func listar_magias_desbloqueadas(user_id: String) -> Array[String]:
	db.query_with_bindings("SELECT magia FROM magias_desbloqueadas WHERE user_id = ?", [user_id])
	var magias: Array[String] = []
	for row in db.query_result:
		magias.append(row["magia"])
	return magias

# --- Partidas de Match-3 ---

func registrar_partida(user_id: String, partida: PartidaMatch3Model) -> void:
	db.query_with_bindings("""
		INSERT INTO partidas_match3 (user_id, nivel_dificuldade, pontuacao, tempo_decorrido, venceu, jogadas, latencia_media, latencia_max, jogado_em, synced)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
	""", [
		user_id, partida.nivel_dificuldade, partida.pontuacao, partida.tempo_decorrido,
		1 if partida.venceu else 0, partida.jogadas, partida.latencia_media, partida.latencia_max,
		Time.get_unix_time_from_system()
	])
	SyncManager.request_sync()


func listar_partidas(user_id: String) -> Array[PartidaMatch3Model]:
	db.query_with_bindings("SELECT * FROM partidas_match3 WHERE user_id = ? ORDER BY id DESC", [user_id])
	var partidas: Array[PartidaMatch3Model] = []
	for row in db.query_result:
		var p := PartidaMatch3Model.new()
		p.nivel_dificuldade = row["nivel_dificuldade"]
		p.pontuacao = row["pontuacao"]
		p.tempo_decorrido = row["tempo_decorrido"]
		p.venceu = row.get("venceu", 0) == 1
		p.jogadas = int(row.get("jogadas", 0))
		p.latencia_media = float(row.get("latencia_media", 0.0))
		p.latencia_max = float(row.get("latencia_max", 0.0))
		partidas.append(p)
	return partidas


const NIVEL_DIFICULDADE_MAX := 5


## Ajuste automático de dificuldade (RF3): sem nenhuma configuração do
## professor, o próximo nível sai do histórico do aluno. Vitória sobe 1;
## duas derrotas seguidas descem 1; o resto mantém. Fica entre 1 e o máximo.
func proximo_nivel_dificuldade(user_id: String) -> int:
	var partidas := listar_partidas(user_id)  # mais recente primeiro
	if partidas.is_empty():
		return 1
	var ultima := partidas[0]
	var nivel := ultima.nivel_dificuldade
	if ultima.venceu:
		nivel += 1
	elif partidas.size() >= 2 and not partidas[1].venceu:
		nivel -= 1
	return clampi(nivel, 1, NIVEL_DIFICULDADE_MAX)

# --- Desafios / quizzes respondidos ---

func registrar_resposta_desafio(user_id: String, desafio_id: String, desafio: DesafioQuizModel, resposta_dada: String, correta: bool) -> void:
	db.query_with_bindings("""
		INSERT INTO desafios_respondidos (user_id, desafio_id, pergunta, resposta_dada, correta, recompensa_magia, respondido_em, synced)
		VALUES (?, ?, ?, ?, ?, ?, ?, 0)
	""", [
		user_id, desafio_id, desafio.pergunta, resposta_dada,
		1 if correta else 0, desafio.recompensa_magia,
		Time.get_unix_time_from_system()
	])

	if correta and desafio.recompensa_magia != "":
		desbloquear_magia(user_id, desafio.recompensa_magia)

	SyncManager.request_sync()


func ja_respondeu_desafio(user_id: String, desafio_id: String) -> bool:
	db.query_with_bindings("SELECT id FROM desafios_respondidos WHERE user_id = ? AND desafio_id = ?", [user_id, desafio_id])
	return not db.query_result.is_empty()

# --- Provas (QuizModel) — Módulo 2 ---

## Registra a tentativa E aplica o desbloqueio se passou. 'resultado' é o
## Dictionary devolvido por QuizModel.calcular_resultado().
func registrar_resultado_quiz(user_id: String, quiz: QuizModel, resultado: Dictionary) -> void:
	db.query_with_bindings("""
		INSERT INTO quizzes_respondidos (user_id, quiz_id, tipo, alvo, acertos, total, passou, respondido_em, synced)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
	""", [
		user_id, quiz.id, quiz.tipo, quiz.alvo,
		resultado["acertos"], resultado["total"], 1 if resultado["passou"] else 0,
		Time.get_unix_time_from_system()
	])

	if resultado["passou"]:
		if quiz.tipo == "forma":
			desbloquear_forma(user_id, quiz.alvo)
		elif quiz.tipo == "elemento":
			desbloquear_elemento(user_id, quiz.alvo)

	SyncManager.request_sync()


func ja_passou_quiz(user_id: String, tipo: String, alvo: String) -> bool:
	db.query_with_bindings("""
		SELECT id FROM quizzes_respondidos WHERE user_id = ? AND tipo = ? AND alvo = ? AND passou = 1
	""", [user_id, tipo, alvo])
	return not db.query_result.is_empty()

# --- Formas e elementos desbloqueados (Módulo 2 — eixos independentes) ---

func desbloquear_forma(user_id: String, forma: String) -> void:
	db.query_with_bindings("""
		INSERT OR IGNORE INTO formas_desbloqueadas (user_id, forma, desbloqueada_em, synced)
		VALUES (?, ?, ?, 0)
	""", [user_id, forma, Time.get_unix_time_from_system()])
	SyncManager.request_sync()


func listar_formas_desbloqueadas(user_id: String) -> Array[String]:
	db.query_with_bindings("SELECT forma FROM formas_desbloqueadas WHERE user_id = ?", [user_id])
	var formas: Array[String] = []
	for row in db.query_result:
		formas.append(row["forma"])
	return formas


func forma_desbloqueada(user_id: String, forma: String) -> bool:
	db.query_with_bindings("SELECT id FROM formas_desbloqueadas WHERE user_id = ? AND forma = ?", [user_id, forma])
	return not db.query_result.is_empty()


func desbloquear_elemento(user_id: String, elemento: String) -> void:
	db.query_with_bindings("""
		INSERT OR IGNORE INTO elementos_desbloqueados (user_id, elemento, desbloqueado_em, synced)
		VALUES (?, ?, ?, 0)
	""", [user_id, elemento, Time.get_unix_time_from_system()])
	SyncManager.request_sync()


func listar_elementos_desbloqueados(user_id: String) -> Array[String]:
	db.query_with_bindings("SELECT elemento FROM elementos_desbloqueados WHERE user_id = ?", [user_id])
	var elementos: Array[String] = []
	for row in db.query_result:
		elementos.append(row["elemento"])
	return elementos


func elemento_desbloqueado(user_id: String, elemento: String) -> bool:
	db.query_with_bindings("SELECT id FROM elementos_desbloqueados WHERE user_id = ? AND elemento = ?", [user_id, elemento])
	return not db.query_result.is_empty()

# --- Loadout equipado (Módulo 2) ---

func salvar_equipado(user_id: String, forma: String, elemento: String) -> void:
	db.query_with_bindings("""
		INSERT INTO loadout_equipado (user_id, forma, elemento, atualizado_em, synced)
		VALUES (?, ?, ?, ?, 0)
		ON CONFLICT(user_id, forma) DO UPDATE SET
			elemento = excluded.elemento,
			atualizado_em = excluded.atualizado_em,
			synced = 0
	""", [user_id, forma, elemento, Time.get_unix_time_from_system()])
	SyncManager.request_sync()


## Retorna {"Forma": "Elemento", ...} só com o que esse usuário já salvou —
## formas ausentes ficam por conta do valor padrão definido em SpellLoadout.
func carregar_loadout(user_id: String) -> Dictionary:
	db.query_with_bindings("SELECT forma, elemento FROM loadout_equipado WHERE user_id = ?", [user_id])
	var loadout := {}
	for row in db.query_result:
		loadout[row["forma"]] = row["elemento"]
	return loadout

# --- Suporte à sincronização (usado pelo SyncManager) ---

func listar_pendentes(tabela: String, user_id: String) -> Array:
	db.query_with_bindings("SELECT * FROM %s WHERE user_id = ? AND synced = 0" % tabela, [user_id])
	return db.query_result.duplicate(true)


func marcar_sincronizado(tabela: String, id: int) -> void:
	db.query_with_bindings("UPDATE %s SET synced = 1 WHERE id = ?" % tabela, [id])


func marcar_perfil_sincronizado(user_id: String) -> void:
	db.query_with_bindings("UPDATE aluno_perfil SET synced = 1 WHERE user_id = ?", [user_id])
