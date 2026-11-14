extends TelaBase
## Aba Trabalho: emprego atual, ritmo de trabalho, estudos e vagas.

const NOME_VINCULO := {"informal": "Informal", "pj": "PJ (sem carteira)", "clt": "CLT (carteira assinada)"}
const DESCRICAO_RITMO := {
	"leve": "Renda 25% menor. Você descansa e o cansaço baixa mais rápido.",
	"normal": "Renda normal. O cansaço se mantém.",
	"puxado": "Renda 25% maior. O cansaço sobe a cada dia trabalhado.",
}


func montar(sim: Simulacao) -> void:
	_emprego_atual(sim)
	_ritmo(sim)
	_estudos(sim)
	_vagas(sim)


func _etiqueta_vinculo(vinculo: String) -> PanelContainer:
	var cores: Array[Color] = [Tema.AMBAR, Tema.AMBAR_CLARO]
	if vinculo == "clt":
		cores = [Tema.VERDE, Tema.VERDE_CLARO]
	elif vinculo == "pj":
		cores = [Tema.ROXO, Tema.ROXO_CLARO]
	return Kit.etiqueta(String(NOME_VINCULO.get(vinculo, vinculo)), cores[0], cores[1])


func _emprego_atual(sim: Simulacao) -> void:
	var emp := sim.emprego()
	var c := novo_cartao("Seu trabalho")
	c.por(_etiqueta_vinculo(sim.vinculo()))
	c.por(Kit.rotulo(String(emp["nome"]), "subtitulo"))
	c.por(Kit.rotulo(String(emp.get("resumo", "")), "pequeno", Tema.TINTA_2))
	c.por(Kit.linha_valor("Renda esperada por mês", Economia.reais(sim.renda_esperada_mes(), false)))
	c.por(Kit.linha_valor("Recebido nos últimos 30 dias", Economia.reais(sim.renda_mensal(), false)))
	if sim.pend_bruto >= 0.01:
		var liquido := sim.pend_bruto - sim.pend_inss - sim.pend_vt
		if sim.atraso_salario_em > 0:
			c.por(Kit.linha_valor("Pagamento atrasado", Economia.reais(liquido), Tema.VERMELHO))
		else:
			c.por(Kit.linha_valor("A receber no dia %d" % Economia.DIA_SALARIO, Economia.reais(liquido), Tema.VERDE))
	if sim.dias_sem_renda > 0:
		c.por(Kit.rotulo("Você está sem conseguir trabalhar por mais %s." % Kit.dias(sim.dias_sem_renda),
				"pequeno_forte", Tema.VERMELHO))
	var direitos: Array = emp.get("direitos", [])
	if sim.vinculo() == "clt":
		for direito: Variant in direitos:
			var linha := Kit.hbox(10)
			linha.add_child(Kit.icone("check", 30, Tema.VERDE))
			linha.add_child(Kit.rotulo(String(direito), "pequeno"))
			c.por(linha)
	else:
		c.por(Kit.rotulo("Sem 13º, férias, FGTS ou dia pago em caso de doença.", "pequeno_forte", Tema.AMBAR))


func _ritmo(sim: Simulacao) -> void:
	var c := novo_cartao("Ritmo de trabalho")
	var linha := Kit.hbox(10)
	for id: Variant in sim.ritmos_disponiveis():
		var ritmo := String(id)
		var ativo := sim.ritmo == ritmo
		var b := Kit.botao_pequeno(String(Simulacao.RITMOS[ritmo]["nome"]),
				"BotaoPrimario" if ativo else "BotaoNeutro")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not ativo:
			b.pressed.connect(func() -> void: acao(&"definir_ritmo", [ritmo]))
		linha.add_child(b)
	c.por(linha)
	var descricao := String(DESCRICAO_RITMO[sim.ritmo])
	if sim.vinculo() != "informal":
		if sim.ritmo == "puxado":
			var extra: Dictionary = sim.emprego()["extra"]
			var por_mes := (float(extra["ganho_min"]) + float(extra["ganho_max"])) / 2.0 * 21.0
			descricao = "%s em todo dia útil: cerca de %s a mais por mês. O cansaço sobe a cada dia." % [
				String(extra["nome"]), Economia.reais(por_mes, false)]
		else:
			descricao = "Jornada normal, sem hora extra."
	c.por(Kit.rotulo(descricao, "pequeno", Tema.TINTA_2))


