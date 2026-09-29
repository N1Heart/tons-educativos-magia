class_name AlunoModel
extends RefCounted

var id: String = ""
var email: String =""
var nome: String = ""
var tipo_perfil: String = "Aluno"
var is_convidado: bool = false
var nivel_atual: int = 1
var magias_desbloqueadas: Array[String] = []
var codigo_turma: String = ""  # ← adiciona aqui

func exportar_para_dicionario() -> Dictionary:
	return {
		"id": id,
		"email": email,
		"nome": nome,
		"tipoPerfil": tipo_perfil,
		"isConvidado": is_convidado,
		"nivelAtual": nivel_atual,
		"magiasDesbloqueadas": magias_desbloqueadas,
		"codigoTurma": codigo_turma  # ← e aqui
	}
