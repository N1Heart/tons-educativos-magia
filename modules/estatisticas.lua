local nk = require("nakama")
--[[
Módulo 4 — RPC de estatísticas para o painel do professor.

Por que uma RPC e não leitura direta de storage pelo cliente: o storage do
aluno é gravado com permission_read = 1 (só o dono lê), de propósito, pra um
aluno não conseguir ler o storage de outro. Essa RPC roda DENTRO do servidor
Nakama, onde nk.storage_list ignora essa restrição de permissão — é o único
jeito seguro do professor ver o agregado sem abrir o storage do aluno pra
qualquer usuário autenticado.

Este arquivo é lido pelo Nakama a partir de /nakama/data/modules dentro do
container (docker-compose monta a raiz do projeto em /nakama/data). Depois
de adicionar ou editar este arquivo é preciso reiniciar o container nakama
("docker compose restart nakama" ou down/up) pra ele recarregar os módulos.
]]

-- Lista TODOS os objetos de uma coleção pertencentes a um usuário,
-- percorrendo a paginação até o fim.
local function listar_colecao(user_id, collection)
	local todos = {}
	local cursor = ""
	repeat
		local objects, next_cursor = nk.storage_list(user_id, collection, 100, cursor)
		for _, obj in ipairs(objects) do
			table.insert(todos, obj)
		end
		cursor = next_cursor
	until cursor == nil or cursor == ""
	return todos
end

-- Todos os grupos (turmas) de que um usuário participa, com paginação.
local function grupos_do_usuario(user_id)
	local grupos = {}
	local cursor = ""
	repeat
		local result, next_cursor = nk.user_groups_list(user_id, 100, nil, cursor)
		for _, ug in ipairs(result) do
			table.insert(grupos, ug)
		end
		cursor = next_cursor
	until cursor == nil or cursor == ""
	return grupos
end

-- Só deixa passar se quem está chamando (professor_id) for admin/superadmin
-- (state 0 ou 1) de pelo menos uma turma da qual aluno_id também participa.
-- Isso evita que um aluno qualquer chame a RPC passando o user_id de outro
-- aluno e veja as notas/estatísticas de um colega.
local function eh_professor_do_aluno(professor_id, aluno_id)
	local turmas_onde_e_professor = {}
	for _, ug in ipairs(grupos_do_usuario(professor_id)) do
		if ug.state <= 1 then
			turmas_onde_e_professor[ug.group.id] = true
		end
	end

	for _, ug in ipairs(grupos_do_usuario(aluno_id)) do
		if turmas_onde_e_professor[ug.group.id] then
			return true
		end
	end
	return false
end

local function obter_estatisticas_aluno(context, payload)
	local data = nk.json_decode(payload)
	local aluno_id = data and data.user_id

	if aluno_id == nil or aluno_id == "" then
		return nk.json_encode({ erro = "user_id é obrigatório" })
	end

	if not eh_professor_do_aluno(context.user_id, aluno_id) then
		return nk.json_encode({ erro = "sem permissão para ver as estatísticas deste aluno" })
	end

	-- Nome do aluno (perfil é sincronizado como um objeto só, key = user_id)
	local nome = aluno_id
	local perfil_objs = listar_colecao(aluno_id, "progresso_perfil")
	if #perfil_objs > 0 and perfil_objs[1].value.nome ~= nil and perfil_objs[1].value.nome ~= "" then
		nome = perfil_objs[1].value.nome
	end

	-- Partidas de Match-3: tempo de jogo e taxa de vitórias
	local total_partidas = 0
	local vitorias = 0
	local tempo_total = 0
	for _, obj in ipairs(listar_colecao(aluno_id, "progresso_partidas")) do
		total_partidas = total_partidas + 1
		tempo_total = tempo_total + (obj.value.tempo_decorrido or 0)
		if obj.value.venceu == 1 or obj.value.venceu == true then
			vitorias = vitorias + 1
		end
	end

	-- Desafios/quizzes respondidos: taxa de acertos
	local total_desafios = 0
	local acertos = 0
	for _, obj in ipairs(listar_colecao(aluno_id, "progresso_desafios")) do
		total_desafios = total_desafios + 1
		if obj.value.correta == 1 or obj.value.correta == true then
			acertos = acertos + 1
		end
	end

	local taxa_acertos = 0
	if total_desafios > 0 then
		taxa_acertos = (acertos / total_desafios) * 100
	end

	local taxa_vitorias = 0
	if total_partidas > 0 then
		taxa_vitorias = (vitorias / total_partidas) * 100
	end

	return nk.json_encode({
		nome = nome,
		tempo_jogo_total_segundos = tempo_total,
		total_partidas = total_partidas,
		taxa_vitorias_percent = taxa_vitorias,
		total_desafios_respondidos = total_desafios,
		taxa_acertos_percent = taxa_acertos,
		-- "Objetos de maior dificuldade" do mockup ainda não dá pra calcular:
		-- nem PartidaMatch3Model nem DesafioQuizModel guardam qual forma/cor
		-- foi usada em cada tentativa. Falta esse campo no modelo de dados
		-- antes de essa métrica existir de verdade — por ora a tela mostra
		-- "em breve" quando disponivel = false.
		objeto_maior_dificuldade_disponivel = false,
	})
end

nk.register_rpc(obter_estatisticas_aluno, "obter_estatisticas_aluno")
