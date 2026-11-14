class_name Economia
extends RefCounted
## Constantes de calibração e fórmulas financeiras do jogo.
##
## Os valores são aproximações didáticas da realidade brasileira, ajustadas
## para o ritmo de uma partida. Mexer aqui muda o equilíbrio do jogo inteiro,
## então rode os testes (res://testes/testes.tscn) depois de qualquer ajuste.

const DIAS_MES := 30
const DIAS_UTEIS := 22
const MESES: Array[String] = [
	"Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
	"Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]
## A partida começa em março (índice 2): o ano que "começa depois do Carnaval".
const MES_INICIAL := 2

# --- Situação inicial ---
const SALDO_INICIAL := 600.0

# --- Custos fixos de vida ---
const MORADIA := 600.0
const DIA_MORADIA := 10
const CONTAS_CASA := 160.0
const DIA_CONTAS := 15
const PLANO_CELULAR := 50.0
const DIA_CELULAR := 20
const ALIMENTACAO_DIA := 16.0
const ALIMENTACAO_MINIMA_DIA := 3.0
## Custo de vida de um mês sem nenhum benefício de emprego. É a base da meta
## de reserva: se o trabalho acabar, o vale-refeição acaba junto.
const CUSTO_VIDA_BASE := MORADIA + CONTAS_CASA + PLANO_CELULAR + ALIMENTACAO_DIA * DIAS_MES

# --- Datas do trabalho e das dívidas ---
const DIA_SALARIO := 5
const DIA_DAS := 20
const DIA_EMPRESTIMOS := 10
const MES_DECIMO_TERCEIRO := "Dezembro"
const DIA_DECIMO_TERCEIRO := 20

# --- Cartão de crédito ---
const DIA_FECHAMENTO := 25
const DIAS_ATE_VENCIMENTO := 10          # fecha no dia 25, vence no dia 5
const PAGAMENTO_MINIMO := 0.15
## Rotativo real no Brasil: acima de 400% ao ano (cerca de 14,5% ao mês).
const TAXA_ROTATIVO_REAL := 0.145
## Atenuação inicial da curva de juros (seção 10 do artigo): nos primeiros
## meses a taxa é menor, para que a punição não chegue antes do aprendizado.
const TAXA_ROTATIVO_INICIAL := 0.08
const MESES_ATENUACAO := 3
const MESES_RAMPA := 3
const MULTA_ATRASO := 0.02
const TAXA_PARCELAMENTO_FATURA := 0.055
const PARCELAS_FATURA := 6

# --- Conta e reserva ---
const LIMITE_CHEQUE_ESPECIAL := 300.0
## Teto do cheque especial definido pelo Banco Central: 8% ao mês.
const TAXA_CHEQUE_ESPECIAL := 0.08
## Reserva com liquidez diária: cerca de 1% ao mês.
const TAXA_RESERVA := 0.010
const META_RESERVA_MESES := 6.0

# --- Fim de jogo ---
## Falência técnica: fechar o mês devendo, em dívida ativa, três meses de renda.
const RAZAO_DIVIDA_FALENCIA := 3.0
## A partir daqui o jogo avisa que a dívida está saindo do controle.
const RAZAO_DIVIDA_ALERTA := 1.5
const ATRASOS_GRAVES_FALENCIA := 3
const DIAS_PARA_ATRASO_GRAVE := 30

# --- Impostos embutidos no consumo (estimativas aproximadas) ---
const IMPOSTO := {
	"alimentacao": 0.17,
	"moradia": 0.0,
	"contas": 0.32,
	"celular": 0.33,
	"transporte": 0.20,
	"lazer": 0.20,
	"eletronicos": 0.36,
	"vestuario": 0.32,
	"servicos": 0.15,
	"saude": 0.20,
}


## Converte uma taxa mensal na taxa diária equivalente (juros compostos).
static func taxa_diaria(taxa_mensal: float) -> float:
	return pow(1.0 + taxa_mensal, 1.0 / float(DIAS_MES)) - 1.0


## Converte uma taxa mensal na taxa anual equivalente (juros compostos).
static func taxa_anual(taxa_mensal: float) -> float:
	return pow(1.0 + taxa_mensal, 12.0) - 1.0


## Taxa mensal do rotativo no mês informado da partida (1 = primeiro mês).
static func taxa_rotativo(mes: int) -> float:
	if mes <= MESES_ATENUACAO:
		return TAXA_ROTATIVO_INICIAL
	var t := clampf(float(mes - MESES_ATENUACAO) / float(MESES_RAMPA), 0.0, 1.0)
	return lerpf(TAXA_ROTATIVO_INICIAL, TAXA_ROTATIVO_REAL, t)


## Parcela fixa pela tabela Price.
static func parcela_price(valor: float, taxa_mensal: float, parcelas: int) -> float:
	if parcelas <= 0:
		return valor
	if taxa_mensal <= 0.0:
		return valor / float(parcelas)
	var fator := pow(1.0 + taxa_mensal, float(parcelas))
	return valor * taxa_mensal * fator / (fator - 1.0)


## Alíquota aproximada de imposto embutido para uma categoria de consumo.
static func imposto(categoria: String) -> float:
	return float(IMPOSTO.get(categoria, 0.0))


## Formata um valor em reais: 1234.5 -> "R$ 1.234,50".
static func reais(valor: float, com_centavos: bool = true) -> String:
	var negativo := valor <= -0.005
	var absoluto := absf(valor)
	var inteiro: int
	var centavos := 0
	if com_centavos:
		var total := int(round(absoluto * 100.0))
		@warning_ignore("integer_division")
		inteiro = total / 100
		centavos = total % 100
	else:
		inteiro = int(round(absoluto))
		negativo = valor <= -0.5
	var digitos := str(inteiro)
	var agrupado := ""
	while digitos.length() > 3:
		agrupado = "." + digitos.substr(digitos.length() - 3) + agrupado
		digitos = digitos.substr(0, digitos.length() - 3)
	agrupado = digitos + agrupado
	var texto := "R$ " + agrupado
	if com_centavos:
		texto += ",%02d" % centavos
	return ("-" + texto) if negativo else texto


## Formata um percentual: 0.145 -> "14,5%".
static func porcento(fracao: float, casas: int = 1) -> String:
	var texto := ("%." + str(casas) + "f") % (fracao * 100.0)
	return texto.replace(".", ",") + "%"
