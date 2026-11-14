extends TelaBase
## Aba Banco: conta, reserva de emergência, cartão, empréstimos e extrato.

const SUGESTOES: Array = [50.0, 100.0, 200.0, 500.0, 1000.0]
const NOME_CATEGORIA := {
	"renda": "renda", "custo_fixo": "custo fixo", "consumo": "consumo", "golpe": "golpe",
	"aposta": "aposta", "premio_aposta": "aposta", "divida": "dívida", "juros": "juros",
	"aporte": "reserva", "resgate": "reserva", "emprestimo": "empréstimo",
	"imposto_direto": "imposto", "outros": "outros",
}


func montar(sim: Simulacao) -> void:
	_conta(sim)
	_reserva(sim)
	_cartao(sim)
	_emprestimos(sim)
	_extrato(sim)


func _conta(sim: Simulacao) -> void:
	var c := novo_cartao("Conta")
	c.por(Kit.rotulo(Economia.reais(sim.saldo), "numero_medio",
			Tema.VERMELHO if sim.saldo < 0.0 else Tema.TINTA, false))
	if sim.saldo < 0.0:
		c.por(Kit.rotulo("Conta no vermelho: o cheque especial cobra %s de juros ao mês, todos os dias." % Economia.porcento(Economia.TAXA_CHEQUE_ESPECIAL, 0),
				"pequeno_forte", Tema.VERMELHO))
	elif sim.limite_cheque() > 0.0:
		c.por(Kit.rotulo("Limite da conta (cheque especial): %s. Não é saldo." % Economia.reais(sim.limite_cheque(), false),
				"mini", Tema.TINTA_3))
	if sim.fgts >= 0.01:
		c.por(Kit.linha_valor("FGTS (bloqueado)", Economia.reais(sim.fgts), Tema.TINTA, "pequeno"))
	for i in sim.contas_atrasadas.size():
		var conta: Dictionary = sim.contas_atrasadas[i]
		var caixa := Cartao.new(Tema.VERMELHO_CLARO, 18, Color.TRANSPARENT, 18, 8)
		caixa.por(Kit.linha_valor("%s em atraso há %s" % [String(conta["nome"]), Kit.dias(int(conta["dias"]))],
				Economia.reais(float(conta["valor"])), Tema.VERMELHO, "pequeno", Tema.VERMELHO))
		var indice := i
		var pagar := Kit.botao_pequeno("Pagar agora", "BotaoPerigo", func() -> void: _pagar_atrasada(indice))
		pagar.disabled = sim.saldo < float(conta["valor"])
		caixa.por(pagar)
		c.por(caixa)


func _pagar_atrasada(indice: int) -> void:
	var pago: Variant = GameManager.agir(&"pagar_atrasada", [indice])
	if float(pago) > 0.0:
		GameManager.aviso.emit("Conta em atraso quitada.", "bom")
	marcar_suja()


func _reserva(sim: Simulacao) -> void:
	var c := novo_cartao("Reserva de emergência")
	var linha := Kit.hbox(14)
	linha.add_child(Kit.icone_em_circulo("reserva", Tema.AZUL, Tema.AZUL_CLARO, 68))
	var textos := Kit.vbox(0)
	textos.add_child(Kit.rotulo(Economia.reais(sim.reserva), "numero_medio", Tema.AZUL, false))
	textos.add_child(Kit.rotulo("Cobre %s meses do custo de vida. Meta: %d meses." % [
			Kit.decimal(sim.meses_reserva()), int(Economia.META_RESERVA_MESES)], "pequeno", Tema.TINTA_2))
	linha.add_child(textos)
	c.por(linha)
	c.por(BarraValor.new(16, sim.reserva / sim.meta_reserva(), Tema.AZUL))
	c.por(Kit.linha_valor("Rendimento neste mês", "+" + Economia.reais(float(sim.mes_acum["rendimentos"])),
			Tema.VERDE, "pequeno"))
	c.por(Kit.rotulo("Rende cerca de %s ao mês, com juros sobre juros, e pode ser resgatada a qualquer hora." % Economia.porcento(Economia.TAXA_RESERVA, 0),
			"mini", Tema.TINTA_3))
	var botoes := Kit.hbox(12)
	var guardar := Kit.botao_pequeno("Guardar", "BotaoPrimario", func() -> void:
		abrir_modal(Modais.valor("Guardar na reserva", "Saldo na conta: %s" % Economia.reais(sim.saldo),
				snappedf(maxf(sim.saldo, 0.0), 0.01), SUGESTOES, "Guardar",
				func(v: float) -> void: acao(&"depositar_reserva", [v]), "reserva")))
	guardar.disabled = sim.saldo < 1.0
	guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botoes.add_child(guardar)
	var resgatar := Kit.botao_pequeno("Resgatar", "BotaoNeutro", func() -> void:
		abrir_modal(Modais.valor("Resgatar da reserva", "Na reserva: %s" % Economia.reais(sim.reserva),
				snappedf(sim.reserva, 0.01), SUGESTOES, "Resgatar",
				func(v: float) -> void: acao(&"sacar_reserva", [v]), "reserva")))
	resgatar.disabled = sim.reserva < 1.0
	resgatar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botoes.add_child(resgatar)
	c.por(botoes)


