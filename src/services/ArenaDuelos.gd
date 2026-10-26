extends Node
class_name ArenaDuelosClass

## Autoload "ArenaDuelos" — arena de duelos amistosos entre alunos (Módulo 5).
##
## Espaço independente da sala do professor: os alunos da MESMA TURMA que
## estão na arena aparecem numa lista e um pode desafiar o outro. Quem aceita
## começa um duelo PvP simultâneo (o mesmo das atividades do professor,
## ver DueloRede), mas amistoso: não conta nas estatísticas nem na dificuldade.
##
## Por baixo é uma partida "relayed" do Nakama com nome fixo "arena_<id da
## turma>" (ou "arena_geral" para quem não tem turma): o servidor só repassa
## mensagens, não existe fila nem pareamento automático.
##
## Mensagens (op codes < 100; a partir de 100 são as do duelo, via DueloRede):
##   OP_PRESENCA  {nome, ocupado, eco}        "estou aqui" (eco = resposta a um recém-chegado)
##   OP_DESAFIO   {para, nome, rid}           convite
##   OP_RESPOSTA  {para, rid, aceito, motivo} aceitou/recusou
##   OP_CANCELAR  {para, rid}                 desisti do convite

signal lista_mudou
signal desafio_recebido(de_id: String, de_nome: String)
signal desafio_encerrado(motivo: String)        # o convite (enviado ou recebido) acabou
signal arena_perdida(motivo: String)            # a conexão caiu
signal duelo_falhou(motivo: String)             # aceito, mas o duelo não abriu
signal mensagem_recebida(op_code: int, remetente_id: String, dados: Dictionary)
signal jogador_saiu(user_id: String)

const OP_PRESENCA := 10
const OP_DESAFIO := 11
const OP_RESPOSTA := 12
const OP_CANCELAR := 13
const OP_ATIVIDADE_BASE := 100

const PREFIXO_NOME_PARTIDA := "arena_"
const TEMPO_CONVITE := 20.0

## Só para testes (bots): outro cliente/sessão e outra chave de arena.
var cliente_alternativo: NakamaClient = null
var sessao_alternativa: NakamaSession = null
var chave_alternativa: String = ""

var socket: NakamaSocket = null
var match_id: String = ""
var meu_id: String = ""
var nome_turma: String = ""
var jogadores := {}                 # user_id -> {nome, ocupado}
var ocupado := false                # estou num duelo (ou preparando um)
var atividade_dados: Dictionary = {}   # mesmo formato da sala do professor; DueloRede lê "rodada"

var _meu_nome := ""
var _enviado := {}                  # convite que eu mandei: {para, rid}
var _recebido := {}                 # convite que me mandaram: {de, nome, rid}
var _rid_esperado := 0              # duelo que está sendo combinado (para guardar mensagens adiantadas)
var _pendentes: Array = []          # mensagens do duelo que chegaram antes de eu abrir o canal


func esta_na_arena() -> bool:
	return match_id != ""


func _cliente() -> NakamaClient:
	return cliente_alternativo if cliente_alternativo != null else NakamaManager.client


func _sessao() -> NakamaSession:
	return sessao_alternativa if sessao_alternativa != null else NakamaManager.session


func convite_enviado() -> bool:
	return not _enviado.is_empty()


func convite_recebido() -> bool:
	return not _recebido.is_empty()


# --------------------------------------------------------------------- entrada

## Entra na arena da turma do aluno. Devolve "" se deu certo, senão o erro.
func entrar(p_nome: String) -> String:
	if esta_na_arena():
		return ""
	if _sessao() == null and cliente_alternativo == null:
		if NakamaManager.convidado_id_ativo != "":
			await NakamaManager.login_convidado(NakamaManager.convidado_id_ativo)
		if NakamaManager.session == null:
			return "Servidor indisponível no momento."

	var chave := chave_alternativa
	nome_turma = ""
	if chave == "":
		chave = "geral"
		if cliente_alternativo == null:
			var turmas: Array = await NakamaManager.listar_minhas_turmas()
			if not turmas.is_empty():
				chave = str(turmas[0]["id"])
				nome_turma = str(turmas[0]["nome"])

	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	_descartar_socket()
	socket = Nakama.create_socket_from(_cliente())
	var r = await socket.connect_async(_sessao())
	if r.is_exception():
		socket = null
		return "Servidor indisponível no momento."
	socket.received_match_presence.connect(_on_presenca)
	socket.received_match_state.connect(_on_estado)
	socket.closed.connect(_on_socket_fechado)
	meu_id = _sessao().user_id

	var m = await socket.create_match_async(PREFIXO_NOME_PARTIDA + chave)
	if m.is_exception():
		_descartar_socket()
		return "Servidor indisponível no momento."

	_zerar()
	match_id = m.match_id
	_meu_nome = p_nome
	jogadores[meu_id] = {"nome": p_nome, "ocupado": false}
	await _enviar(OP_PRESENCA, {"nome": p_nome, "ocupado": false, "eco": false})
	lista_mudou.emit()
	return ""


