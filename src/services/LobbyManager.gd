extends Node
class_name LobbySalaClass

## Autoload "LobbyManager" — sala em tempo real (Módulo 5).
##
## O professor abre uma sala para a turma e recebe um CÓDIGO de 4 letras; os
## alunos digitam o código e entram. Por baixo é uma partida "relayed" do
## Nakama com NOME fixo ("tons_<CÓDIGO>"): quem pede o mesmo nome cai na mesma
## partida, então o código dispensa qualquer tabela no servidor. O servidor só
## repassa mensagens; quem manda na sala é o professor (lista de participantes
## e início de atividade).
##
## Mensagens (op codes, corpo em JSON):
##   OP_HELLO   aluno -> sala   {nome}           "cheguei"
##   OP_SALA    professor -> todos {turma, professor, alunos:[{id,nome}], atividade}
##   OP_INICIAR professor -> todos {modo, rodada, grupos}  "pve" | "pvp"; modo "" = encerra
##   OP_ENCERRAR professor -> todos              sala fechada

signal sala_atualizada                      # lista/estado mudou
signal atividade_iniciada(modo: String)
signal sala_encerrada(motivo: String)
signal mensagem_recebida(op_code: int, remetente_id: String, dados: Dictionary)
signal jogador_saiu(user_id: String)        # alguém saiu da sala (ou caiu)

const OP_HELLO := 1
const OP_SALA := 2
const OP_INICIAR := 3
const OP_ENCERRAR := 4
## A partir daqui ficam as mensagens das atividades (PvE/PvP).
const OP_ATIVIDADE_BASE := 100

## Tamanho máximo de cada equipe no PvE cooperativo.
const TAMANHO_EQUIPE_PVE := 3

const PREFIXO_NOME_PARTIDA := "tons_"
const ALFABETO_CODIGO := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sem I/O/0/1 (confundem)
const TAMANHO_CODIGO := 4
const TEMPO_ESPERA_PROFESSOR := 4.0

## Só para testes: permite usar outro cliente/sessão que não os do NakamaManager.
var cliente_alternativo: NakamaClient = null
var sessao_alternativa: NakamaSession = null

var socket: NakamaSocket = null
var match_id: String = ""
var codigo: String = ""
var sou_professor: bool = false
var meu_id: String = ""

# Estado compartilhado (o professor mantém; os alunos recebem pelo OP_SALA)
var nome_turma: String = ""
var nome_professor: String = ""
var atividade: String = ""        # "" = ainda no saguão; "pve" / "pvp" depois de iniciar
var alunos: Array = []            # [{id, nome}]
var atividade_dados: Dictionary = {}   # último OP_INICIAR: {modo, rodada, grupos:[[{id,nome}]]}
var _rodada: int = 0              # conta as atividades iniciadas (descarta mensagens velhas)

var _nomes_alunos := {}           # user_id -> nome (só o professor usa)
var _presentes := {}              # user_id -> true (quem está conectado na partida)
var _meu_nome: String = ""
var _recebeu_sala := false


# ------------------------------------------------------------------ utilidades

func _cliente() -> NakamaClient:
	return cliente_alternativo if cliente_alternativo != null else NakamaManager.client


func _sessao() -> NakamaSession:
	return sessao_alternativa if sessao_alternativa != null else NakamaManager.session


func gerar_codigo() -> String:
	var c := ""
	for i in TAMANHO_CODIGO:
		c += ALFABETO_CODIGO[randi() % ALFABETO_CODIGO.length()]
	return c


static func normalizar_codigo(texto: String) -> String:
	return texto.strip_edges().to_upper()


func esta_em_sala() -> bool:
	return match_id != ""


## Nome mostrado na sala para o usuário local.
func _nome_local() -> String:
	if _meu_nome != "":
		return _meu_nome
	var sessao := _sessao()
	return sessao.username if sessao != null else "?"


# --------------------------------------------------------------------- conexão

