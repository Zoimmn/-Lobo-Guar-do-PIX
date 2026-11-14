extends TelaBase
## Aba Vida: saúde emocional (com a Equação 1 aberta), folga e lazer,
## o perfil que o algoritmo traçou do jogador e os bens.

const EFEITO_FAIXA := {
	"Tranquilo": "Cabeça fria: você decide com calma.",
	"Atento": "Tudo sob controle, mas vale acompanhar.",
	"Tenso": "A pressão está subindo. Folga e lazer ajudam.",
	"Ansioso": "Você rende menos nas entregas e tem menos tempo para decidir as ofertas com relógio.",
	"No limite": "Alguns dias você nem consegue trabalhar. Se o estresse ficar no máximo por muitos dias, a partida acaba.",
}
const NOME_INTERESSE := {"bets": "Apostas", "influencer": "Ofertas e influenciadores", "credito": "Crédito fácil"}


func montar(sim: Simulacao) -> void:
	_saude(sim)
	_lazer(sim)
	_equacao(sim)
	_algoritmo(sim)
	_bens(sim)
	_loja(sim)


func _saude(sim: Simulacao) -> void:
	var estresse := sim.estresse()
	var faixa := ModeloEstresse.faixa(estresse)
	var cor := Tema.cor_estresse(estresse)
	var c := novo_cartao("Saúde emocional")
	var linha := Kit.hbox(18)
	var numero := Kit.rotulo(str(int(round(estresse))), "numero", cor, false)
	linha.add_child(numero)
	var textos := Kit.vbox(4)
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_child(Kit.rotulo("Estresse: %s" % faixa.to_lower(), "forte", cor))
	textos.add_child(BarraValor.new(18, estresse / 100.0, cor))
	linha.add_child(textos)
	c.por(linha)
	c.por(Kit.rotulo(String(EFEITO_FAIXA.get(faixa, "")), "pequeno", Tema.TINTA_2))
	if sim.dias_criticos > 0:
		c.por(Kit.rotulo("No limite há %s. A partida termina aos %d dias seguidos." % [
				Kit.dias(sim.dias_criticos), ModeloEstresse.DIAS_ATE_ESGOTAMENTO], "pequeno_forte", Tema.VERMELHO))


func _lazer(sim: Simulacao) -> void:
	var c := novo_cartao("Folga e lazer")
	var primeiro := true
	for l: Variant in Catalogo.lazeres():
		var id := String(l["id"])
		if not primeiro:
			c.por(Kit.divisor())
		primeiro = false
		var custo := float(l.get("custo", 0.0))
		c.por(Kit.linha_valor(String(l["nome"]), "Grátis" if custo <= 0.0 else Economia.reais(custo, false)))
		c.por(Kit.rotulo(String(l["descricao"]), "pequeno", Tema.TINTA_2))
		var motivo := sim.motivo_sem_lazer(id)
		var b := Kit.botao_pequeno("Fazer agora" if motivo == "" else motivo, "BotaoSuave",
				func() -> void: acao(&"lazer", [id]))
		b.disabled = motivo != ""
		c.por(b)


## Mostra a Equação 1 do artigo com os valores atuais do jogador.
func _equacao(sim: Simulacao) -> void:
	var d := sim.detalhe_estresse()
	var c := novo_cartao("Como o estresse é calculado")
	var formula := Kit.rotulo("S = S0 × e^(α × D) + β × F", "subtitulo", Tema.GUARA_ESCURO)
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.por(formula)
	c.por(Kit.linha_valor("S0 · estresse basal", Kit.decimal(float(d["s0"])), Tema.TINTA, "pequeno"))
	c.por(Kit.rotulo("Trabalho %s + cansaço %s + choques %s" % [
			Kit.decimal(float(d["base_emprego"])), Kit.decimal(float(d["fadiga"])),
			Kit.decimal(float(d["choque"]))], "mini", Tema.TINTA_3))
	c.por(Kit.linha_valor("D · dívida ativa ÷ renda do mês", Kit.decimal(float(d["d"]), 2), Tema.TINTA, "pequeno"))
	c.por(Kit.rotulo("%s de dívida ÷ %s de renda" % [
			Economia.reais(sim.divida_ativa(), false), Economia.reais(maxf(sim.renda_mensal(), ModeloEstresse.RENDA_PISO), false)],
			"mini", Tema.TINTA_3))
	c.por(Kit.linha_valor("α · sensibilidade à dívida", Kit.decimal(float(d["alfa"]), 2), Tema.TINTA, "pequeno"))
	c.por(Kit.linha_valor("F · gatilhos de FOMO recentes", Kit.decimal(float(d["fomo"])), Tema.TINTA, "pequeno"))
	c.por(Kit.linha_valor("β · vulnerabilidade", Kit.decimal(float(d["beta"]), 2), Tema.TINTA, "pequeno"))
	c.por(Kit.rotulo("Cai a cada vacina aprendida (%d) e sobe quando você cede aos gatilhos (%d)." % [
			sim.vacinas.size(), sim.cedidas], "mini", Tema.TINTA_3))
	c.por(Kit.divisor())
	c.por(Kit.linha_valor("Peso da dívida", Kit.decimal(float(d["termo_divida"])), Tema.GUARA_ESCURO, "pequeno"))
	c.por(Kit.linha_valor("Peso do FOMO", "+ " + Kit.decimal(float(d["termo_fomo"])), Tema.ROXO, "pequeno"))
	c.por(Kit.linha_valor("Estresse (máximo 100)", Kit.decimal(float(d["total"])), Tema.cor_estresse(float(d["total"]))))


