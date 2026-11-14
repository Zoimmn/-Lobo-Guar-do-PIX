extends Node
## Testes automáticos da simulação e da persistência.
##
## Rodar pela linha de comando, na pasta do projeto:
##   godot --headless --path . res://testes/testes.tscn
## Com o relatório de calibração dos bots:
##   godot --headless --path . res://testes/testes.tscn -- --bots
##
## O processo termina com código 0 se tudo passou e 1 se houve falha.

const TIPOS_ESCOLHA: Array[String] = ["segura", "neutra", "arriscada", "golpe"]
const TIPOS_META: Array[String] = ["mes_sem_divida", "reserva_meses", "cursos", "vacinas", "vinculo"]

var _total: int = 0
var _falhas: int = 0


func _ready() -> void:
	var argumentos := OS.get_cmdline_user_args()
	print("== Testes do Lobo-Guará do PIX ==")
	_teste_formulas()
	_teste_estresse()
	_teste_catalogo()
	_teste_livro_caixa()
	_teste_cartao()
	_teste_teto_rotativo()
	_teste_reserva_e_contas()
	_teste_trabalho_e_estudo()
	_teste_eventos()
	_teste_salvar_carregar()
	_teste_banco(false)
	_teste_banco(true)
	_teste_game_manager()
	_teste_bots()
	if argumentos.has("--bots"):
		_relatorio_bots()
	print("\n%d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


# ---------------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------------

func _ok(condicao: bool, descricao: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("  FALHOU: " + descricao)


func _perto(a: float, b: float, descricao: String, tolerancia: float = 0.01) -> void:
	_ok(absf(a - b) <= tolerancia, "%s (obtido %.4f, esperado %.4f)" % [descricao, a, b])


func _nova(semente: int) -> Simulacao:
	var sim := Simulacao.new()
	sim.nova_partida(semente)
	return sim


func _avancar(sim: Simulacao, dias: int) -> void:
	for i in dias:
		sim.avancar_dia()


func _avancar_ate_dia_do_mes(sim: Simulacao, dia: int) -> void:
	var guarda := 0
	while sim.dia_do_mes() != dia and guarda < 40 and not sim.fim:
		sim.avancar_dia()
		guarda += 1


# ---------------------------------------------------------------------------
# Fórmulas
# ---------------------------------------------------------------------------

func _teste_formulas() -> void:
	print("- fórmulas financeiras")
	var diaria := Economia.taxa_diaria(0.08)
	_perto(pow(1.0 + diaria, 30.0), 1.08, "taxa diária composta equivale à mensal", 0.00001)
	_perto(Economia.parcela_price(800.0, 0.075, 10), 116.55, "parcela Price de R$ 800 a 7,5% em 10x")
	_perto(Economia.parcela_price(600.0, 0.0, 6), 100.0, "parcela sem juros")
	_perto(Economia.taxa_rotativo(1), Economia.TAXA_ROTATIVO_INICIAL, "rotativo atenuado no mês 1")
	_perto(Economia.taxa_rotativo(12), Economia.TAXA_ROTATIVO_REAL, "rotativo real depois da rampa")
	_ok(Economia.taxa_rotativo(5) > Economia.taxa_rotativo(3), "rotativo sobe durante a rampa")
	_ok(Economia.taxa_anual(Economia.TAXA_ROTATIVO_REAL) > 4.0, "rotativo real passa de 400% ao ano")
	_ok(Economia.reais(1234.5) == "R$ 1.234,50", "formato de reais com milhar: " + Economia.reais(1234.5))
	_ok(Economia.reais(-50.0) == "-R$ 50,00", "formato de reais negativo: " + Economia.reais(-50.0))
	_ok(Economia.reais(0.004) == "R$ 0,00", "formato de reais perto de zero: " + Economia.reais(0.004))
	_ok(Economia.reais(1999.999) == "R$ 2.000,00", "arredondamento de centavos: " + Economia.reais(1999.999))
	_ok(Economia.reais(1234567.0, false) == "R$ 1.234.567", "formato sem centavos: " + Economia.reais(1234567.0, false))
	_ok(Economia.porcento(0.145) == "14,5%", "formato de percentual: " + Economia.porcento(0.145))


func _teste_estresse() -> void:
	print("- Equação 1 do estresse")
	_perto(ModeloEstresse.calcular(12.0, 0.0, 0.0), 12.0, "sem dívida e sem FOMO, S = S0")
	_perto(ModeloEstresse.calcular(10.0, 2.0, 3.0, 0.5, 2.0), 10.0 * exp(1.0) + 6.0, "valor da equação")
	_ok(ModeloEstresse.calcular(12.0, 2.0, 0.0) > ModeloEstresse.calcular(12.0, 1.0, 0.0), "cresce com a dívida")
	var passo_1 := ModeloEstresse.calcular(12.0, 1.0, 0.0) - ModeloEstresse.calcular(12.0, 0.0, 0.0)
	var passo_2 := ModeloEstresse.calcular(12.0, 2.0, 0.0) - ModeloEstresse.calcular(12.0, 1.0, 0.0)
	_ok(passo_2 > passo_1, "crescimento exponencial (bola de neve)")
	_perto(ModeloEstresse.calcular(40.0, 9.0, 9.0), 100.0, "limitado a 100")
	_ok(ModeloEstresse.beta(6, 0) < ModeloEstresse.beta(0, 0), "vacinas reduzem a vulnerabilidade")
	_ok(ModeloEstresse.beta(0, 4) > ModeloEstresse.beta(0, 0), "ceder aumenta a vulnerabilidade")
	_ok(ModeloEstresse.peso_exposicao(1.0, 10) < ModeloEstresse.peso_exposicao(1.0, 1), "exposição perde força com os dias")
	_perto(ModeloEstresse.razao_divida(1200.0, 1200.0), 1.0, "D = dívida / renda")
	_perto(ModeloEstresse.razao_divida(600.0, 0.0), 1.0, "piso de renda em D")


# ---------------------------------------------------------------------------
# Catálogo
# ---------------------------------------------------------------------------

func _teste_catalogo() -> void:
	print("- catálogo de dados")
	_ok(Catalogo.eventos().size() >= 40, "ao menos 40 eventos (%d)" % Catalogo.eventos().size())
	_ok(Catalogo.vacinas().size() >= 20, "ao menos 20 vacinas (%d)" % Catalogo.vacinas().size())
	var ids := {}
	var vacinas_usadas := {}
	for ev: Variant in Catalogo.eventos():
		var id := String(ev.get("id", ""))
		_ok(id != "" and not ids.has(id), "evento com id único: " + id)
		ids[id] = true
		for campo: String in ["categoria", "canal", "remetente", "titulo", "texto"]:
			_ok(String(ev.get(campo, "")) != "", "%s tem o campo %s" % [id, campo])
		var escolhas: Array = ev.get("escolhas", [])
		_ok(escolhas.size() >= 1, id + " tem escolhas")
		var ids_escolha := {}
		for e: Variant in escolhas:
			ids_escolha[String(e.get("id", ""))] = true
			_ok(TIPOS_ESCOLHA.has(String(e.get("tipo", ""))), "%s/%s tem tipo válido" % [id, e.get("id", "")])
			_ok(String(e.get("texto", "")) != "", "%s/%s tem texto" % [id, e.get("id", "")])
			var ef: Dictionary = e.get("efeitos", {})
			var tem_resultado: bool = String(e.get("resultado", "")) != "" \
					or (bool(e.has("resultado_ganhou")) and bool(e.has("resultado_perdeu")))
			_ok(tem_resultado, "%s/%s tem texto de resultado" % [id, e.get("id", "")])
			if e.has("vacina"):
				vacinas_usadas[String(e["vacina"])] = true
				_ok(not Catalogo.vacina(String(e["vacina"])).is_empty(), "%s: vacina %s existe" % [id, e["vacina"]])
			if ef.has("bem"):
				_ok(not Catalogo.bem(String(ef["bem"])).is_empty(), "%s: bem %s existe" % [id, ef["bem"]])
			if ef.has("matricula"):
				_ok(not Catalogo.curso(String(ef["matricula"])).is_empty(), "%s: curso existe" % id)
			if ef.has("imposto"):
				_ok(Economia.IMPOSTO.has(String(ef["imposto"])), "%s: categoria de imposto %s existe" % [id, ef["imposto"]])
			for a: Variant in ef.get("agenda", []):
				_ok(not Catalogo.evento(String(a["evento"])).is_empty(), "%s agenda evento existente (%s)" % [id, a["evento"]])
		_ok(ids_escolha.has(String(ev.get("padrao", ""))), id + " tem escolha padrão válida")
		if ev.has("vacina"):
			vacinas_usadas[String(ev["vacina"])] = true
			_ok(not Catalogo.vacina(String(ev["vacina"])).is_empty(), "%s: vacina %s existe" % [id, ev["vacina"]])
		# A escolha padrão é aplicada sozinha quando o tempo acaba: não pode exigir nada.
		for e: Variant in escolhas:
			if String(e["id"]) == String(ev.get("padrao", "")):
				_ok(not e.has("requer"), id + ": a escolha padrão não tem requisito")
	for v: Variant in Catalogo.vacinas():
		_ok(vacinas_usadas.has(String(v["id"])) or String(v["id"]) in ["urgencia", "rotativo", "parcelinha"],
				"vacina %s é usada por algum evento" % String(v["id"]))
		for campo: String in ["nome", "tecnica", "explicacao", "protecao"]:
			_ok(String(v.get(campo, "")) != "", "vacina %s tem %s" % [v["id"], campo])
	for emp: Variant in Catalogo.empregos():
		var req: Dictionary = emp.get("requisitos", {})
		for c: Variant in req.get("cursos", []):
			_ok(not Catalogo.curso(String(c)).is_empty(), "emprego %s exige curso existente" % emp["id"])
		_ok(emp.has("extra") and emp.has("s0"), "emprego %s completo" % emp["id"])
	for meta: Variant in Catalogo.metas():
		_ok(TIPOS_META.has(String(meta["tipo"])), "meta %s tem tipo válido" % meta["id"])
	for l: Variant in Catalogo.lazeres():
		_ok(l.has("nome") and l.has("espera"), "lazer %s completo" % l["id"])


# ---------------------------------------------------------------------------
# Simulação
# ---------------------------------------------------------------------------

## O saldo tem de ser sempre a soma do extrato: nenhum dinheiro aparece ou
## some sem uma transação registrada.
func _teste_livro_caixa() -> void:
	print("- livro-caixa: saldo = soma das transações")
	for semente: int in [11, 22, 33]:
		var sim := Simulacao.new()
		var soma := {"conta": 0.0, "n": 0}
		sim.transacao.connect(func(t: Dictionary) -> void:
			if String(t["meio"]) == "conta":
				soma["conta"] = float(soma["conta"]) + float(t["valor"])
			soma["n"] = int(soma["n"]) + 1)
		sim.nova_partida(semente)
		var bot := BotJogador.new("medio", semente)
		bot.jogar(sim, 6, false)
		_perto(sim.saldo, Economia.SALDO_INICIAL + float(soma["conta"]),
				"semente %d: saldo bate com o extrato" % semente, 0.05)
		_ok(int(soma["n"]) > 100, "semente %d: extrato registrado (%d linhas)" % [semente, int(soma["n"])])
		_ok(sim.historico_meses.size() >= 1, "semente %d: houve fechamento de mês" % semente)
	var a := _nova(77)
	var b := _nova(77)
	BotJogador.new("medio", 5).jogar(a, 4, false)
	BotJogador.new("medio", 5).jogar(b, 4, false)
	_perto(a.patrimonio(), b.patrimonio(), "mesma semente, mesma partida (determinismo)", 0.001)


func _teste_cartao() -> void:
	print("- cartão de crédito e rotativo")
	var sim := _nova(5)
	sim.cartao_ativo = true
	sim.limite = 1000.0
	sim.saldo = 2000.0
	sim._compra_cartao("Compra de teste", 400.0, 1, 0.0)
	sim._compra_cartao("Parcelado de teste", 300.0, 3, 0.0)
	_perto(sim.fatura_aberta, 400.0, "compra à vista entra na fatura aberta")
	_perto(sim.limite_disponivel(), 300.0, "limite desconta compras e parcelas futuras")
	_avancar_ate_dia_do_mes(sim, Economia.DIA_FECHAMENTO)
	sim.avancar_dia()
	_perto(sim.fatura_fechada, 500.0, "fatura fechada soma compra e primeira parcela")
	_ok(sim.vencimento_em > sim.dia_total, "vencimento marcado")
	_avancar_ate_dia_do_mes(sim, Economia.DIA_SALARIO)
	var pendente := {}
	for p: Variant in sim.pendentes:
		if String(p["evento"]) == "sis_fatura":
			pendente = p
	_ok(not pendente.is_empty(), "a fatura vira notificação no dia do vencimento")
	if not pendente.is_empty():
		var antes := sim.saldo
		var res := sim.responder(int(pendente["uid"]), "minimo")
		_perto(antes - sim.saldo, 75.0, "pagamento mínimo de 15%")
		_perto(sim.rot_saldo, 425.0, "o restante entra no rotativo")
		_ok(String(res.get("vacina", {}).get("id", "")) == "rotativo", "pagar o mínimo ensina a vacina do rotativo")
		_ok(sim.divida_ativa() >= 425.0, "rotativo conta como dívida ativa")
	var rot_antes := sim.rot_saldo
	_avancar(sim, 10)
	_ok(sim.rot_saldo > rot_antes, "o rotativo cresce todos os dias")
	var taxa := Economia.taxa_rotativo(sim.mes())
	_perto(sim.rot_saldo, rot_antes * pow(1.0 + Economia.taxa_diaria(taxa), 10.0), "juros compostos diários", 0.5)
	var pago := sim.pagar_rotativo(99999.0)
	_ok(pago > 0.0 and sim.rot_saldo == 0.0, "rotativo quitado zera a dívida")
	# Fatura paga inteira não gera juros.
	var limpo := _nova(6)
	limpo.cartao_ativo = true
	limpo.limite = 1000.0
	limpo.saldo = 3000.0
	limpo._compra_cartao("Compra", 200.0, 1, 0.0)
	_avancar_ate_dia_do_mes(limpo, Economia.DIA_FECHAMENTO)
	limpo.avancar_dia()
	_avancar_ate_dia_do_mes(limpo, Economia.DIA_SALARIO)
	for p: Variant in limpo.pendentes.duplicate():
		if String(p["evento"]) == "sis_fatura":
			limpo.responder(int(p["uid"]), "total")
	_perto(limpo.rot_saldo, 0.0, "fatura paga no total não entra no rotativo")
	_perto(limpo.fatura_fechada, 0.0, "fatura quitada")


func _teste_teto_rotativo() -> void:
	print("- teto de juros do rotativo")
	var sim := _nova(9)
	sim.cartao_ativo = true
	sim.limite = 5000.0
	sim.rot_saldo = 1000.0
	sim.rot_origem = 1000.0
	sim.saldo = 50000.0
	# Dias 6 a 24: não há fechamento de fatura no caminho.
	sim.dia_total = 12 * Economia.DIAS_MES + 6
	for i in 18:
		sim._juros_do_dia()
	_ok(sim.rot_saldo > 1000.0, "juros cobrados")
	sim.rot_juros_acum = 999.0
	sim._juros_do_dia()
	_perto(sim.rot_juros_acum, 1000.0, "juros acumulados param em 100% do valor original")
	var no_teto := sim.rot_saldo
	sim._juros_do_dia()
	_perto(sim.rot_saldo, no_teto, "no teto, a dívida para de crescer")


func _teste_reserva_e_contas() -> void:
	print("- reserva, contas e atrasos")
	var sim := _nova(3)
	sim.saldo = 1000.0
	var r := sim.depositar_reserva(600.0)
	_ok(bool(r["ok"]), "depósito aceito")
	_perto(sim.saldo, 400.0, "saldo cai no depósito")
	_perto(sim.reserva, 600.0, "reserva sobe no depósito")
	sim._juros_do_dia()
	_ok(sim.reserva > 600.0, "a reserva rende todos os dias")
	_perto(sim.reserva, 600.0 * (1.0 + Economia.taxa_diaria(Economia.TAXA_RESERVA)), "rendimento diário composto", 0.001)
	sim.sacar_reserva(100.0)
	_perto(sim.saldo, 500.0, "resgate volta para a conta")
	_ok(not bool(sim.depositar_reserva(0.0)["ok"]), "depósito zero é recusado")
	_perto(sim.meses_reserva(), sim.reserva / Economia.CUSTO_VIDA_BASE, "meses de reserva")
	_perto(sim.meta_reserva(), Economia.CUSTO_VIDA_BASE * 6.0, "a meta é seis meses de custo de vida")
	_ok(sim.custos_fixos_mensais() > 1000.0 and sim.custos_fixos_mensais() < 1400.0,
			"custos fixos iniciais plausíveis (%s)" % Economia.reais(sim.custos_fixos_mensais()))
	# Sem saldo no dia da moradia: a conta entra em atraso com multa.
	var apertado := _nova(4)
	apertado.saldo = 5.0
	apertado.dias_sem_renda = 99
	_avancar_ate_dia_do_mes(apertado, Economia.DIA_MORADIA)
	apertado.saldo = 5.0
	apertado.avancar_dia()
	_ok(apertado.contas_atrasadas.size() >= 1, "moradia sem saldo entra em atraso")
	_perto(apertado.total_atrasadas(), Economia.MORADIA * 1.02, "atraso com multa de 2%", 0.5)
	_ok(apertado.divida_ativa() > 500.0, "conta atrasada é dívida ativa")
	_ok(apertado.estresse() > _nova(4).estresse(), "atraso aumenta o estresse")
	apertado.dias_sem_renda = 0
	apertado.saldo = 2000.0
	apertado.avancar_dia()
	_ok(apertado.contas_atrasadas.is_empty(), "com saldo, a conta atrasada é quitada")
	# Falência técnica por três atrasos graves.
	var falido := _nova(8)
	falido.atrasos_graves = Economia.ATRASOS_GRAVES_FALENCIA
	falido.avancar_dia()
	_ok(falido.fim and falido.resultado == "falencia", "três atrasos graves encerram em falência")
	var esgotado := _nova(8)
	esgotado.dias_criticos = ModeloEstresse.DIAS_ATE_ESGOTAMENTO
	esgotado.choque = 30.0
	esgotado.fadiga = 40.0
	esgotado.rot_saldo = 9000.0
	esgotado.avancar_dia()
	_ok(esgotado.fim and esgotado.resultado == "esgotamento", "estresse crítico prolongado encerra em esgotamento")


func _teste_trabalho_e_estudo() -> void:
	print("- trabalho, estudo e carreira")
	# Ritmo de trabalho: puxado rende mais e cansa; leve rende menos e recupera.
	var puxado := _nova(2)
	var leve := _nova(2)
	_ok(puxado.ritmos_disponiveis().size() == 3, "quem ganha por dia escolhe entre três ritmos")
	_ok(bool(puxado.definir_ritmo("puxado")["ok"]) and bool(leve.definir_ritmo("leve")["ok"]), "ritmo alterado")
	var renda := {"puxado": 0.0, "leve": 0.0}
	puxado.transacao.connect(func(t: Dictionary) -> void:
		if String(t["categoria"]) == "renda":
			renda["puxado"] = float(renda["puxado"]) + float(t["valor"]))
	leve.transacao.connect(func(t: Dictionary) -> void:
		if String(t["categoria"]) == "renda":
			renda["leve"] = float(renda["leve"]) + float(t["valor"]))
	for i in 12:
		puxado.pendentes.clear()
		leve.pendentes.clear()
		puxado.avancar_dia()
		leve.avancar_dia()
	_ok(float(renda["puxado"]) > float(renda["leve"]) * 1.3, "ritmo puxado rende mais (%.0f contra %.0f)" % [renda["puxado"], renda["leve"]])
	_ok(puxado.fadiga > 5.0 and leve.fadiga < 0.0, "ritmo puxado cansa e ritmo leve recupera (%.1f e %.1f)" % [puxado.fadiga, leve.fadiga])
	_ok(puxado.estresse() > leve.estresse(), "o cansaço acumulado aumenta o estresse")
	# Folga: quem é informal perde a renda do dia.
	var folga := _nova(3)
	var rendeu := {"n": 0}
	folga.transacao.connect(func(t: Dictionary) -> void:
		if String(t["categoria"]) == "renda":
			rendeu["n"] = int(rendeu["n"]) + 1)
	folga.fadiga = 10.0
	var antes := folga.estresse()
	var r := folga.lazer("descansar")
	_ok(bool(r["ok"]) and folga.estresse() < antes, "tirar folga reduz o estresse")
	folga.avancar_dia()
	_ok(int(rendeu["n"]) == 0, "no dia de folga, quem é informal não recebe")
	_ok(folga.motivo_sem_lazer("descansar") != "", "a folga tem intervalo entre uma e outra")
	# Estudo: depois da matrícula, uma aula por dia.
	var sim := _nova(2)
	_ok(sim.motivo_sem_candidatura("pj_loja") != "", "vaga PJ exige curso")
	_ok(bool(sim.matricular("atendimento")["ok"]) and sim.curso_atual() == "atendimento", "matrícula no curso gratuito")
	_ok(sim.motivo_sem_matricula("informatica") != "", "um curso por vez")
	sim.avancar_dia()
	_ok(int(sim.cursos["atendimento"]) == 1, "o curso avança sozinho, uma aula por dia")
	sim.alternar_estudo()
	sim.avancar_dia()
	_ok(int(sim.cursos["atendimento"]) == 1, "curso pausado não avança")
	sim.alternar_estudo()
	_avancar(sim, int(Catalogo.curso("atendimento")["aulas"]))
	_ok(sim.cursos_concluidos.has("atendimento") and sim.curso_atual() == "", "curso concluído depois de todas as aulas")
	var rapido := _nova(2)
	rapido.bens.append("notebook")
	rapido.matricular("atendimento")
	rapido.avancar_dia()
	_ok(int(rapido.cursos["atendimento"]) == 2, "com notebook o estudo rende o dobro")
	# Processo seletivo: a resposta chega dias depois, como notificação.
	_ok(sim.motivo_sem_candidatura("clt_auxiliar") != "", "a vaga CLT exige outro curso")
	var contratado := false
	for tentativa in 8:
		if sim.motivo_sem_candidatura("pj_loja") != "":
			break
		_ok(bool(sim.candidatar("pj_loja")["ok"]), "currículo enviado (tentativa %d)" % (tentativa + 1))
		_ok(sim.motivo_sem_candidatura("pj_loja") != "", "um processo seletivo por vez")
		for dia in Simulacao.DIAS_PROCESSO_SELETIVO_MAX + 1:
			sim.avancar_dia()
			for p: Variant in sim.pendentes.duplicate():
				var id := String(p["evento"])
				if id == "sis_aprovado":
					sim.responder(int(p["uid"]), "aceitar")
					contratado = true
				elif id == "sis_reprovado":
					sim.responder(int(p["uid"]), "ok")
				else:
					sim.responder(int(p["uid"]), String(sim.evento_de(p)["padrao"]), -1, true)
		if contratado:
			break
	_ok(contratado and sim.vinculo() == "pj", "aprovado e contratado como PJ")
	_ok(sim.ritmos_disponiveis().size() == 2 and sim.ritmo != "leve", "salário fixo: só ritmo normal ou hora extra")
	_avancar_ate_dia_do_mes(sim, Economia.DIAS_MES)
	sim.avancar_dia()
	_ok(sim.pend_bruto > 0.0, "salário proporcional acumulado no fechamento do mês")
	# CLT: desconto de INSS, FGTS e vale-refeição.
	var clt := _nova(12)
	clt.saldo = 3000.0
	clt._trocar_emprego("clt_auxiliar")
	_ok(clt.vinculo() == "clt", "contratado como CLT")
	_ok(clt.alimentacao_dia() < Economia.ALIMENTACAO_DIA, "vale-refeição reduz o gasto com comida")
	_avancar(clt, 70)
	_ok(clt.fgts > 0.0, "FGTS depositado para quem tem carteira")
	_ok(clt.meses_clt >= 2, "meses de carteira contados")
	var item := _nova(13)
	item.saldo = 500.0
	_ok(bool(item.comprar_bem("bag", "avista")["ok"]) and item.tem_bem("bag"), "compra de bem à vista")
	_perto(item.multiplicador_entrega(), 1.08, "mochila térmica aumenta a renda das entregas")
	_ok(not bool(item.vender_bem("bike")["ok"]), "ferramenta de trabalho não pode ser vendida")
	_ok(bool(item.vender_bem("bag")["ok"]) and not item.tem_bem("bag"), "venda de bem")


func _teste_eventos() -> void:
	print("- eventos, vacinas e FOMO")
	var sim := _nova(21)
	_ok(sim.pendentes.size() == 1 and String(sim.pendentes[0]["evento"]) == "boas_vindas",
			"a partida começa com a mensagem de boas-vindas")
	var res := sim.responder(int(sim.pendentes[0]["uid"]), "ok")
	_ok(String(res.get("vacina", {}).get("id", "")) == "reserva" and bool(res["vacina"]["nova"]),
			"a primeira resposta entrega uma vacina")
	_ok(sim.vacinas.has("reserva"), "vacina registrada")
	# Golpe: cair perde dinheiro; evitar não perde.
	sim.saldo = 800.0
	sim._criar_pendente(Catalogo.evento("mae_numero_novo"), {})
	var uid := sim.ultimo_uid
	var caiu := sim.responder(uid, "mandar")
	_perto(sim.saldo, 450.0, "cair no golpe custa R$ 350")
	_ok(String(caiu["tipo"]) == "golpe" and int(sim.estat["golpes_sofridos"]) == 1, "golpe sofrido contado")
	_ok(float(caiu["deltas"]["estresse"]) > 0.0, "golpe aumenta o estresse")
	sim._criar_pendente(Catalogo.evento("mae_numero_novo"), {})
	sim.responder(sim.ultimo_uid, "ligar")
	_perto(sim.saldo, 450.0, "conferir antes não custa nada")
	_ok(int(sim.estat["golpes_evitados"]) == 1, "golpe evitado contado")
	# Escolha sem requisito atendido é recusada.
	sim.saldo = 10.0
	sim._criar_pendente(Catalogo.evento("vaga_taxa"), {})
	_ok(sim.responder(sim.ultimo_uid, "pagar").is_empty(), "escolha sem saldo é recusada")
	_ok(sim.motivo_indisponivel(Catalogo.evento("vaga_taxa")["escolhas"][0]) != "", "motivo da indisponibilidade informado")
	# FOMO: a exposição aumenta o estresse; ceder remove a exposição.
	var fomo := _nova(22)
	fomo.responder(int(fomo.pendentes[0]["uid"]), "ok")
	var base := fomo.estresse()
	fomo._criar_pendente(Catalogo.evento("stories_ostentacao"), {})
	_ok(fomo.f_fomo() > 0.0 and fomo.estresse() > base, "gatilho de FOMO aumenta o estresse")
	var com_gatilho := fomo.estresse()
	fomo.responder(fomo.ultimo_uid, "silenciar")
	_ok(fomo.estresse() < com_gatilho, "silenciar perfis alivia o FOMO")
	_ok(fomo.vacinas.has("algoritmo"), "silenciar ensina a vacina do algoritmo")
	# Evento com relógio: tempo esgotado aplica a escolha padrão.
	var relogio := _nova(23)
	relogio.saldo = 900.0
	relogio._criar_pendente(Catalogo.evento("falsa_central"), {})
	_ok(bool(relogio.pendentes[relogio.pendentes.size() - 1]["urgente"]), "evento com relógio é urgente")
	var por_tempo := relogio.responder(relogio.ultimo_uid, "desligar", -1, true)
	_ok(bool(por_tempo["por_tempo"]) and int(relogio.estat["tempo_esgotado"]) == 1, "tempo esgotado contado")
	_perto(relogio.saldo, 900.0, "tempo esgotado em golpe não perde dinheiro")
	# Aposta: a casa tem vantagem no longo prazo.
	var apostador := _nova(24)
	apostador.flags["ja_apostou"] = true
	var ganho := 0.0
	var apostado := 0.0
	for i in 400:
		apostador.saldo = 100.0
		apostador._criar_pendente(Catalogo.evento("amigo_print"), {})
		apostador.responder(apostador.ultimo_uid, "apostar")
		ganho += apostador.saldo - 70.0
		apostado += 30.0
	_ok(ganho < apostado, "em 400 apostas a casa fica com parte do dinheiro (retorno de %.0f%%)" % (ganho / apostado * 100.0))
	_ok(apostador.cedidas == 400, "ceder ao gatilho é contado")
	# O algoritmo mostra mais do que o jogador clica.
	var alvo := Catalogo.evento("amigo_print")
	var frio := _nova(25)
	var quente := _nova(25)
	quente.interesse["bets"] = 2.0
	_ok(quente._peso(alvo) > frio._peso(alvo) * 2.5, "interesse acumulado multiplica as ofertas da categoria")


func _teste_salvar_carregar() -> void:
	print("- salvar e carregar")
	var sim := _nova(31)
	BotJogador.new("medio", 9).jogar(sim, 3, false)
	var texto := JSON.stringify(sim.para_dict())
	var copia := Simulacao.new()
	copia.de_dict(JSON.parse_string(texto))
	_ok(copia.dia_total == sim.dia_total, "dia restaurado")
	_perto(copia.saldo, sim.saldo, "saldo restaurado")
	_perto(copia.patrimonio(), sim.patrimonio(), "patrimônio restaurado")
	_perto(copia.estresse(), sim.estresse(), "estresse restaurado", 0.001)
	_ok(copia.vacinas.size() == sim.vacinas.size(), "vacinas restauradas")
	_ok(copia.pendentes.size() == sim.pendentes.size(), "notificações restauradas")
	_ok(copia.emprego_id == sim.emprego_id, "emprego restaurado")
	# Depois de carregar, a partida continua igual à original.
	BotJogador.new("prudente", 4).jogar(sim, 5, false)
	BotJogador.new("prudente", 4).jogar(copia, 5, false)
	_perto(copia.patrimonio(), sim.patrimonio(), "a partida carregada segue idêntica à original", 0.01)
	_ok(copia.dia_total == sim.dia_total, "mesmo dia depois de continuar")


# ---------------------------------------------------------------------------
# Persistência
# ---------------------------------------------------------------------------

func _teste_banco(forcar_arquivo: bool) -> void:
	var modo := "arquivo JSON" if forcar_arquivo else "SQLite"
	print("- banco de dados (%s)" % modo)
	for caminho: String in ["user://teste.db", "user://teste.db-wal", "user://teste.db-shm", "user://teste.json"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	Database.abrir("user://teste.db", "user://teste.json", forcar_arquivo)
	if not forcar_arquivo:
		_ok(Database.usando_sqlite, "plugin SQLite carregado")
		if not Database.usando_sqlite:
			return
	else:
		_ok(not Database.usando_sqlite, "modo arquivo ativo")
	var id := Database.iniciar_partida(123)
	_ok(id > 0, "partida criada")
	Database.iniciar_lote()
	for i in 5:
		Database.registrar_transacao({"dia": i + 1, "categoria": "renda", "descricao": "Corrida %d" % i,
			"valor": 10.0 * float(i + 1), "meio": "conta", "saldo_apos": 100.0, "imposto": 0.5})
		Database.registrar_estresse({"dia": i + 1, "estresse": 20.0 + float(i), "s0": 16.0, "d": 0.1,
			"fomo": 0.5, "patrimonio": 500.0 + float(i)})
	Database.registrar_decisao({"dia": 2, "evento_id": "mae_numero_novo", "categoria": "golpe_pix",
		"escolha_id": "ligar", "tipo": "segura", "tempo_ms": 3200, "estresse": 22.0, "d": 0.0, "saldo": 300.0})
	Database.registrar_decisao({"dia": 3, "evento_id": "drop_tenis", "categoria": "influencer",
		"escolha_id": "esperar", "tipo": "tempo_esgotado", "tempo_ms": -1, "estresse": 25.0, "d": 0.0, "saldo": 300.0})
	Database.registrar_bem("bike", "Bicicleta usada", 0.0, 1)
	Database.registrar_bem("bag", "Mochila térmica", 130.0, 4)
	Database.confirmar_lote()
	var extrato := Database.ultimas_transacoes(3)
	_ok(extrato.size() == 3, "extrato limitado a 3 linhas")
	_ok(String(extrato[0]["descricao"]) == "Corrida 4", "extrato da mais nova para a mais antiga")
	_perto(float(extrato[0]["valor"]), 50.0, "valor gravado")
	var serie := Database.historico_estresse()
	_ok(serie.size() == 5 and int(serie[0]["dia"]) == 1, "log de estresse em ordem de dia")
	_perto(float(serie[4]["estresse"]), 24.0, "estresse gravado")
	_ok(Database.inventario().size() == 2, "inventário com dois bens")
	Database.baixar_bem("bag")
	_ok(Database.inventario().size() == 1, "bem vendido sai do inventário ativo")
	var resumo := Database.resumo_decisoes()
	_ok(int(resumo["total"]) == 2 and int(resumo["por_tipo"].get("segura", 0)) == 1, "telemetria resumida")
	_perto(float(resumo["tempo_medio_ms"]), 3200.0, "tempo médio de resposta")
	Database.registrar_vacina("clonagem")
	Database.registrar_vacina("clonagem")
	Database.registrar_vacina("rotativo")
	_ok(Database.vacinas_adquiridas().size() == 2, "vacinas sem repetição")
	Database.salvar_estado({"dia_total": 42, "saldo": 12.5, "texto": "ção"})
	var estado := Database.carregar_estado()
	_ok(int(estado.get("dia_total", 0)) == 42 and String(estado.get("texto", "")) == "ção", "estado salvo e lido")
	_ok(int(estado.get("partida_id", 0)) == id, "estado guarda a partida")
	Database.definir_config("vibracao", false)
	_ok(Database.config("vibracao", true) == false and Database.config("inexistente", 7) == 7, "configurações")
	Database.encerrar_partida("vitoria", 300, 9000.0, 4321)
	var ranking := Database.melhores_partidas()
	_ok(ranking.size() == 1 and int(ranking[0]["pontuacao"]) == 4321, "partida encerrada entra no histórico")
	_ok(Database.contar("transacoes") == 5, "contagem de linhas")
	# Os dados continuam lá depois de fechar e abrir de novo.
	Database.abrir("user://teste.db", "user://teste.json", forcar_arquivo)
	Database.partida_id = id
	_ok(Database.ultimas_transacoes(10).size() == 5, "dados persistem depois de reabrir")
	_ok(int(Database.carregar_estado().get("dia_total", 0)) == 42, "estado persiste depois de reabrir")
	Database.abrir("user://teste.db", "user://teste.json", forcar_arquivo)
	Database.fechar()


func _teste_game_manager() -> void:
	print("- GameManager")
	for caminho: String in ["user://teste_gm.db", "user://teste_gm.db-wal", "user://teste_gm.db-shm", "user://teste_gm.json"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	Database.abrir("user://teste_gm.db", "user://teste_gm.json")
	_ok(not GameManager.tem_partida_salva(), "sem partida salva no começo")
	GameManager.nova_partida(404)
	_ok(GameManager.tem_partida() and GameManager.tem_partida_salva(), "partida criada e salva")
	_ok(Database.inventario().size() == 2, "bens iniciais no inventário do banco")
	var dias := {"n": 0}
	var contar_dia := func(_resumo: Dictionary) -> void: dias["n"] = int(dias["n"]) + 1
	GameManager.dia_passou.connect(contar_dia)
	for i in 40:
		for p: Variant in GameManager.sim.pendentes.duplicate():
			var ev := GameManager.sim.evento_de(p)
			GameManager.responder(int(p["uid"]), String(ev["padrao"]), 1500)
		GameManager.avancar_dia()
	GameManager.dia_passou.disconnect(contar_dia)
	_ok(int(dias["n"]) == 40, "sinal de dia emitido a cada dia")
	_ok(Database.historico_estresse().size() == 40, "um log de estresse por dia")
	_ok(Database.ultimas_transacoes(500).size() > 60, "transações gravadas no banco")
	_ok(int(Database.resumo_decisoes()["total"]) >= 1, "decisões gravadas na telemetria")
	GameManager.sim.saldo = 500.0
	var retorno: Variant = GameManager.agir(&"depositar_reserva", [50.0])
	_ok(retorno is Dictionary and bool(retorno["ok"]), "ação pelo GameManager")
	var dia := GameManager.sim.dia_total
	var patrimonio := GameManager.sim.patrimonio()
	GameManager.sair_para_o_titulo()
	_ok(not GameManager.tem_partida() and GameManager.tem_partida_salva(), "sair mantém a partida salva")
	_ok(GameManager.continuar(), "continuar carrega a partida")
	_ok(GameManager.sim.dia_total == dia, "dia restaurado ao continuar")
	_perto(GameManager.sim.patrimonio(), patrimonio, "patrimônio restaurado ao continuar")
	GameManager.bloquear_tempo()
	_ok(not GameManager.relogio_ativo(), "janela aberta pausa o relógio")
	GameManager.liberar_tempo()
	_ok(GameManager.relogio_ativo(), "relógio volta ao fechar a janela")
	GameManager.definir_velocidade(0)
	_ok(not GameManager.relogio_ativo(), "pausa")
	GameManager.nova_partida(405)
	_ok(Database.melhores_partidas().size() == 1, "partida anterior registrada como abandonada")
	GameManager.sair_para_o_titulo()
	Database.fechar()
	# Devolve o banco ao arquivo normal do jogo.
	Database.abrir()


# ---------------------------------------------------------------------------
# Bots: o equilíbrio do jogo
# ---------------------------------------------------------------------------

func _rodar_bots(perfil: String, sementes: int, meses: int) -> Array:
	var resultados: Array = []
	for s in sementes:
		var sim := _nova(1000 + s)
		resultados.append(BotJogador.new(perfil, 2000 + s).jogar(sim, meses))
	return resultados


func _media(resultados: Array, campo: String) -> float:
	var soma := 0.0
	for r: Variant in resultados:
		soma += float(r[campo])
	return soma / maxf(float(resultados.size()), 1.0)


func _fracao(resultados: Array, resultado: String) -> float:
	var n := 0
	for r: Variant in resultados:
		if String(r["resultado"]) == resultado:
			n += 1
	return float(n) / maxf(float(resultados.size()), 1.0)


func _teste_bots() -> void:
	print("- equilíbrio (bots)")
	var prudente := _rodar_bots("prudente", 12, 36)
	var atento := _rodar_bots("atento", 12, 36)
	var impulsivo := _rodar_bots("impulsivo", 12, 36)
	var derrotas_prudente := _fracao(prudente, "falencia") + _fracao(prudente, "esgotamento")
	var derrotas_atento := _fracao(atento, "falencia") + _fracao(atento, "esgotamento")
	var derrotas_impulsivo := _fracao(impulsivo, "falencia") + _fracao(impulsivo, "esgotamento")
	_ok(derrotas_prudente <= 0.1, "quem joga com prudência quase nunca quebra (%.0f%% de derrotas)" % (derrotas_prudente * 100.0))
	_ok(_fracao(prudente, "vitoria") >= 0.8, "a meta de 6 meses de reserva é alcançável (%.0f%% de vitórias em 36 meses)" % (_fracao(prudente, "vitoria") * 100.0))
	_ok(_media(prudente, "mes_vitoria") >= 9.0, "a vitória exige uma campanha longa (média no mês %.1f)" % _media(prudente, "mes_vitoria"))
	_ok(derrotas_atento <= 0.25, "errar de vez em quando não condena a partida (%.0f%% de derrotas)" % (derrotas_atento * 100.0))
	_ok(derrotas_impulsivo >= 0.6, "quem cede a tudo costuma quebrar (%.0f%% de derrotas)" % (derrotas_impulsivo * 100.0))
	_ok(_media(impulsivo, "estresse_medio") > _media(prudente, "estresse_medio") + 8.0,
			"decisões impulsivas elevam o estresse (%.0f contra %.0f)" % [
				_media(impulsivo, "estresse_medio"), _media(prudente, "estresse_medio")])
	_ok(_media(impulsivo, "ganho_apostas") < _media(impulsivo, "apostado"), "apostando sempre, perde-se dinheiro")


func _relatorio_bots() -> void:
	print("\n== Calibração: 30 partidas por perfil, até 36 meses ==")
	print("perfil     | vitória | falência | esgot. | mês vit. | mês fim | mês CLT | patrimônio | estresse | vacinas | golpes | apostado | juros")
	for perfil: String in ["prudente", "atento", "regular", "medio", "impulsivo"]:
		var r := _rodar_bots(perfil, 30, 36)
		var meses_vitoria: Array = []
		for x: Variant in r:
			if int(x["mes_vitoria"]) > 0:
				meses_vitoria.append(int(x["mes_vitoria"]))
		meses_vitoria.sort()
		var mediana := "-"
		if not meses_vitoria.is_empty():
			@warning_ignore("integer_division")
			mediana = str(meses_vitoria[meses_vitoria.size() / 2])
		print("%-10s | %6.0f%% | %7.0f%% | %5.0f%% | %8s | %7.1f | %7.1f | %10.0f | %8.1f | %7.1f | %6.1f | %8.0f | %5.0f" % [
			perfil, _fracao(r, "vitoria") * 100.0, _fracao(r, "falencia") * 100.0,
			_fracao(r, "esgotamento") * 100.0, mediana, _media(r, "mes_final"),
			_media(r, "mes_carteira"), _media(r, "patrimonio"), _media(r, "estresse_medio"), _media(r, "vacinas"),
			_media(r, "golpes_sofridos"), _media(r, "apostado"), _media(r, "juros")])
