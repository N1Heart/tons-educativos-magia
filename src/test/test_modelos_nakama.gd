extends GdUnitTestSuite

# =============================================================================
# SUITE DE TESTES — MODELOS DO JOGO
# Cobre: AlunoModel, ProfessorModel, PartidaMatch3Model,
#        LobbySessaoModel, DesafioQuizModel
# Framework: GDUnit4
# =============================================================================

var gerenciador: NakamaManagerClass


func before_test() -> void:
	gerenciador = NakamaManagerClass.new()
	add_child(gerenciador)


func after_test() -> void:
	if is_instance_valid(gerenciador):
		gerenciador.queue_free()


# =============================================================================
# ALUNO MODEL
# =============================================================================

func test_aluno_model_valores_padrao() -> void:
	var aluno := AlunoModel.new()

	assert_int(aluno.id).is_equal(0)
	assert_str(aluno.nome).is_equal("")
	assert_str(aluno.tipo_perfil).is_equal("Aluno")
	assert_bool(aluno.is_convidado).is_false()
	assert_int(aluno.nivel_atual).is_equal(1)
	assert_array(aluno.magias_desbloqueadas).is_empty()
	assert_str(aluno.codigo_turma).is_equal("")


func test_aluno_model_gera_json_valido() -> void:
	var aluno := AlunoModel.new()
	aluno.nome = "Matheus Teste"
	aluno.nivel_atual = 3
	aluno.codigo_turma = "TURMA-UNIGRAN-01"
	aluno.magias_desbloqueadas = ["Fogo", "Gelo"]

	var json := JSON.stringify(aluno.exportar_para_dicionario())

	assert_str(json).contains("Matheus Teste")
	assert_str(json).contains("Aluno")
	assert_str(json).contains("TURMA-UNIGRAN-01")
	assert_str(json).contains("Fogo")
	assert_str(json).contains("nivelAtual")


func test_aluno_model_exportar_dicionario_chaves() -> void:
	var aluno := AlunoModel.new()
	var dict := aluno.exportar_para_dicionario()

	assert_bool(dict.has("id")).is_true()
	assert_bool(dict.has("nome")).is_true()
	assert_bool(dict.has("tipoPerfil")).is_true()
	assert_bool(dict.has("isConvidado")).is_true()
	assert_bool(dict.has("nivelAtual")).is_true()
	assert_bool(dict.has("magiasDesbloqueadas")).is_true()
	assert_bool(dict.has("codigoTurma")).is_true()


func test_aluno_persistir_no_nakama() -> void:
	var logado := await gerenciador.login_convidado("aluno_teste_persist")
	assert_bool(logado).is_true()

	var aluno := AlunoModel.new()
	aluno.nome = "Matheus Teste"
	aluno.codigo_turma = "TURMA-UNIGRAN-01"
	aluno.nivel_atual = 2

	var json := JSON.stringify(aluno.exportar_para_dicionario())
	var objeto := NakamaWriteStorageObject.new(
		"perfis_usuarios", "aluno_mock", 1, 1, json, ""
	)

	var resultado: NakamaAPI.ApiStorageObjectAcks = await NakamaManager.client.write_storage_objects_async(
		gerenciador.session, [objeto]
	)
	assert_bool(resultado.is_exception()).is_false()


# =============================================================================
# PROFESSOR MODEL
# =============================================================================

func test_professor_model_valores_padrao() -> void:
	var professor := ProfessorModel.new()

	assert_int(professor.id).is_equal(0)
	assert_str(professor.nome).is_equal("")
	assert_str(professor.tipo_perfil).is_equal("Professor")
	assert_bool(professor.is_convidado).is_false()
	assert_array(professor.turmas).is_empty()


func test_professor_model_gera_json_valido() -> void:
	var professor := ProfessorModel.new()
	professor.nome = "Prof. Silva"
	professor.turmas = ["TURMA-UNIGRAN-01", "TURMA-UNIGRAN-02"]

	var json := JSON.stringify(professor.exportar_para_dicionario())

	assert_str(json).contains("Prof. Silva")
	assert_str(json).contains("Professor")
	assert_str(json).contains("TURMA-UNIGRAN-01")
	assert_str(json).contains("TURMA-UNIGRAN-02")


