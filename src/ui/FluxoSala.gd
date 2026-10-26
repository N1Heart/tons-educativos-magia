class_name FluxoSala
extends Node

## Orquestra as interações da sala de aula: menu de temas -> aula (repetível,
## pela cadeira) ou prova (com o professor). Cria a CaixaDialogo, congela o
## jogador enquanto o diálogo está aberto e, ao fim da prova, grava o
## resultado e desbloqueia a forma/elemento via LocalDB.registrar_resultado_quiz().
##
## Uso (a partir de qualquer objeto interagível):
##   FluxoSala.iniciar(self, "aula",  "formas", {"nome": "Mestre das Formas"})
##   FluxoSala.iniciar(self, "prova", "cores",  {"nome": "Mestre das Cores"})
##   FluxoSala.iniciar(self, "falas", "",       {"nome": "Mestre dos Duelos"}, ["Olá!"])
##   FluxoSala.iniciar(self, "duelo", "duelo",  {"nome": "Mestre dos Duelos"})   # sala do professor

static var _em_andamento := false

const CENA_LOBBY := "res://scenes/Login/TelaLobby.tscn"
const CENA_ARENA := "res://scenes/Login/TelaArena.tscn"

var _dialogo: CaixaDialogo
var _jogador: Node
var _uid: String = ""


## 'professor' aceita {"nome": String, "retrato": Texture2D (opcional)}.
## 'modo' = "aula" | "prova" | "falas" (só mostra as falas dadas, sem menu).
static func iniciar(host: Node, modo: String, tipo_sala: String, professor: Dictionary, falas: Array = []) -> void:
	if _em_andamento:
		return
	var cena := host.get_tree().current_scene
	if cena == null:
		return

	var fluxo := FluxoSala.new()
	cena.add_child(fluxo)
	fluxo._rodar(modo, tipo_sala, professor, falas)


func _rodar(modo: String, tipo_sala: String, professor: Dictionary, falas: Array) -> void:
	_em_andamento = true
	_uid = LocalDB.get_user_id_ativo()
	_jogador = get_tree().get_first_node_in_group("jogador")
	_definir_controle(false)

	_dialogo = CaixaDialogo.new()
	add_child(_dialogo)
	_dialogo.abrir(str(professor.get("nome", "Professor")), professor.get("retrato", null))

	var destino := ""
	match modo:
		"aula", "prova":
			await _menu_temas(tipo_sala, modo)
		"falas":
			for fala in falas:
				await _dialogo.falar(str(fala))
		"duelo":
			destino = await _menu_duelo()

	_dialogo.fechar()
	_definir_controle(true)
	_em_andamento = false
	if destino == "sala":
		_ir_para_a_sala_de_espera()
	elif destino == "arena":
		_ir_para_a_arena()
	queue_free()


func _definir_controle(ativo: bool) -> void:
	if is_instance_valid(_jogador):
		_jogador.set("controle_ativo", ativo)


# ------------------------------------------------------------- sala do professor

## Menu do Mestre dos Duelos: entrar na sala que o professor abriu (PvE em
## equipe / PvP), voltar à sala de espera ou sair dela. Devolve true se o
## jogador escolheu ir para a sala de espera ("sala") ou para a arena de duelos
## amistosos ("arena"); a troca de cena acontece depois que o diálogo fecha.
func _menu_duelo() -> String:
	while true:
		if LobbyManager.esta_em_sala():
			var pergunta := "Você está na sala %s. O que quer fazer?" % LobbyManager.codigo
			var opcoes: Array[String] = ["Ver a sala de espera", "Sair da sala", "Cancelar"]
			var i: int = await _dialogo.escolher(pergunta, opcoes)
			if i == 0:
				return "sala"
			if i == 1:
				LobbyManager.sair()
				await _dialogo.falar("Você saiu da sala. Volte quando o professor abrir outra!")
				continue
			return ""
		else:
			var opcoes: Array[String] = ["Entrar na sala do professor", "Arena de duelos amistosos", "Como funciona?", "Cancelar"]
			var i: int = await _dialogo.escolher("Quer enfrentar seus colegas?", opcoes)
			if i == 0 or i == 1:
				var motivo := SpellLoadout.motivo_bloqueio_combate(_uid)
				if motivo != "":
					await _dialogo.falar(motivo)
					continue
				return "sala" if i == 0 else "arena"
			if i == 2:
				await _dialogo.falar("Sala do professor: ele abre uma sala e mostra um código de 4 letras. Você digita o código e espera. Quando ele iniciar, você joga com a sua equipe contra um monstro (PvE) ou duela com um colega (PvP).")
				await _dialogo.falar("Arena de duelos amistosos: você vê os colegas da sua turma que estão lá e pode desafiar um deles, ou aceitar um desafio. É só pela diversão: não vale nota nem muda a dificuldade das suas aulas.")
				await _dialogo.falar("Nos duelos os dois jogam ao mesmo tempo, cada um no seu ritmo, e os feitiços são resolvidos juntos, por ordem de prioridade. Treine bastante antes!")
				continue
			return ""
	return ""


## Guarda o ponto do mundo pra voltar depois e abre a sala de espera.
func _ir_para_a_sala_de_espera() -> void:
	var cena := get_tree().current_scene
	var retorno := {"cena": cena.scene_file_path}
	if is_instance_valid(_jogador) and _jogador is Node2D:
		retorno["posicao"] = (_jogador as Node2D).global_position
	Engine.set_meta("lobby_retorno", retorno)
	Engine.set_meta("lobby_modo", "aluno")
	get_tree().change_scene_to_file(CENA_LOBBY)


