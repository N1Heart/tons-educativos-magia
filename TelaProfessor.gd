extends Control

var codigo_gerado = ""

func _ready():
# Conectando os botões
	%btnGerarCodigo.pressed.connect(_on_btn_gerar_codigo_pressed)
	%btnSalvarTurma.pressed.connect(_on_btn_salvar_turma_pressed)
	%btnLogout.pressed.connect(_on_btn_logout_pressed)
	# AGORA SIM: Conectando o botão de atualizar!
	%btnAtualizarLista.pressed.connect(_on_btn_atualizar_lista_pressed)
	
	# Carrega a lista automaticamente assim que a tela abre
	_atualizar_lista_turmas()

func _on_btn_gerar_codigo_pressed():
	# 1. Pega a primeira letra do período (M, T ou N)
	var texto_periodo = %opcaoPeriodo.get_item_text(%opcaoPeriodo.selected)
	var inicial_periodo = texto_periodo.substr(0, 1).to_upper()
	
	# 2. Pega o Ano (como o SpinBox retorna float, convertemos para String)
	var ano = str(%anoTurma.value)
	
	# 3. Pega a Letra da Turma (removemos espaços e deixamos maiúsculo)
	var letra = %LetraTurma.text.strip_edges().to_upper()
	
	if letra == "":
		%DisplayCodigo.text = "Erro: Informe a Letra da turma!"
		return
		
	# 4. Gera um identificador aleatório de 3 letras/números para ser único
	var hash_unico = str(randi() % 899 + 100) # Gera número entre 100 e 999
	
	# Monta o código final (Ex: M-6A-452)
	codigo_gerado = inicial_periodo + "-" + ano + letra + "-" + hash_unico
	
	# Exibe na tela
	%displayCodigo.text = "Código: " + codigo_gerado

func _on_btn_salvar_turma_pressed():
	if codigo_gerado == "":
		print("Gere o código primeiro!")
		return
		
	print("Iniciando salvamento da turma: ", codigo_gerado)
	%btnSalvarTurma.disabled = true
	
	var sucesso = await  NakamaManager.criar_turmas(codigo_gerado)
	
	if sucesso:
		print("TUrma salva com sucesso no servido Nakama!")
		%displayCodigo.text = "Turma Salva: " + codigo_gerado
		_atualizar_lista_turmas()
		
		codigo_gerado = ""
	else:
		print("Falha ao salvar turma.")
		%displayCodigo.text = "erro ao salvar turma"
	
	%btnSalvarTurma.disabled = false
	
func _on_btn_logout_pressed():
	NakamaManager.fazer_logout()
	get_tree().change_scene_to_file("res://TelaAutenticacao.tscn")
	# O próximo passo será enviar esse 'codigo_gerado' para o Nakama 
	# criar um 'Grupo' onde os alunos vão se conectar!

func _on_btn_atualizar_lista_pressed():
	_atualizar_lista_turmas()

# A função que faz a mágica na interface
func _atualizar_lista_turmas():
	%btnAtualizarLista.disabled = true
	
	# Limpa a lista atual e mostra um aviso de carregamento
	%listaTurmas.clear()
	%listaTurmas.add_item("Carregando turmas...")
	
	# Busca lá no servidor
	var turmas = await NakamaManager.listar_minhas_turmas()
	
	# Limpa o "Carregando..."
	%listaTurmas.clear()
	
	# Preenche a lista com as turmas encontradas
	if turmas.is_empty():
		%listaTurmas.add_item("Nenhuma turma criada ainda.")
	else:
		for nome_turma in turmas:
			%listaTurmas.add_item(nome_turma)
			
	%btnAtualizarLista.disabled = false
	