func sair() -> void:
	if esta_na_arena():
		if not _enviado.is_empty():
			await _enviar(OP_CANCELAR, _enviado)
		if socket != null:
			await socket.leave_match_async(match_id)
	_descartar_socket()
	_zerar()


func _zerar() -> void:
	match_id = ""
	jogadores = {}
	ocupado = false
	atividade_dados = {}
	_enviado = {}
	_recebido = {}
	_rid_esperado = 0
	_pendentes = []


func _descartar_socket() -> void:
	if socket != null:
		if socket.closed.is_connected(_on_socket_fechado):
			socket.closed.disconnect(_on_socket_fechado)
		socket.close()
		socket = null


func _on_socket_fechado() -> void:
	if esta_na_arena():
		_zerar()
		socket = null
		arena_perdida.emit("A conexão com o servidor caiu.")


func _enviar(op_code: int, dados: Dictionary) -> void:
	if socket == null or match_id == "":
		return
	await socket.send_match_state_async(match_id, op_code, JSON.stringify(dados))


## Mensagem do duelo (op_code >= 100), usada pelo DueloRede.
func enviar_atividade(op_code: int, dados: Dictionary) -> void:
	await _enviar(op_code, dados)


func _transmitir_presenca(eco: bool = false) -> void:
	if esta_na_arena():
		jogadores[meu_id] = {"nome": _meu_nome, "ocupado": ocupado}
		lista_mudou.emit()
		await _enviar(OP_PRESENCA, {"nome": _meu_nome, "ocupado": ocupado, "eco": eco})


## Os outros alunos da arena, ordenados por nome: [{id, nome, ocupado}].
func lista_outros() -> Array:
	var lista := []
	for id in jogadores:
		if id != meu_id:
			lista.append({"id": id, "nome": jogadores[id]["nome"], "ocupado": jogadores[id]["ocupado"]})
	lista.sort_custom(func(a, b): return str(a["nome"]).naturalnocasecmp_to(str(b["nome"])) < 0)
	return lista


## Mensagens do duelo que chegaram antes do canal ser aberto (DueloRede.preparar).
func consumir_pendentes() -> Array:
	var l := _pendentes
	_pendentes = []
	return l


# --------------------------------------------------------------------- convites

## Desafia um colega livre. Devolve "" ou o motivo de não ter enviado.
func desafiar(id: String) -> String:
	if not esta_na_arena():
		return "Você não está na arena."
	if ocupado or convite_enviado() or convite_recebido():
		return "Termine o convite em andamento antes."
	if not jogadores.has(id) or id == meu_id:
		return "Esse aluno saiu da arena."
	if jogadores[id]["ocupado"]:
		return "%s está ocupado agora." % jogadores[id]["nome"]
	_enviado = {"para": id, "rid": randi_range(1, 2000000000)}
	_rid_esperado = _enviado["rid"]
	await _enviar(OP_DESAFIO, {"para": id, "nome": _meu_nome, "rid": _enviado["rid"]})
	_expirar_convite_enviado(_enviado["rid"])
	return ""


func _expirar_convite_enviado(rid: int) -> void:
	await get_tree().create_timer(TEMPO_CONVITE).timeout
	if convite_enviado() and int(_enviado["rid"]) == rid:
		var alvo := str(_enviado["para"])
		await _enviar(OP_CANCELAR, _enviado)
		_enviado = {}
		_rid_esperado = 0
		desafio_encerrado.emit("%s não respondeu ao desafio." % _nome(alvo))


func _expirar_convite_recebido(rid: int) -> void:
	await get_tree().create_timer(TEMPO_CONVITE).timeout
	if convite_recebido() and int(_recebido["rid"]) == rid:
		await responder(false)


## Desisto do convite que enviei.
func cancelar_desafio() -> void:
	if convite_enviado():
		var c := _enviado
		_enviado = {}
		_rid_esperado = 0
		await _enviar(OP_CANCELAR, c)
		desafio_encerrado.emit("")


## Respondo ao convite que recebi.
func responder(aceitar: bool, motivo: String = "") -> void:
	if not convite_recebido():
		return
	var c := _recebido
	_recebido = {}
	if aceitar:
		_iniciar_duelo(str(c["de"]), str(c["nome"]), int(c["rid"]), false)
	else:
		_rid_esperado = 0
		desafio_encerrado.emit("")
	await _enviar(OP_RESPOSTA, {"para": c["de"], "rid": c["rid"], "aceito": aceitar, "motivo": motivo})


func _nome(id: String) -> String:
	return str(jogadores[id]["nome"]) if jogadores.has(id) else "O colega"