## Guarda o ponto do mundo pra voltar depois e abre a arena de duelos.
func _ir_para_a_arena() -> void:
	var cena := get_tree().current_scene
	var retorno := {"cena": cena.scene_file_path}
	if is_instance_valid(_jogador) and _jogador is Node2D:
		retorno["posicao"] = (_jogador as Node2D).global_position
	Engine.set_meta("arena_retorno", retorno)
	get_tree().change_scene_to_file(CENA_ARENA)


# --------------------------------------------------------------------- menu

func _menu_temas(tipo_sala: String, modo: String) -> void:
	var tipo: String = ConteudoLoader.TIPO_POR_SALA.get(tipo_sala, "")
	var alvos: Array = ConteudoLoader.ALVOS_POR_SALA.get(tipo_sala, [])
	if tipo == "" or alvos.is_empty():
		await _dialogo.falar("Ainda não tenho nada para ensinar por aqui.")
		return

	var pergunta := "Qual tema você quer estudar?"
	if modo == "prova":
		pergunta = "Em qual tema você quer fazer a prova? (é preciso acertar 70%)"

	while true:
		var rotulos: Array[String] = []
		for alvo in alvos:
			rotulos.append(_rotulo_tema(tipo, alvo))
		rotulos.append("Sair")

		var escolhido: int = await _dialogo.escolher(pergunta, rotulos)
		if escolhido >= alvos.size():
			break

		var dados := ConteudoLoader.carregar(tipo, alvos[escolhido])
		var problemas := ConteudoLoader.validar(dados)
		if not problemas.is_empty():
			push_error("Conteúdo %s_%s inválido: %s" % [tipo, alvos[escolhido], ", ".join(problemas)])
			await _dialogo.falar("Hmm, o material desse tema ainda não está pronto. Tente outro!")
			continue

		if modo == "aula":
			await _rodar_aula(dados)
		else:
			await _rodar_prova(dados)


func _rotulo_tema(tipo: String, alvo: String) -> String:
	var rotulo := ConteudoLoader.nome_menu(ConteudoLoader.carregar(tipo, alvo), alvo)
	if LocalDB.ja_passou_quiz(_uid, tipo, alvo):
		rotulo += "  (aprovado)"
	elif _ja_desbloqueado(tipo, alvo):
		rotulo += "  (desbloqueado)"
	return rotulo


func _ja_desbloqueado(tipo: String, alvo: String) -> bool:
	if tipo == "forma":
		return LocalDB.forma_desbloqueada(_uid, alvo)
	return LocalDB.elemento_desbloqueado(_uid, alvo)


# --------------------------------------------------------------------- aula

func _rodar_aula(dados: Dictionary) -> void:
	var aula := ConteudoLoader.aula(dados)
	for fala in aula.falas:
		await _dialogo.falar(fala)
	await _dialogo.falar("Fim da aula sobre %s! Quando se sentir confiante, fale comigo para fazer a prova." % aula.titulo)


# -------------------------------------------------------------------- prova

func _rodar_prova(dados: Dictionary) -> void:
	var quiz := ConteudoLoader.prova(dados)
	var titulo := ConteudoLoader.aula(dados).titulo
	var total := quiz.perguntas.size()
	var minimo := ceili(quiz.nota_de_corte * total - 0.0001)

	await _dialogo.falar("Prova de %s: %d perguntas. Você precisa acertar pelo menos %d. Vamos lá!" % [titulo, total, minimo])

	var acertos: Array = []
	for i in total:
		var p := quiz.perguntas[i]

		var opcoes: Array[String] = []
		var cabecalho := "Pergunta %d de %d" % [i + 1, total]
		if p.tipo == "vf":
			opcoes.append("Verdadeiro")
			opcoes.append("Falso")
			cabecalho += " (verdadeiro ou falso)"
		else:
			for alternativa in p.alternativas:
				opcoes.append(alternativa)
			opcoes.shuffle()  # a posição da resposta certa muda a cada tentativa

		var escolhido: int = await _dialogo.escolher("%s\n%s" % [cabecalho, p.pergunta], opcoes)
		var correta := opcoes[escolhido] == p.resposta_correta
		acertos.append(correta)
		await _dialogo.falar(_feedback(correta, p))

	var resultado := quiz.calcular_resultado(acertos)
	var ja_tinha := _ja_desbloqueado(quiz.tipo, quiz.alvo)
	LocalDB.registrar_resultado_quiz(_uid, quiz, resultado)

	if resultado["passou"]:
		SpellLoadout.normalizar_equipados(_uid)
		var mensagem := "Parabéns! Você acertou %d de %d e dominou %s." % [resultado["acertos"], resultado["total"], titulo]
		if not ja_tinha:
			mensagem += " Novo poder desbloqueado: %s! Confira em “Minhas Magias”." % ConteudoLoader.nome_menu(dados, quiz.alvo)
		await _dialogo.falar(mensagem)
	else:
		await _dialogo.falar("Você acertou %d de %d, e precisava de pelo menos %d. Revise a aula na cadeira e tente de novo!" % [resultado["acertos"], resultado["total"], minimo])


func _feedback(correta: bool, p: DesafioQuizModel) -> String:
	if correta:
		return ("Correto! %s" % p.explicacao).strip_edges()
	return ("Não foi dessa vez. Resposta certa: %s. %s" % [p.resposta_correta, p.explicacao]).strip_edges()
