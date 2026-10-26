extends Node
class_name DueloRedeClass

## Autoload "DueloRede" — as atividades multiplayer da sala (Módulo 5).
##
##   PvE cooperativo ("pve" na sala; "coop" no Combat): equipes de até 3
##     alunos enfrentam o MESMO monstro, alternando turnos. O monstro age uma
##     vez por rodada, depois do último aluno da equipe.
##   PvP ("pvp"): duelo 1x1, cada um no seu tabuleiro, alternando turnos.
##
## O professor já mandou os grupos em LobbyManager.atividade_dados. Aqui:
##   1. cada aluno anuncia seu "roster" (formas/elementos que pode usar) —
##      OP_PRONTO — e espera os colegas do grupo;
##   2. a cena duelos.tscn roda o Combat em modo rede (ver combat.gd): quem
##      tem a vez resolve o turno e manda o estado — OP_TURNO — pros outros;
##   3. cada aluno manda um resumo pro professor acompanhar — OP_ESTADO.
##
## Todas as mensagens levam "r" (rodada) e "g" (grupo) pra descartar o que
## sobrou de uma atividade anterior ou de outro grupo.

signal turno_recebido(snapshot: Dictionary)
signal membro_saiu(user_id: String)       # alguém do meu grupo saiu (ou caiu)
signal atividade_encerrada                # o professor encerrou a atividade
signal sala_perdida(motivo: String)       # o professor fechou a sala / conexão caiu
signal status_mudou(texto: String)       # mensagem pro aluno (sala de espera / aviso na tela)
signal feiticos_recebidos                 # PvP (anfitrião): chegaram os feitiços do outro jogador
signal estados_atualizados                # chegou resumo de algum aluno (professor)

const CENA_DUELO := "res://scenes/salas/duelos.tscn"
const CENA_LOBBY := "res://scenes/Login/TelaLobby.tscn"

const OP_PRONTO := 101
const OP_TURNO := 102
const OP_SAIDA := 103
const OP_ESTADO := 104
const OP_FEITICOS := 105

const TEMPO_ESPERA_GRUPO := 12.0
## Cada jogador tem no máximo este número de turnos; depois disso o combate
## termina por tempo (ver Combat.encerrar_por_limite_de_turnos).
const LIMITE_RODADAS := 10

## --- Estado da partida em andamento (cena duelos.tscn lê tudo isto) ---
var ativo := false
var modo: String = ""                 # "pve" | "pvp" (nomes da sala)
var modo_combate: String = ""         # "coop" | "pvp" (nomes do Combat)
var rodada: int = -1
var grupo: int = -1
var membros: Array = []               # [{id, nome}] na ordem dos turnos
var meu_indice: int = 0
var turno_idx: int = 0                # de quem é a vez agora
var rodada_pvp: int = 0               # PvP: número da rodada (os dois jogam a mesma por vez)
var turnos_jogados: int = 0           # turnos já resolvidos nesta partida (todos os jogadores)
var formas_equipe: Array[String] = [] # coop: formas que o time usa (vazio = as do próprio jogador)
var tipos_adversario: Array[TileType] = []   # pvp: formas/elementos do outro jogador
var nivel_equipe: int = 1             # coop: média dos níveis de dificuldade

var _lista_oponente: Array = []       # PvP: feitiços recebidos do outro jogador
var _lista_oponente_n := -1           # ...e de qual rodada
var _meu_envio_n := -1                # rodada em que eu já mandei os meus
var _prontos := {}                    # user_id -> roster (OP_PRONTO) da rodada atual
## Duelo amistoso (arena): as mensagens trafegam pela ArenaDuelos, não pela
## sala do professor, e nada é enviado ao professor nem registrado.
var amistoso := false
var _canal_amistoso: Node = null
var estados := {}                     # user_id -> último OP_ESTADO (o professor lê)


func _ready() -> void:
	LobbyManager.mensagem_recebida.connect(_on_mensagem.bind(LobbyManager))
	LobbyManager.atividade_iniciada.connect(_on_atividade)
	LobbyManager.jogador_saiu.connect(_on_jogador_saiu.bind(LobbyManager))
	LobbyManager.sala_encerrada.connect(_on_sala_encerrada.bind(LobbyManager))
	ArenaDuelos.mensagem_recebida.connect(_on_mensagem.bind(ArenaDuelos))
	ArenaDuelos.jogador_saiu.connect(_on_jogador_saiu.bind(ArenaDuelos))
	ArenaDuelos.arena_perdida.connect(func(m): _on_sala_encerrada(m, ArenaDuelos))


## Canal por onde passam as mensagens da partida atual: a sala do professor
## ou a arena de duelos amistosos.
func _c() -> Node:
	return _canal_amistoso if _canal_amistoso != null else LobbyManager


# --------------------------------------------------------------- preparação