func _algoritmo(sim: Simulacao) -> void:
	var c := novo_cartao("O que o algoritmo sabe de você")
	c.por(Kit.rotulo("Cada clique em oferta ensina os aplicativos a mostrar mais do mesmo. Silenciar, bloquear e fazer detox esfriam o perfil.",
			"pequeno", Tema.TINTA_2))
	for chave: Variant in NOME_INTERESSE.keys():
		var nivel := float(sim.interesse.get(chave, 0.0)) / Simulacao.INTERESSE_MAXIMO
		c.por(Kit.rotulo(String(NOME_INTERESSE[chave]), "pequeno_forte"))
		c.por(BarraValor.new(12, nivel, Tema.ROXO))


func _bens(sim: Simulacao) -> void:
	var c := novo_cartao("Seus bens")
	for id: Variant in sim.bens:
		var item := Catalogo.bem(String(id))
		if item.is_empty():
			continue
		var revenda := float(item.get("revenda", 0.0))
		c.por(Kit.linha_valor(String(item["nome"]), "revenda %s" % Economia.reais(revenda, false), Tema.TINTA_2, "pequeno", Tema.TINTA))
		if not bool(item.get("essencial", false)):
			var item_id := String(id)
			var nome := String(item["nome"])
			c.por(Kit.botao_pequeno("Vender por %s" % Economia.reais(revenda, false), "BotaoNeutro", func() -> void:
				abrir_modal(Modais.confirmar("Vender %s?" % nome,
						"Você recebe %s na conta. É bem menos do que custou." % Economia.reais(revenda, false),
						"Vender", func() -> void: acao(&"vender_bem", [item_id])))))
	c.por(Kit.rotulo("O que você tem entra no patrimônio pelo valor de revenda.", "mini", Tema.TINTA_3))


func _loja(sim: Simulacao) -> void:
	var itens: Array = []
	for item: Variant in Catalogo.bens():
		if bool(item.get("loja", false)) and not sim.tem_bem(String(item["id"])):
			itens.append(item)
	if itens.is_empty():
		return
	var c := novo_cartao("Loja")
	var primeiro := true
	for item: Variant in itens:
		var id := String(item["id"])
		if not primeiro:
			c.por(Kit.divisor())
		primeiro = false
		var preco := float(item["preco"])
		c.por(Kit.linha_valor(String(item["nome"]), Economia.reais(preco, false)))
		if item.has("efeito"):
			c.por(Kit.rotulo(String(item["efeito"]), "pequeno_forte", Tema.VERDE))
		c.por(Kit.rotulo(String(item["descricao"]), "pequeno", Tema.TINTA_2))
		var botoes := Kit.hbox(12)
		var motivo_vista := sim.motivo_sem_compra(id, "avista")
		var a_vista := Kit.botao_pequeno("À vista" if motivo_vista == "" else motivo_vista, "BotaoSuave",
				func() -> void: acao(&"comprar_bem", [id, "avista"]))
		a_vista.disabled = motivo_vista != ""
		a_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botoes.add_child(a_vista)
		var parcelas := int(item.get("parcelas", 1))
		if parcelas > 1 and sim.cartao_ativo:
			var motivo_cartao := sim.motivo_sem_compra(id, "cartao")
			var no_cartao := Kit.botao_pequeno(
					"%dx de %s" % [parcelas, Economia.reais(preco / float(parcelas), false)] if motivo_cartao == "" else motivo_cartao,
					"BotaoNeutro", func() -> void: acao(&"comprar_bem", [id, "cartao"]))
			no_cartao.disabled = motivo_cartao != ""
			no_cartao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			botoes.add_child(no_cartao)
		c.por(botoes)
