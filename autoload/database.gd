extends Node
## Persistência local do jogo (autoload "Database").
##
## Usa o SQLite por meio do plugin godot-sqlite (GDExtension). As tabelas
## seguem o artigo: histórico de transações, inventário de bens móveis e
## registros de pontuação (logs de estresse), mais a telemetria anônima das
## decisões e o salvamento da partida.
##
## Se o plugin não estiver disponível (por exemplo, em aparelhos Android de
## 32 bits, para os quais ele não tem binário), os mesmos dados são guardados
## em um arquivo JSON, com as mesmas funções. O resto do jogo não percebe a
## diferença.

const CAMINHO_SQLITE := "user://lobo_guara.db"
const CAMINHO_ARQUIVO := "user://lobo_guara_dados.json"
## Limite de linhas por tabela no modo arquivo (as mais antigas são descartadas).
const LIMITE_LINHAS_ARQUIVO := 5000

const ESQUEMA: Array[String] = [
	"""CREATE TABLE IF NOT EXISTS partidas (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		semente TEXT NOT NULL,
		iniciada_em TEXT NOT NULL,
		encerrada_em TEXT,
		resultado TEXT NOT NULL DEFAULT 'em_andamento',
		dias_jogados INTEGER NOT NULL DEFAULT 0,
		patrimonio_final REAL NOT NULL DEFAULT 0,
		pontuacao INTEGER NOT NULL DEFAULT 0
	);""",
	"""CREATE TABLE IF NOT EXISTS transacoes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		partida_id INTEGER NOT NULL,
		dia INTEGER NOT NULL,
		categoria TEXT NOT NULL,
		descricao TEXT NOT NULL,
		valor REAL NOT NULL,
		meio TEXT NOT NULL,
		saldo_apos REAL NOT NULL,
		imposto_embutido REAL NOT NULL DEFAULT 0
	);""",
	"""CREATE TABLE IF NOT EXISTS inventario_bens (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		partida_id INTEGER NOT NULL,
		item_id TEXT NOT NULL,
		nome TEXT NOT NULL,
		valor_pago REAL NOT NULL DEFAULT 0,
		dia_aquisicao INTEGER NOT NULL,
		ativo INTEGER NOT NULL DEFAULT 1
	);""",
	"""CREATE TABLE IF NOT EXISTS log_estresse (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		partida_id INTEGER NOT NULL,
		dia INTEGER NOT NULL,
		estresse REAL NOT NULL,
		estresse_basal REAL NOT NULL,
		razao_divida REAL NOT NULL,
		fomo REAL NOT NULL,
		patrimonio REAL NOT NULL
	);""",
	"""CREATE TABLE IF NOT EXISTS telemetria_decisoes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		partida_id INTEGER NOT NULL,
		dia INTEGER NOT NULL,
		evento_id TEXT NOT NULL,
		categoria TEXT NOT NULL,
		escolha_id TEXT NOT NULL,
		tipo_escolha TEXT NOT NULL,
		tempo_resposta_ms INTEGER NOT NULL DEFAULT -1,
		estresse REAL NOT NULL DEFAULT 0,
		razao_divida REAL NOT NULL DEFAULT 0,
		saldo REAL NOT NULL DEFAULT 0
	);""",
	"""CREATE TABLE IF NOT EXISTS vacinas (
		id TEXT PRIMARY KEY,
		adquirida_em TEXT NOT NULL,
		vezes INTEGER NOT NULL DEFAULT 1
	);""",
	"""CREATE TABLE IF NOT EXISTS estado_salvo (
		chave TEXT PRIMARY KEY,
		valor TEXT NOT NULL
	);""",
	"CREATE INDEX IF NOT EXISTS idx_transacoes_partida ON transacoes (partida_id, id);",
	"CREATE INDEX IF NOT EXISTS idx_estresse_partida ON log_estresse (partida_id, dia);",
	"CREATE INDEX IF NOT EXISTS idx_decisoes_partida ON telemetria_decisoes (partida_id, id);",
]