func _cartao(sim: Simulacao) -> void:
	var c := novo_cartao("Cartão de crédito")
	if not sim.cartao_ativo:
		c.por(Kit.rotulo("Você ainda não tem cartão de crédito.", "pequeno", Tema.TINTA_2))
		return
	c.por(Kit.linha_valor("Limite", Economia.reais(sim.limite, false)))
	c.por(Kit.linha_valor("Disponível", Economia.reais(sim.limite_disponivel(), false)))
	c.por(Kit.linha_valor("Fatura aberta (fecha no dia %d)" % Economia.DIA_FECHAMENTO,
			Economia.reais(sim.fatura_aberta + sim.parcelas_cartao_mes())))

	if sim.fatura_fechada >= 0.01:
		var faltam := maxi(sim.vencimento_em - sim.dia_total, 0)
		var caixa := Cartao.new(Tema.AMBAR_CLARO, 18, Color.TRANSPARENT, 18, 8)
		var quando := "vence hoje" if faltam == 0 else "vence em " + Kit.dias(faltam)
		caixa.por(Kit.linha_valor("Fatura fechada, %s" % quando, Economia.reais(sim.fatura_fechada),
				Tema.AMBAR, "pequeno", Tema.AMBAR))
		var pagar := Kit.botao_pequeno("Pagar a fatura", "BotaoPrimario", func() -> void:
			abrir_modal(Modais.valor("Pagar a fatura",
					"Fatura: %s. Mínimo: %s. Saldo: %s." % [Economia.reais(sim.fatura_fechada),
						Economia.reais(sim.fatura_minimo), Economia.reais(sim.saldo)],
					snappedf(minf(sim.fatura_fechada, maxf(sim.saldo, 0.0)), 0.01),
					[sim.fatura_minimo, snappedf(sim.fatura_fechada / 2.0, 0.01)], "Pagar",
					func(v: float) -> void: _pagar(&"pagar_fatura", v), "cartao")))
		pagar.disabled = sim.saldo < 1.0
		caixa.por(pagar)
		c.por(caixa)

	if sim.rot_saldo >= 0.01:
		var taxa := Economia.taxa_rotativo(sim.mes())
		var caixa_rot := Cartao.new(Tema.VERMELHO_CLARO, 18, Color.TRANSPARENT, 18, 8)
		caixa_rot.por(Kit.linha_valor("No rotativo", Economia.reais(sim.rot_saldo), Tema.VERMELHO,
				"pequeno", Tema.VERMELHO))
		caixa_rot.por(Kit.rotulo("Juros de %s ao mês (%s ao ano), cobrados todos os dias." % [
				Economia.porcento(taxa), Economia.porcento(Economia.taxa_anual(taxa), 0)], "mini", Tema.VERMELHO))
		var pagar_rot := Kit.botao_pequeno("Pagar o rotativo", "BotaoPerigo", func() -> void:
			abrir_modal(Modais.valor("Pagar o rotativo",
					"No rotativo: %s. Saldo: %s." % [Economia.reais(sim.rot_saldo), Economia.reais(sim.saldo)],
					snappedf(minf(sim.rot_saldo, maxf(sim.saldo, 0.0)), 0.01), SUGESTOES, "Pagar",
					func(v: float) -> void: _pagar(&"pagar_rotativo", v), "cartao")))
		pagar_rot.disabled = sim.saldo < 1.0
		caixa_rot.por(pagar_rot)
		c.por(caixa_rot)

	if not sim.parcelamentos.is_empty():
		c.por(Kit.divisor())
		c.por(Kit.rotulo("PARCELAS NAS PRÓXIMAS FATURAS", "mini", Tema.TINTA_3, false))
		for p: Variant in sim.parcelamentos:
			c.por(Kit.linha_valor(String(p["descricao"]), "%dx de %s" % [
					int(p["restantes"]), Economia.reais(float(p["parcela"]))], Tema.TINTA, "pequeno"))


