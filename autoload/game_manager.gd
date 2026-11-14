extends Node
## Estado global do jogo (autoload "GameManager", padrão Singleton).
##
## Guarda a partida em andamento, conduz o relógio da simulação em segundo
## plano, grava no banco tudo o que a simulação emite e avisa as telas por
## sinais. As telas nunca alteram dinheiro diretamente: pedem uma ação ao
## GameManager, que a repassa à simulação.

signal estado_mudou
signal dia_passou(resumo: Dictionary)
signal evento_recebido(pendente: Dictionary)
signal mes_fechado(resumo: Dictionary)
signal meta_concluida(meta: Dictionary)
signal vacina_adquirida(vacina: Dictionary)
signal aviso(texto: String, tipo: String)
signal partida_encerrada(resultado: String)
signal vitoria
signal velocidade_mudou(velocidade: int)

## Duração de um dia de jogo na velocidade 1x, em segundos.
const SEGUNDOS_POR_DIA := 3.0
## Multiplicadores de velocidade. Posição 0 = pausado.
const VELOCIDADES: Array[float] = [0.0, 1.0, 2.0, 4.0]
const MAX_DIAS_POR_QUADRO := 2

var sim: Simulacao = null
var velocidade: int = 1
## Fração do dia atual já decorrida (0 a 1), para a barra do relógio.
var progresso_dia: float = 0.0

