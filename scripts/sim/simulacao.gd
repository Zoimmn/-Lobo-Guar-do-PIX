class_name Simulacao
extends RefCounted
## Núcleo da simulação financeira: todo o estado e todas as regras do jogo.
##
## Não acessa a interface nem o disco. O GameManager (autoload) conduz o
## relógio, grava no banco o que esta classe emite por sinais e repassa as
## mudanças para as telas. Por ser independente, a simulação inteira pode ser
## executada pelos testes e pelos bots de calibração (res://testes).

signal transacao(registro: Dictionary)
signal decisao(registro: Dictionary)
signal evento_chegou(pendente: Dictionary)
signal aviso(texto: String, tipo: String)
signal dia_concluido(resumo: Dictionary)
signal mes_fechado(resumo: Dictionary)
signal meta_concluida(meta: Dictionary)
signal vacina_adquirida(vacina: Dictionary)
signal bem_alterado(item_id: String, adquirido: bool, valor: float)
signal venceu_jogo()
signal encerrada(resultado: String)

const MAX_PENDENTES := 3
const CHANCE_EVENTO_DIA := 0.30
const VALIDADE_PADRAO := 8
const LINHAS_DIARIO := 40
## Ritmos de trabalho: multiplicador da renda de quem ganha por dia e o
## cansaço somado a cada dia trabalhado.
const RITMOS := {
	"leve": {"nome": "Leve", "renda": 0.75, "fadiga": -1.3},
	"normal": {"nome": "Normal", "renda": 1.0, "fadiga": 0.0},
	"puxado": {"nome": "Puxado", "renda": 1.25, "fadiga": 1.7},
}
const DIAS_PROCESSO_SELETIVO_MIN := 4
const DIAS_PROCESSO_SELETIVO_MAX := 8
const BONUS_NOVA_TENTATIVA := 0.15
const FADIGA_MINIMA := -6.0
const FADIGA_MAXIMA := 40.0
const RECUPERACAO_FADIGA := 0.7
const RECUPERACAO_CHOQUE := 0.5
const CHOQUE_MAXIMO := 30.0
const CHOQUE_APERTO := 0.9
const CHOQUE_APERTO_TETO := 10.0
const CHANCE_CHUVA := 0.12
const INTERESSE_MAXIMO := 3.0
const MESES_SEM_DISPENSA := 2

## Campos gravados no salvamento da partida.
const CAMPOS: Array[String] = [
	"semente", "dia_total", "saldo", "reserva", "fgts",
	"cartao_ativo", "limite", "fatura_aberta", "fatura_fechada", "fatura_fechada_rot",
	"fatura_minimo", "fatura_pago", "vencimento_em",
	"rot_saldo", "rot_origem", "rot_juros_acum", "parcelamentos",
	"emprestimos", "contas_atrasadas", "atrasos_graves", "juros_cheque_acum",
	"emprego_id", "dias_trab_mes", "pend_bruto", "pend_inss", "pend_vt", "pend_fgts",
	"atraso_salario_em", "meses_clt", "meses_clt_ano", "mes_admissao", "dias_sem_renda",
	"cursos", "cursos_concluidos", "bens",
	"ritmo", "estudo_pausado", "candidatura", "tentativas_emprego", "alerta_limite",
	"fadiga", "choque", "exposicoes", "vacinas", "cedidas", "dias_criticos", "interesse",
	"flags", "pendentes", "agenda", "esperas", "esperas_lazer", "vistos",
	"ultimo_uid", "ultima_categoria", "acoes_hoje",
	"renda_30", "mes_acum", "historico_meses", "estat", "metas_ok", "diario",
	"fim", "resultado", "venceu",
]

var rng := RandomNumberGenerator.new()
var semente: int = 0
var dia_total: int = 1
var saldo: float = 0.0
var reserva: float = 0.0
var fgts: float = 0.0

# --- Cartão de crédito ---
var cartao_ativo: bool = false
var limite: float = 0.0
var fatura_aberta: float = 0.0        ## Compras do ciclo atual.
var fatura_fechada: float = 0.0       ## Fatura fechada aguardando pagamento.
var fatura_fechada_rot: float = 0.0   ## Parte da fatura fechada que veio do rotativo.
var fatura_minimo: float = 0.0
var fatura_pago: float = 0.0
var vencimento_em: int = -1           ## Dia (dia_total) do vencimento; -1 = sem fatura.
var rot_saldo: float = 0.0            ## Saldo no rotativo, com juros.
var rot_origem: float = 0.0           ## Valor original que entrou no rotativo.
var rot_juros_acum: float = 0.0       ## Juros já cobrados sobre rot_origem.
var parcelamentos: Array = []         ## [{descricao, parcela, restantes}]

# --- Outras dívidas ---
var emprestimos: Array = []           ## [{nome, saldo, taxa, parcela, restantes}]
var contas_atrasadas: Array = []      ## [{nome, valor, dias, imposto}]
var atrasos_graves: int = 0
var juros_cheque_acum: float = 0.0

# --- Trabalho e estudo ---
var emprego_id: String = "bico_bike"
var dias_trab_mes: int = 0
var pend_bruto: float = 0.0           ## Salário a receber no próximo dia 5.
var pend_inss: float = 0.0
var pend_vt: float = 0.0
var pend_fgts: float = 0.0
var atraso_salario_em: int = -1
var meses_clt: int = 0
var meses_clt_ano: int = 0
var mes_admissao: int = 1
var dias_sem_renda: int = 0
var cursos: Dictionary = {}           ## curso_id -> aulas feitas (matriculado).
var cursos_concluidos: Array = []
var bens: Array = []
var ritmo: String = "normal"          ## "leve", "normal" ou "puxado".
var estudo_pausado: bool = false
var candidatura: Dictionary = {}      ## {emprego, dia}: processo seletivo em andamento.
var tentativas_emprego: Dictionary = {}
var alerta_limite: bool = false

# --- Estresse (ver ModeloEstresse) ---
var fadiga: float = 0.0
var choque: float = 0.0
var exposicoes: Array = []            ## [{dia, i, uid}] gatilhos de FOMO recentes.
var vacinas: Dictionary = {}          ## vacina_id -> vezes vista.
var cedidas: int = 0
var dias_criticos: int = 0
var interesse: Dictionary = {"bets": 0.0, "influencer": 0.0, "credito": 0.0}

# --- Eventos ---
var flags: Dictionary = {}
var pendentes: Array = []             ## Notificações aguardando resposta.
var agenda: Array = []                ## [{evento, dia}]
var esperas: Dictionary = {}          ## evento_id -> dia em que volta a ser sorteável.
var esperas_lazer: Dictionary = {}
var vistos: Dictionary = {}
var ultimo_uid: int = 0
var ultima_categoria: String = ""
var acoes_hoje: Dictionary = {}

# --- Histórico e estatísticas ---
var renda_30: Array = []
var mes_acum: Dictionary = {}
var historico_meses: Array = []
var estat: Dictionary = {}
var metas_ok: Array = []
var diario: Array = []
var fim: bool = false
var resultado: String = ""
var venceu: bool = false

var _renda_dia: float = 0.0


# ---------------------------------------------------------------------------
# Início e salvamento
# ---------------------------------------------------------------------------

func nova_partida(semente_inicial: int = 0) -> void:
	semente = semente_inicial
	if semente == 0:
		semente = int(Time.get_unix_time_from_system()) ^ (randi() << 8)
	rng.seed = semente
	saldo = Economia.SALDO_INICIAL
	mes_acum = _novo_acumulador()
	estat = {
		"dias": 0, "soma_estresse": 0.0, "maior_estresse": 0.0, "renda_total": 0.0,
		"golpes_evitados": 0, "golpes_sofridos": 0, "perdido_golpes": 0.0,
		"apostas": 0, "apostado": 0.0, "ganho_apostas": 0.0,
		"juros": 0.0, "rendimentos": 0.0, "impostos": 0.0,
		"decisoes": 0, "seguras": 0, "arriscadas": 0, "tempo_esgotado": 0,
		"gatilhos_fomo": 0, "fomo_cedidos": 0, "fomo_resistidos": 0,
		"dias_puxado": 0, "lazeres": 0, "vezes_rotativo": 0, "dias_no_aperto": 0,
	}
	for item: Variant in Catalogo.bens():
		if bool(item.get("inicial", false)):
			bens.append(String(item["id"]))
	agenda = [
		{"evento": "boas_vindas", "dia": 1},
		{"evento": "oferta_cartao", "dia": 9 + rng.randi_range(0, 5)},
		{"evento": "nota_mercado", "dia": 13 + rng.randi_range(0, 4)},
		{"evento": "cheque_liberado", "dia": 33 + rng.randi_range(0, 4)},
	]
	_processar_agenda()


func para_dict() -> Dictionary:
	var d := {"rng_estado": str(rng.state)}
	for campo in CAMPOS:
		d[campo] = get(campo)
	return d


func de_dict(d: Dictionary) -> void:
	for campo in CAMPOS:
		if not d.has(campo):
			continue
		var novo: Variant = d[campo]
		match typeof(get(campo)):
			TYPE_INT:
				set(campo, int(novo))
			TYPE_FLOAT:
				set(campo, float(novo))
			TYPE_BOOL:
				set(campo, bool(novo))
			TYPE_STRING:
				set(campo, String(novo))
			_:
				set(campo, novo)
	rng.seed = semente
	rng.state = String(d.get("rng_estado", "0")).to_int()


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func mes() -> int:
	@warning_ignore("integer_division")
	return (dia_total - 1) / Economia.DIAS_MES + 1


func dia_do_mes() -> int:
	return (dia_total - 1) % Economia.DIAS_MES + 1


func nome_mes() -> String:
	return Economia.MESES[(Economia.MES_INICIAL + mes() - 1) % 12]


func emprego() -> Dictionary:
	return Catalogo.emprego(emprego_id)


func vinculo() -> String:
	return String(emprego().get("vinculo", "informal"))


func tem_bem(id: String) -> bool:
	return bens.has(id)


func multiplicador_entrega() -> float:
	return 1.08 if tem_bem("bag") else 1.0


func transporte_dia() -> float:
	return float(emprego().get("transporte_dia", 0.0))


func alimentacao_dia() -> float:
	var vale := float(emprego().get("vale_refeicao", 0.0)) / float(Economia.DIAS_MES)
	return maxf(Economia.ALIMENTACAO_DIA - vale, Economia.ALIMENTACAO_MINIMA_DIA)


