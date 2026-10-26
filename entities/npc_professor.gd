extends CharacterBody2D

## NPC "professor" de uma sala (formas, cores ou duelos).
##
## Nas salas de formas/cores, conversar abre o menu de PROVAS (a aula fica na
## cadeira da sala). Na sala de duelos abre o menu da sala do professor (entrar/sair do PvE e PvP em grupo).

@export var tipo: String = ""  # "formas", "cores" ou "duelo"
@export var nome_exibicao: String = "Professor"
## Placeholder: deixe vazio e a caixa de diálogo mostra um quadrado colorido
## com a inicial. Arraste a imagem do retrato aqui quando existir.
@export var retrato: Texture2D
@export_multiline var mensagem: String = "Olá! Em breve terei uma aula para você."


func interagir() -> void:
	var dados := {"nome": nome_exibicao, "retrato": retrato}
	if tipo == "formas" or tipo == "cores":
		FluxoSala.iniciar(self, "prova", tipo, dados)
	elif tipo == "duelo":
		FluxoSala.iniciar(self, "duelo", tipo, dados)
	else:
		FluxoSala.iniciar(self, "falas", tipo, dados, [mensagem])
