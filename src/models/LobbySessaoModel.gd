class_name LobbySessaoModel
extends RefCounted

var codigo_acesso: String = ""
var modo_jogo: String = ""
var status_ativo: bool = false

func exportar_para_dicionario() -> Dictionary:
	return {
		"codigoAcesso": codigo_acesso,
		"modoJogo": modo_jogo,
		"statusAtivo": status_ativo
	}
