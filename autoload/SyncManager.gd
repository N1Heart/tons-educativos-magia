extends Node

## Autoload "SyncManager" — empurra pro Nakama (que persiste no CockroachDB
## por trás) tudo que o LocalDB marcou como pendente (synced = 0).
##
## Não conhece o schema do jogo — só sabe pegar linhas pendentes do LocalDB,
## empacotar em JSON e escrever via NakamaManager.escrever_dados(). Sem
## sessão ativa (offline, ou convidado que nunca logou), simplesmente adia:
## os dados continuam seguros no SQLite local até a próxima tentativa.

const DEBOUNCE_SECONDS := 4.0

var _timer: Timer
var _syncing := false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = DEBOUNCE_SECONDS
	_timer.timeout.connect(_do_sync)
	add_child(_timer)


## Chame depois de qualquer escrita local (o próprio LocalDB já chama isso
## sozinho em todos os seus métodos de escrita — normalmente você não
## precisa chamar na mão). Várias escritas seguidas (ex: partida + quiz +
## magia desbloqueada no mesmo instante) disparam UMA sincronização só,
## alguns segundos depois — evita bater na rede repetidamente.
func request_sync() -> void:
	_timer.start()


func _do_sync() -> void:
	if _syncing:
		return
	if NakamaManager.session == null:
		return  # offline / não logado — tenta de novo na próxima request_sync()

	_syncing = true
	var user_id: String = NakamaManager.session.user_id

	await _sync_perfil(user_id)
	await _sync_tabela("magias_desbloqueadas", user_id, "progresso_magias")
	await _sync_tabela("partidas_match3", user_id, "progresso_partidas")
	await _sync_tabela("desafios_respondidos", user_id, "progresso_desafios")

	_syncing = false


func _sync_perfil(user_id: String) -> void:
	var aluno = LocalDB.carregar_perfil(user_id)
	if aluno == null:
		return

	var ok: bool = await NakamaManager.escrever_dados("progresso_perfil", user_id, aluno.exportar_para_dicionario())
	if ok:
		LocalDB.marcar_perfil_sincronizado(user_id)


## Escreve CADA linha pendente como o seu próprio storage object (chave =
## id da linha, que é globalmente único por ser AUTOINCREMENT no SQLite).
##
## Importante: antes isso escrevia tudo numa chave única (collection, user_id),
## o que fazia cada sincronização SOBRESCREVER o histórico já salvo no Nakama
## com só o lote pendente do momento — partidas e respostas de desafio
## anteriores desapareciam do servidor (o SQLite local continuava íntegro,
## só o espelho no Nakama é que ficava incompleto). Uma chave por linha evita
## isso: nada é sobrescrito, só adicionado.
func _sync_tabela(tabela: String, user_id: String, colecao: String) -> void:
	var pendentes: Array = LocalDB.listar_pendentes(tabela, user_id)
	for row in pendentes:
		var chave := str(row["id"])
		var ok: bool = await NakamaManager.escrever_dados(colecao, chave, row)
		if ok:
			LocalDB.marcar_sincronizado(tabela, row["id"])
