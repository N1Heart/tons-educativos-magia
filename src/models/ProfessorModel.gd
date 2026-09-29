class_name ProfessorModel
extends RefCounted

# Atributos herdados de Usuario
var id: String = ""
var email: String=""
var nome: String = ""
var tipo_perfil: String = "Professor"
var is_convidado: bool = false

# Atributos específicos de Professor
var turmas: Array[String] = []

func exportar_para_dicionario() -> Dictionary:
	return {
		"id": id,
		"email": email,
		"nome": nome,
		"tipoPerfil": tipo_perfil,
		"isConvidado": is_convidado,
		"turmas": turmas
	}