## Garante sessão (convidado que começou offline tenta autenticar agora) e
## socket aberto. Devolve "" se deu certo, senão a mensagem de erro.
func _conectar() -> String:
	if _sessao() == null and cliente_alternativo == null:
		if NakamaManager.convidado_id_ativo != "":
			await NakamaManager.login_convidado(NakamaManager.convidado_id_ativo)
		if NakamaManager.session == null:
			return "Sem conexão com o servidor. Confira o IP do professor na tela de login."

	# O menu ESC pausa o jogo; sem isto o websocket parava de ser lido.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	_descartar_socket()
	socket = Nakama.create_socket_from(_cliente())
	var r = await socket.connect_async(_sessao())
	if r.is_exception():
		socket = null
		return "Não consegui conectar ao servidor (%s)." % r.get_exception().message
	socket.received_match_presence.connect(_on_presenca)
	socket.received_match_state.connect(_on_estado)
	socket.closed.connect(_on_socket_fechado)
	meu_id = _sessao().user_id
	return ""


func _descartar_socket() -> void:
	if socket != null:
		if socket.closed.is_connected(_on_socket_fechado):
			socket.closed.disconnect(_on_socket_fechado)
		socket.close()
		socket = null


func _zerar_estado() -> void:
	atividade_dados = {}
	match_id = ""
	codigo = ""
	nome_turma = ""
	nome_professor = ""
	atividade = ""
	alunos = []
	_nomes_alunos = {}
	_presentes = {}
	_recebeu_sala = false
	sou_professor = false


func _on_socket_fechado() -> void:
	if esta_em_sala():
		_zerar_estado()
		sala_encerrada.emit("A conexão com o servidor caiu.")


# ------------------------------------------------------------------- professor

## Abre uma sala nova para a turma. Devolve "" se deu certo, senão o erro.
func abrir_sala(p_turma: String, p_professor: String = "") -> String:
	if esta_em_sala():
		await sair()
	var erro := await _conectar()
	if erro != "":
		return erro

	var cod := gerar_codigo()
	var m = await socket.create_match_async(PREFIXO_NOME_PARTIDA + cod)
	if m.is_exception():
		return "Não consegui abrir a sala (%s)." % m.get_exception().message

	_zerar_estado()
	sou_professor = true
	codigo = cod
	match_id = m.match_id
	nome_turma = p_turma
	_meu_nome = p_professor if p_professor != "" else (_sessao().username if _sessao() else "Professor")
	nome_professor = _meu_nome
	_presentes[meu_id] = true
	sala_atualizada.emit()
	return ""


## Divide os alunos presentes em grupos: PvE = equipes de até TAMANHO_EQUIPE_PVE
## (as mais equilibradas possível); PvP = pares (quem sobra fica sem par).
## Devolve [[{id, nome}, ...], ...]; a ordem dentro do grupo é a ordem dos turnos.
static func montar_grupos(modo: String, lista: Array) -> Array:
	var embaralhada := lista.duplicate()
	embaralhada.shuffle()
	var grupos: Array = []
	if modo == "pvp":
		var i := 0
		while i + 1 < embaralhada.size():
			grupos.append([embaralhada[i], embaralhada[i + 1]])
			i += 2
		if i < embaralhada.size():
			grupos.append([embaralhada[i]])  # sem par
	elif modo == "pve":
		var n_equipes := int(ceil(embaralhada.size() / float(TAMANHO_EQUIPE_PVE)))
		for k in n_equipes:
			grupos.append([])
		for k in embaralhada.size():
			grupos[k % n_equipes].append(embaralhada[k])
	return grupos


func iniciar_atividade(modo: String) -> void:
	if not sou_professor or not esta_em_sala():
		return
	_rodada += 1
	atividade = modo
	var grupos := montar_grupos(modo, alunos)
	atividade_dados = {"modo": modo, "rodada": _rodada, "grupos": grupos}
	await _enviar(OP_INICIAR, atividade_dados)
	atividade_iniciada.emit(modo)
	sala_atualizada.emit()
	_transmitir_sala()


## Professor encerra a atividade em andamento: todos voltam pra sala.
func encerrar_atividade() -> void:
	if not sou_professor or not esta_em_sala() or atividade == "":
		return
	await iniciar_atividade("")


func _transmitir_sala() -> void:
	if not sou_professor or not esta_em_sala():
		return
	alunos = []
	for id in _nomes_alunos:
		if _presentes.has(id):
			alunos.append({"id": id, "nome": _nomes_alunos[id]})
	alunos.sort_custom(func(a, b): return str(a["nome"]).naturalnocasecmp_to(str(b["nome"])) < 0)
	await _enviar(OP_SALA, {"turma": nome_turma, "professor": nome_professor,
		"alunos": alunos, "atividade": atividade})
	sala_atualizada.emit()


# ----------------------------------------------------------------------- aluno