## Custos fixos de um mês no padrão de vida atual.
func custos_fixos_mensais() -> float:
	var total := Economia.MORADIA + Economia.CONTAS_CASA + Economia.PLANO_CELULAR
	total += alimentacao_dia() * float(Economia.DIAS_MES)
	total += transporte_dia() * float(Economia.DIAS_UTEIS)
	total += float(emprego().get("das", 0.0))
	return total


## Valor da reserva de emergência que encerra o jogo com vitória.
func meta_reserva() -> float:
	return Economia.CUSTO_VIDA_BASE * Economia.META_RESERVA_MESES


## Quantos meses de custo de vida a reserva atual cobre.
func meses_reserva() -> float:
	return reserva / Economia.CUSTO_VIDA_BASE


## Renda líquida esperada em um mês cheio no emprego atual.
func renda_esperada_mes() -> float:
	var emp := emprego()
	if emp.has("salario"):
		var bruto := float(emp["salario"])
		return bruto * (1.0 - float(emp.get("inss", 0.0)) - float(emp.get("desconto_vt", 0.0)))
	var media := (float(emp.get("renda_min", 0.0)) + float(emp.get("renda_max", 0.0))) / 2.0
	return media * 26.0 * multiplicador_entrega() * (1.0 - CHANCE_CHUVA * 0.6)


## Renda dos últimos 30 dias. No começo da partida, completa a janela com a
## renda esperada do emprego.
func renda_mensal() -> float:
	var soma := 0.0
	for valor: Variant in renda_30:
		soma += float(valor)
	var faltam := Economia.DIAS_MES - renda_30.size()
	if faltam > 0:
		soma += renda_esperada_mes() * float(faltam) / float(Economia.DIAS_MES)
	return soma


func limite_cheque() -> float:
	return Economia.LIMITE_CHEQUE_ESPECIAL if flags.has("cheque") else 0.0


func parcelas_futuras_cartao() -> float:
	var total := 0.0
	for p: Variant in parcelamentos:
		total += float(p["parcela"]) * float(p["restantes"])
	return total


func parcelas_cartao_mes() -> float:
	var total := 0.0
	for p: Variant in parcelamentos:
		total += float(p["parcela"])
	return total


func limite_disponivel() -> float:
	if not cartao_ativo:
		return 0.0
	return maxf(limite - fatura_aberta - fatura_fechada - rot_saldo - parcelas_futuras_cartao(), 0.0)


func total_emprestimos() -> float:
	var total := 0.0
	for e: Variant in emprestimos:
		total += float(e["saldo"])
	return total


func total_atrasadas() -> float:
	var total := 0.0
	for c: Variant in contas_atrasadas:
		total += float(c["valor"])
	return total


## Dívida ativa: tudo que já está correndo juros ou em atraso.
func divida_ativa() -> float:
	return maxf(-saldo, 0.0) + rot_saldo + fatura_fechada_rot \
			+ total_emprestimos() + total_atrasadas()


## Tudo que o jogador deve, incluindo compras ainda não vencidas.
func total_devido() -> float:
	return maxf(-saldo, 0.0) + fatura_aberta + fatura_fechada + rot_saldo \
			+ parcelas_futuras_cartao() + total_emprestimos() + total_atrasadas()


func valor_bens() -> float:
	var total := 0.0
	for id: Variant in bens:
		total += float(Catalogo.bem(String(id)).get("revenda", 0.0))
	return total


func patrimonio() -> float:
	return maxf(saldo, 0.0) + reserva + fgts + valor_bens() - total_devido()


func razao_divida() -> float:
	return ModeloEstresse.razao_divida(divida_ativa(), renda_mensal())


func f_fomo() -> float:
	var total := 0.0
	for e: Variant in exposicoes:
		total += ModeloEstresse.peso_exposicao(float(e["i"]), dia_total - int(e["dia"]))
	return total


func beta() -> float:
	return ModeloEstresse.beta(vacinas.size(), cedidas)


func estresse_basal() -> float:
	return clampf(float(emprego().get("s0", 14.0)) + fadiga + choque,
			ModeloEstresse.S0_MINIMO, ModeloEstresse.S0_MAXIMO)


## Nível de estresse atual, pela Equação 1 do artigo.
func estresse() -> float:
	return ModeloEstresse.calcular(estresse_basal(), razao_divida(), f_fomo(),
			ModeloEstresse.ALFA, beta())


## Parcelas da Equação 1, para a tela que explica o cálculo.
func detalhe_estresse() -> Dictionary:
	var s0 := estresse_basal()
	var d := razao_divida()
	var f := f_fomo()
	var b := beta()
	return {
		"base_emprego": float(emprego().get("s0", 14.0)), "fadiga": fadiga, "choque": choque,
		"s0": s0, "d": d, "alfa": ModeloEstresse.ALFA, "fomo": f, "beta": b,
		"termo_divida": s0 * exp(ModeloEstresse.ALFA * d), "termo_fomo": b * f,
		"total": ModeloEstresse.calcular(s0, d, f, ModeloEstresse.ALFA, b),
	}


func pontuacao() -> int:
	var media_estresse := float(estat["soma_estresse"]) / maxf(float(estat["dias"]), 1.0)
	var pontos := maxf(patrimonio(), 0.0) / 10.0
	pontos += 150.0 * float(estat["golpes_evitados"]) + 120.0 * float(vacinas.size())
	pontos += 250.0 * float(metas_ok.size()) - 80.0 * float(estat["golpes_sofridos"])
	pontos -= media_estresse * 3.0
	return maxi(int(round(pontos)), 0)


# ---------------------------------------------------------------------------
# Relógio: um dia de jogo
# ---------------------------------------------------------------------------

## Processa o dia atual e avança para o próximo.
func avancar_dia() -> void:
	if fim:
		return
	_renda_dia = 0.0
	var d := dia_do_mes()
	_renda_do_trabalho(d)
	_custos_do_dia()
	_contas_com_data(d)
	_juros_do_dia()
	if cartao_ativo and d == Economia.DIA_FECHAMENTO:
		_fechar_fatura()
	_expirar_pendentes()
	_estresse_do_dia()

	renda_30.append(_renda_dia)
	while renda_30.size() > Economia.DIAS_MES:
		renda_30.pop_front()
	_verificar_metas()

	var e := estresse()
	estat["dias"] = int(estat["dias"]) + 1
	estat["soma_estresse"] = float(estat["soma_estresse"]) + e
	estat["maior_estresse"] = maxf(float(estat["maior_estresse"]), e)
	mes_acum["soma_estresse"] = float(mes_acum["soma_estresse"]) + e
	mes_acum["dias"] = int(mes_acum["dias"]) + 1
	dia_concluido.emit({
		"dia": dia_total, "estresse": e, "s0": estresse_basal(), "d": razao_divida(),
		"fomo": f_fomo(), "patrimonio": patrimonio(), "saldo": saldo, "reserva": reserva,
		"divida": divida_ativa(),
	})

	if d == Economia.DIAS_MES:
		_fechar_mes()
	_verificar_fim()
	if fim:
		return
	dia_total += 1
	_inicio_do_dia()


func _inicio_do_dia() -> void:
	acoes_hoje = {}
	if cartao_ativo and vencimento_em == dia_total and fatura_fechada >= 0.01:
		_criar_evento_fatura()
	if not candidatura.is_empty() and dia_total >= int(candidatura["dia"]):
		_resultado_candidatura()
	_processar_agenda()
	_sortear_evento_do_dia()


func _renda_do_trabalho(d: int) -> void:
	var emp := emprego()
	var tipo := vinculo()
	if atraso_salario_em > 0 and dia_total >= atraso_salario_em:
		atraso_salario_em = -1
		_creditar_salario("Salário (pago com atraso)")
	if tipo == "informal":
		if dias_sem_renda > 0:
			dias_sem_renda -= 1
			return
		if dia_total % 7 == 0 or acoes_hoje.has("folga"):
			return  # folga semanal, ou folga tirada por conta própria
		acoes_hoje["trabalhou"] = true
		var ganho := rng.randf_range(float(emp["renda_min"]), float(emp["renda_max"]))
		ganho *= multiplicador_entrega() * float(RITMOS[ritmo]["renda"])
		if rng.randf() < CHANCE_CHUVA:
			if tem_bem("capa_chuva"):
				ganho *= 1.15
				_diario("Choveu o dia todo. De capa, você rodou e pegou as melhores corridas.", "bom", false)
			else:
				ganho *= 0.4
				_diario("Choveu o dia todo: quase nenhuma corrida.", "ruim", false)
		var e := estresse()
		if e >= ModeloEstresse.NO_LIMITE and rng.randf() < 0.2:
			_diario("Sem energia para rodar hoje. O esgotamento custou um dia de renda.", "ruim")
			return
		if e >= ModeloEstresse.ANSIOSO:
			ganho *= 0.9
		_mov("renda", "Corridas do dia", ganho)
		return
	# Vínculos com salário mensal (PJ e CLT)
	if dias_sem_renda > 0:
		dias_sem_renda -= 1
		if tipo == "clt":
			dias_trab_mes += 1  # o atestado cobre o dia
	else:
		dias_trab_mes += 1
		var dia_semana := dia_total % 7
		if dia_semana != 0 and dia_semana != 6 and not acoes_hoje.has("folga"):
			acoes_hoje["trabalhou"] = true
			if ritmo == "puxado":
				var extra: Dictionary = emp["extra"]
				_mov("renda", String(extra["nome"]),
						rng.randf_range(float(extra["ganho_min"]), float(extra["ganho_max"])))
	if d == Economia.DIA_SALARIO:
		_pagar_salario()
	if tipo == "clt" and nome_mes() == Economia.MES_DECIMO_TERCEIRO \
			and d == Economia.DIA_DECIMO_TERCEIRO:
		_pagar_decimo_terceiro()


func _acumular_salario() -> void:
	var emp := emprego()
	if emp.has("salario") and dias_trab_mes > 0:
		var bruto := float(emp["salario"]) * float(mini(dias_trab_mes, Economia.DIAS_MES)) \
				/ float(Economia.DIAS_MES)
		pend_bruto += bruto
		pend_inss += bruto * float(emp.get("inss", 0.0))
		pend_vt += bruto * float(emp.get("desconto_vt", 0.0))
		if String(emp["vinculo"]) == "clt":
			pend_fgts += bruto * 0.08
	dias_trab_mes = 0


func _pagar_salario() -> void:
	if pend_bruto < 0.01:
		return
	var emp := emprego()
	if vinculo() == "pj" and atraso_salario_em < 0 \
			and rng.randf() < float(emp.get("risco_atraso", 0.0)):
		var dias := rng.randi_range(6, 12)
		atraso_salario_em = dia_total + dias
		_ajustar_choque(3.0)
		_diario("A loja avisou que o pagamento vai atrasar %d dias. Quem é PJ não tem a quem reclamar." % dias, "ruim")
		return
	_creditar_salario("Salário")