const TABELAS_ARQUIVO: Array[String] = [
	"partidas", "transacoes", "inventario_bens", "log_estresse", "telemetria_decisoes",
]

var usando_sqlite: bool = false
var partida_id: int = 0

## Instância de SQLite. Sem tipo estático de propósito: a classe só existe
## quando o plugin foi carregado.
var _db: Variant = null
var _arquivo: Dictionary = {}
var _caminho_arquivo: String = CAMINHO_ARQUIVO
var _em_lote: bool = false
var _sujo: bool = false


func _ready() -> void:
	abrir()


func _exit_tree() -> void:
	fechar()


## Abre o banco. Os parâmetros existem para os testes; o jogo usa os padrões.
func abrir(caminho_sqlite: String = CAMINHO_SQLITE, caminho_arquivo: String = CAMINHO_ARQUIVO,
		forcar_arquivo: bool = false) -> void:
	fechar()
	partida_id = 0
	_caminho_arquivo = caminho_arquivo
	usando_sqlite = false
	if not forcar_arquivo and ClassDB.class_exists(&"SQLite"):
		_db = ClassDB.instantiate(&"SQLite")
		_db.path = caminho_sqlite
		_db.verbosity_level = 0
		if _db.open_db():
			usando_sqlite = true
			_db.query("PRAGMA journal_mode = WAL;")
			_db.query("PRAGMA synchronous = NORMAL;")
			for comando in ESQUEMA:
				if not _db.query(comando):
					push_error("SQLite: falha ao criar o esquema: " + str(_db.error_message))
		else:
			push_warning("SQLite indisponível (%s). Usando arquivo." % str(_db.error_message))
			_db = null
	if not usando_sqlite:
		_carregar_arquivo()


func fechar() -> void:
	if usando_sqlite and _db != null:
		if _em_lote:
			_db.query("COMMIT;")
		_db.close_db()
	elif _sujo:
		_gravar_arquivo()
	_db = null
	_em_lote = false
	usando_sqlite = false


## Nome do mecanismo em uso, para a tela "Sobre".
func mecanismo() -> String:
	return "SQLite (GDExtension)" if usando_sqlite else "Arquivo JSON (plugin SQLite indisponível)"


# ---------------------------------------------------------------------------
# Lotes: um dia de jogo é gravado de uma vez só
# ---------------------------------------------------------------------------

func iniciar_lote() -> void:
	if _em_lote:
		return
	_em_lote = true
	if usando_sqlite:
		_db.query("BEGIN TRANSACTION;")


func confirmar_lote() -> void:
	if not _em_lote:
		return
	_em_lote = false
	if usando_sqlite:
		_db.query("COMMIT;")
	elif _sujo:
		_gravar_arquivo()


# ---------------------------------------------------------------------------
# Partidas
# ---------------------------------------------------------------------------

func iniciar_partida(semente: int) -> int:
	var linha := {
		"semente": str(semente), "iniciada_em": _agora(), "resultado": "em_andamento",
		"dias_jogados": 0, "patrimonio_final": 0.0, "pontuacao": 0,
	}
	partida_id = _inserir("partidas", linha)
	return partida_id


func encerrar_partida(resultado: String, dias: int, patrimonio: float, pontuacao: int) -> void:
	if partida_id <= 0:
		return
	if usando_sqlite:
		_db.query_with_bindings(
			"UPDATE partidas SET resultado = ?, encerrada_em = ?, dias_jogados = ?, patrimonio_final = ?, pontuacao = ? WHERE id = ?;",
			[resultado, _agora(), dias, patrimonio, pontuacao, partida_id])
	else:
		for p: Variant in _arquivo["partidas"]:
			if int(p["id"]) == partida_id:
				p["resultado"] = resultado
				p["encerrada_em"] = _agora()
				p["dias_jogados"] = dias
				p["patrimonio_final"] = patrimonio
				p["pontuacao"] = pontuacao
		_marcar_sujo()


