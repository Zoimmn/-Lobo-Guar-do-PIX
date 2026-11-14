class_name BotJogador
extends RefCounted
## Jogador automático usado nos testes e na calibração do equilíbrio.
##
## Cada perfil tem uma probabilidade de agir por impulso em cada decisão:
##   "prudente"  -   0%: escolhe sempre a opção segura, guarda, estuda, descansa.
##   "atento"    -  15%: joga bem, mas escorrega de vez em quando.
##   "regular"   -  30%: planeja como o atento, mas cede a quase um terço dos gatilhos.
##   "medio"     -  50%: metade das decisões no impulso, pouco planejamento.
##   "impulsivo" - 100%: cede a todo gatilho, paga só o mínimo, não guarda nada.
##
## O bot joga a mesma simulação que o jogador: lê as notificações pendentes,
## responde e usa as mesmas ações das telas.

const IMPULSO := {"prudente": 0.0, "atento": 0.15, "regular": 0.3, "medio": 0.5, "impulsivo": 1.0}
const ORDEM_CURSOS: Array[String] = ["atendimento", "informatica", "tecnico"]
## Caixa mínimo para trocar a renda diária por um salário que só cai no dia 5.
const CAIXA_PARA_TROCAR_DE_TRABALHO := 900.0

var perfil: String
var impulso: float
var rng := RandomNumberGenerator.new()


func _init(perfil_do_bot: String, semente: int) -> void:
	perfil = perfil_do_bot
	impulso = float(IMPULSO.get(perfil_do_bot, 0.5))
	rng.seed = semente


func _planeja() -> bool:
	return perfil == "prudente" or perfil == "atento" or perfil == "regular"


## Joga até [param meses] meses, ou até a partida acabar. Devolve um resumo.
func jogar(sim: Simulacao, meses: int, parar_na_vitoria: bool = true) -> Dictionary:
	var mes_vitoria := -1
	var mes_carteira := -1
	while not sim.fim and sim.mes() <= meses:
		decidir(sim)
		agir(sim)
		sim.avancar_dia()
		if mes_carteira < 0 and sim.vinculo() == "clt":
			mes_carteira = sim.mes()
		if sim.venceu and mes_vitoria < 0:
			mes_vitoria = sim.mes()
			if parar_na_vitoria:
				break
	return {
		"perfil": perfil, "resultado": sim.resultado if (sim.fim or sim.venceu) else "em_andamento",
		"mes_final": sim.mes(), "mes_vitoria": mes_vitoria, "mes_carteira": mes_carteira,
		"patrimonio": sim.patrimonio(), "reserva_meses": sim.meses_reserva(),
		"estresse_medio": float(sim.estat["soma_estresse"]) / maxf(float(sim.estat["dias"]), 1.0),
		"maior_estresse": float(sim.estat["maior_estresse"]),
		"vacinas": sim.vacinas.size(), "golpes_sofridos": int(sim.estat["golpes_sofridos"]),
		"golpes_evitados": int(sim.estat["golpes_evitados"]),
		"apostado": float(sim.estat["apostado"]), "ganho_apostas": float(sim.estat["ganho_apostas"]),
		"juros": float(sim.estat["juros"]), "emprego": sim.emprego_id,
		"decisoes": int(sim.estat["decisoes"]), "pontuacao": sim.pontuacao(),
	}


## Responde a todas as notificações pendentes.
func decidir(sim: Simulacao) -> void:
	for p: Variant in sim.pendentes.duplicate():
		var ev := sim.evento_de(p)
		# Quem planeja usa a reserva para não deixar a fatura cair no rotativo.
		if String(ev["id"]) == "sis_fatura" and _planeja() and sim.saldo < sim.fatura_fechada:
			sim.sacar_reserva(sim.fatura_fechada - sim.saldo + 1.0)
		var escolha := _escolher(sim, ev)
		if escolha != "":
			sim.responder(int(p["uid"]), escolha, 4000)


func _escolher(sim: Simulacao, ev: Dictionary) -> String:
	var cauteloso := rng.randf() >= impulso
	var disponiveis: Array = []
	for e: Variant in ev.get("escolhas", []):
		if sim.motivo_indisponivel(e) == "":
			disponiveis.append(e)
	if disponiveis.is_empty():
		return ""
	var id_evento := String(ev["id"])
	if id_evento == "sis_fatura":
		var ordem: Array = ["total", "parcial", "parcelar", "minimo", "nada"] if cauteloso \
				else ["minimo", "nada", "parcial", "total"]
		for id: Variant in ordem:
			for e: Variant in disponiveis:
				if String(e["id"]) == String(id):
					return String(id)
	if id_evento == "sis_aprovado":
		var tem_caixa := sim.saldo + sim.reserva >= CAIXA_PARA_TROCAR_DE_TRABALHO
		if _planeja() and sim.vinculo() == "informal" and not tem_caixa:
			return "recusar"
		return "aceitar"
	var preferidos: Array = ["segura", "neutra"] if cauteloso else ["golpe", "arriscada"]
	for tipo: Variant in preferidos:
		for e: Variant in disponiveis:
			if String(e.get("tipo", "neutra")) == String(tipo):
				return String(e["id"])
	return String(disponiveis[0]["id"])