func _creditar_salario(descricao: String) -> void:
	if pend_bruto < 0.01:
		return
	_mov("renda", descricao, pend_bruto)
	if pend_inss >= 0.01:
		_mov("imposto_direto", "Desconto do INSS", -pend_inss)
	if pend_vt >= 0.01:
		_mov("custo_fixo", "Vale-transporte (6%)", -pend_vt)
	fgts = snappedf(fgts + pend_fgts, 0.01)
	pend_bruto = 0.0
	pend_inss = 0.0
	pend_vt = 0.0
	pend_fgts = 0.0


func _pagar_decimo_terceiro() -> void:
	if meses_clt_ano <= 0:
		return
	var emp := emprego()
	var valor := float(emp["salario"]) * float(mini(meses_clt_ano, 12)) / 12.0
	valor *= 1.0 - float(emp.get("inss", 0.0))
	meses_clt_ano = 0
	_mov("renda", "13º salário", valor)
	_diario("Caiu o 13º salário: %s. Só existe para quem tem carteira assinada." % Economia.reais(valor), "bom")


func _custos_do_dia() -> void:
	_pagar_essencial("Alimentação", alimentacao_dia(), "alimentacao", true)
	var transporte := transporte_dia()
	var dia_semana := dia_total % 7
	if transporte > 0.0 and dia_semana != 0 and dia_semana != 6:
		_pagar_essencial("Transporte", transporte, "transporte", true)


func _contas_com_data(d: int) -> void:
	_cobrar_atrasadas()
	if d == Economia.DIA_MORADIA:
		_pagar_essencial("Moradia", Economia.MORADIA, "moradia", false)
	if d == Economia.DIA_CONTAS:
		var valor := snappedf(Economia.CONTAS_CASA * rng.randf_range(0.92, 1.12), 0.01)
		_pagar_essencial("Contas da casa", valor, "contas", false)
	if d == Economia.DIA_CELULAR:
		_pagar_essencial("Plano do celular", Economia.PLANO_CELULAR, "celular", false)
	if d == Economia.DIA_DAS and emprego().has("das"):
		_pagar_essencial("Boleto do MEI (DAS)", float(emprego()["das"]), "", false, "imposto_direto")
	if d == Economia.DIA_EMPRESTIMOS:
		_cobrar_emprestimos()


## Paga uma despesa essencial. Sem saldo (nem limite da conta), um gasto do
## dia é reduzido e uma conta com data entra em atraso com multa.
func _pagar_essencial(nome: String, valor: float, cat_imposto: String, do_dia: bool,
		categoria: String = "custo_fixo") -> bool:
	var taxa := Economia.imposto(cat_imposto)
	var disponivel := saldo + limite_cheque()
	if disponivel + 0.005 >= valor:
		_mov(categoria, nome, -valor, "conta", valor * taxa)
		return true
	if do_dia:
		var parcial := maxf(snappedf(disponivel, 0.01), 0.0)
		if parcial >= 1.0:
			_mov(categoria, nome + " (o que deu)", -parcial, "conta", parcial * taxa)
		_ajustar_choque(2.5)
		estat["dias_no_aperto"] = int(estat["dias_no_aperto"]) + 1
		_diario("Faltou dinheiro para %s hoje." % nome.to_lower(), "ruim", false)
		return false
	contas_atrasadas.append({
		"nome": nome, "valor": snappedf(valor * (1.0 + Economia.MULTA_ATRASO), 0.01),
		"dias": 0, "imposto": cat_imposto, "categoria": categoria,
	})
	_ajustar_choque(4.0)
	_diario("%s venceu e não havia saldo. Entrou em atraso, com multa de 2%%." % nome, "ruim")
	return false


func _cobrar_atrasadas() -> void:
	var restantes: Array = []
	for c: Variant in contas_atrasadas:
		var valor := float(c["valor"])
		if saldo >= valor:
			_mov(String(c.get("categoria", "custo_fixo")), "%s (em atraso)" % String(c["nome"]),
					-valor, "conta", valor * Economia.imposto(String(c.get("imposto", ""))))
			_diario("Conta em atraso quitada: %s." % String(c["nome"]), "bom", false)
			continue
		c["dias"] = int(c["dias"]) + 1
		if int(c["dias"]) == Economia.DIAS_PARA_ATRASO_GRAVE:
			atrasos_graves += 1
			_ajustar_choque(6.0)
			_diario("%s está há 30 dias sem pagamento. Atrasos graves: %d de %d." % [
				String(c["nome"]), atrasos_graves, Economia.ATRASOS_GRAVES_FALENCIA], "ruim")
		restantes.append(c)
	contas_atrasadas = restantes


func _cobrar_emprestimos() -> void:
	var restantes: Array = []
	for e: Variant in emprestimos:
		var saldo_devedor := float(e["saldo"])
		var juros := saldo_devedor * float(e["taxa"])
		var parcela := minf(float(e["parcela"]), saldo_devedor + juros)
		mes_acum["juros"] = float(mes_acum["juros"]) + juros
		estat["juros"] = float(estat["juros"]) + juros
		if saldo + limite_cheque() + 0.005 >= parcela:
			_mov("divida", "Parcela: %s" % String(e["nome"]), -parcela)
			e["saldo"] = snappedf(saldo_devedor + juros - parcela, 0.01)
			e["restantes"] = int(e["restantes"]) - 1
		else:
			e["saldo"] = snappedf((saldo_devedor + juros) * (1.0 + Economia.MULTA_ATRASO), 0.01)
			_ajustar_choque(5.0)
			_diario("A parcela de %s não foi paga: a dívida cresceu com juros e multa." % String(e["nome"]), "ruim")
		if float(e["saldo"]) > 0.5:
			restantes.append(e)
		else:
			_diario("%s quitado." % String(e["nome"]), "bom")
	emprestimos = restantes


func _juros_do_dia() -> void:
	if reserva > 0.0:
		var rendimento := reserva * Economia.taxa_diaria(Economia.TAXA_RESERVA)
		reserva += rendimento
		mes_acum["rendimentos"] = float(mes_acum["rendimentos"]) + rendimento
		estat["rendimentos"] = float(estat["rendimentos"]) + rendimento
	if rot_saldo > 0.0:
		var juros := rot_saldo * Economia.taxa_diaria(Economia.taxa_rotativo(mes()))
		# Os juros do rotativo não podem passar de 100% do valor original.
		juros = minf(juros, maxf(rot_origem - rot_juros_acum, 0.0))
		rot_saldo += juros
		rot_juros_acum += juros
		mes_acum["juros"] = float(mes_acum["juros"]) + juros
		estat["juros"] = float(estat["juros"]) + juros
	if saldo < 0.0:
		var juros_conta := -saldo * Economia.taxa_diaria(Economia.TAXA_CHEQUE_ESPECIAL)
		juros_cheque_acum += juros_conta
		mes_acum["juros"] = float(mes_acum["juros"]) + juros_conta
		estat["juros"] = float(estat["juros"]) + juros_conta


func _estresse_do_dia() -> void:
	if acoes_hoje.has("trabalhou"):
		fadiga = clampf(fadiga + float(RITMOS[ritmo]["fadiga"]), FADIGA_MINIMA, FADIGA_MAXIMA)
		if ritmo == "puxado":
			estat["dias_puxado"] = int(estat["dias_puxado"]) + 1
	_estudo_do_dia()
	fadiga = move_toward(fadiga, 0.0, RECUPERACAO_FADIGA)
	choque = maxf(choque - RECUPERACAO_CHOQUE, 0.0)
	# Aperto: sem caixa para os próximos cinco dias, o estresse basal sobe.
	if maxf(saldo, 0.0) + reserva < custos_fixos_mensais() / float(Economia.DIAS_MES) * 5.0:
		choque = minf(choque + CHOQUE_APERTO, maxf(choque, CHOQUE_APERTO_TETO))
	var recentes: Array = []
	for e: Variant in exposicoes:
		if dia_total - int(e["dia"]) < ModeloEstresse.DIAS_MEMORIA_FOMO:
			recentes.append(e)
	exposicoes = recentes
	for chave: Variant in interesse.keys():
		interesse[chave] = maxf(float(interesse[chave]) - 0.01, 0.0)
	if estresse() >= ModeloEstresse.CRITICO:
		dias_criticos += 1
		if not alerta_limite:
			alerta_limite = true
			_criar_evento_limite()
	else:
		dias_criticos = maxi(dias_criticos - 1, 0)
		if dias_criticos == 0:
			alerta_limite = false


func _criar_evento_limite() -> void:
	var ev := {
		"id": "sis_limite", "categoria": "sistema", "canal": "Mensagem", "remetente": "Guará",
		"titulo": "Você está no limite",
		"texto": "Seu estresse chegou ao máximo. Se continuar assim por %d dias, você não aguenta e a partida termina. O que derruba o estresse: tirar folga e buscar lazer (aba Vida), baixar o ritmo de trabalho e, principalmente, reduzir a dívida." % ModeloEstresse.DIAS_ATE_ESGOTAMENTO,
		"validade": 2, "urgente": true, "padrao": "ok",
		"escolhas": [{"id": "ok", "texto": "Vou cuidar disso", "tipo": "neutra", "efeitos": {},
			"resultado": "A saúde emocional é um recurso que acaba, como o dinheiro. Cuidar dela também é uma decisão financeira."}],
	}
	_criar_pendente(ev, ev)


# ---------------------------------------------------------------------------
# Cartão de crédito
# ---------------------------------------------------------------------------

func _compra_cartao(descricao: String, valor: float, parcelas: int, imposto_embutido: float) -> void:
	valor = snappedf(valor, 0.01)
	var rotulo := descricao
	if parcelas <= 1:
		fatura_aberta = snappedf(fatura_aberta + valor, 0.01)
	else:
		parcelamentos.append({
			"descricao": descricao, "parcela": snappedf(valor / float(parcelas), 0.01),
			"restantes": parcelas,
		})
		rotulo = "%s (%dx)" % [descricao, parcelas]
	mes_acum["consumo"] = float(mes_acum["consumo"]) + valor
	mes_acum["impostos"] = float(mes_acum["impostos"]) + imposto_embutido
	estat["impostos"] = float(estat["impostos"]) + imposto_embutido
	transacao.emit({
		"dia": dia_total, "categoria": "consumo", "descricao": rotulo, "valor": -valor,
		"meio": "cartao", "saldo_apos": saldo, "imposto": snappedf(imposto_embutido, 0.01),
	})