## Partidas encerradas, da maior pontuação para a menor.
func melhores_partidas(limite: int = 5) -> Array:
	if usando_sqlite:
		_db.query_with_bindings(
			"SELECT id, resultado, dias_jogados, patrimonio_final, pontuacao FROM partidas WHERE resultado != 'em_andamento' ORDER BY pontuacao DESC LIMIT ?;",
			[limite])
		return (_db.query_result as Array).duplicate(true)
	var lista: Array = []
	for p: Variant in _arquivo["partidas"]:
		if String(p["resultado"]) != "em_andamento":
			lista.append(p)
	lista.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a["pontuacao"]) > int(b["pontuacao"]))
	return lista.slice(0, limite)


# ---------------------------------------------------------------------------
# Registros do dia a dia
# ---------------------------------------------------------------------------

func registrar_transacao(t: Dictionary) -> void:
	if partida_id <= 0:
		return
	_inserir("transacoes", {
		"partida_id": partida_id, "dia": int(t.get("dia", 0)),
		"categoria": String(t.get("categoria", "")), "descricao": String(t.get("descricao", "")),
		"valor": float(t.get("valor", 0.0)), "meio": String(t.get("meio", "conta")),
		"saldo_apos": float(t.get("saldo_apos", 0.0)),
		"imposto_embutido": float(t.get("imposto", 0.0)),
	})


func registrar_estresse(r: Dictionary) -> void:
	if partida_id <= 0:
		return
	_inserir("log_estresse", {
		"partida_id": partida_id, "dia": int(r.get("dia", 0)),
		"estresse": float(r.get("estresse", 0.0)), "estresse_basal": float(r.get("s0", 0.0)),
		"razao_divida": float(r.get("d", 0.0)), "fomo": float(r.get("fomo", 0.0)),
		"patrimonio": float(r.get("patrimonio", 0.0)),
	})


func registrar_decisao(r: Dictionary) -> void:
	if partida_id <= 0:
		return
	_inserir("telemetria_decisoes", {
		"partida_id": partida_id, "dia": int(r.get("dia", 0)),
		"evento_id": String(r.get("evento_id", "")), "categoria": String(r.get("categoria", "")),
		"escolha_id": String(r.get("escolha_id", "")), "tipo_escolha": String(r.get("tipo", "")),
		"tempo_resposta_ms": int(r.get("tempo_ms", -1)), "estresse": float(r.get("estresse", 0.0)),
		"razao_divida": float(r.get("d", 0.0)), "saldo": float(r.get("saldo", 0.0)),
	})


func registrar_bem(item_id: String, nome: String, valor_pago: float, dia: int) -> void:
	if partida_id <= 0:
		return
	_inserir("inventario_bens", {
		"partida_id": partida_id, "item_id": item_id, "nome": nome,
		"valor_pago": valor_pago, "dia_aquisicao": dia, "ativo": 1,
	})


## Marca um bem como vendido ou perdido.
func baixar_bem(item_id: String) -> void:
	if partida_id <= 0:
		return
	if usando_sqlite:
		_db.query_with_bindings(
			"UPDATE inventario_bens SET ativo = 0 WHERE partida_id = ? AND item_id = ? AND ativo = 1;",
			[partida_id, item_id])
	else:
		for b: Variant in _arquivo["inventario_bens"]:
			if int(b["partida_id"]) == partida_id and String(b["item_id"]) == item_id:
				b["ativo"] = 0
		_marcar_sujo()


func registrar_vacina(id: String) -> void:
	if usando_sqlite:
		_db.query_with_bindings(
			"INSERT INTO vacinas (id, adquirida_em, vezes) VALUES (?, ?, 1) ON CONFLICT(id) DO UPDATE SET vezes = vezes + 1;",
			[id, _agora()])
	else:
		var tabela: Dictionary = _arquivo["vacinas"]
		if tabela.has(id):
			tabela[id]["vezes"] = int(tabela[id]["vezes"]) + 1
		else:
			tabela[id] = {"adquirida_em": _agora(), "vezes": 1}
		_marcar_sujo()


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