## Usa as ações do dia conforme o perfil.
func agir(sim: Simulacao) -> void:
	var estresse := sim.estresse()
	_ajustar_ritmo(sim, estresse)
	_cuidar_do_estresse(sim, estresse)
	match perfil:
		"prudente", "atento", "regular":
			_estudar(sim, 300.0, estresse)
			_buscar_emprego(sim)
			_equipar(sim)
			_quitar_dividas(sim, 150.0)
			_guardar(sim, 400.0 if perfil == "prudente" else 500.0)
		"medio":
			if rng.randf() < 0.04:
				_estudar(sim, 200.0, estresse)
			_buscar_emprego(sim)
			_quitar_dividas(sim, 300.0)
			_guardar(sim, 700.0)
		_:
			pass


func _ajustar_ritmo(sim: Simulacao, estresse: float) -> void:
	var alvo := "normal"
	match perfil:
		"prudente", "atento", "regular":
			if estresse < 40.0:
				alvo = "puxado"
			elif estresse >= 58.0:
				alvo = "leve"
		"medio":
			if estresse < 50.0:
				alvo = "puxado"
		_:
			if sim.saldo < 150.0:
				alvo = "puxado"
	if not sim.ritmos_disponiveis().has(alvo):
		alvo = "normal"
	if sim.ritmo != alvo:
		sim.definir_ritmo(alvo)


func _cuidar_do_estresse(sim: Simulacao, estresse: float) -> void:
	var limite_folga := 68.0
	var limite_role := 50.0
	match perfil:
		"medio":
			limite_folga = 75.0
			limite_role = 65.0
		"impulsivo":
			limite_folga = 88.0
			limite_role = 999.0
	if estresse > limite_folga and sim.motivo_sem_lazer("descansar") == "":
		sim.lazer("descansar")
	if estresse > limite_role and sim.saldo > 250.0 and sim.motivo_sem_lazer("role_barato") == "":
		sim.lazer("role_barato")
	if _planeja() and sim.f_fomo() > 3.0 and sim.motivo_sem_lazer("detox") == "":
		sim.lazer("detox")


func _estudar(sim: Simulacao, folga: float, estresse: float) -> void:
	if sim.curso_atual() != "":
		# Com o estresse alto, tranca o curso por uns dias.
		var deve_pausar := estresse > 75.0
		if deve_pausar != sim.estudo_pausado and (deve_pausar or estresse < 60.0):
			sim.alternar_estudo()
		return
	for id in ORDEM_CURSOS:
		if sim.cursos_concluidos.has(id):
			continue
		var custo := float(Catalogo.curso(id).get("custo", 0.0))
		if sim.saldo >= custo + folga and sim.motivo_sem_matricula(id) == "":
			sim.matricular(id)
		return


func _buscar_emprego(sim: Simulacao) -> void:
	if not sim.candidatura.is_empty():
		return
	if _planeja() and sim.vinculo() == "informal" \
			and sim.saldo + sim.reserva < CAIXA_PARA_TROCAR_DE_TRABALHO:
		return
	var lista := Catalogo.empregos()
	var atual := 0
	for i in lista.size():
		if String(lista[i]["id"]) == sim.emprego_id:
			atual = i
	for i in range(lista.size() - 1, atual, -1):
		var id := String(lista[i]["id"])
		if sim.motivo_sem_candidatura(id) == "":
			sim.candidatar(id)
			return


func _equipar(sim: Simulacao) -> void:
	if sim.vinculo() != "informal":
		return
	if sim.saldo > 450.0 and sim.motivo_sem_compra("bag", "avista") == "":
		sim.comprar_bem("bag", "avista")
	if sim.saldo > 400.0 and sim.motivo_sem_compra("capa_chuva", "avista") == "":
		sim.comprar_bem("capa_chuva", "avista")


func _quitar_dividas(sim: Simulacao, folga: float) -> void:
	if _planeja():
		# Dívida cara rende mais contra você do que a reserva rende a favor.
		var cara := sim.rot_saldo + sim.total_atrasadas()
		for e: Variant in sim.emprestimos:
			if float(e["taxa"]) >= 0.05:
				cara += float(e["saldo"])
		var falta := cara - maxf(sim.saldo - folga, 0.0)
		if cara > 0.0 and falta > 0.0 and sim.reserva > 0.0:
			sim.sacar_reserva(falta)
		for i in range(sim.emprestimos.size() - 1, -1, -1):
			if float(sim.emprestimos[i]["taxa"]) >= 0.05 and sim.saldo > folga:
				sim.amortizar_emprestimo(i, sim.saldo - folga)
	if sim.rot_saldo > 0.0 and sim.saldo > folga:
		sim.pagar_rotativo(sim.saldo - folga)
	if sim.fatura_fechada > 0.0 and sim.saldo > sim.fatura_fechada + folga:
		sim.pagar_fatura(sim.fatura_fechada)


func _guardar(sim: Simulacao, folga: float) -> void:
	var comprometido := sim.fatura_fechada + sim.fatura_aberta + sim.total_atrasadas()
	var sobra := sim.saldo - folga - comprometido
	if sobra > 50.0:
		sim.depositar_reserva(sobra)
	elif sim.saldo < 60.0 and sim.reserva > 0.0:
		sim.sacar_reserva(minf(250.0, sim.reserva))