func _fechar_fatura() -> void:
	var parcelas_mes := 0.0
	var restantes: Array = []
	for p: Variant in parcelamentos:
		parcelas_mes += float(p["parcela"])
		p["restantes"] = int(p["restantes"]) - 1
		if int(p["restantes"]) > 0:
			restantes.append(p)
	parcelamentos = restantes
	var total := snappedf(fatura_aberta + parcelas_mes + rot_saldo, 0.01)
	fatura_aberta = 0.0
	if total < 0.01:
		return
	fatura_fechada = total
	fatura_fechada_rot = snappedf(rot_saldo, 0.01)
	rot_saldo = 0.0
	fatura_minimo = snappedf(total * Economia.PAGAMENTO_MINIMO, 0.01)
	fatura_pago = 0.0
	vencimento_em = dia_total + Economia.DIAS_ATE_VENCIMENTO
	_diario("A fatura do cartão fechou em %s. Vence no dia %d." % [
		Economia.reais(total), Economia.DIA_SALARIO], "alerta")


func _limpar_fatura() -> void:
	fatura_fechada = 0.0
	fatura_fechada_rot = 0.0
	fatura_minimo = 0.0
	fatura_pago = 0.0
	vencimento_em = -1
	if rot_saldo < 0.01:
		rot_saldo = 0.0
		rot_origem = 0.0
		rot_juros_acum = 0.0


## Paga a fatura fechada, no todo ou em parte. Devolve o valor pago.
func pagar_fatura(valor: float) -> float:
	valor = snappedf(minf(minf(valor, fatura_fechada), maxf(saldo, 0.0)), 0.01)
	if valor < 0.01:
		return 0.0
	_mov("divida", "Pagamento da fatura", -valor)
	fatura_fechada = snappedf(fatura_fechada - valor, 0.01)
	fatura_pago += valor
	fatura_fechada_rot = maxf(snappedf(fatura_fechada_rot - valor, 0.01), 0.0)
	if fatura_fechada < 0.01:
		_limpar_fatura()
	return valor


## O que sobrou da fatura no vencimento entra no rotativo.
func _vencer_fatura() -> float:
	var resto := fatura_fechada
	if resto < 0.01:
		_limpar_fatura()
		return 0.0
	var pagou_minimo := fatura_pago + 0.005 >= fatura_minimo
	rot_origem += maxf(resto - fatura_fechada_rot, 0.0)
	var multa := 0.0
	if not pagou_minimo:
		multa = snappedf(resto * Economia.MULTA_ATRASO, 0.01)
		_ajustar_choque(4.0)
		mes_acum["juros"] = float(mes_acum["juros"]) + multa
		estat["juros"] = float(estat["juros"]) + multa
	rot_saldo = snappedf(rot_saldo + resto + multa, 0.01)
	fatura_fechada = 0.0
	fatura_fechada_rot = 0.0
	fatura_minimo = 0.0
	fatura_pago = 0.0
	vencimento_em = -1
	estat["vezes_rotativo"] = int(estat["vezes_rotativo"]) + 1
	return rot_saldo


## Paga parte ou todo o saldo do rotativo. Devolve o valor pago.
func pagar_rotativo(valor: float) -> float:
	valor = snappedf(minf(minf(valor, rot_saldo), maxf(saldo, 0.0)), 0.01)
	if valor < 0.01:
		return 0.0
	_mov("divida", "Pagamento do rotativo", -valor)
	rot_saldo = snappedf(rot_saldo - valor, 0.01)
	if rot_saldo < 0.01:
		rot_saldo = 0.0
		if fatura_fechada_rot < 0.01:
			rot_origem = 0.0
			rot_juros_acum = 0.0
	return valor


func _criar_evento_fatura() -> void:
	var total := fatura_fechada
	var minimo := fatura_minimo
	var taxa := Economia.taxa_rotativo(mes())
	var texto := "Sua fatura de %s vence hoje. Saldo na conta: %s." % [
		Economia.reais(total), Economia.reais(saldo)]
	if fatura_fechada_rot >= 0.01:
		texto += " Ela inclui %s que vieram do rotativo." % Economia.reais(fatura_fechada_rot)
	texto += " O que não for pago entra no rotativo, com juros de %s ao mês (%s ao ano)." % [
		Economia.porcento(taxa), Economia.porcento(Economia.taxa_anual(taxa), 0)]
	var escolhas: Array = []
	if saldo + 0.005 >= total:
		escolhas.append({"id": "total", "texto": "Pagar o total (%s)" % Economia.reais(total),
			"tipo": "segura", "efeitos": {"pagar_fatura": "total"}})
	elif saldo > minimo + 1.0:
		escolhas.append({"id": "parcial", "texto": "Pagar o que tenho (%s)" % Economia.reais(saldo),
			"tipo": "neutra", "efeitos": {"pagar_fatura": "parcial"}, "vacina": "rotativo"})
	if saldo + 0.005 >= minimo:
		escolhas.append({"id": "minimo", "texto": "Pagar só o mínimo (%s)" % Economia.reais(minimo),
			"tipo": "arriscada", "efeitos": {"pagar_fatura": "minimo"}, "vacina": "rotativo"})
	if total >= 100.0:
		var parcela := Economia.parcela_price(total, Economia.TAXA_PARCELAMENTO_FATURA,
				Economia.PARCELAS_FATURA)
		escolhas.append({"id": "parcelar", "texto": "Parcelar em %dx de %s" % [
				Economia.PARCELAS_FATURA, Economia.reais(parcela)],
			"tipo": "neutra", "efeitos": {"pagar_fatura": "parcelar"}, "vacina": "rotativo"})
	escolhas.append({"id": "nada", "texto": "Não pagar agora", "tipo": "arriscada",
		"efeitos": {"pagar_fatura": "nada"}, "vacina": "rotativo"})
	var ev := {
		"id": "sis_fatura", "categoria": "sistema", "canal": "App do banco",
		"remetente": "Seu banco digital", "titulo": "A fatura do cartão vence hoje",
		"texto": texto, "validade": 1, "urgente": true, "padrao": "nada", "escolhas": escolhas,
	}
	_criar_pendente(ev, ev)


func _efeito_fatura(modo: String) -> String:
	var total := fatura_fechada
	var taxa := Economia.taxa_rotativo(mes())
	match modo:
		"total":
			pagar_fatura(total)
			return "Fatura quitada: nenhum centavo de juros. Usado assim, o cartão trabalha a seu favor."
		"parcelar":
			_novo_emprestimo("Fatura parcelada", total, Economia.TAXA_PARCELAMENTO_FATURA,
					Economia.PARCELAS_FATURA, false)
			_limpar_fatura()
			return "Fatura trocada por %d parcelas com juros de %s ao mês. Custa caro, mas bem menos que o rotativo." % [
				Economia.PARCELAS_FATURA, Economia.porcento(Economia.TAXA_PARCELAMENTO_FATURA)]
		"minimo":
			pagar_fatura(fatura_minimo)
		"parcial":
			pagar_fatura(maxf(saldo, 0.0))
		_:
			pass
	var no_rotativo := _vencer_fatura()
	if no_rotativo < 0.01:
		return "Fatura quitada."
	var em_um_mes := no_rotativo * (1.0 + taxa)
	var texto := "%s entraram no rotativo. Com juros de %s ao mês, viram %s em 30 dias, sem você comprar mais nada." % [
		Economia.reais(no_rotativo), Economia.porcento(taxa), Economia.reais(em_um_mes)]
	if modo == "nada":
		texto += " Sem o pagamento mínimo, ainda entrou multa de 2%."
	return texto


# ---------------------------------------------------------------------------
# Empréstimos
# ---------------------------------------------------------------------------

func _novo_emprestimo(nome: String, valor: float, taxa: float, parcelas: int, creditar: bool) -> void:
	valor = snappedf(valor, 0.01)
	emprestimos.append({
		"nome": nome, "saldo": valor, "original": valor, "taxa": taxa,
		"parcela": snappedf(Economia.parcela_price(valor, taxa, parcelas), 0.01),
		"restantes": parcelas,
	})
	if creditar:
		_mov("emprestimo", nome, valor)


func _renegociar(regras: Dictionary) -> void:
	if rot_saldo < 0.01:
		return
	var desconto := minf(rot_juros_acum, rot_saldo) * float(regras.get("desconto", 0.0))
	_novo_emprestimo("Dívida renegociada", rot_saldo - desconto,
			float(regras.get("taxa", 0.03)), int(regras.get("parcelas", 8)), false)
	rot_saldo = 0.0
	rot_origem = 0.0
	rot_juros_acum = 0.0


## Antecipa parte do saldo devedor de um empréstimo. Devolve o valor pago.
func amortizar_emprestimo(indice: int, valor: float) -> float:
	if indice < 0 or indice >= emprestimos.size():
		return 0.0
	var e: Dictionary = emprestimos[indice]
	valor = snappedf(minf(minf(valor, float(e["saldo"])), maxf(saldo, 0.0)), 0.01)
	if valor < 0.01:
		return 0.0
	_mov("divida", "Antecipação: %s" % String(e["nome"]), -valor)
	e["saldo"] = snappedf(float(e["saldo"]) - valor, 0.01)
	if float(e["saldo"]) <= 0.5:
		emprestimos.remove_at(indice)
		_diario("%s quitado antes do prazo." % String(e["nome"]), "bom")
	return valor


## Paga agora uma conta em atraso. Devolve o valor pago.
func pagar_atrasada(indice: int) -> float:
	if indice < 0 or indice >= contas_atrasadas.size():
		return 0.0
	var c: Dictionary = contas_atrasadas[indice]
	var valor := float(c["valor"])
	if saldo < valor:
		return 0.0
	_mov(String(c.get("categoria", "custo_fixo")), "%s (em atraso)" % String(c["nome"]),
			-valor, "conta", valor * Economia.imposto(String(c.get("imposto", ""))))
	contas_atrasadas.remove_at(indice)
	return valor


# ---------------------------------------------------------------------------
# Ações do jogador
# ---------------------------------------------------------------------------

## Ritmos de trabalho disponíveis no vínculo atual. Quem ganha por dia pode
## rodar menos; quem tem salário fixo só escolhe entre o normal e a hora extra.
func ritmos_disponiveis() -> Array:
	if vinculo() == "informal":
		return ["leve", "normal", "puxado"]
	return ["normal", "puxado"]