func _estudos(sim: Simulacao) -> void:
	var c := novo_cartao("Estudos")
	var atual := sim.curso_atual()
	if atual != "":
		var curso := Catalogo.curso(atual)
		var feitas := int(sim.cursos[atual])
		var total := int(curso["aulas"])
		var por_dia := 2 if sim.tem_bem("notebook") else 1
		@warning_ignore("integer_division")
		var faltam := (total - feitas + por_dia - 1) / por_dia
		c.por(Kit.rotulo(String(curso["nome"]), "forte"))
		c.por(BarraValor.new(16, float(feitas) / float(total), Tema.AZUL))
		var situacao := "Pausado" if sim.estudo_pausado else "Termina em %s" % Kit.dias(faltam)
		c.por(Kit.linha_valor("Aula %d de %d" % [feitas, total], situacao, Tema.AZUL, "pequeno"))
		c.por(Kit.botao_pequeno("Retomar os estudos" if sim.estudo_pausado else "Pausar os estudos",
				"BotaoNeutro", func() -> void: acao(&"alternar_estudo")))
		c.por(Kit.rotulo("Estudar cansa um pouco todos os dias. Se o estresse apertar, pausar é uma saída.",
				"mini", Tema.TINTA_3))
	for curso: Variant in Catalogo.cursos():
		var id := String(curso["id"])
		if id == atual:
			continue
		if sim.cursos_concluidos.has(id):
			var linha := Kit.hbox(10)
			linha.add_child(Kit.icone("check", 30, Tema.VERDE))
			linha.add_child(Kit.rotulo("%s: concluído" % String(curso["nome"]), "pequeno_forte", Tema.VERDE))
			c.por(linha)
			continue
		if atual != "":
			continue
		c.por(Kit.divisor())
		c.por(Kit.rotulo(String(curso["nome"]), "forte"))
		c.por(Kit.rotulo(String(curso["descricao"]), "pequeno", Tema.TINTA_2))
		var custo := float(curso.get("custo", 0.0))
		var preco := "Gratuito" if custo <= 0.0 else Economia.reais(custo, false)
		c.por(Kit.linha_valor("%d aulas, uma por dia" % int(curso["aulas"]), preco, Tema.TINTA, "pequeno"))
		var motivo := sim.motivo_sem_matricula(id)
		var b := Kit.botao_pequeno("Fazer a matrícula" if motivo == "" else motivo, "BotaoSuave",
				func() -> void: acao(&"matricular", [id]))
		b.disabled = motivo != ""
		c.por(b)


func _vagas(sim: Simulacao) -> void:
	var c := novo_cartao("Vagas")
	var primeira := true
	for emp: Variant in Catalogo.empregos():
		var id := String(emp["id"])
		if id == sim.emprego_id:
			continue
		if not primeira:
			c.por(Kit.divisor())
		primeira = false
		c.por(_etiqueta_vinculo(String(emp["vinculo"])))
		c.por(Kit.rotulo(String(emp["nome"]), "forte"))
		if emp.has("salario"):
			var bruto := float(emp["salario"])
			var liquido := bruto * (1.0 - float(emp.get("inss", 0.0)) - float(emp.get("desconto_vt", 0.0)))
			c.por(Kit.linha_valor("Salário", Economia.reais(bruto, false), Tema.TINTA, "pequeno"))
			if liquido < bruto - 0.5:
				c.por(Kit.linha_valor("Cai na conta, depois dos descontos", Economia.reais(liquido, false), Tema.TINTA, "pequeno"))
			if emp.has("vale_refeicao"):
				c.por(Kit.linha_valor("Vale-refeição", Economia.reais(float(emp["vale_refeicao"]), false), Tema.VERDE, "pequeno"))
			if emp.has("das"):
				c.por(Kit.linha_valor("Boleto do MEI, por sua conta", Economia.reais(-float(emp["das"]), false), Tema.VERMELHO, "pequeno"))
		else:
			c.por(Kit.linha_valor("Renda por dia rodado", "%s a %s" % [
				Economia.reais(float(emp["renda_min"]), false), Economia.reais(float(emp["renda_max"]), false)],
				Tema.TINTA, "pequeno"))
		for requisito: Variant in sim.requisitos_emprego(id):
			var ok := bool(requisito["ok"])
			var linha := Kit.hbox(10)
			linha.add_child(Kit.icone("check" if ok else "fechar", 28, Tema.VERDE if ok else Tema.TINTA_3))
			linha.add_child(Kit.rotulo(String(requisito["texto"]), "pequeno", Tema.TINTA if ok else Tema.TINTA_2))
			c.por(linha)
		if String(sim.candidatura.get("emprego", "")) == id:
			var faltam := maxi(int(sim.candidatura["dia"]) - sim.dia_total, 1)
			c.por(Kit.rotulo("Processo seletivo em andamento. A resposta chega em até %s." % Kit.dias(faltam),
					"pequeno_forte", Tema.AZUL))
			continue
		var motivo := sim.motivo_sem_candidatura(id)
		if motivo.begins_with("Falta"):
			motivo = "Faltam requisitos"
		var b := Kit.botao_pequeno("Enviar currículo" if motivo == "" else motivo, "BotaoSuave",
				func() -> void: acao(&"candidatar", [id]))
		b.disabled = motivo != ""
		c.por(b)