func test_professor_model_exportar_dicionario_chaves() -> void:
	var professor := ProfessorModel.new()
	var dict := professor.exportar_para_dicionario()

	assert_bool(dict.has("id")).is_true()
	assert_bool(dict.has("nome")).is_true()
	assert_bool(dict.has("tipoPerfil")).is_true()
	assert_bool(dict.has("isConvidado")).is_true()
	assert_bool(dict.has("turmas")).is_true()


func test_professor_persistir_no_nakama() -> void:
	var logado := await gerenciador.login_convidado("professor_teste_persist")
	assert_bool(logado).is_true()

	var professor := ProfessorModel.new()
	professor.nome = "Prof. Silva"
	professor.turmas = ["TURMA-UNIGRAN-01"]

	var json := JSON.stringify(professor.exportar_para_dicionario())
	var objeto := NakamaWriteStorageObject.new(
		"perfis_usuarios", "professor_mock", 1, 1, json, ""
	)

	var resultado: NakamaAPI.ApiStorageObjectAcks = await NakamaManager.client.write_storage_objects_async(
		gerenciador.session, [objeto]
	)
	assert_bool(resultado.is_exception()).is_false()


# =============================================================================
# PARTIDA MATCH3 MODEL
# =============================================================================

func test_partida_match3_valores_padrao() -> void:
	var partida := PartidaMatch3Model.new()

	assert_int(partida.nivel_dificuldade).is_equal(1)
	assert_int(partida.pontuacao).is_equal(0)
	assert_float(partida.tempo_decorrido).is_equal(0.0)


func test_partida_match3_gera_json_valido() -> void:
	var partida := PartidaMatch3Model.new()
	partida.nivel_dificuldade = 3
	partida.pontuacao = 1500
	partida.tempo_decorrido = 42.7

	var json := JSON.stringify(partida.exportar_para_dicionario())

	assert_str(json).contains("nivelDificuldade")
	assert_str(json).contains("pontuacao")
	assert_str(json).contains("tempoDecorrido")


func test_partida_match3_exportar_dicionario_chaves() -> void:
	var partida := PartidaMatch3Model.new()
	var dict := partida.exportar_para_dicionario()

	assert_bool(dict.has("nivelDificuldade")).is_true()
	assert_bool(dict.has("pontuacao")).is_true()
	assert_bool(dict.has("tempoDecorrido")).is_true()


func test_partida_match3_valores_corretos_no_dicionario() -> void:
	var partida := PartidaMatch3Model.new()
	partida.nivel_dificuldade = 5
	partida.pontuacao = 9999
	partida.tempo_decorrido = 120.5

	var dict := partida.exportar_para_dicionario()

	assert_int(dict["nivelDificuldade"]).is_equal(5)
	assert_int(dict["pontuacao"]).is_equal(9999)
	assert_float(dict["tempoDecorrido"]).is_equal(120.5)


func test_partida_persistir_no_nakama() -> void:
	var logado := await gerenciador.login_convidado("partida_teste_persist")
	assert_bool(logado).is_true()

	var partida := PartidaMatch3Model.new()
	partida.nivel_dificuldade = 2
	partida.pontuacao = 850
	partida.tempo_decorrido = 60.0

	var json := JSON.stringify(partida.exportar_para_dicionario())
	var objeto := NakamaWriteStorageObject.new(
		"partidas", "partida_mock", 1, 1, json, ""
	)

	var resultado: NakamaAPI.ApiStorageObjectAcks = await NakamaManager.client.write_storage_objects_async(
		gerenciador.session, [objeto]
	)
	assert_bool(resultado.is_exception()).is_false()


# =============================================================================
# LOBBY SESSAO MODEL
# =============================================================================

func test_lobby_sessao_valores_padrao() -> void:
	var lobby := LobbySessaoModel.new()

	assert_str(lobby.codigo_acesso).is_equal("")
	assert_str(lobby.modo_jogo).is_equal("")
	assert_bool(lobby.status_ativo).is_false()


func test_lobby_sessao_gera_json_valido() -> void:
	var lobby := LobbySessaoModel.new()
	lobby.codigo_acesso = "ABC123"
	lobby.modo_jogo = "quiz"
	lobby.status_ativo = true

	var json := JSON.stringify(lobby.exportar_para_dicionario())

	assert_str(json).contains("ABC123")
	assert_str(json).contains("quiz")
	assert_str(json).contains("codigoAcesso")
	assert_str(json).contains("modoJogo")
	assert_str(json).contains("statusAtivo")