func definir_ritmo(novo: String) -> Dictionary:
	if not ritmos_disponiveis().has(novo):
		return {"ok": false, "msg": "Ritmo indisponível neste trabalho."}
	ritmo = novo
	return {"ok": true, "msg": "Ritmo de trabalho: %s." % String(RITMOS[novo]["nome"]).to_lower()}


func motivo_sem_lazer(id: String) -> String:
	var l := Catalogo.lazer(id)
	if l.is_empty():
		return "Indisponível."
	var libera := int(esperas_lazer.get(id, 0))
	if libera > dia_total:
		var dias := libera - dia_total
		return "Disponível amanhã." if dias == 1 else "Disponível em %d dias." % dias
	if saldo < float(l.get("custo", 0.0)):
		return "Saldo insuficiente."
	return ""


func lazer(id: String) -> Dictionary:
	var motivo := motivo_sem_lazer(id)
	if motivo != "":
		return {"ok": false, "msg": motivo}
	var l := Catalogo.lazer(id)
	var antes := estresse()
	var custo := float(l.get("custo", 0.0))
	if custo > 0.0:
		_mov("consumo", String(l["nome"]), -custo, "conta", custo * Economia.imposto("lazer"))
	fadiga = maxf(fadiga + float(l.get("fadiga", 0.0)), FADIGA_MINIMA)
	choque = maxf(choque + float(l.get("choque", 0.0)), 0.0)
	for i in int(l.get("exposicoes", 0)):
		_remover_exposicao_mais_forte()
	if bool(l.get("detox", false)):
		for e: Variant in exposicoes:
			e["i"] = float(e["i"]) * 0.4
		for chave: Variant in interesse.keys():
			interesse[chave] = maxf(float(interesse[chave]) - 0.6, 0.0)
	esperas_lazer[id] = dia_total + int(l.get("espera", 1))
	var texto := ""
	if bool(l.get("folga", false)):
		acoes_hoje["folga"] = true
		if vinculo() == "informal":
			texto = " Hoje não entra renda."
	estat["lazeres"] = int(estat["lazeres"]) + 1
	var alivio := antes - estresse()
	return {"ok": true, "msg": "Estresse: %s%d pontos.%s" % [
		"-" if alivio >= 0.0 else "+", int(round(absf(alivio))), texto]}


func motivo_sem_matricula(id: String) -> String:
	var c := Catalogo.curso(id)
	if c.is_empty():
		return "Indisponível."
	if cursos_concluidos.has(id):
		return "Curso concluído."
	if cursos.has(id):
		return "Você já está matriculado."
	if not cursos.is_empty():
		return "Termine o curso atual primeiro."
	var req: Dictionary = c.get("requisitos", {})
	for necessario: Variant in req.get("cursos", []):
		if not cursos_concluidos.has(String(necessario)):
			return "Exige o curso: %s." % String(Catalogo.curso(String(necessario)).get("nome", necessario))
	if saldo < float(c.get("custo", 0.0)):
		return "Saldo insuficiente para a matrícula."
	return ""


func matricular(id: String) -> Dictionary:
	var motivo := motivo_sem_matricula(id)
	if motivo != "":
		return {"ok": false, "msg": motivo}
	var c := Catalogo.curso(id)
	var custo := float(c.get("custo", 0.0))
	if custo > 0.0:
		_mov("consumo", "Matrícula: %s" % String(c["nome"]), -custo, "conta",
				custo * Economia.imposto("servicos"))
	cursos[id] = 0
	estudo_pausado = false
	return {"ok": true, "msg": "Matrícula feita: %s. As aulas avançam sozinhas, uma por dia." % String(c["nome"])}


## Curso em andamento ("" se não houver).
func curso_atual() -> String:
	for id: Variant in cursos.keys():
		return String(id)
	return ""


## Pausa ou retoma os estudos. Pausado, o curso não avança nem cansa.
func alternar_estudo() -> Dictionary:
	if curso_atual() == "":
		return {"ok": false, "msg": "Você não está matriculado em nenhum curso."}
	estudo_pausado = not estudo_pausado
	return {"ok": true, "msg": "Estudos pausados." if estudo_pausado else "Estudos retomados."}


## Com matrícula ativa, o curso avança uma aula por dia (duas com notebook).
func _estudo_do_dia() -> void:
	var id := curso_atual()
	if id == "" or estudo_pausado:
		return
	var c := Catalogo.curso(id)
	var total := int(c["aulas"])
	var feitas := mini(int(cursos[id]) + (2 if tem_bem("notebook") else 1), total)
	cursos[id] = feitas
	fadiga = minf(fadiga + float(c.get("fadiga", 0.5)), FADIGA_MAXIMA)
	if feitas >= total:
		cursos.erase(id)
		cursos_concluidos.append(id)
		_ajustar_choque(-3.0)
		_diario("Curso concluído: %s. Veja as vagas na aba Trabalho." % String(c["nome"]), "bom")


## Lista de requisitos de um emprego: [{texto, ok}].
func requisitos_emprego(id: String) -> Array:
	var lista: Array = []
	var req: Dictionary = Catalogo.emprego(id).get("requisitos", {})
	for curso_id: Variant in req.get("cursos", []):
		lista.append({
			"texto": "Curso: %s" % String(Catalogo.curso(String(curso_id)).get("nome", curso_id)),
			"ok": cursos_concluidos.has(String(curso_id)),
		})
	if req.has("meses_clt"):
		var meses := int(req["meses_clt"])
		lista.append({"texto": "%d meses de carteira assinada" % meses, "ok": meses_clt >= meses})
	return lista


func motivo_sem_candidatura(id: String) -> String:
	if id == emprego_id:
		return "É o seu trabalho atual."
	if not candidatura.is_empty():
		return "Você já está em um processo seletivo."
	for requisito: Variant in requisitos_emprego(id):
		if not bool(requisito["ok"]):
			return "Falta: %s." % String(requisito["texto"])
	return ""


## Envia o currículo. A resposta do processo seletivo chega em alguns dias,
## como notificação.
func candidatar(id: String) -> Dictionary:
	var motivo := motivo_sem_candidatura(id)
	if motivo != "":
		return {"ok": false, "msg": motivo}
	candidatura = {
		"emprego": id,
		"dia": dia_total + rng.randi_range(DIAS_PROCESSO_SELETIVO_MIN, DIAS_PROCESSO_SELETIVO_MAX),
	}
	return {"ok": true, "msg": "Currículo enviado. A resposta chega em alguns dias."}


func _resultado_candidatura() -> void:
	var id := String(candidatura["emprego"])
	candidatura = {}
	var emp := Catalogo.emprego(id)
	var tentativas := int(tentativas_emprego.get(id, 0))
	var chance := float(emp.get("chance", 0.8)) + BONUS_NOVA_TENTATIVA * float(tentativas)
	var ev: Dictionary
	if rng.randf() < chance:
		var texto := "“Você foi aprovado para a vaga de %s.”" % String(emp["nome"])
		if emp.has("salario"):
			var liquido := float(emp["salario"]) * (1.0 - float(emp.get("inss", 0.0)) \
					- float(emp.get("desconto_vt", 0.0)))
			texto += " Cai na conta cerca de %s por mês, sempre no dia %d. Atenção: se você aceitar, a renda atual para hoje e o primeiro pagamento só vem no dia %d do mês que vem. É preciso ter caixa para atravessar esse período." % [
				Economia.reais(liquido, false), Economia.DIA_SALARIO, Economia.DIA_SALARIO]
		ev = {
			"id": "sis_aprovado", "categoria": "trabalho", "canal": "Trabalho",
			"remetente": "Processo seletivo", "titulo": "Você foi aprovado!", "texto": texto,
			"validade": 5, "urgente": true, "padrao": "recusar",
			"escolhas": [
				{"id": "aceitar", "texto": "Aceitar a vaga", "tipo": "neutra",
					"efeitos": {"emprego": id},
					"resultado": "Vaga aceita. " + String(emp.get("resumo", ""))},
				{"id": "recusar", "texto": "Recusar por enquanto", "tipo": "neutra", "efeitos": {},
					"resultado": "Você recusou. Dá para se candidatar de novo quando tiver mais fôlego no caixa."},
			],
		}
	else:
		tentativas_emprego[id] = tentativas + 1
		ev = {
			"id": "sis_reprovado", "categoria": "trabalho", "canal": "Trabalho",
			"remetente": "Processo seletivo", "titulo": "Não foi desta vez",
			"texto": "“Agradecemos o interesse na vaga de %s, mas seguimos com outro candidato.”" % String(emp["nome"]),
			"validade": 3, "urgente": true, "padrao": "ok",
			"escolhas": [{"id": "ok", "texto": "Tentar de novo depois", "tipo": "neutra",
				"efeitos": {"estresse": 2},
				"resultado": "Processo seletivo depende de muita coisa além de você. Cada nova tentativa aumenta a sua chance."}],
		}
	_criar_pendente(ev, ev)


func _trocar_emprego(novo: String) -> void:
	_acumular_salario()  # acerta os dias já trabalhados no emprego anterior
	emprego_id = novo
	dias_trab_mes = 0
	mes_admissao = mes()
	if not ritmos_disponiveis().has(ritmo):
		ritmo = "normal"
	var emp := emprego()
	var texto := "Novo trabalho: %s." % String(emp["nome"])
	if emp.has("salario"):
		texto += " O primeiro salário só cai no dia %d do mês que vem." % Economia.DIA_SALARIO
	_diario(texto, "bom")


func depositar_reserva(valor: float) -> Dictionary:
	valor = snappedf(minf(valor, maxf(saldo, 0.0)), 0.01)
	if valor < 0.01:
		return {"ok": false, "msg": "Sem saldo para guardar."}
	_mov("aporte", "Aporte na reserva", -valor)
	reserva = snappedf(reserva + valor, 0.01)
	mes_acum["aportes"] = float(mes_acum["aportes"]) + valor
	return {"ok": true, "msg": "%s guardados na reserva." % Economia.reais(valor), "valor": valor}


func sacar_reserva(valor: float) -> Dictionary:
	valor = snappedf(minf(valor, reserva), 0.01)
	if valor < 0.01:
		return {"ok": false, "msg": "A reserva está vazia."}
	reserva = maxf(snappedf(reserva - valor, 0.01), 0.0)
	_mov("resgate", "Resgate da reserva", valor)
	mes_acum["aportes"] = float(mes_acum["aportes"]) - valor
	return {"ok": true, "msg": "%s resgatados da reserva." % Economia.reais(valor), "valor": valor}


