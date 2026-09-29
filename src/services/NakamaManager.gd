extends Node
class_name NakamaManagerClass

var client: NakamaClient
var session: NakamaSession

# Estado simples de navegação entre telas do painel do professor (Godot não
# passa parâmetro em change_scene_to_file, então guardamos aqui o que a
# próxima tela precisa saber). Só usado pelo fluxo Turma -> Aluno.
var turma_selecionada_id: String = ""
var turma_selecionada_nome: String = ""
var aluno_selecionado_id: String = ""
var aluno_selecionado_nome: String = ""

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
	
func listar_minhas_turmas() -> Array:
	print("Iniciando busca de turmas para o ID: ", session.user_id)
	
	# A ordem EXATA e segura: Sessão, ID, Estado (0 = Superadmin), Limite (100), Cursor ("")
	var result = await client.list_user_groups_async(session, session.user_id, 0, 100, "")
	
	if result is NakamaException:
		printerr("Erro na busca: ", result.message)
		return []
		
	print("O servidor respondeu! Total de turmas encontradas: ", result.user_groups.size())

	# Retorna {id, nome} em vez de só o nome — as telas de gestão de turma
	# (apagar, listar alunos) precisam do group_id, não só do texto exibido.
	var lista_turmas = []

	for user_group in result.user_groups:
		print("Lendo turma do banco: ", user_group.group.name)
		lista_turmas.append({"id": user_group.group.id, "nome": user_group.group.name})

	return lista_turmas
	
	
func escrever_dados(colecao: String, chave: String, dados: Dictionary) -> bool:
	if session == null:
		return false

	var json_string = JSON.stringify(dados)
	var write_objects = [
		NakamaWriteStorageObject.new(colecao, chave, 1, 1, json_string, "")
	]
	var result = await client.write_storage_objects_async(session, write_objects)

	if result.is_exception():
		printerr("Erro ao sincronizar '%s/%s': %s" % [colecao, chave, result.get_exception().message])
		return false

	return true


func ler_dados(colecao: String, chave: String) -> Dictionary:
	if session == null:
		return {}

	var read_object_id = NakamaStorageObjectId.new(colecao, chave, session.user_id)
	var result = await client.read_storage_objects_async(session, [read_object_id])

	if result.is_exception() or result.objects.is_empty():
		return {}

	var json_data = JSON.parse_string(result.objects[0].value)
	return json_data if json_data != null else {}


# --- Painel do professor (Módulo 4): gestão de turma e estatísticas ---
# O storage do aluno é gravado com permission_read=1 (só o dono lê) — de
# propósito, pra um aluno não conseguir ler o storage de outro aluno direto.
# Por isso a estatística do professor NÃO lê o storage do aluno direto daqui:
# ela passa por uma RPC (modules/estatisticas.lua) que roda no servidor com
# acesso total, calcula os números lá e devolve só o resultado agregado.

func apagar_turma(id_turma: String) -> bool:
	var result = await client.delete_group_async(session, id_turma)
	if result.is_exception():
		printerr("Erro ao apagar turma: ", id_turma, " - ", result.get_exception().message)
		return false
	return true


## Retorna Array de {id, username, nome_display, is_professor} — os membros
## do grupo. state 0/1 = superadmin/admin (o professor que criou a turma),
## state 2 = membro comum (aluno).
func listar_alunos_da_turma(id_turma: String) -> Array:
	var result = await client.list_group_users_async(session, id_turma, null, 100, "")
	if result.is_exception():
		printerr("Erro ao listar alunos da turma: ", id_turma, " - ", result.get_exception().message)
		return []

	var alunos = []
	for group_user in result.group_users:
		alunos.append({
			"id": group_user.user.id,
			"username": group_user.user.username,
			"is_professor": group_user.state <= 1,
		})
	return alunos


func remover_aluno_da_turma(id_turma: String, id_aluno: String) -> bool:
	var ids := PackedStringArray([id_aluno])
	var result = await client.kick_group_users_async(session, id_turma, ids)
	if result.is_exception():
		printerr("Erro ao remover aluno %s da turma %s: %s" % [id_aluno, id_turma, result.get_exception().message])
		return false
	return true


## Chama a RPC server-side "obter_estatisticas_aluno" (ver modules/estatisticas.lua).
## Retorna um Dictionary já pronto pra tela exibir, ou {} se der erro.
func obter_estatisticas_aluno(id_aluno: String) -> Dictionary:
	var payload := JSON.stringify({"user_id": id_aluno})
	var result = await client.rpc_async(session, "obter_estatisticas_aluno", payload)

	if result.is_exception():
		printerr("Erro ao chamar RPC de estatísticas para ", id_aluno, " - ", result.get_exception().message)
		return {}

	var json_data = JSON.parse_string(result.payload)
	return json_data if json_data != null else {}
