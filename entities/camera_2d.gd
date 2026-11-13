extends Camera2D

var alvo: Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		buscar_alvo()
		if alvo != null:
			global_position = alvo.global_position
			


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if alvo == null:
			return
	global_position = alvo.global_position
	

func buscar_alvo() -> void:
	var nos := get_tree().get_nodes_in_group("jogador")
	if nos.is_empty():
			push_error("camera2d: nenhum no no grupo player")
			return
	alvo = nos[0]