func motivo_sem_compra(id: String, forma: String) -> String:
	var b := Catalogo.bem(id)
	if b.is_empty():
		return "Indisponível."
	if tem_bem(id):
		return "Você já tem."
	var preco := float(b["preco"])
	if forma == "cartao":
		if not cartao_ativo:
			return "Você não tem cartão."
		if limite_disponivel() < preco:
			return "Limite insuficiente."
	elif saldo < preco:
		return "Saldo insuficiente."
	return ""


## Compra um bem da loja. [param forma]: "avista" ou "cartao".
func comprar_bem(id: String, forma: String) -> Dictionary:
	var motivo := motivo_sem_compra(id, forma)
	if motivo != "":
		return {"ok": false, "msg": motivo}
	var b := Catalogo.bem(id)
	var preco := float(b["preco"])
	var imposto_embutido := preco * Economia.imposto(String(b.get("categoria", "")))
	if forma == "cartao":
		_compra_cartao(String(b["nome"]), preco, int(b.get("parcelas", 1)), imposto_embutido)
	else:
		_mov("consumo", String(b["nome"]), -preco, "conta", imposto_embutido)
	_ganhar_bem(id, preco)
	return {"ok": true, "msg": "Comprado: %s." % String(b["nome"])}


func vender_bem(id: String) -> Dictionary:
	var b := Catalogo.bem(id)
	if not tem_bem(id) or b.is_empty():
		return {"ok": false, "msg": "Você não tem esse item."}
	if bool(b.get("essencial", false)):
		return {"ok": false, "msg": "É a sua ferramenta de trabalho."}
	var valor := float(b.get("revenda", 0.0))
	bens.erase(id)
	_mov("outros", "Venda: %s" % String(b["nome"]), valor)
	bem_alterado.emit(id, false, valor)
	return {"ok": true, "msg": "Vendido por %s." % Economia.reais(valor), "valor": valor}


func _ganhar_bem(id: String, valor_pago: float) -> void:
	if tem_bem(id):
		return
	bens.append(id)
	bem_alterado.emit(id, true, valor_pago)


# ---------------------------------------------------------------------------
# Eventos e decisões
# ---------------------------------------------------------------------------

## Dados do evento de uma notificação pendente.
func evento_de(pendente: Dictionary) -> Dictionary:
	if pendente.has("inline"):
		return pendente["inline"]
	return Catalogo.evento(String(pendente.get("evento", "")))


## Texto do evento com os valores atuais do jogador.
func texto_evento(ev: Dictionary) -> String:
	var texto := String(ev.get("texto", ""))
	if texto.contains("{"):
		texto = texto.replace("{parcelas_mes}", Economia.reais(parcelas_cartao_mes()))
	return texto


## Tempo, em segundos, para decidir um evento com relógio. O estresse alto
## encurta o tempo: pressão gera impulso.
func tempo_evento(ev: Dictionary) -> float:
	var tempo := float(ev.get("tempo", 0.0))
	if tempo > 0.0 and estresse() >= ModeloEstresse.ANSIOSO:
		tempo *= 0.7
	return tempo


## "" se a escolha está disponível; senão, o motivo.
func motivo_indisponivel(escolha: Dictionary) -> String:
	var req: Dictionary = escolha.get("requer", {})
	if req.has("saldo") and saldo < float(req["saldo"]):
		return "Saldo insuficiente"
	if req.has("reserva") and reserva < float(req["reserva"]):
		return "Reserva insuficiente"
	if req.has("limite"):
		if not cartao_ativo:
			return "Sem cartão"
		if limite_disponivel() < float(req["limite"]):
			return "Limite insuficiente"
	if req.has("saldo_ou_limite"):
		var valor := float(req["saldo_ou_limite"])
		if saldo < valor and limite_disponivel() < valor:
			return "Sem saldo nem limite"
	return ""


func _pendente(uid: int) -> Dictionary:
	for p: Variant in pendentes:
		if int(p["uid"]) == uid:
			return p
	return {}


func _remover_pendente(uid: int) -> void:
	for i in pendentes.size():
		if int(pendentes[i]["uid"]) == uid:
			pendentes.remove_at(i)
			return


func _condicoes_ok(ev: Dictionary) -> bool:
	var c: Dictionary = ev.get("condicoes", {})
	if dia_total < int(c.get("dia_min", 1)):
		return false
	if c.has("cartao") and bool(c["cartao"]) != cartao_ativo:
		return false
	if c.has("vinculo") and not (c["vinculo"] as Array).has(vinculo()):
		return false
	if c.has("saldo_min") and saldo < float(c["saldo_min"]):
		return false
	if c.has("flag") and not flags.has(String(c["flag"])):
		return false
	if c.has("sem_flag") and flags.has(String(c["sem_flag"])):
		return false
	if c.has("bem") and not tem_bem(String(c["bem"])):
		return false
	if c.has("sem_bem"):
		for id: Variant in (c["sem_bem"] as Array):
			if tem_bem(String(id)):
				return false
	if c.has("divida_min") and divida_ativa() < float(c["divida_min"]):
		return false
	if c.has("rotativo_min") and rot_saldo < float(c["rotativo_min"]):
		return false
	if c.has("reserva_min") and reserva < float(c["reserva_min"]):
		return false
	if c.has("fgts_min") and fgts < float(c["fgts_min"]):
		return false
	if c.has("mes") and not (c["mes"] as Array).has(nome_mes()):
		return false
	if c.has("sem_curso"):
		var curso_id := String(c["sem_curso"])
		if cursos.has(curso_id) or cursos_concluidos.has(curso_id):
			return false
	if c.has("parcelas_min") and parcelamentos.size() < int(c["parcelas_min"]):
		return false
	return true


func _dentro_do_limite(ev: Dictionary) -> bool:
	return not ev.has("max_vezes") or int(vistos.get(String(ev["id"]), 0)) < int(ev["max_vezes"])


## Peso do evento no sorteio. O "algoritmo" mostra mais do que o jogador
## costuma clicar: o interesse acumulado multiplica o peso da categoria.
func _peso(ev: Dictionary) -> float:
	var peso := float(ev.get("peso", 1.0))
	var categoria := String(ev.get("categoria", ""))
	if interesse.has(categoria):
		peso *= 1.0 + float(interesse[categoria])
	if categoria == ultima_categoria:
		peso *= 0.35
	return peso


func _criar_pendente(ev: Dictionary, inline: Dictionary) -> Dictionary:
	ultimo_uid += 1
	var id := String(ev["id"])
	var tempo := float(ev.get("tempo", 0.0))
	var validade := int(ev.get("validade", 1 if tempo > 0.0 else VALIDADE_PADRAO))
	var p := {
		"uid": ultimo_uid, "evento": id, "chegou": dia_total,
		"expira_em": dia_total + validade - 1,
		"urgente": tempo > 0.0 or bool(ev.get("urgente", false)),
	}
	if not inline.is_empty():
		p["inline"] = inline
	var intensidade := float(ev.get("fomo", 0.0))
	if intensidade > 0.0:
		exposicoes.append({"dia": dia_total, "i": intensidade, "uid": ultimo_uid})
		estat["gatilhos_fomo"] = int(estat["gatilhos_fomo"]) + 1
	if ev.has("ao_chegar"):
		var ao: Dictionary = ev["ao_chegar"]
		_mov(String(ao.get("cat", "outros")), String(ao.get("rotulo", ev.get("titulo", ""))),
				float(ao.get("saldo", 0.0)))
	vistos[id] = int(vistos.get(id, 0)) + 1
	esperas[id] = dia_total + int(ev.get("espera", 30))
	ultima_categoria = String(ev.get("categoria", ""))
	pendentes.append(p)
	evento_chegou.emit(p)
	return p


func _disparar(id: String) -> bool:
	var ev := Catalogo.evento(id)
	if ev.is_empty() or not _condicoes_ok(ev) or not _dentro_do_limite(ev):
		return false
	_criar_pendente(ev, {})
	return true


func _processar_agenda() -> void:
	var hoje: Array = []
	var futuros: Array = []
	for a: Variant in agenda:
		if int(a["dia"]) <= dia_total:
			hoje.append(a)
		else:
			futuros.append(a)
	agenda = futuros
	for a: Variant in hoje:
		_disparar(String(a["evento"]))


func _sortear_evento_do_dia() -> void:
	if dia_total < 3 or pendentes.size() >= MAX_PENDENTES:
		return
	if rng.randf() >= CHANCE_EVENTO_DIA:
		return
	var candidatos: Array = []
	var pesos: Array[float] = []
	var total := 0.0
	for ev: Variant in Catalogo.eventos():
		if bool(ev.get("so_agenda", false)):
			continue
		if int(esperas.get(String(ev["id"]), 0)) > dia_total:
			continue
		if not _dentro_do_limite(ev) or not _condicoes_ok(ev):
			continue
		var peso := _peso(ev)
		if peso <= 0.0:
			continue
		candidatos.append(ev)
		pesos.append(peso)
		total += peso
	if candidatos.is_empty():
		return
	var sorteio := rng.randf() * total
	var escolhido: Dictionary = candidatos[candidatos.size() - 1]
	for i in candidatos.size():
		sorteio -= pesos[i]
		if sorteio <= 0.0:
			escolhido = candidatos[i]
			break
	_criar_pendente(escolhido, {})


func _expirar_pendentes() -> void:
	for p: Variant in pendentes.duplicate():
		if dia_total >= int(p["expira_em"]):
			var ev := evento_de(p)
			var escolhas: Array = ev.get("escolhas", [])
			if escolhas.is_empty():
				_remover_pendente(int(p["uid"]))
				continue
			var padrao := String(ev.get("padrao", String(escolhas[0]["id"])))
			responder(int(p["uid"]), padrao, -1, true)


func _escolha(ev: Dictionary, escolha_id: String) -> Dictionary:
	for e: Variant in ev.get("escolhas", []):
		if String(e["id"]) == escolha_id:
			return e
	return {}