## Entra numa sala pelo código. Devolve "" se deu certo, senão o erro.
func entrar_na_sala(p_codigo: String, p_nome: String) -> String:
	if esta_em_sala():
		await sair()
	p_codigo = normalizar_codigo(p_codigo)
	if p_codigo.length() != TAMANHO_CODIGO:
		return "O código da sala tem %d caracteres." % TAMANHO_CODIGO
	var erro := await _conectar()
	if erro != "":
		return erro

	var m = await socket.create_match_async(PREFIXO_NOME_PARTIDA + p_codigo)
	if m.is_exception():
		return "Não consegui entrar na sala (%s)." % m.get_exception().message

	_zerar_estado()
	codigo = p_codigo
	match_id = m.match_id
	_meu_nome = p_nome
	_presentes[meu_id] = true
	for p in m.presences:
		_presentes[p.user_id] = true

	await _enviar(OP_HELLO, {"nome": p_nome})

	# Se o código estiver errado, a "sala" está vazia: o professor nunca responde.
	var limite := Time.get_ticks_msec() + int(TEMPO_ESPERA_PROFESSOR * 1000.0)
	while not _recebeu_sala and Time.get_ticks_msec() < limite:
		await get_tree().create_timer(0.1).timeout
	if not _recebeu_sala:
		await sair()
		return "Sala não encontrada. Confira o código com o professor."
	return ""


# ------------------------------------------------------------------ comum/saída

func sair() -> void:
	var estava_em_sala := esta_em_sala()
	if estava_em_sala and sou_professor:
		await _enviar(OP_ENCERRAR, {})
	if estava_em_sala and socket != null:
		await socket.leave_match_async(match_id)
	_descartar_socket()
	_zerar_estado()


## Mensagem de uma atividade (op_code >= OP_ATIVIDADE_BASE) para todos na sala.
func enviar_atividade(op_code: int, dados: Dictionary) -> void:
	await _enviar(op_code, dados)


func _enviar(op_code: int, dados: Dictionary) -> void:
	if socket == null or match_id == "":
		return
	await socket.send_match_state_async(match_id, op_code, JSON.stringify(dados))


func _on_presenca(ev) -> void:
	if ev.match_id != match_id:
		return
	for p in ev.joins:
		_presentes[p.user_id] = true
	for p in ev.leaves:
		_presentes.erase(p.user_id)
		jogador_saiu.emit(p.user_id)
		if not sou_professor and p.user_id != meu_id and _professor_saiu(p.user_id):
			_zerar_estado()
			_descartar_socket()
			sala_encerrada.emit("O professor saiu da sala.")
			return
	if sou_professor:
		_transmitir_sala()  # novo aluno recebe o estado pela resposta ao OP_HELLO; saídas atualizam a lista
	else:
		sala_atualizada.emit()


var _id_professor: String = ""

func _professor_saiu(user_id: String) -> bool:
	return _id_professor != "" and user_id == _id_professor


func _on_estado(msg) -> void:
	if msg.match_id != match_id:
		return
	var dados = JSON.parse_string(msg.data)
	if typeof(dados) != TYPE_DICTIONARY:
		dados = {}
	var remetente: String = msg.presence.user_id if msg.presence != null else ""

	match msg.op_code:
		OP_HELLO:
			if sou_professor:
				_nomes_alunos[remetente] = str(dados.get("nome", "Aluno"))
				_presentes[remetente] = true
				_transmitir_sala()
		OP_SALA:
			if not sou_professor:
				_id_professor = remetente
				nome_turma = str(dados.get("turma", ""))
				nome_professor = str(dados.get("professor", ""))
				alunos = dados.get("alunos", [])
				var nova: String = str(dados.get("atividade", ""))
				_recebeu_sala = true
				var mudou := nova != atividade
				atividade = nova
				sala_atualizada.emit()
				if mudou and nova != "":
					atividade_iniciada.emit(nova)
		OP_INICIAR:
			if not sou_professor:
				atividade = str(dados.get("modo", ""))
				atividade_dados = dados
				atividade_iniciada.emit(atividade)
				sala_atualizada.emit()
		OP_ENCERRAR:
			if not sou_professor:
				_zerar_estado()
				_descartar_socket()
				sala_encerrada.emit("O professor encerrou a sala.")
		_:
			if msg.op_code >= OP_ATIVIDADE_BASE:
				mensagem_recebida.emit(msg.op_code, remetente, dados)