func _on_atividade(novo_modo: String) -> void:
	if amistoso:
		return
	# Começou (ou terminou) uma atividade: o que sobrou da anterior vale nada.
	_prontos.clear()
	estados.clear()
	if novo_modo == "":
		if ativo:
			atividade_encerrada.emit()
		limpar_partida()
		status_mudou.emit("Aguardando o professor iniciar a atividade...")
		return
	if not LobbyManager.sou_professor:
		_entrar_na_atividade()


## O professor iniciou: quem está na sala entra na partida de onde estiver
## (sala de espera ou andando pelo jogo), a não ser que esteja ocupado.
func _entrar_na_atividade() -> void:
	if ativo:
		return
	if Combat.combat_active or FluxoSala._em_andamento:
		_avisar("Atividade em grupo iniciada, mas você está ocupado. Termine e fale com o Mestre dos Duelos.")
		return
	_avisar("Preparando a partida...")
	var resultado: String = await preparar(LobbyManager.atividade_dados)
	if resultado == "SEM_PAR":
		_avisar("Você ficou sem par nesta rodada. Aguarde o professor.")
	elif resultado != "":
		_avisar(resultado)
	elif Combat.combat_active or FluxoSala._em_andamento:
		limpar_partida()  # ficou ocupado enquanto esperava os colegas
		_avisar("A partida em grupo começou, mas você estava ocupado.")
	else:
		if MenuPausa.esta_aberto():
			MenuPausa.fechar()
		get_tree().change_scene_to_file(CENA_DUELO)


## Mostra o aviso na sala de espera e, em outras telas, num balão no topo.
func _avisar(texto: String) -> void:
	status_mudou.emit(texto)
	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path == CENA_LOBBY:
		return
	var camada := CanvasLayer.new()
	camada.layer = 90
	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.offset_top = 8
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", 12)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.custom_minimum_size = Vector2(380, 0)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	painel.add_child(rotulo)
	camada.add_child(painel)
	add_child(camada)
	get_tree().create_timer(4.0).timeout.connect(camada.queue_free)


## Zera o estado da partida (volta ao comportamento normal de PvE solo).
func limpar_partida() -> void:
	ativo = false
	modo = ""
	modo_combate = ""
	grupo = -1
	membros = []
	meu_indice = 0
	turno_idx = 0
	turnos_jogados = 0
	rodada_pvp = 0
	_lista_oponente = []
	_lista_oponente_n = -1
	_meu_envio_n = -1
	formas_equipe = []
	tipos_adversario = []
	amistoso = false
	_canal_amistoso = null
	Combat.modo_rede = ""


## Procura o meu grupo nos grupos que o professor mandou.
func _meu_grupo(dados: Dictionary) -> int:
	var grupos: Array = dados.get("grupos", [])
	for i in grupos.size():
		for m in grupos[i]:
			if str(m.get("id", "")) == _c().meu_id:
				return i
	return -1


## Chamado pela TelaLobby do aluno quando o professor inicia uma atividade.
## Devolve "" se a partida está pronta (a cena pode abrir), "SEM_PAR" se o
## aluno não tem grupo/adversário nesta rodada, ou a mensagem de erro.
func preparar(dados: Dictionary, canal_amistoso: Node = null) -> String:
	limpar_partida()
	_canal_amistoso = canal_amistoso
	amistoso = canal_amistoso != null
	var modo_sala := str(dados.get("modo", ""))
	rodada = int(dados.get("rodada", -1))
	grupo = _meu_grupo(dados)
	if grupo < 0:
		return "SEM_PAR"
	var previstos: Array = dados["grupos"][grupo]
	if modo_sala == "pvp" and previstos.size() < 2:
		grupo = -1
		return "SEM_PAR"

	# Duelo amistoso: aproveita o que o outro jogador já mandou antes do canal abrir.
	if canal_amistoso != null:
		for m in canal_amistoso.consumir_pendentes():
			_on_mensagem(int(m[0]), str(m[1]), m[2], canal_amistoso)

	# Anuncia o que eu posso usar na partida.
	var uid := LocalDB.get_user_id_ativo()
	var motivo := SpellLoadout.motivo_bloqueio_combate(uid)
	var formas_info := []
	if motivo == "":
		for f in SpellLoadout.formas_disponiveis(uid):
			formas_info.append({"f": f, "e": SpellLoadout.get_equipped_type(f).element_name})
	var roster := {
		"id": _c().meu_id,
		"nome": _meu_nome(),
		"pode": motivo == "",
		"formas": formas_info,
		"nivel": LocalDB.proximo_nivel_dificuldade(uid) if motivo == "" else 1,
	}
	_prontos[_c().meu_id] = roster
	await _c().enviar_atividade(OP_PRONTO, _com_ids(roster))
	if motivo != "":
		grupo = -1
		return motivo

	# Espera os colegas do grupo anunciarem também.
	var limite := Time.get_ticks_msec() + int(TEMPO_ESPERA_GRUPO * 1000.0)
	while Time.get_ticks_msec() < limite and not _todos_prontos(previstos):
		await get_tree().create_timer(0.1).timeout

	var validos := []
	for m in previstos:
		var id := str(m["id"])
		if _prontos.has(id) and _prontos[id]["pode"]:
			validos.append({"id": id, "nome": _prontos[id]["nome"]})
	if modo_sala == "pvp" and validos.size() < 2:
		grupo = -1
		return "Seu adversário não conseguiu entrar na partida."

	modo = modo_sala
	modo_combate = "pvp" if modo_sala == "pvp" else "coop"
	membros = validos
	meu_indice = 0
	for i in membros.size():
		if membros[i]["id"] == _c().meu_id:
			meu_indice = i
	turno_idx = 0
	turnos_jogados = 0
	rodada_pvp = 0

	if modo_combate == "pvp":
		var outro: Dictionary = _prontos[membros[1 - meu_indice]["id"]]
		for fe in outro["formas"]:
			tipos_adversario.append(SpellLoadout.get_tile_type(str(fe["f"]), str(fe["e"])))
	else:
		formas_equipe = _formas_da_equipe()
		var soma := 0
		for m in membros:
			soma += int(_prontos[m["id"]]["nivel"])
		nivel_equipe = maxi(1, int(round(soma / float(membros.size()))))

	ativo = true
	return ""


