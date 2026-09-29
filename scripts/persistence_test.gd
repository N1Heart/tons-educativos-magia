extends Node

## Cena de teste isolada do Módulo 3 — valida LocalDB (SQLite) sozinho, sem
## precisar de login nem do resto do jogo. Acompanhe pelo Output.
##
## Se não houver sessão do Nakama ativa (você não logou antes de rodar essa
## cena), a sincronização fica pendente — isso é o comportamento ESPERADO,
## não um erro: os dados continuam salvos localmente e seriam enviados na
## próxima vez que houver uma sessão + SyncManager.request_sync().


func _ready() -> void:
	var uid := LocalDB.get_user_id_ativo()
	print("Testando persistência para user_id: ", uid)

	var aluno := AlunoModel.new()
	aluno.id = uid
	aluno.nome = "Aluno de Teste"
	aluno.email = "teste@escola.com"
	aluno.nivel_atual = 2
	aluno.codigo_turma = "TURMA01"
	aluno.magias_desbloqueadas = ["Triangulo_Fogo", "Quadrado_Agua"]
	LocalDB.salvar_perfil(aluno)

	LocalDB.desbloquear_magia(uid, "Pentagono_Eletricidade")

	var partida := PartidaMatch3Model.new()
	partida.nivel_dificuldade = 2
	partida.pontuacao = 340
	partida.tempo_decorrido = 87.5
	LocalDB.registrar_partida(uid, partida)

	var desafio := DesafioQuizModel.new()
	desafio.pergunta = "Quanto é 7 x 8?"
	desafio.recompensa_magia = "Hexagono_Cura"
	LocalDB.registrar_resposta_desafio(uid, "quiz_001", desafio, "56", true)

	print("--- Perfil salvo e recarregado ---")
	var recarregado := LocalDB.carregar_perfil(uid)
	print("Nome: %s | Nível: %d | Turma: %s" % [recarregado.nome, recarregado.nivel_atual, recarregado.codigo_turma])
	print("Magias desbloqueadas: ", recarregado.magias_desbloqueadas)

	print("--- Partidas registradas ---")
	for p in LocalDB.listar_partidas(uid):
		print("Dificuldade %d | Pontuação %d | Tempo %.1fs" % [p.nivel_dificuldade, p.pontuacao, p.tempo_decorrido])

	print("--- Já respondeu quiz_001? ", LocalDB.ja_respondeu_desafio(uid, "quiz_001"))

	print("--- Feche e reabra essa cena (F6 de novo): perfil, magias e partida devem continuar aparecendo, mesmo sem internet, porque já estão em user://progresso.db ---")
	print("(Sincronização com o Nakama roda em segundo plano só se houver sessão ativa — sem sessão, fica pendente localmente, o que é esperado.)")
