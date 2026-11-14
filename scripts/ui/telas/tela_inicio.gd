extends TelaBase
## Aba Início: notificações, próximos vencimentos, metas e diário.


func montar(sim: Simulacao) -> void:
	_notificacoes(sim)
	_mes_ate_agora(sim)
	_metas(sim)
	_diario(sim)


func _notificacoes(sim: Simulacao) -> void:
	var c := novo_cartao("Notificações")
	if sim.pendentes.is_empty():
		c.por(Kit.rotulo("Nenhuma notificação esperando. O dia segue.", "pequeno", Tema.TINTA_2))
		return
	for p: Variant in sim.pendentes:
		var ev := sim.evento_de(p)
		var canal := String(ev.get("canal", "Mensagem"))
		var b := Kit.botao("%s\n%s" % [String(ev.get("remetente", "")), String(ev.get("titulo", ""))],
				"BotaoSuave", Callable(), String(ModalEvento.ICONE_CANAL.get(canal, "mensagem")))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pendente: Dictionary = p
		b.pressed.connect(func() -> void: get_tree().call_group("jogo", "abrir_evento", pendente))
		c.por(b)
		var restam := int(p["expira_em"]) - sim.dia_total + 1
		c.por(Kit.rotulo("Sem resposta em %s, vale a opção padrão." % Kit.dias(maxi(restam, 1)), "mini", Tema.TINTA_3))


func _mes_ate_agora(sim: Simulacao) -> void:
	var c := novo_cartao("%s até agora" % sim.nome_mes())
	var m := sim.mes_acum
	c.por(Kit.linha_valor("Entrou", Economia.reais(float(m["renda"])), Tema.VERDE))
	var saiu := float(m["custos_fixos"]) + float(m["consumo"]) + float(m["golpes"]) \
			+ float(m["apostado"]) - float(m["ganho_apostas"]) + float(m["impostos_diretos"])
	c.por(Kit.linha_valor("Saiu", Economia.reais(saiu)))
	if float(m["juros"]) >= 0.01:
		c.por(Kit.linha_valor("Juros e multas", Economia.reais(float(m["juros"])), Tema.VERMELHO))
	c.por(Kit.divisor())
	c.por(Kit.rotulo("PRÓXIMOS VENCIMENTOS", "mini", Tema.TINTA_3, false))
	for conta: Variant in _proximas_contas(sim):
		var quando := "hoje" if int(conta["em"]) == 0 else "em " + Kit.dias(int(conta["em"]))
		var entra := float(conta["valor"]) > 0.0
		c.por(Kit.linha_valor("%s · %s" % [String(conta["nome"]), quando],
				Economia.reais(float(conta["valor"]), false), Tema.VERDE if entra else Tema.TINTA, "pequeno"))


## As próximas quatro movimentações com data marcada.
func _proximas_contas(sim: Simulacao) -> Array:
	var hoje := sim.dia_do_mes()
	var lista: Array = [
		{"dia": Economia.DIA_MORADIA, "nome": "Moradia", "valor": -Economia.MORADIA},
		{"dia": Economia.DIA_CONTAS, "nome": "Contas da casa", "valor": -Economia.CONTAS_CASA},
		{"dia": Economia.DIA_CELULAR, "nome": "Plano do celular", "valor": -Economia.PLANO_CELULAR},
	]
	var emp := sim.emprego()
	if emp.has("das"):
		lista.append({"dia": Economia.DIA_DAS, "nome": "Boleto do MEI", "valor": -float(emp["das"])})
	if emp.has("salario"):
		var liquido := sim.pend_bruto - sim.pend_inss - sim.pend_vt
		if liquido < 0.01:
			liquido = sim.renda_esperada_mes()
		lista.append({"dia": Economia.DIA_SALARIO, "nome": "Salário", "valor": liquido})
	if sim.fatura_fechada >= 0.01:
		lista.append({"dia": Economia.DIA_SALARIO, "nome": "Fatura do cartão", "valor": -sim.fatura_fechada})
	var parcelas := 0.0
	for e: Variant in sim.emprestimos:
		parcelas += float(e["parcela"])
	if parcelas >= 0.01:
		lista.append({"dia": Economia.DIA_EMPRESTIMOS, "nome": "Parcelas de empréstimo", "valor": -parcelas})
	for item: Variant in lista:
		item["em"] = (int(item["dia"]) - hoje + Economia.DIAS_MES) % Economia.DIAS_MES
	lista.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a["em"]) < int(b["em"]))
	return lista.slice(0, 4)


func _metas(sim: Simulacao) -> void:
	var metas := Catalogo.metas()
	var c := novo_cartao("Metas · %d de %d" % [sim.metas_ok.size(), metas.size()])
	for meta: Variant in metas:
		var feita := sim.metas_ok.has(String(meta["id"]))
		var linha := Kit.hbox(14)
		if feita:
			linha.add_child(Kit.icone_em_circulo("check", Tema.BRANCO, Tema.VERDE, 44))
		else:
			linha.add_child(Kit.icone_em_circulo("trofeu", Tema.TINTA_3, Tema.LINHA, 44))
		var textos := Kit.vbox(6)
		textos.add_child(Kit.rotulo(String(meta["titulo"]), "pequeno_forte", Tema.TINTA_2 if feita else Tema.TINTA))
		if not feita:
			var progresso := sim.progresso_meta(meta)
			textos.add_child(BarraValor.new(10, progresso, Tema.GUARA))
		linha.add_child(textos)
		c.por(linha)


func _diario(sim: Simulacao) -> void:
	var c := novo_cartao("Diário")
	if sim.diario.is_empty():
		c.por(Kit.rotulo("O que acontecer de importante aparece aqui.", "pequeno", Tema.TINTA_2))
		return
	var inicio := maxi(sim.diario.size() - 6, 0)
	for i in range(sim.diario.size() - 1, inicio - 1, -1):
		var entrada: Dictionary = sim.diario[i]
		var linha := Kit.hbox(12)
		var ponto := Kit.icone("ponto", 22, Tema.cores_tipo(String(entrada["tipo"]))[0])
		ponto.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		linha.add_child(ponto)
		var textos := Kit.vbox(0)
		textos.add_child(Kit.rotulo("DIA %d" % int(entrada["dia"]), "mini", Tema.TINTA_3, false))
		textos.add_child(Kit.rotulo(String(entrada["texto"]), "pequeno"))
		linha.add_child(textos)
		c.por(linha)