func _todos_prontos(previstos: Array) -> bool:
	for m in previstos:
		if not _prontos.has(str(m["id"])):
			return false
	return true


func _meu_nome() -> String:
	var perfil := LocalDB.carregar_perfil(LocalDB.get_user_id_ativo())
	if perfil != null and perfil.nome != "":
		return perfil.nome
	return NakamaManager.convidado_nome if NakamaManager.convidado_nome != "" else "Aluno"


func _com_ids(d: Dictionary) -> Dictionary:
	var r := d.duplicate()
	r["r"] = rodada
	r["g"] = grupo
	return r


## Formas que toda a equipe usa: as que TODOS têm; se sobrar menos de 3,
## todas as que alguém tem (até 5).
func _formas_da_equipe() -> Array[String]:
	var comuns: Array[String] = []
	var todas: Array[String] = []
	for forma in SpellLoadout.SHAPES:
		var todos_tem := true
		var alguem_tem := false
		for m in membros:
			var tem := false
			for fe in _prontos[m["id"]]["formas"]:
				if fe["f"] == forma:
					tem = true
			todos_tem = todos_tem and tem
			alguem_tem = alguem_tem or tem
		if todos_tem:
			comuns.append(forma)
		if alguem_tem:
			todas.append(forma)
	return comuns if comuns.size() >= SpellLoadout.MIN_FORMAS_COMBATE else todas


# ------------------------------------------------------------------- turnos

func limite_atingido() -> bool:
	return turnos_jogados >= LIMITE_RODADAS * maxi(1, membros.size())


## PvP: os dois jogam ao mesmo tempo, então a "vez" é sempre minha.
func meu_turno() -> bool:
	return ativo and (modo_combate == "pvp" or turno_idx == meu_indice)


## PvP: o membro 0 resolve a rodada (junta os feitiços dos dois).
func sou_anfitriao() -> bool:
	return meu_indice == 0


## PvP: mando os feitiços que conjurei nesta rodada.
func enviar_feiticos(lista: Array) -> void:
	_meu_envio_n = rodada_pvp
	_c().enviar_atividade(OP_FEITICOS, _com_ids({"n": rodada_pvp, "lista": lista}))


## Anfitrião: tenho os meus e os do outro jogador desta rodada?
func pvp_pronto_para_resolver() -> bool:
	return ativo and sou_anfitriao() and _meu_envio_n == rodada_pvp and _lista_oponente_n == rodada_pvp


func consumir_lista_oponente() -> Array:
	var l := _lista_oponente
	_lista_oponente = []
	return l


## Anfitrião: publica o resultado da rodada e abre a próxima.
func publicar_rodada_pvp(snapshot: Dictionary) -> void:
	snapshot["n"] = rodada_pvp
	rodada_pvp += 1
	turnos_jogados += membros.size()
	snapshot["t"] = turnos_jogados
	snapshot["prox"] = meu_indice
	snapshot["nome"] = _meu_nome()
	_c().enviar_atividade(OP_TURNO, _com_ids(snapshot))


func sou_ultimo() -> bool:
	return meu_indice == membros.size() - 1


func nome_de_quem_joga() -> String:
	if turno_idx >= 0 and turno_idx < membros.size():
		return str(membros[turno_idx]["nome"])
	return "?"