var _acumulado: float = 0.0
var _bloqueios: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not relogio_ativo():
		return
	_acumulado += delta * VELOCIDADES[velocidade]
	var dias := 0
	while _acumulado >= SEGUNDOS_POR_DIA and dias < MAX_DIAS_POR_QUADRO and relogio_ativo():
		_acumulado -= SEGUNDOS_POR_DIA
		dias += 1
		avancar_dia()
	_acumulado = minf(_acumulado, SEGUNDOS_POR_DIA)
	progresso_dia = clampf(_acumulado / SEGUNDOS_POR_DIA, 0.0, 1.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_CLOSE_REQUEST:
			salvar()


# ---------------------------------------------------------------------------
# Partida
# ---------------------------------------------------------------------------

func tem_partida() -> bool:
	return sim != null


func tem_partida_salva() -> bool:
	var estado := Database.carregar_estado()
	return not estado.is_empty() and not bool(estado.get("fim", false))


## Começa uma partida nova. [param semente] diferente de zero torna a partida
## reproduzível (usado nos testes e na demonstração).
func nova_partida(semente: int = 0) -> void:
	_encerrar_partida_anterior()
	_criar_simulacao()
	Database.partida_id = 0
	sim.nova_partida(semente)
	Database.iniciar_lote()
	Database.iniciar_partida(sim.semente)
	for id: Variant in sim.bens:
		var item := Catalogo.bem(String(id))
		Database.registrar_bem(String(id), String(item.get("nome", id)), 0.0, 1)
	Database.salvar_estado(sim.para_dict())
	Database.confirmar_lote()
	_reiniciar_relogio()
	estado_mudou.emit()


## Retoma a partida salva. Devolve false se não houver nenhuma.
func continuar() -> bool:
	var estado := Database.carregar_estado()
	if estado.is_empty():
		return false
	_criar_simulacao()
	sim.de_dict(estado)
	Database.partida_id = int(estado.get("partida_id", 0))
	_reiniciar_relogio()
	estado_mudou.emit()
	return true


func salvar() -> void:
	if sim != null:
		Database.salvar_estado(sim.para_dict())


## Sai da partida atual sem apagá-la: ela continua salva para "Continuar".
func sair_para_o_titulo() -> void:
	salvar()
	sim = null


## Registra como abandonada a partida em andamento (a da memória ou a salva)
## antes de começar outra.
func _encerrar_partida_anterior() -> void:
	var anterior := sim
	if anterior == null:
		var estado := Database.carregar_estado()
		if estado.is_empty():
			return
		anterior = Simulacao.new()
		anterior.de_dict(estado)
		Database.partida_id = int(estado.get("partida_id", 0))
	if not anterior.fim and not anterior.venceu:
		Database.encerrar_partida("abandonada", int(anterior.estat.get("dias", 0)),
				anterior.patrimonio(), anterior.pontuacao())
	Database.apagar_estado()
	sim = null


func _criar_simulacao() -> void:
	sim = Simulacao.new()
	sim.transacao.connect(Database.registrar_transacao)
	sim.decisao.connect(Database.registrar_decisao)
	sim.dia_concluido.connect(_ao_concluir_dia)
	sim.evento_chegou.connect(_ao_chegar_evento)
	sim.mes_fechado.connect(func(resumo: Dictionary) -> void: mes_fechado.emit(resumo))
	sim.meta_concluida.connect(_ao_concluir_meta)
	sim.vacina_adquirida.connect(_ao_adquirir_vacina)
	sim.bem_alterado.connect(_ao_alterar_bem)
	sim.aviso.connect(func(texto: String, tipo: String) -> void: aviso.emit(texto, tipo))
	sim.venceu_jogo.connect(_ao_vencer)
	sim.encerrada.connect(_ao_encerrar)


## Toda partida abre com o tempo parado: o jogador olha a situação com calma
## e põe o relógio para andar quando quiser.
func _reiniciar_relogio() -> void:
	_acumulado = 0.0
	progresso_dia = 0.0
	_bloqueios = 0
	definir_velocidade(0)


# ---------------------------------------------------------------------------
# Relógio
# ---------------------------------------------------------------------------

func relogio_ativo() -> bool:
	return sim != null and not sim.fim and velocidade > 0 and _bloqueios == 0


func definir_velocidade(nova: int) -> void:
	velocidade = clampi(nova, 0, VELOCIDADES.size() - 1)
	velocidade_mudou.emit(velocidade)


## Janelas que exigem atenção (evento, fechamento do mês) pausam o tempo
## enquanto estão abertas. Cada bloquear_tempo() pede um liberar_tempo().
func bloquear_tempo() -> void:
	_bloqueios += 1


func liberar_tempo() -> void:
	_bloqueios = maxi(_bloqueios - 1, 0)


## Avança um dia de jogo e grava tudo o que aconteceu de uma vez só.
func avancar_dia() -> void:
	if sim == null or sim.fim:
		return
	Database.iniciar_lote()
	sim.avancar_dia()
	Database.salvar_estado(sim.para_dict())
	Database.confirmar_lote()
	estado_mudou.emit()


# ---------------------------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------------------------

## Executa uma ação da simulação pelo nome e devolve o resultado dela.
## Exemplo: GameManager.agir(&"depositar_reserva", [100.0])
func agir(metodo: StringName, argumentos: Array = []) -> Variant:
	if sim == null or sim.fim:
		return {"ok": false, "msg": "Não há partida em andamento."}
	Database.iniciar_lote()
	var retorno: Variant = sim.callv(metodo, argumentos)
	Database.salvar_estado(sim.para_dict())
	Database.confirmar_lote()
	estado_mudou.emit()
	return retorno


## Responde a uma notificação. Devolve o resultado para o modal mostrar.
func responder(uid: int, escolha_id: String, tempo_ms: int = -1, por_tempo: bool = false) -> Dictionary:
	var retorno: Variant = agir(&"responder", [uid, escolha_id, tempo_ms, por_tempo])
	if retorno is Dictionary and retorno.has("tipo"):
		if String(retorno["tipo"]) == "golpe":
			vibrar(180)
		return retorno
	return {}


## Vibração curta em celulares, se estiver ligada nas configurações.
func vibrar(milissegundos: int = 40) -> void:
	if bool(Database.config("vibracao", true)):
		Input.vibrate_handheld(milissegundos)


# ---------------------------------------------------------------------------
# Sinais da simulação
# ---------------------------------------------------------------------------

func _ao_concluir_dia(resumo: Dictionary) -> void:
	Database.registrar_estresse(resumo)
	dia_passou.emit(resumo)


func _ao_chegar_evento(pendente: Dictionary) -> void:
	if bool(pendente.get("urgente", false)):
		vibrar(60)
	evento_recebido.emit(pendente)


func _ao_concluir_meta(meta: Dictionary) -> void:
	vibrar(40)
	meta_concluida.emit(meta)


func _ao_adquirir_vacina(vacina: Dictionary) -> void:
	Database.registrar_vacina(String(vacina.get("id", "")))
	vacina_adquirida.emit(vacina)


func _ao_alterar_bem(item_id: String, adquirido: bool, valor: float) -> void:
	if adquirido:
		var item := Catalogo.bem(item_id)
		Database.registrar_bem(item_id, String(item.get("nome", item_id)), valor, sim.dia_total)
	else:
		Database.baixar_bem(item_id)


func _ao_vencer() -> void:
	Database.encerrar_partida("vitoria", int(sim.estat.get("dias", 0)), sim.patrimonio(),
			sim.pontuacao())
	vitoria.emit()


func _ao_encerrar(resultado: String) -> void:
	Database.encerrar_partida(resultado, int(sim.estat.get("dias", 0)), sim.patrimonio(),
			sim.pontuacao())
	partida_encerrada.emit(resultado)
