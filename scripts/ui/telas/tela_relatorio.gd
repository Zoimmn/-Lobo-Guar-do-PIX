extends TelaBase
## Aba Relatório: gráfico de patrimônio e estresse, indicadores da partida,
## telemetria das decisões e histórico dos meses.


func montar(sim: Simulacao) -> void:
	_grafico()
	_indicadores(sim)
	_decisoes(sim)
	_meses(sim)
	conteudo.add_child(Kit.rotulo("Todos os dados ficam só neste aparelho (%s). O jogo não usa internet." % Database.mecanismo(),
			"mini", Tema.TINTA_3))


func _grafico() -> void:
	var c := novo_cartao("Patrimônio e estresse")
	var grafico := GraficoLinhas.new()
	grafico.definir(Database.historico_estresse())
	c.por(grafico)
	var legenda := Kit.hbox(20)
	legenda.alignment = BoxContainer.ALIGNMENT_CENTER
	for item: Array in [["Patrimônio líquido", Tema.GUARA], ["Estresse (0 a 100)", Tema.ROXO]]:
		var par := Kit.hbox(8)
		par.add_child(Kit.icone("ponto", 22, item[1]))
		par.add_child(Kit.rotulo(String(item[0]), "mini", Tema.TINTA_2, false))
		legenda.add_child(par)
	c.por(legenda)
	c.por(Kit.rotulo("Quando a dívida cresce, o estresse cresce junto, e cada vez mais rápido.", "mini", Tema.TINTA_3))


func _indicadores(sim: Simulacao) -> void:
	var e := sim.estat
	var c := novo_cartao("A partida até aqui")
	var patrimonio := sim.patrimonio()
	c.por(Kit.linha_valor("Patrimônio líquido", Economia.reais(patrimonio),
			Tema.VERMELHO if patrimonio < 0.0 else Tema.VERDE))
	c.por(Kit.linha_valor("Pontuação", str(sim.pontuacao()), Tema.GUARA_ESCURO))
	var dias := int(e["dias"])
	@warning_ignore("integer_division")
	var meses := dias / Economia.DIAS_MES
	c.por(Kit.linha_valor("Tempo de jogo", "%d meses e %s" % [meses, Kit.dias(dias % Economia.DIAS_MES)]))
	c.por(Kit.divisor())
	c.por(Kit.linha_valor("Golpes evitados", str(int(e["golpes_evitados"])), Tema.VERDE, "pequeno"))
	c.por(Kit.linha_valor("Golpes e armadilhas sofridos", str(int(e["golpes_sofridos"])),
			Tema.VERMELHO if int(e["golpes_sofridos"]) > 0 else Tema.TINTA, "pequeno"))
	c.por(Kit.linha_valor("Perdido em golpes", Economia.reais(float(e["perdido_golpes"])), Tema.TINTA, "pequeno"))
	c.por(Kit.linha_valor("Gatilhos de FOMO: resistiu / cedeu", "%d / %d" % [
			int(e["fomo_resistidos"]), int(e["fomo_cedidos"])], Tema.TINTA, "pequeno"))
	if int(e["apostas"]) > 0:
		var resultado := float(e["ganho_apostas"]) - float(e["apostado"])
		c.por(Kit.linha_valor("Apostas: colocou / recebeu", "%s / %s" % [
				Economia.reais(float(e["apostado"]), false), Economia.reais(float(e["ganho_apostas"]), false)],
				Tema.TINTA, "pequeno"))
		c.por(Kit.linha_valor("Resultado das apostas", Economia.reais(resultado),
				Tema.VERMELHO if resultado < 0.0 else Tema.VERDE, "pequeno"))
	c.por(Kit.divisor())
	c.por(Kit.linha_valor("Juros e multas pagos", Economia.reais(float(e["juros"])),
			Tema.VERMELHO if float(e["juros"]) >= 1.0 else Tema.TINTA, "pequeno"))
	c.por(Kit.linha_valor("Rendimento da reserva", Economia.reais(float(e["rendimentos"])), Tema.VERDE, "pequeno"))
	var renda_total := maxf(float(e["renda_total"]), 1.0)
	c.por(Kit.linha_valor("Imposto embutido no consumo", "%s (%s da renda)" % [
			Economia.reais(float(e["impostos"]), false), Economia.porcento(float(e["impostos"]) / renda_total, 0)],
			Tema.TINTA, "pequeno"))
	c.por(Kit.divisor())
	var total_vacinas := Catalogo.vacinas().size()
	c.por(Kit.linha_valor("Vacinas cognitivas", "%d de %d" % [sim.vacinas.size(), total_vacinas], Tema.VERDE))
	c.por(BarraValor.new(12, float(sim.vacinas.size()) / float(total_vacinas), Tema.VERDE))
	c.por(Kit.botao_pequeno("Ver as vacinas desta partida", "BotaoNeutro", func() -> void:
		abrir_modal(Modais.vacinas(sim.vacinas.keys()))))