## Nome do adversário (PvP) ou "" (coop).
func nome_do_adversario() -> String:
	if modo_combate == "pvp" and membros.size() == 2:
		return str(membros[1 - meu_indice]["nome"])
	return ""


## Termina o turno local: manda o estado pros outros e passa a vez.
## Devolve true se o próximo turno também é meu (equipe de um só).
func enviar_turno(snapshot: Dictionary) -> bool:
	turno_idx = (turno_idx + 1) % maxi(1, membros.size())
	turnos_jogados += 1
	snapshot["prox"] = turno_idx
	snapshot["t"] = turnos_jogados
	snapshot["nome"] = _meu_nome()
	_c().enviar_atividade(OP_TURNO, _com_ids(snapshot))
	return turno_idx == meu_indice


## Resumo pro painel do professor (hp = soma do meu lado).
func enviar_estado(hp: int, hp_max: int, fim: String) -> void:
	if not ativo or amistoso:
		return
	var contra := nome_do_adversario()
	var d := {
		"id": _c().meu_id,
		"nome": _meu_nome(),
		"modo": modo,
		"hp": hp,
		"hpmax": hp_max,
		"fim": fim,
		"contra": contra,
		"vez": nome_de_quem_joga(),
	}
	estados[_c().meu_id] = d
	_c().enviar_atividade(OP_ESTADO, _com_ids(d))


## Aviso de que estou saindo da partida (desistência ou fechamento).
func avisar_saida() -> void:
	if grupo < 0:
		return
	_c().enviar_atividade(OP_SAIDA, _com_ids({"id": _c().meu_id}))


# -------------------------------------------------------------- recebimento

func _on_mensagem(op_code: int, remetente: String, dados: Dictionary, origem: Node) -> void:
	if origem != _c():
		return
	if int(dados.get("r", -2)) != _c().atividade_dados.get("rodada", -1):
		return
	match op_code:
		OP_ESTADO:
			# Todos recebem; o professor é quem usa.
			estados[remetente] = dados
			estados_atualizados.emit()
		OP_PRONTO:
			if int(dados.get("g", -1)) == grupo or grupo == -1 and not ativo:
				_prontos[remetente] = dados
		OP_TURNO:
			if ativo and int(dados.get("g", -1)) == grupo:
				turno_idx = int(dados.get("prox", 0))
				turnos_jogados = int(dados.get("t", turnos_jogados + 1))
				if modo_combate == "pvp":
					rodada_pvp = int(dados.get("n", rodada_pvp)) + 1
				turno_recebido.emit(dados)
		OP_FEITICOS:
			if ativo and modo_combate == "pvp" and sou_anfitriao() and int(dados.get("g", -1)) == grupo:
				_lista_oponente = dados.get("lista", [])
				_lista_oponente_n = int(dados.get("n", -1))
				feiticos_recebidos.emit()
		OP_SAIDA:
			if ativo and int(dados.get("g", -1)) == grupo:
				_remover_membro(remetente)


func _on_jogador_saiu(user_id: String, origem: Node) -> void:
	if origem != _c():
		return
	if ativo:
		_remover_membro(user_id)


## Tira alguém do grupo (saiu/caiu/desistiu). Todos os clientes fazem a mesma
## conta, então concordam sobre de quem é a vez.
func _remover_membro(user_id: String) -> void:
	var idx := -1
	for i in membros.size():
		if membros[i]["id"] == user_id:
			idx = i
	if idx < 0 or user_id == _c().meu_id:
		return
	membros.remove_at(idx)
	if idx < meu_indice:
		meu_indice -= 1
	var vez_dele := idx == turno_idx
	if idx < turno_idx:
		turno_idx -= 1
	if turno_idx >= membros.size():
		turno_idx = 0
	membro_saiu.emit(user_id)
	if vez_dele and meu_turno() and Combat.combat_active and modo_combate == "coop":
		Combat.monstro_age_ao_fim = sou_ultimo()
		Combat.start_player_turn()


func _on_sala_encerrada(motivo: String, origem: Node) -> void:
	if origem != _c():
		return
	if ativo:
		limpar_partida()
		sala_perdida.emit(motivo)


# ------------------------------------------------------------------ professor

## Linha de texto do estado de um aluno pro painel do professor ("" = nada).
func texto_estado(user_id: String) -> String:
	if not estados.has(user_id):
		return ""
	var e: Dictionary = estados[user_id]
	var fim := str(e.get("fim", ""))
	if fim == "venceu":
		return "venceu!"
	if fim == "perdeu":
		return "perdeu"
	if fim == "empate":
		return "empate"
	var base := "HP %d/%d" % [int(e.get("hp", 0)), int(e.get("hpmax", 0))]
	if str(e.get("contra", "")) != "":
		base += " vs %s" % e["contra"]
	return base