## Aplica a escolha do jogador a uma notificação. Devolve o resultado para a
## interface: {titulo, texto, tipo, vacina, deltas, por_tempo}.
## [param por_tempo] indica que o relógio acabou ou a notificação expirou.
func responder(uid: int, escolha_id: String, tempo_ms: int = -1, por_tempo: bool = false) -> Dictionary:
	var p := _pendente(uid)
	if p.is_empty():
		return {}
	var ev := evento_de(p)
	var esc := _escolha(ev, escolha_id)
	if esc.is_empty():
		return {}
	if not por_tempo and motivo_indisponivel(esc) != "":
		return {}
	_remover_pendente(uid)

	var antes_saldo := saldo
	var antes_reserva := reserva
	var antes_devido := total_devido()
	var antes_estresse := estresse()
	var contexto := {"estresse": antes_estresse, "d": razao_divida(), "saldo": saldo}

	var texto := _aplicar_efeitos(ev, esc, p)
	var tipo := String(esc.get("tipo", "neutra"))
	_contar_decisao(ev, tipo, por_tempo)

	var vacina := {}
	var vacina_id := String(esc.get("vacina", ev.get("vacina", "")))
	if vacina_id != "":
		vacina = _dar_vacina(vacina_id)

	decisao.emit({
		"dia": dia_total, "evento_id": String(ev["id"]), "categoria": String(ev.get("categoria", "")),
		"escolha_id": escolha_id, "tipo": "tempo_esgotado" if por_tempo else tipo,
		"tempo_ms": tempo_ms, "estresse": contexto["estresse"], "d": contexto["d"],
		"saldo": contexto["saldo"],
	})
	return {
		"titulo": String(ev.get("titulo", "")), "texto": texto, "tipo": tipo,
		"vacina": vacina, "por_tempo": por_tempo,
		"deltas": {
			"saldo": saldo - antes_saldo, "reserva": reserva - antes_reserva,
			"devido": total_devido() - antes_devido, "estresse": estresse() - antes_estresse,
		},
	}


func _contar_decisao(ev: Dictionary, tipo: String, por_tempo: bool) -> void:
	estat["decisoes"] = int(estat["decisoes"]) + 1
	if por_tempo:
		estat["tempo_esgotado"] = int(estat["tempo_esgotado"]) + 1
		return
	match tipo:
		"golpe":
			estat["golpes_sofridos"] = int(estat["golpes_sofridos"]) + 1
			estat["arriscadas"] = int(estat["arriscadas"]) + 1
		"arriscada":
			estat["arriscadas"] = int(estat["arriscadas"]) + 1
		"segura":
			estat["seguras"] = int(estat["seguras"]) + 1
			for e: Variant in ev.get("escolhas", []):
				if String(e.get("tipo", "")) == "golpe":
					estat["golpes_evitados"] = int(estat["golpes_evitados"]) + 1
					break


func _aplicar_efeitos(ev: Dictionary, esc: Dictionary, p: Dictionary) -> String:
	var ef: Dictionary = esc.get("efeitos", {})
	var rotulo := String(ef.get("rotulo", ev.get("titulo", "Evento")))
	var texto := String(esc.get("resultado", ""))
	var taxa := Economia.imposto(String(ef.get("imposto", "")))
	var uid := int(p["uid"])

	if ef.has("pagar_fatura"):
		texto = _efeito_fatura(String(ef["pagar_fatura"]))
	if ef.has("saldo"):
		var valor := float(ef["saldo"])
		var categoria := String(ef.get("cat", "consumo" if valor < 0.0 else "outros"))
		_mov(categoria, rotulo, valor, "conta", (-valor * taxa) if valor < 0.0 else 0.0)
	if ef.has("gasto"):
		var gasto := float(ef["gasto"])
		if saldo >= gasto:
			_mov("consumo", rotulo, -gasto, "conta", gasto * taxa)
		else:
			_compra_cartao(rotulo, gasto, 1, gasto * taxa)
	if ef.has("cartao"):
		var compra := float(ef["cartao"])
		_compra_cartao(rotulo, compra, int(ef.get("parcelas", 1)), compra * taxa)
	if ef.has("reserva"):
		var da_reserva := float(ef["reserva"])
		_mov("consumo", rotulo, da_reserva, "reserva",
				(-da_reserva * taxa) if da_reserva < 0.0 else 0.0)
	if ef.has("aporte"):
		depositar_reserva(float(ef["aporte"]))
	if ef.has("perda"):
		var perda: Dictionary = ef["perda"]
		var disponivel := maxf(saldo, 0.0)
		var valor_perdido: float
		if perda.has("valor"):
			valor_perdido = float(perda["valor"])
		else:
			valor_perdido = clampf(disponivel * float(perda.get("pct", 0.5)),
					float(perda.get("min", 0.0)), float(perda.get("max", 1000000.0)))
		_mov("golpe", rotulo, -minf(valor_perdido, disponivel))
	if ef.has("aposta"):
		texto = _efeito_aposta(ef["aposta"], esc)
	if ef.has("estresse"):
		_ajustar_choque(float(ef["estresse"]))
	if ef.has("fadiga"):
		fadiga = clampf(fadiga + float(ef["fadiga"]), FADIGA_MINIMA, FADIGA_MAXIMA)
	if bool(ef.get("cedeu", false)):
		cedidas += 1
		estat["fomo_cedidos"] = int(estat["fomo_cedidos"]) + 1
		_remover_exposicao(uid)
	if bool(ef.get("resistiu", false)):
		estat["fomo_resistidos"] = int(estat["fomo_resistidos"]) + 1
	if ef.has("alivio_fomo"):
		_aliviar_exposicao(uid, float(ef["alivio_fomo"]))
	if ef.has("interesse"):
		var mudancas: Dictionary = ef["interesse"]
		for chave: Variant in mudancas.keys():
			interesse[chave] = clampf(float(interesse.get(chave, 0.0)) + float(mudancas[chave]),
					0.0, INTERESSE_MAXIMO)
	if ef.has("flag"):
		flags[String(ef["flag"])] = true
	if ef.has("bem"):
		var bem_id := String(ef["bem"])
		_ganhar_bem(bem_id, float(Catalogo.bem(bem_id).get("preco", 0.0)))
	if ef.has("dias_sem_renda") and vinculo() != "clt":
		dias_sem_renda += int(ef["dias_sem_renda"])
	if ef.has("liberar_cartao"):
		cartao_ativo = true
		limite = float(ef["liberar_cartao"])
	if ef.has("limite"):
		limite += float(ef["limite"])
	if ef.has("emprestimo"):
		var em: Dictionary = ef["emprestimo"]
		_novo_emprestimo(String(em["nome"]), float(em["valor"]), float(em["taxa"]),
				int(em["parcelas"]), true)
	if ef.has("renegociar"):
		_renegociar(ef["renegociar"])
	if ef.has("fgts_antecipar") and fgts >= 0.01:
		_mov("outros", "Antecipação do FGTS", fgts * float(ef["fgts_antecipar"]))
		fgts = 0.0
	if ef.has("matricula"):
		matricular(String(ef["matricula"]))
	if ef.has("rescisao"):
		var verba := float(emprego().get("salario", 0.0)) + fgts * 1.4
		fgts = 0.0
		_mov("renda", "Rescisão: aviso prévio e FGTS com multa", verba)
	if ef.has("emprego"):
		_trocar_emprego(String(ef["emprego"]))
	if ef.has("agenda"):
		for a: Variant in (ef["agenda"] as Array):
			agenda.append({"evento": String(a["evento"]), "dia": dia_total + int(a["dias"])})
	return texto


func _efeito_aposta(aposta: Dictionary, esc: Dictionary) -> String:
	var valor := snappedf(minf(float(aposta["valor"]), maxf(saldo, 0.0)), 0.01)
	if valor < 0.01:
		return "Não havia saldo para isso."
	var especulacao := bool(aposta.get("especulacao", false))
	_mov("aposta", String(aposta.get("rotulo", "Depósito em aposta")), -valor)
	estat["apostas"] = int(estat["apostas"]) + 1
	estat["apostado"] = float(estat["apostado"]) + valor
	mes_acum["apostado"] = float(mes_acum["apostado"]) + valor
	var prob := float(aposta["prob"])
	if not especulacao:
		# A primeira aposta costuma dar certo: é a isca.
		if not flags.has("ja_apostou") and aposta.has("prob_primeira"):
			prob = float(aposta["prob_primeira"])
		flags["ja_apostou"] = true
	if rng.randf() < prob:
		var premio := snappedf(valor * float(aposta["mult"]), 0.01)
		_mov("premio_aposta", String(aposta.get("rotulo_premio", "Saque de aposta")), premio)
		estat["ganho_apostas"] = float(estat["ganho_apostas"]) + premio
		mes_acum["ganho_apostas"] = float(mes_acum["ganho_apostas"]) + premio
		return String(esc.get("resultado_ganhou", esc.get("resultado", "")))
	_ajustar_choque(2.0)
	return String(esc.get("resultado_perdeu", esc.get("resultado", "")))


func _dar_vacina(id: String) -> Dictionary:
	var dados := Catalogo.vacina(id)
	if dados.is_empty():
		return {}
	var nova := not vacinas.has(id)
	vacinas[id] = int(vacinas.get(id, 0)) + 1
	var resultado_vacina := dados.duplicate()
	resultado_vacina["nova"] = nova
	if nova:
		vacina_adquirida.emit(resultado_vacina)
	return resultado_vacina


## Soma ao choque (valor positivo) ou alivia o estresse basal (negativo):
## o alívio abate primeiro o choque e depois o cansaço.
func _ajustar_choque(valor: float) -> void:
	if valor >= 0.0:
		choque = minf(choque + valor, CHOQUE_MAXIMO)
		return
	var alivio := -valor
	var do_choque := minf(choque, alivio)
	choque -= do_choque
	fadiga = maxf(fadiga - (alivio - do_choque), FADIGA_MINIMA)


func _remover_exposicao(uid: int) -> void:
	for i in exposicoes.size():
		if int(exposicoes[i].get("uid", -1)) == uid:
			exposicoes.remove_at(i)
			return


func _aliviar_exposicao(uid: int, fracao: float) -> void:
	for e: Variant in exposicoes:
		if int(e.get("uid", -1)) == uid:
			e["i"] = float(e["i"]) * (1.0 - fracao)
			return


func _remover_exposicao_mais_forte() -> void:
	var indice := -1
	var maior := 0.0
	for i in exposicoes.size():
		var e: Dictionary = exposicoes[i]
		var peso := ModeloEstresse.peso_exposicao(float(e["i"]), dia_total - int(e["dia"]))
		if peso > maior:
			maior = peso
			indice = i
	if indice >= 0:
		exposicoes.remove_at(indice)


# ---------------------------------------------------------------------------
# Fechamento do mês, metas e fim de jogo
# ---------------------------------------------------------------------------

func _novo_acumulador() -> Dictionary:
	return {
		"renda": 0.0, "custos_fixos": 0.0, "consumo": 0.0, "juros": 0.0, "rendimentos": 0.0,
		"impostos": 0.0, "impostos_diretos": 0.0, "apostado": 0.0, "ganho_apostas": 0.0,
		"golpes": 0.0, "pagamentos_divida": 0.0, "aportes": 0.0, "soma_estresse": 0.0, "dias": 0,
	}