func test_lobby_sessao_exportar_dicionario_chaves() -> void:
	var lobby := LobbySessaoModel.new()
	var dict := lobby.exportar_para_dicionario()

	assert_bool(dict.has("codigoAcesso")).is_true()
	assert_bool(dict.has("modoJogo")).is_true()
	assert_bool(dict.has("statusAtivo")).is_true()


func test_lobby_sessao_status_ativo_correto() -> void:
	var lobby := LobbySessaoModel.new()
	lobby.status_ativo = true

	var dict := lobby.exportar_para_dicionario()
	assert_bool(dict["statusAtivo"]).is_true()


func test_lobby_persistir_no_nakama() -> void:
	var logado := await gerenciador.login_convidado("lobby_teste_persist")
	assert_bool(logado).is_true()

	var lobby := LobbySessaoModel.new()
	lobby.codigo_acesso = "ABC123"
	lobby.modo_jogo = "quiz"
	lobby.status_ativo = true

	var json := JSON.stringify(lobby.exportar_para_dicionario())
	var objeto := NakamaWriteStorageObject.new(
		"lobbies", "lobby_mock", 1, 1, json, ""
	)

	var resultado: NakamaAPI.ApiStorageObjectAcks = await NakamaManager.client.write_storage_objects_async(
		gerenciador.session, [objeto]
	)
	assert_bool(resultado.is_exception()).is_false()


# =============================================================================
# DESAFIO QUIZ MODEL
# =============================================================================

func test_desafio_quiz_valores_padrao() -> void:
	var quiz := DesafioQuizModel.new()

	assert_str(quiz.pergunta).is_equal("")
	assert_str(quiz.resposta_correta).is_equal("")
	assert_str(quiz.recompensa_magia).is_equal("")


func test_desafio_quiz_gera_json_valido() -> void:
	var quiz := DesafioQuizModel.new()
	quiz.pergunta = "Quanto é 2+2?"
	quiz.resposta_correta = "4"
	quiz.recompensa_magia = "Fogo"

	var json := JSON.stringify(quiz.exportar_para_dicionario())

	assert_str(json).contains("Quanto é 2+2?")
	assert_str(json).contains("4")
	assert_str(json).contains("Fogo")
	assert_str(json).contains("pergunta")
	assert_str(json).contains("respostaCorreta")
	assert_str(json).contains("recompensaMagia")


func test_desafio_quiz_exportar_dicionario_chaves() -> void:
	var quiz := DesafioQuizModel.new()
	var dict := quiz.exportar_para_dicionario()

	assert_bool(dict.has("pergunta")).is_true()
	assert_bool(dict.has("respostaCorreta")).is_true()
	assert_bool(dict.has("recompensaMagia")).is_true()


func test_desafio_quiz_valores_corretos_no_dicionario() -> void:
	var quiz := DesafioQuizModel.new()
	quiz.pergunta = "Capital do Brasil?"
	quiz.resposta_correta = "Brasília"
	quiz.recompensa_magia = "Relâmpago"

	var dict := quiz.exportar_para_dicionario()

	assert_str(dict["pergunta"]).is_equal("Capital do Brasil?")
	assert_str(dict["respostaCorreta"]).is_equal("Brasília")
	assert_str(dict["recompensaMagia"]).is_equal("Relâmpago")


func test_desafio_quiz_persistir_no_nakama() -> void:
	var logado := await gerenciador.login_convidado("quiz_teste_persist")
	assert_bool(logado).is_true()

	var quiz := DesafioQuizModel.new()
	quiz.pergunta = "Quanto é 2+2?"
	quiz.resposta_correta = "4"
	quiz.recompensa_magia = "Fogo"

	var json := JSON.stringify(quiz.exportar_para_dicionario())
	var objeto := NakamaWriteStorageObject.new(
		"desafios", "quiz_mock", 1, 1, json, ""
	)

	var resultado: NakamaAPI.ApiStorageObjectAcks = await NakamaManager.client.write_storage_objects_async(
		gerenciador.session, [objeto]
	)
	assert_bool(resultado.is_exception()).is_false()