## Telemetria anônima: como o jogador decidiu.
func _decisoes(_sim: Simulacao) -> void:
	var resumo := Database.resumo_decisoes()
	var total := int(resumo["total"])
	var c := novo_cartao("Suas decisões")
	if total == 0:
		c.por(Kit.rotulo("As decisões que você tomar nas notificações aparecem aqui.", "pequeno", Tema.TINTA_2))
		return
	var por_tipo: Dictionary = resumo["por_tipo"]
	var nomes := [["segura", "Seguras", Tema.VERDE], ["neutra", "Neutras", Tema.TINTA],
		["arriscada", "De risco", Tema.AMBAR], ["golpe", "Armadilhas", Tema.VERMELHO],
		["tempo_esgotado", "Tempo esgotado", Tema.TINTA_2]]
	for item: Array in nomes:
		var n := int(por_tipo.get(String(item[0]), 0))
		if n == 0:
			continue
		c.por(Kit.linha_valor(String(item[1]), "%d (%s)" % [n, Economia.porcento(float(n) / float(total), 0)],
				item[2], "pequeno"))
	if float(resumo["tempo_medio_ms"]) > 0.0:
		c.por(Kit.linha_valor("Tempo médio para decidir", "%s s" % Kit.decimal(float(resumo["tempo_medio_ms"]) / 1000.0),
				Tema.TINTA, "pequeno"))
	c.por(Kit.rotulo("Registro anônimo, guardado no banco de dados local para a pesquisa.", "mini", Tema.TINTA_3))


func _meses(sim: Simulacao) -> void:
	if sim.historico_meses.is_empty():
		return
	var c := novo_cartao("Meses anteriores")
	var inicio := maxi(sim.historico_meses.size() - 6, 0)
	for i in range(sim.historico_meses.size() - 1, inicio - 1, -1):
		var m: Dictionary = sim.historico_meses[i]
		if i < sim.historico_meses.size() - 1:
			c.por(Kit.divisor())
		c.por(Kit.rotulo("%s · mês %d" % [String(m["nome_mes"]), int(m["mes"])], "pequeno_forte"))
		var gastos := float(m["custos_fixos"]) + float(m["consumo"])
		c.por(Kit.linha_valor("Renda / gastos", "%s / %s" % [
				Economia.reais(float(m["renda"]), false), Economia.reais(gastos, false)], Tema.TINTA, "pequeno"))
		c.por(Kit.linha_valor("Reserva", "%s meses" % Kit.decimal(float(m["meses_reserva"])), Tema.AZUL, "pequeno"))
		if float(m["divida"]) >= 1.0:
			c.por(Kit.linha_valor("Dívida ativa", Economia.reais(float(m["divida"]), false), Tema.VERMELHO, "pequeno"))
		c.por(Kit.linha_valor("Estresse médio", str(int(round(float(m["estresse_medio"])))),
				Tema.cor_estresse(float(m["estresse_medio"])), "pequeno"))