func _fechar_mes() -> void:
	if juros_cheque_acum >= 0.01:
		_mov("juros", "Juros do cheque especial", -juros_cheque_acum)
		juros_cheque_acum = 0.0
	_acumular_salario()
	if vinculo() == "clt":
		meses_clt += 1
		meses_clt_ano += 1
	var resumo := mes_acum.duplicate()
	resumo["mes"] = mes()
	resumo["nome_mes"] = nome_mes()
	resumo["saldo"] = saldo
	resumo["reserva"] = reserva
	resumo["meses_reserva"] = meses_reserva()
	resumo["divida"] = divida_ativa()
	resumo["razao_divida"] = razao_divida()
	resumo["patrimonio"] = patrimonio()
	resumo["estresse"] = estresse()
	resumo["estresse_medio"] = float(mes_acum["soma_estresse"]) / maxf(float(mes_acum["dias"]), 1.0)
	resumo["taxa_rotativo"] = Economia.taxa_rotativo(mes())
	resumo["vinculo"] = vinculo()
	resumo["dica"] = _dica_do_mes(resumo)
	historico_meses.append(resumo)
	if divida_ativa() < 1.0:
		flags["mes_sem_divida"] = true
	mes_acum = _novo_acumulador()
	mes_fechado.emit(resumo)
	_alerta_de_divida(float(resumo["razao_divida"]))
	_riscos_do_vinculo()


## Avisa, uma vez por episódio, que a dívida está a caminho da falência.
func _alerta_de_divida(razao: float) -> void:
	if razao < 1.0:
		flags.erase("alerta_divida")
		return
	if razao < Economia.RAZAO_DIVIDA_ALERTA or razao >= Economia.RAZAO_DIVIDA_FALENCIA \
			or flags.has("alerta_divida"):
		return
	flags["alerta_divida"] = true
	var ev := {
		"id": "sis_alerta_divida", "categoria": "sistema", "canal": "Mensagem", "remetente": "Guará",
		"titulo": "A dívida está saindo do controle",
		"texto": "Sua dívida ativa já equivale a %s meses da sua renda. Se um mês fechar com ela acima de %d meses de renda, é falência técnica. Saídas, da mais barata para a mais cara: usar a reserva, renegociar no feirão do banco, vender o que não é essencial. Rotativo e agiota vêm antes de qualquer outra conta." % [
			("%.1f" % razao).replace(".", ","), int(Economia.RAZAO_DIVIDA_FALENCIA)],
		"validade": 3, "urgente": true, "padrao": "ok", "vacina": "rotativo",
		"escolhas": [{"id": "ok", "texto": "Vou encarar a dívida", "tipo": "neutra", "efeitos": {},
			"resultado": "Dívida cara não se resolve sozinha: a cada dia parado ela cresce. O primeiro passo é parar de usar o cartão para o que não cabe no mês."}],
	}
	_criar_pendente(ev, ev)


func _dica_do_mes(r: Dictionary) -> String:
	var renda := maxf(float(r["renda"]), 1.0)
	if float(r["juros"]) >= 20.0:
		return "Você pagou %s de juros neste mês. É dinheiro que saiu sem comprar nada. Com o rotativo a %s ao mês, uma dívida parada dobra em menos de meio ano." % [
			Economia.reais(float(r["juros"])), Economia.porcento(float(r["taxa_rotativo"]))]
	if float(r["apostado"]) > 0.0:
		var saldo_apostas := float(r["ganho_apostas"]) - float(r["apostado"])
		return "Você apostou %s e recebeu %s de volta. Resultado das apostas no mês: %s." % [
			Economia.reais(float(r["apostado"])), Economia.reais(float(r["ganho_apostas"])),
			Economia.reais(saldo_apostas)]
	if float(r["golpes"]) > 0.0:
		return "Golpes e armadilhas levaram %s neste mês. Nenhum começou pedindo muito: todos começaram pedindo pressa." % Economia.reais(float(r["golpes"]))
	if float(r["rendimentos"]) >= 1.0:
		return "Sua reserva rendeu %s neste mês sem você fazer nada. São os juros compostos trabalhando a seu favor." % Economia.reais(float(r["rendimentos"]))
	return "Cerca de %s dos seus gastos foram imposto embutido nos preços: %s da sua renda do mês." % [
		Economia.reais(float(r["impostos"])), Economia.porcento(float(r["impostos"]) / renda, 0)]


## Sorteia, no fim do mês, a dispensa de quem trabalha por salário.
func _riscos_do_vinculo() -> void:
	var emp := emprego()
	var tipo := vinculo()
	if tipo == "informal" or mes() - mes_admissao < MESES_SEM_DISPENSA:
		return
	if rng.randf() >= float(emp.get("risco_dispensa", 0.0)):
		return
	var ev: Dictionary
	if tipo == "pj":
		ev = {
			"id": "sis_dispensa_pj", "categoria": "trabalho", "canal": "Trabalho",
			"remetente": "Gerente da loja", "titulo": "A loja encerrou os contratos PJ",
			"texto": "“A partir de amanhã não precisamos mais dos seus serviços.” Sem aviso prévio, sem rescisão, sem FGTS e sem seguro-desemprego. Os dias que você trabalhou serão pagos no dia 5.",
			"validade": 2, "urgente": true, "padrao": "ok", "vacina": "pj_clt",
			"escolhas": [{"id": "ok", "texto": "Voltar para as entregas", "tipo": "neutra",
				"efeitos": {"emprego": "bico_bike", "estresse": 8},
				"resultado": "De volta ao aplicativo. Quem é PJ pode ser dispensado de um dia para o outro: por isso a reserva pesa ainda mais."}],
		}
	else:
		ev = {
			"id": "sis_dispensa_clt", "categoria": "trabalho", "canal": "Trabalho",
			"remetente": "RH", "titulo": "A empresa cortou parte da equipe",
			"texto": "Você foi dispensado sem justa causa. Por ter carteira assinada, recebe o aviso prévio e saca o FGTS com multa de 40%.",
			"validade": 2, "urgente": true, "padrao": "ok", "vacina": "pj_clt",
			"escolhas": [{"id": "ok", "texto": "Receber a rescisão", "tipo": "neutra",
				"efeitos": {"rescisao": true, "emprego": "bico_bike", "estresse": 6},
				"resultado": "A rescisão caiu na conta e te dá fôlego para procurar outra vaga. É a diferença entre ser dispensado com e sem direitos."}],
		}
	_criar_pendente(ev, ev)


## Progresso de uma meta, de 0 a 1.
func progresso_meta(meta: Dictionary) -> float:
	match String(meta.get("tipo", "")):
		"mes_sem_divida":
			return 1.0 if flags.has("mes_sem_divida") else 0.0
		"reserva_meses":
			return clampf(meses_reserva() / maxf(float(meta["valor"]), 0.01), 0.0, 1.0)
		"cursos":
			return clampf(float(cursos_concluidos.size()) / maxf(float(meta["valor"]), 1.0), 0.0, 1.0)
		"vacinas":
			return clampf(float(vacinas.size()) / maxf(float(meta["valor"]), 1.0), 0.0, 1.0)
		"vinculo":
			return 1.0 if vinculo() == String(meta["valor"]) else 0.0
	return 0.0


func _meta_cumprida(meta: Dictionary) -> bool:
	if progresso_meta(meta) < 1.0:
		return false
	# A meta final também exige estar sem dívida ativa.
	if bool(meta.get("final", false)) and divida_ativa() >= 1.0:
		return false
	return true


func _verificar_metas() -> void:
	for meta: Variant in Catalogo.metas():
		var id := String(meta["id"])
		if metas_ok.has(id) or not _meta_cumprida(meta):
			continue
		metas_ok.append(id)
		_ajustar_choque(-3.0)
		_diario("Meta concluída: %s." % String(meta["titulo"]), "bom", false)
		meta_concluida.emit(meta)
		if bool(meta.get("final", false)) and not venceu:
			venceu = true
			resultado = "vitoria"
			venceu_jogo.emit()


func _verificar_fim() -> void:
	if fim:
		return
	if dias_criticos >= ModeloEstresse.DIAS_ATE_ESGOTAMENTO:
		_encerrar("esgotamento")
	elif atrasos_graves >= Economia.ATRASOS_GRAVES_FALENCIA:
		_encerrar("falencia")
	elif dia_do_mes() == Economia.DIAS_MES and razao_divida() >= Economia.RAZAO_DIVIDA_FALENCIA:
		_encerrar("falencia")


func _encerrar(motivo: String) -> void:
	fim = true
	resultado = motivo
	encerrada.emit(motivo)


# ---------------------------------------------------------------------------
# Registro
# ---------------------------------------------------------------------------

## Movimenta dinheiro e emite a transação para o extrato.
## [param meio]: "conta" ou "reserva".
func _mov(categoria: String, descricao: String, valor: float, meio: String = "conta",
		imposto_embutido: float = 0.0) -> void:
	valor = snappedf(valor, 0.01)
	if absf(valor) < 0.005:
		return
	if meio == "reserva":
		reserva = maxf(snappedf(reserva + valor, 0.01), 0.0)
	else:
		saldo = snappedf(saldo + valor, 0.01)
	match categoria:
		"renda":
			mes_acum["renda"] = float(mes_acum["renda"]) + valor
			estat["renda_total"] = float(estat["renda_total"]) + valor
			_renda_dia += valor
		"imposto_direto":
			mes_acum["impostos_diretos"] = float(mes_acum["impostos_diretos"]) - valor
			_renda_dia += valor
		"custo_fixo":
			mes_acum["custos_fixos"] = float(mes_acum["custos_fixos"]) - valor
		"consumo":
			mes_acum["consumo"] = float(mes_acum["consumo"]) - valor
		"golpe":
			mes_acum["golpes"] = float(mes_acum["golpes"]) - valor
			estat["perdido_golpes"] = float(estat["perdido_golpes"]) - valor
		"divida":
			mes_acum["pagamentos_divida"] = float(mes_acum["pagamentos_divida"]) - valor
	if imposto_embutido > 0.0:
		mes_acum["impostos"] = float(mes_acum["impostos"]) + imposto_embutido
		estat["impostos"] = float(estat["impostos"]) + imposto_embutido
	transacao.emit({
		"dia": dia_total, "categoria": categoria, "descricao": descricao, "valor": valor,
		"meio": meio, "saldo_apos": saldo, "imposto": snappedf(imposto_embutido, 0.01),
	})


func _diario(texto: String, tipo: String, notificar: bool = true) -> void:
	diario.append({"dia": dia_total, "texto": texto, "tipo": tipo})
	while diario.size() > LINHAS_DIARIO:
		diario.pop_front()
	if notificar:
		aviso.emit(texto, tipo)