## Últimas transações da partida atual, da mais nova para a mais antiga.
func ultimas_transacoes(limite: int = 40) -> Array:
	if partida_id <= 0:
		return []
	if usando_sqlite:
		_db.query_with_bindings(
			"SELECT dia, categoria, descricao, valor, meio, saldo_apos, imposto_embutido FROM transacoes WHERE partida_id = ? ORDER BY id DESC LIMIT ?;",
			[partida_id, limite])
		return (_db.query_result as Array).duplicate(true)
	var lista: Array = []
	var tabela: Array = _arquivo["transacoes"]
	for i in range(tabela.size() - 1, -1, -1):
		if int(tabela[i]["partida_id"]) == partida_id:
			lista.append(tabela[i])
			if lista.size() >= limite:
				break
	return lista


## Série diária de estresse e patrimônio da partida atual, em ordem de dia.
func historico_estresse() -> Array:
	if partida_id <= 0:
		return []
	if usando_sqlite:
		_db.query_with_bindings(
			"SELECT dia, estresse, estresse_basal, razao_divida, fomo, patrimonio FROM log_estresse WHERE partida_id = ? ORDER BY dia ASC;",
			[partida_id])
		return (_db.query_result as Array).duplicate(true)
	var lista: Array = []
	for r: Variant in _arquivo["log_estresse"]:
		if int(r["partida_id"]) == partida_id:
			lista.append(r)
	return lista


func inventario() -> Array:
	if partida_id <= 0:
		return []
	if usando_sqlite:
		_db.query_with_bindings(
			"SELECT item_id, nome, valor_pago, dia_aquisicao FROM inventario_bens WHERE partida_id = ? AND ativo = 1 ORDER BY id ASC;",
			[partida_id])
		return (_db.query_result as Array).duplicate(true)
	var lista: Array = []
	for b: Variant in _arquivo["inventario_bens"]:
		if int(b["partida_id"]) == partida_id and int(b["ativo"]) == 1:
			lista.append(b)
	return lista


## Ids de todas as vacinas já vistas neste aparelho, em qualquer partida.
func vacinas_adquiridas() -> Array:
	var ids: Array = []
	if usando_sqlite:
		_db.query("SELECT id FROM vacinas ORDER BY adquirida_em ASC;")
		for linha: Variant in (_db.query_result as Array):
			ids.append(String(linha["id"]))
	else:
		ids = (_arquivo["vacinas"] as Dictionary).keys()
	return ids


## Resumo da telemetria da partida atual: decisões por tipo e tempo médio de
## resposta nas ofertas com relógio.
func resumo_decisoes() -> Dictionary:
	var resumo := {"total": 0, "por_tipo": {}, "tempo_medio_ms": 0.0}
	if partida_id <= 0:
		return resumo
	var linhas: Array = []
	if usando_sqlite:
		_db.query_with_bindings(
			"SELECT tipo_escolha, tempo_resposta_ms FROM telemetria_decisoes WHERE partida_id = ?;",
			[partida_id])
		linhas = _db.query_result
	else:
		for r: Variant in _arquivo["telemetria_decisoes"]:
			if int(r["partida_id"]) == partida_id:
				linhas.append(r)
	var soma_tempo := 0.0
	var com_tempo := 0
	for r: Variant in linhas:
		var tipo := String(r["tipo_escolha"])
		resumo["por_tipo"][tipo] = int(resumo["por_tipo"].get(tipo, 0)) + 1
		var tempo := int(r["tempo_resposta_ms"])
		if tempo >= 0:
			soma_tempo += float(tempo)
			com_tempo += 1
	resumo["total"] = linhas.size()
	if com_tempo > 0:
		resumo["tempo_medio_ms"] = soma_tempo / float(com_tempo)
	return resumo