## Quem desafiou é o anfitrião (membro 0) do PvP. A parte síncrona vem antes
## de qualquer espera, para o canal já estar certo quando chegar o OP_PRONTO
## do outro lado.
func _iniciar_duelo(outro_id: String, outro_nome: String, rid: int, anfitriao: bool) -> void:
	ocupado = true
	_transmitir_presenca()
	var eu := {"id": meu_id, "nome": _meu_nome}
	var ele := {"id": outro_id, "nome": outro_nome}
	atividade_dados = {"modo": "pvp", "rodada": rid, "grupos": [[eu, ele] if anfitriao else [ele, eu]]}
	var resultado: String = await DueloRede.preparar(atividade_dados, self)
	_rid_esperado = 0
	if not esta_na_arena():
		DueloRede.limpar_partida()
		return
	if resultado != "":
		DueloRede.limpar_partida()
		ocupado = false
		atividade_dados = {}
		_transmitir_presenca()
		duelo_falhou.emit(resultado if resultado != "SEM_PAR" else "Não foi possível abrir o duelo.")
		return
	if MenuPausa.esta_aberto():
		MenuPausa.fechar()
	get_tree().change_scene_to_file(DueloRede.CENA_DUELO)


## O duelo acabou e o jogador voltou para a lista.
func duelo_terminado() -> void:
	ocupado = false
	atividade_dados = {}
	_transmitir_presenca()


# --------------------------------------------------------------------- recepção

func _on_presenca(ev) -> void:
	if ev.match_id != match_id:
		return
	for p in ev.leaves:
		jogadores.erase(p.user_id)
		jogador_saiu.emit(p.user_id)
		if convite_enviado() and _enviado["para"] == p.user_id:
			_enviado = {}
			_rid_esperado = 0
			desafio_encerrado.emit("O colega saiu da arena.")
		if convite_recebido() and _recebido["de"] == p.user_id:
			_recebido = {}
			_rid_esperado = 0
			desafio_encerrado.emit("Quem te desafiou saiu da arena.")
	lista_mudou.emit()


func _on_estado(msg) -> void:
	if msg.match_id != match_id:
		return
	var dados = JSON.parse_string(msg.data)
	if typeof(dados) != TYPE_DICTIONARY:
		dados = {}
	var remetente: String = msg.presence.user_id if msg.presence != null else ""
	if remetente == meu_id:
		return

	if msg.op_code >= OP_ATIVIDADE_BASE:
		# Duelo ainda sendo combinado: guarda o que chegou na frente.
		if atividade_dados.is_empty() and _rid_esperado != 0 and int(dados.get("r", -2)) == _rid_esperado:
			_pendentes.append([msg.op_code, remetente, dados])
		mensagem_recebida.emit(msg.op_code, remetente, dados)
		return

	match msg.op_code:
		OP_PRESENCA:
			var novo := not jogadores.has(remetente)
			jogadores[remetente] = {"nome": str(dados.get("nome", "Aluno")), "ocupado": bool(dados.get("ocupado", false))}
			if novo and not bool(dados.get("eco", false)):
				_transmitir_presenca(true)  # o recém-chegado fica sabendo de mim
			lista_mudou.emit()
		OP_DESAFIO:
			if str(dados.get("para", "")) != meu_id:
				return
			var rid := int(dados.get("rid", 0))
			if ocupado or convite_recebido() or convite_enviado():
				await _enviar(OP_RESPOSTA, {"para": remetente, "rid": rid, "aceito": false, "motivo": "ocupado"})
				return
			_recebido = {"de": remetente, "nome": str(dados.get("nome", "Aluno")), "rid": rid}
			_rid_esperado = rid
			desafio_recebido.emit(remetente, _recebido["nome"])
			_expirar_convite_recebido(rid)
		OP_RESPOSTA:
			if str(dados.get("para", "")) != meu_id or not convite_enviado() or int(dados.get("rid", 0)) != int(_enviado["rid"]):
				return
			var alvo := str(_enviado["para"])
			var rid := int(_enviado["rid"])
			_enviado = {}
			if bool(dados.get("aceito", false)):
				_iniciar_duelo(alvo, _nome(alvo), rid, true)
			else:
				_rid_esperado = 0
				if str(dados.get("motivo", "")) == "ocupado":
					desafio_encerrado.emit("%s está ocupado agora." % _nome(alvo))
				else:
					desafio_encerrado.emit("%s recusou o desafio." % _nome(alvo))
		OP_CANCELAR:
			if convite_recebido() and _recebido["de"] == remetente and int(dados.get("rid", 0)) == int(_recebido["rid"]):
				_recebido = {}
				_rid_esperado = 0
				desafio_encerrado.emit("%s cancelou o desafio." % _nome(remetente))