func _pagar(metodo: StringName, valor: float) -> void:
	var pago: Variant = GameManager.agir(metodo, [valor])
	if float(pago) > 0.0:
		GameManager.aviso.emit("Pagamento de %s feito." % Economia.reais(float(pago)), "bom")
	else:
		GameManager.aviso.emit("Não foi possível pagar.", "alerta")
	marcar_suja()


func _emprestimos(sim: Simulacao) -> void:
	if sim.emprestimos.is_empty():
		return
	var c := novo_cartao("Empréstimos")
	for i in sim.emprestimos.size():
		var e: Dictionary = sim.emprestimos[i]
		if i > 0:
			c.por(Kit.divisor())
		c.por(Kit.linha_valor(String(e["nome"]), Economia.reais(float(e["saldo"])), Tema.VERMELHO))
		c.por(Kit.linha_valor("Parcela no dia %d" % Economia.DIA_EMPRESTIMOS, Economia.reais(float(e["parcela"])),
				Tema.TINTA, "pequeno"))
		c.por(Kit.linha_valor("Juros", "%s ao mês" % Economia.porcento(float(e["taxa"])), Tema.TINTA, "pequeno"))
		var indice := i
		var antecipar := Kit.botao_pequeno("Antecipar pagamento", "BotaoNeutro", func() -> void:
			abrir_modal(Modais.valor("Antecipar: %s" % String(e["nome"]),
					"Saldo devedor: %s. Antecipar reduz os juros que ainda viriam." % Economia.reais(float(e["saldo"])),
					snappedf(minf(float(e["saldo"]), maxf(sim.saldo, 0.0)), 0.01), SUGESTOES, "Pagar",
					func(v: float) -> void: _antecipar(indice, v))))
		antecipar.disabled = sim.saldo < 1.0
		c.por(antecipar)


func _antecipar(indice: int, valor: float) -> void:
	var pago: Variant = GameManager.agir(&"amortizar_emprestimo", [indice, valor])
	if float(pago) > 0.0:
		GameManager.aviso.emit("Antecipação de %s feita." % Economia.reais(float(pago)), "bom")
	marcar_suja()


func _extrato(sim: Simulacao) -> void:
	var c := novo_cartao("Extrato")
	var primeiro_dia_do_mes := (sim.mes() - 1) * Economia.DIAS_MES + 1
	var rotina := Database.soma_da_rotina(primeiro_dia_do_mes)
	if rotina <= -0.01:
		c.por(Kit.linha_valor("Comida e transporte do dia a dia, neste mês", Economia.reais(rotina),
				Tema.TINTA, "pequeno"))
		c.por(Kit.divisor())
	var linhas := Database.ultimas_transacoes(25, true)
	if linhas.is_empty():
		c.por(Kit.rotulo("As outras movimentações aparecem aqui.", "pequeno", Tema.TINTA_2))
		return
	for t: Variant in linhas:
		var valor := float(t["valor"])
		var cor := Tema.VERDE if valor > 0.0 else Tema.TINTA
		var categoria := String(t["categoria"])
		if categoria == "golpe" or categoria == "juros":
			cor = Tema.VERMELHO
		var meio := " · cartão" if String(t["meio"]) == "cartao" else ""
		var linha := Kit.hbox(10)
		var textos := Kit.vbox(0)
		textos.add_child(Kit.rotulo(String(t["descricao"]), "pequeno"))
		var detalhe := "DIA %d · %s%s" % [int(t["dia"]), String(NOME_CATEGORIA.get(categoria, categoria)).to_upper(), meio.to_upper()]
		var imposto := float(t["imposto_embutido"])
		if imposto >= 0.01:
			detalhe += " · IMPOSTO EMBUTIDO %s" % Economia.reais(imposto)
		textos.add_child(Kit.rotulo(detalhe, "mini", Tema.TINTA_3))
		linha.add_child(textos)
		var rotulo_valor := Kit.rotulo(("+" if valor > 0.0 else "") + Economia.reais(valor), "pequeno_forte", cor, false)
		rotulo_valor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		linha.add_child(rotulo_valor)
		c.por(linha)