## Quantidade de linhas de uma tabela (usado nos testes e na tela "Sobre").
func contar(tabela: String) -> int:
	if usando_sqlite:
		if not _db.query("SELECT COUNT(*) AS n FROM %s;" % tabela):
			return -1
		return int((_db.query_result as Array)[0]["n"])
	if not _arquivo.has(tabela):
		return -1
	var conteudo: Variant = _arquivo[tabela]
	return int(conteudo.size())


# ---------------------------------------------------------------------------
# Salvamento da partida e configurações
# ---------------------------------------------------------------------------

func salvar_estado(estado: Dictionary) -> void:
	estado["partida_id"] = partida_id
	_gravar_chave("partida", JSON.stringify(estado))


func carregar_estado() -> Dictionary:
	var texto := _ler_chave("partida")
	if texto == "":
		return {}
	var dados: Variant = JSON.parse_string(texto)
	return dados if dados is Dictionary else {}


func apagar_estado() -> void:
	_gravar_chave("partida", "")


func config(chave: String, padrao: Variant) -> Variant:
	var texto := _ler_chave("config_" + chave)
	if texto == "":
		return padrao
	var valor: Variant = JSON.parse_string(texto)
	return padrao if valor == null else valor


func definir_config(chave: String, valor: Variant) -> void:
	_gravar_chave("config_" + chave, JSON.stringify(valor))


func _gravar_chave(chave: String, valor: String) -> void:
	if usando_sqlite:
		_db.query_with_bindings(
			"INSERT INTO estado_salvo (chave, valor) VALUES (?, ?) ON CONFLICT(chave) DO UPDATE SET valor = excluded.valor;",
			[chave, valor])
	else:
		_arquivo["estado"][chave] = valor
		_marcar_sujo()


func _ler_chave(chave: String) -> String:
	if usando_sqlite:
		_db.query_with_bindings("SELECT valor FROM estado_salvo WHERE chave = ?;", [chave])
		var linhas: Array = _db.query_result
		return String(linhas[0]["valor"]) if linhas.size() > 0 else ""
	return String((_arquivo["estado"] as Dictionary).get(chave, ""))


# ---------------------------------------------------------------------------
# Infraestrutura
# ---------------------------------------------------------------------------

func _inserir(tabela: String, linha: Dictionary) -> int:
	if usando_sqlite:
		if not _db.insert_row(tabela, linha):
			push_error("SQLite: falha ao inserir em %s: %s" % [tabela, str(_db.error_message)])
			return 0
		return int(_db.last_insert_rowid)
	_arquivo["seq"] = int(_arquivo["seq"]) + 1
	linha["id"] = int(_arquivo["seq"])
	var linhas: Array = _arquivo[tabela]
	linhas.append(linha)
	if linhas.size() > LIMITE_LINHAS_ARQUIVO:
		linhas.pop_front()
	_marcar_sujo()
	return int(linha["id"])


func _marcar_sujo() -> void:
	_sujo = true
	if not _em_lote:
		_gravar_arquivo()


func _carregar_arquivo() -> void:
	_arquivo = {}
	if FileAccess.file_exists(_caminho_arquivo):
		var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(_caminho_arquivo))
		if dados is Dictionary:
			_arquivo = dados
	for tabela in TABELAS_ARQUIVO:
		if not (_arquivo.get(tabela) is Array):
			_arquivo[tabela] = []
	for tabela: String in ["vacinas", "estado"]:
		if not (_arquivo.get(tabela) is Dictionary):
			_arquivo[tabela] = {}
	_arquivo["seq"] = int(_arquivo.get("seq", 0))
	_sujo = false


func _gravar_arquivo() -> void:
	var f := FileAccess.open(_caminho_arquivo, FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível gravar " + _caminho_arquivo)
		return
	f.store_string(JSON.stringify(_arquivo))
	f.close()
	_sujo = false


func _agora() -> String:
	return Time.get_datetime_string_from_system(true)
