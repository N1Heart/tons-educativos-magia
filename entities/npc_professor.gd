extends CharacterBody2D

## NPC "professor" de uma sala (formas, cores ou duelos).
##
## Por enquanto `interagir()` só mostra uma mensagem de placeholder no
## console — na próxima etapa (quizzes) isso vira a tela de aula
## (AulaModel) ou a prova (QuizModel), de acordo com `tipo`. O ponto de
## entrada já está pronto: quando a UI existir, troca-se só o corpo desta
## função.

@export var tipo: String = ""  # "formas", "cores" ou "duelo"
@export_multiline var mensagem: String = "Olá! Em breve terei uma aula para você."


func interagir() -> void:
	print("[Professor:%s] %s" % [tipo, mensagem])
