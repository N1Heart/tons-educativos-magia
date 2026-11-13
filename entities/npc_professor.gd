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

const Indicador := preload("res://entities/IndicadorInteracao.gd")
var _indicador: Node = null


func _ready() -> void:
	var acao := "Conversar"
	if tipo == "formas" or tipo == "cores":
		acao = "Fazer a prova"
	elif tipo == "duelo":
		acao = "Falar sobre duelos"
	_indicador = Indicador.new()
	add_child(_indicador)
	# O NPC tem escala 0.7: a altura vai em pixels do mundo, já corrigida.
	_indicador.configurar(nome_exibicao, acao, 52.0 * scale.y)


## Chamado pelo jogador: este é (ou deixou de ser) o objeto que o E aciona.
func definir_destaque(ativo: bool) -> void:
	_indicador.definir_ativo(ativo)


func interagir() -> void:
	var dados := {"nome": nome_exibicao, "retrato": retrato}
	if tipo == "formas" or tipo == "cores":
		FluxoSala.iniciar(self, "prova", tipo, dados)
	elif tipo == "duelo":
		FluxoSala.iniciar(self, "duelo", tipo, dados)
	else:
		FluxoSala.iniciar(self, "falas", tipo, dados, [mensagem])
