class_name ModeloEstresse
extends RefCounted
## Equação 1 do artigo - Estresse Acumulado:
##
##     S_t = S_0 * e^(alfa * D) + soma(beta * F_fomo)
##
## S_0    estresse basal: depende do vínculo de trabalho, do cansaço
##        acumulado e de choques recentes (golpe, conta atrasada, aperto).
## D      razão entre a dívida ativa e a renda mensal disponível.
## alfa   sensibilidade ao endividamento (efeito "bola de neve").
## F_fomo exposição recente a gatilhos de consumo; cada exposição perde
##        força com os dias.
## beta   coeficiente de vulnerabilidade: cai a cada "vacina cognitiva"
##        aprendida e sobe quando o jogador cede aos gatilhos.
##
## O resultado é limitado a 0..100 e exibido como "saúde emocional".

const ALFA := 0.55
const BETA_BASE := 2.6
## Fração da intensidade de uma exposição que sobra a cada dia.
const RETENCAO_FOMO_DIA := 0.93
const DIAS_MEMORIA_FOMO := 45
const S0_MINIMO := 4.0
const S0_MAXIMO := 45.0
## Piso da renda usada em D, para a razão não explodir sem renda nenhuma.
const RENDA_PISO := 600.0

const VULNERABILIDADE_MINIMA := 0.45
const VULNERABILIDADE_MAXIMA := 1.6
const PESO_VACINA := 0.05
const PESO_CEDIDA := 0.07
const MAX_CEDIDAS := 8

const TENSO := 50.0
const ANSIOSO := 70.0
const NO_LIMITE := 85.0
const CRITICO := 95.0
const DIAS_ATE_ESGOTAMENTO := 10


## Aplica a Equação 1.
static func calcular(s0: float, d: float, f_fomo: float,
		alfa: float = ALFA, beta_atual: float = BETA_BASE) -> float:
	return clampf(s0 * exp(alfa * d) + beta_atual * f_fomo, 0.0, 100.0)


## D: dívida ativa dividida pela renda mensal disponível.
static func razao_divida(divida_ativa: float, renda_mensal: float) -> float:
	return maxf(divida_ativa, 0.0) / maxf(renda_mensal, RENDA_PISO)


## Beta ajustado pela vulnerabilidade do jogador.
static func beta(vacinas: int, cedidas: int) -> float:
	var vulnerabilidade := 1.0 + PESO_CEDIDA * float(mini(cedidas, MAX_CEDIDAS)) \
			- PESO_VACINA * float(vacinas)
	return BETA_BASE * clampf(vulnerabilidade, VULNERABILIDADE_MINIMA, VULNERABILIDADE_MAXIMA)


## Peso atual de uma exposição de intensidade [param intensidade] ocorrida
## há [param dias] dias.
static func peso_exposicao(intensidade: float, dias: int) -> float:
	return intensidade * pow(RETENCAO_FOMO_DIA, float(maxi(dias, 0)))


## Nome da faixa de estresse, para a interface.
static func faixa(estresse: float) -> String:
	if estresse >= NO_LIMITE:
		return "No limite"
	if estresse >= ANSIOSO:
		return "Ansioso"
	if estresse >= TENSO:
		return "Tenso"
	if estresse >= 30.0:
		return "Atento"
	return "Tranquilo"
