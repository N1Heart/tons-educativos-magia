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
    return true