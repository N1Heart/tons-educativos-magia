extends Control

# Referências para os campos da interface baseada no pergaminho
@onready var input_nome: LineEdit = $Nome
@onready var input_email: LineEdit = $Email
@onready var input_nascimento: LineEdit = $DataNascimento
@onready var input_turma: LineEdit = $CodigoTurma

func _on_btn_confirmar_pressed() -> void:
	# 1. Monta a estrutura de dados em um Dicionário nativo
	var dados_aluno: Dictionary = {
		"tipo_conta": "aluno",
		"nome": input_nome.text,
		"email": input_email.text,
		"data_nascimento": input_nascimento.text,
		"codigo_turma": input_turma.text
	}
	
	# 2. Converte o dicionário em uma String estruturada em JSON
	var json_string = JSON.stringify(dados_aluno)
	
	# 3. Cria o objeto de escrita usando os 6 parâmetros obrigatórios da assinatura do Nakama
	var objeto_gravar = NakamaWriteStorageObject.new(
		"perfis_usuarios",   # Nome da coleção (Collection)
		"dados_cadastro",    # Chave única por usuário (Key)
		1,                   # permissão de leitura pública (1 = apenas o dono lê)
		1,                   # permissão de escrita pública (1 = apenas o dono escreve)
		json_string,         # O valor textual do JSON
		""                   # Versão (vazia para ignorar controle estrito)
	)
	
	# 4. Envia o objeto para o contêiner usando o cliente e a sessão do seu NakamaManager
	var resultado = await NakamaManager.client.write_storage_objects_async(NakamaManager.session, [objeto_gravar])
	
	if resultado.is_exception():
		print("Erro ao guardar dados: ", resultado.get_exception().message)
	else:
		print("Perfil guardado com sucesso no servidor local!")
		# Transição de cena para o mapa ou fluxo seguinte