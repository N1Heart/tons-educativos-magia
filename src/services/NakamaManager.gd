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
	
	
	
func login_conta(email: String, senha: String) -> bool:
	var result = await client.authenticate_email_async(email, senha, "" , false)
	
	if result.is_exception():
		print("erro credenciais invalidas.")
		return false
		
	session = result
	
	return true
	
