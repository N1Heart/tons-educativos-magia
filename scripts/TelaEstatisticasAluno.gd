extends Control

## Tela 3 do painel do professor (mockup "Página 7"): estatísticas de um
## aluno. Os números vêm da RPC "obter_estatisticas_aluno" (ver
## modules/estatisticas.lua) — nunca lendo o storage do aluno direto, porque
## esse storage é privado ao dono (permission_read = 1).
##
## Recebe qual aluno abrir via NakamaManager.aluno_selecionado_id/nome.


func _ready() -> void:
	%labelNomeAluno.text = NakamaManager.aluno_selecionado_nome
	%btnVoltar.pressed.connect(_on_btn_voltar_pressed)
	_carregar_estatisticas()


func _on_btn_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Login/TelaTurma.tscn")


func _carregar_estatisticas() -> void:
	%labelEstatisticas.text = "Carregando..."

	var dados := await NakamaManager.obter_estatisticas_aluno(NakamaManager.aluno_selecionado_id)

	if dados.is_empty():
		%labelEstatisticas.text = "Não foi possível carregar as estatísticas (sem conexão com o servidor?)."
		return

	if dados.has("erro"):
		%labelEstatisticas.text = "Erro: %s" % dados["erro"]
		return

	if dados.has("nome") and dados["nome"] != "":
		%labelNomeAluno.text = dados["nome"]

	var tempo_total_seg: float = dados.get("tempo_jogo_total_segundos", 0.0)
	var minutos := int(tempo_total_seg) / 60
	var segundos := int(tempo_total_seg) % 60

	var texto := ""
	texto += "Tempo de jogo: %dm %ds\n" % [minutos, segundos]
	texto += "Partidas jogadas: %d\n" % dados.get("total_partidas", 0)
	texto += "Nível máximo alcançado: %d\n" % dados.get("nivel_maximo", 0)
	texto += "Taxa de vitórias: %.0f%%\n" % dados.get("taxa_vitorias_percent", 0.0)
	texto += "Desafios respondidos: %d\n" % dados.get("total_desafios_respondidos", 0)
	texto += "Taxa de acertos em quizzes: %.0f%%\n" % dados.get("taxa_acertos_percent", 0.0)

	if dados.get("alerta_dificuldade", false):
		texto += "\n⚠ ALERTA: demora média de %.1fs por jogada nas últimas partidas (limite %.0fs). Pode ser sinal de dificuldade de aprendizado.\n\n" % [
			dados.get("latencia_recente_segundos", 0.0), dados.get("limiar_latencia_segundos", 0.0)]
	elif dados.get("latencia_recente_segundos", 0.0) > 0.0:
		texto += "Tempo médio por jogada: %.1fs\n" % dados.get("latencia_recente_segundos", 0.0)

	if dados.get("objeto_maior_dificuldade_disponivel", false):
		texto += "Objeto de maior dificuldade: %s\n" % dados.get("objeto_maior_dificuldade", "-")
	else:
		texto += "Objeto de maior dificuldade: em breve\n"

	%labelEstatisticas.text = texto
