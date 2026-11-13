extends Control

## Tela 3 do painel do professor: estatísticas de um aluno. Os números vêm da
## RPC "obter_estatisticas_aluno" (ver modules/estatisticas.lua) — nunca lendo o
## storage do aluno direto, porque esse storage é privado ao dono.
##
## Recebe qual aluno abrir via NakamaManager.aluno_selecionado_id/nome.

var _titulo: Label
var _status: Label
var _grade: GridContainer
var _alerta: PanelContainer
var _texto_alerta: Label
var _objeto: Label
var _cartoes := {}


func _ready() -> void:
	var t := TemaUI.preparar(self, NakamaManager.aluno_selecionado_nome, "‹ Turma", _on_btn_voltar_pressed)
	_titulo = t["titulo"]

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	t["corpo"].add_child(linha)

	# Esquerda: personagem
	var esq := TemaUI.painel("PERSONAGEM")
	linha.add_child(esq)
	TemaUI.conteudo(esq).add_child(TemaUI.retrato_personagem(110))

	# Direita: números
	var dir := TemaUI.painel("DESEMPENHO")
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(dir)
	var v := TemaUI.conteudo(dir)

	_status = TemaUI.rotulo("Carregando...", "Aviso")
	v.add_child(_status)

	_grade = GridContainer.new()
	_grade.columns = 3
	_grade.add_theme_constant_override("h_separation", 6)
	_grade.add_theme_constant_override("v_separation", 6)
	_grade.visible = false
	v.add_child(_grade)
	for chave in [["tempo", "Tempo de jogo"], ["partidas", "Partidas jogadas"], ["nivel", "Nível máximo"],
			["vitorias", "Taxa de vitórias"], ["desafios", "Desafios respondidos"], ["acertos", "Acertos nos quizzes"]]:
		var c := TemaUI.cartao_numero(chave[1])
		_cartoes[chave[0]] = c
		_grade.add_child(c)

	_alerta = PanelContainer.new()
	_alerta.theme_type_variation = "Alerta"
	_texto_alerta = TemaUI.rotulo("", "Aviso")
	_alerta.add_child(_texto_alerta)
	_alerta.visible = false
	v.add_child(_alerta)

	_objeto = TemaUI.rotulo("", "Subtitulo")
	_objeto.visible = false
	v.add_child(_objeto)

	_carregar_estatisticas()


func _on_btn_voltar_pressed() -> void:
	Transicao.ir_para("res://scenes/Login/TelaTurma.tscn")


func _definir(chave: String, texto: String) -> void:
	(_cartoes[chave].get_meta("valor") as Label).text = texto


func _carregar_estatisticas() -> void:
	var dados := await NakamaManager.obter_estatisticas_aluno(NakamaManager.aluno_selecionado_id)
	if not is_inside_tree():
		return

	if dados.is_empty():
		_status.text = "Não foi possível carregar as estatísticas (sem conexão com o servidor?)."
		return
	if dados.has("erro"):
		_status.text = "Erro: %s" % dados["erro"]
		return

	if dados.has("nome") and dados["nome"] != "":
		_titulo.text = dados["nome"]

	var tempo_total_seg: float = dados.get("tempo_jogo_total_segundos", 0.0)
	_definir("tempo", "%dm %ds" % [int(tempo_total_seg) / 60, int(tempo_total_seg) % 60])
	_definir("partidas", str(int(dados.get("total_partidas", 0))))
	_definir("nivel", str(int(dados.get("nivel_maximo", 0))))
	_definir("vitorias", "%.0f%%" % dados.get("taxa_vitorias_percent", 0.0))
	_definir("desafios", str(int(dados.get("total_desafios_respondidos", 0))))
	_definir("acertos", "%.0f%%" % dados.get("taxa_acertos_percent", 0.0))

	_status.visible = false
	_grade.visible = true

	if dados.get("alerta_dificuldade", false):
		_texto_alerta.text = "⚠ Alerta: demora média de %.1fs por jogada nas últimas partidas (limite %.0fs). Pode ser sinal de dificuldade de aprendizado." % [
			dados.get("latencia_recente_segundos", 0.0), dados.get("limiar_latencia_segundos", 0.0)]
		_alerta.visible = true
	elif dados.get("latencia_recente_segundos", 0.0) > 0.0:
		_objeto.text = "Tempo médio por jogada: %.1fs" % dados.get("latencia_recente_segundos", 0.0)
		_objeto.visible = true

	var extra := ""
	if dados.get("objeto_maior_dificuldade_disponivel", false):
		extra = "Objeto de maior dificuldade: %s" % dados.get("objeto_maior_dificuldade", "-")
	else:
		extra = "Objeto de maior dificuldade: em breve"
	_objeto.text = (_objeto.text + "\n" if _objeto.visible else "") + extra
	_objeto.visible = true
