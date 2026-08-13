extends Node
class_name NakamaManagerClass

var client: NakamaClient
var session: NakamaSession

func _ready() -> void:
	# A variável global 'Nakama' agora existe graças ao Autoload oficial
	client = Nakama.create_client("defaultkey", "127.0.0.1", 7350, "http")

func login_convidado(id_dispositivo: String) -> bool:
	var result = await client.authenticate_device_async(id_dispositivo)
	if result.is_exception():
		printerr("Erro no login: ", result.get_exception().message)
		return false
		
	session = result
	await definir_perfil("aluno")
	return true
	
	
func cadastrar_conta(email: String, senha: String, nome_usuario: String, tipo_perfil: String) -> bool:
	var result =await client.authenticate_email_async(email ,senha ,nome_usuario, true)

	if result.is_exception():
		print("Erro ao cadastrar", result.get_exception().message)
		return false
	session = result
	
	await definir_perfil(tipo_perfil)
	return true
	
	
	
	
func definir_perfil(tipo: String):
	var dados = {"nivel_acesso": tipo}
	var json_string = JSON.stringify(dados)
	
	var write_objects = [
		NakamaWriteStorageObject.new("perfil", "dados_acesso", 1 , 1, json_string, "")
	]
	await client.write_storage_objects_async(session, write_objects)
	
func criar_turmas(codigo_turma: String) ->bool:
	var max_alunos = 50
	
	var result = await  client.create_group_async(
		session,
		codigo_turma,
		"Turma" + codigo_turma,
		"",
		"",
		true,
		max_alunos
	)
	if result is NakamaException:
		printerr("erro ao criar turma no Nakama:", result.message)
		return false
	
	print("TUrma Oficializada no Nakama ID do grupo", result.id)
	return true
	 
func ler_perfil_usuario() -> String:
	var read_object_id = NakamaStorageObjectId.new("perfil", "dados_acesso", session.user_id)
	
	var result = await client.read_storage_objects_async(session, [read_object_id])
	
	# Se der erro ou não achar o arquivo, por segurança, tratamos como aluno
	if result.is_exception() or result.objects.is_empty():
		return "aluno" 
		
	# Converte o texto JSON salvo de volta para um Dicionário
	var json_data = JSON.parse_string(result.objects[0].value)
	
	if json_data != null and json_data.has("nivel_acesso"):
		return json_data["nivel_acesso"]
		
	return "aluno"


func login_conta(email: String, senha: String) -> String:
	var result = await client.authenticate_email_async(email, senha, "" , false)
	
	if result.is_exception():
		print("erro credenciais invalidas.")
		return "Erro"
		
	session = result
	
	var nivel_perfil = await  ler_perfil_usuario()
	
	return nivel_perfil
	
func entrar_turma(codigo_turma: String) -> bool:
	# 1. Pesquisa a turma pelo nome (código)
	# O "0" é filtro de tipo, e "1" é o limite de resultados
	var busca_result = await client.list_groups_async(session, codigo_turma, 1, "")
	
	if busca_result is NakamaException:
		printerr("Erro ao buscar servidor: ", busca_result.message)
		return false
		
	if busca_result.groups.is_empty():
		print("Erro: Nenhuma turma encontrada com o código ", codigo_turma)
		return false
		
	# 2. Pega o ID verdadeiro do grupo encontrado
	var turma_encontrada = busca_result.groups[0]
	var id_verdadeiro = turma_encontrada.id
	
	# 3. Solicita a entrada no grupo
	var join_result = await client.join_group_async(session, id_verdadeiro)
	
	if join_result is NakamaException:
		printerr("Erro ao se vincular à turma: ", join_result.message)
		return false
		
	print("✅ Sucesso! Aluno vinculado à turma: ", turma_encontrada.name)
	return true

# Função de Logout
func fazer_logout():
	# Limpa a sessão da memória do Godot
	session = null
	print("Sessão encerrada.")
	
