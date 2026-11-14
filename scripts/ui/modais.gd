class_name Modais
extends RefCounted
## Fábrica dos modais de conteúdo fixo: como jogar, vacinas, confirmação,
## escolha de valor, fechamento do mês, fim de partida e menu.

const COMO_JOGAR: Array = [
	["relogio", "O dinheiro anda sozinho", "O tempo passa mesmo sem você tocar em nada: a renda entra, as contas vencem, os juros correm. No topo da tela dá para pausar ou acelerar."],
	["sino", "Toda notificação é uma decisão", "Mensagens, ofertas e imprevistos chegam o tempo todo, e algumas têm relógio. Nem toda oferta é golpe e nem todo gasto é erro: leia antes de tocar."],
	["vida", "Estresse também é saldo", "Dívida, cansaço e a pressão das redes aumentam o estresse. Se ele ficar no máximo por muitos dias, a partida acaba. Folga e lazer recuperam."],
	["escudo", "Vacinas cognitivas", "Cada armadilha, caindo nela ou escapando, revela a técnica de manipulação que estava por trás. Quanto mais vacinas, menos a pressão te afeta."],
	["trofeu", "A meta", "Juntar uma reserva de emergência de 6 meses do custo de vida, sem dívida ativa. No caminho: estudar, sair da informalidade e manter as contas em dia."],
]


## Cartão que explica uma vacina cognitiva.
static func cartao_vacina(v: Dictionary, nova: bool = false) -> Cartao:
	var escuro := Tema.VERDE.darkened(0.3)
	var c := Cartao.new(Tema.VERDE_CLARO, 24, Color.TRANSPARENT)
	var topo := Kit.hbox(16)
	topo.add_child(Kit.icone_em_circulo("escudo", Tema.BRANCO, Tema.VERDE, 68))
	var textos := Kit.vbox(0)
	var linha := Kit.hbox(10)
	linha.add_child(Kit.rotulo("VACINA COGNITIVA", "secao", escuro, false))
	if nova:
		linha.add_child(Kit.etiqueta("NOVA", Tema.BRANCO, Tema.VERDE))
	textos.add_child(linha)
	textos.add_child(Kit.rotulo(String(v.get("nome", "")), "subtitulo", escuro))
	topo.add_child(textos)
	c.por(topo)
	c.por(Kit.rotulo(String(v.get("explicacao", "")), "pequeno"))
	var protecao := Cartao.new(Color(1, 1, 1, 0.72), 18, Color.TRANSPARENT, 16, 4)
	protecao.por(Kit.rotulo("COMO SE PROTEGER", "mini", escuro, false))
	protecao.por(Kit.rotulo(String(v.get("protecao", "")), "pequeno_forte"))
	c.por(protecao)
	return c


static func como_jogar() -> ModalBase:
	var m := ModalBase.new()
	m.cabecalho("Como jogar", "", "ajuda")
	for item: Variant in COMO_JOGAR:
		var c := Cartao.new(Tema.SUPERFICIE, 22)
		var linha := Kit.hbox(16)
		linha.add_child(Kit.icone_em_circulo(String(item[0]), Tema.GUARA_ESCURO, Tema.GUARA_CLARO, 64))
		var textos := Kit.vbox(4)
		textos.add_child(Kit.rotulo(String(item[1]), "forte"))
		textos.add_child(Kit.rotulo(String(item[2]), "pequeno", Tema.TINTA_2))
		linha.add_child(textos)
		c.por(linha)
		m.corpo.add_child(c)
	m.botao("Entendi")
	return m


## Coleção de vacinas. [param adquiridas] é a lista de ids já vistos.
static func vacinas(adquiridas: Array) -> ModalBase:
	var m := ModalBase.new()
	var todas := Catalogo.vacinas()
	m.cabecalho("Vacinas cognitivas", "%d de %d descobertas" % [adquiridas.size(), todas.size()],
			"escudo", Tema.VERDE, Tema.VERDE_CLARO)
	m.texto("Cada vacina é uma técnica de manipulação que você já reconhece. Elas aparecem quando você encontra a armadilha no jogo.", "pequeno", Tema.TINTA_2)
	for v: Variant in todas:
		if adquiridas.has(String(v["id"])):
			m.corpo.add_child(cartao_vacina(v))
	var faltam := 0
	for v: Variant in todas:
		if not adquiridas.has(String(v["id"])):
			faltam += 1
	if faltam > 0:
		var c := Cartao.new(Tema.SUPERFICIE_2, 22)
		var linha := Kit.hbox(16)
		linha.add_child(Kit.icone_em_circulo("cadeado", Tema.TINTA_3, Tema.LINHA, 64))
		var texto_faltam := "Falta 1 vacina por descobrir." if faltam == 1 \
				else "Faltam %d vacinas por descobrir." % faltam
		linha.add_child(Kit.rotulo(texto_faltam, "pequeno_forte", Tema.TINTA_2))
		c.por(linha)
		m.corpo.add_child(c)
	m.botao("Fechar", "BotaoNeutro")
	return m


static func confirmar(titulo: String, texto: String, rotulo_sim: String, acao: Callable,
		variacao: String = "BotaoPrimario", rotulo_nao: String = "Cancelar") -> ModalBase:
	var m := ModalBase.new()
	m.cabecalho(titulo)
	m.texto(texto, "corpo", Tema.TINTA_2)
	m.botao(rotulo_sim, variacao, acao)
	m.botao(rotulo_nao, "BotaoNeutro")
	return m


## Escolha de um valor em reais entre sugestões. [param acao] recebe o valor.
static func valor(titulo: String, descricao: String, maximo: float, sugestoes: Array,
		rotulo_acao: String, acao: Callable, nome_icone: String = "moeda") -> ModalBase:
	var m := ModalBase.new()
	m.cabecalho(titulo, "", nome_icone)
	if descricao != "":
		m.texto(descricao, "pequeno", Tema.TINTA_2)
	var estado := {"valor": 0.0}
	var mostrador := Kit.rotulo(Economia.reais(0.0), "numero", Tema.TINTA, false)
	mostrador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.corpo.add_child(mostrador)
	var confirmar_botao := Kit.botao(rotulo_acao, "BotaoPrimario")
	confirmar_botao.disabled = true
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	var botoes: Array[Button] = []
	var opcoes: Array = []
	for s: Variant in sugestoes:
		if float(s) < maximo - 0.005:
			opcoes.append(float(s))
	opcoes.append(maximo)
	for opcao: Variant in opcoes:
		var v := float(opcao)
		var e_tudo := is_equal_approx(v, maximo)
		var b := Kit.botao_pequeno(("Tudo\n" if e_tudo else "") + Economia.reais(v, e_tudo), "BotaoNeutro")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			estado["valor"] = v
			mostrador.text = Economia.reais(v)
			confirmar_botao.disabled = false
			for outro in botoes:
				outro.theme_type_variation = "BotaoNeutro"
			b.theme_type_variation = "BotaoSuave")
		botoes.append(b)
		grade.add_child(b)
	m.corpo.add_child(grade)
	confirmar_botao.pressed.connect(func() -> void:
		var escolhido := float(estado["valor"])
		m.fechar()
		acao.call(escolhido))
	m.rodape.add_child(confirmar_botao)
	m.botao("Cancelar", "BotaoNeutro")
	return m


## Resumo do mês que acabou de fechar.
static func fechamento(r: Dictionary) -> ModalBase:
	var m := ModalBase.new()
	m.dispensavel = false
	m.cabecalho("Fechamento de %s" % String(r["nome_mes"]), "Mês %d" % int(r["mes"]), "relatorio")
	var renda := float(r["renda"])

	var fluxo := Cartao.new()
	fluxo.por(Kit.secao("Entrou e saiu"))
	fluxo.por(Kit.linha_valor("Renda", Economia.reais(renda), Tema.VERDE))
	fluxo.por(Kit.linha_valor("Custos fixos", Economia.reais(-float(r["custos_fixos"]))))
	fluxo.por(Kit.linha_valor("Outros gastos", Economia.reais(-float(r["consumo"]))))
	var perdas := float(r["golpes"]) + float(r["apostado"]) - float(r["ganho_apostas"])
	if absf(perdas) >= 0.01:
		fluxo.por(Kit.linha_valor("Golpes e apostas", Economia.reais(-perdas),
				Tema.VERMELHO if perdas > 0.0 else Tema.VERDE))
	if float(r["juros"]) >= 0.01:
		fluxo.por(Kit.linha_valor("Juros e multas", Economia.reais(-float(r["juros"])), Tema.VERMELHO))
	if float(r["impostos_diretos"]) >= 0.01:
		fluxo.por(Kit.linha_valor("INSS e MEI", Economia.reais(-float(r["impostos_diretos"]))))
	if float(r["rendimentos"]) >= 0.01:
		fluxo.por(Kit.linha_valor("Rendimento da reserva", Economia.reais(float(r["rendimentos"])), Tema.VERDE))
	m.corpo.add_child(fluxo)

	var situacao := Cartao.new()
	situacao.por(Kit.secao("Como você terminou o mês"))
	situacao.por(Kit.linha_valor("Saldo na conta", Economia.reais(float(r["saldo"])),
			Tema.VERMELHO if float(r["saldo"]) < 0.0 else Tema.TINTA))
	situacao.por(Kit.linha_valor("Reserva", "%s (%s meses)" % [
			Economia.reais(float(r["reserva"])), Kit.decimal(float(r["meses_reserva"]))], Tema.AZUL))
	situacao.por(Kit.linha_valor("Dívida ativa", Economia.reais(float(r["divida"])),
			Tema.VERMELHO if float(r["divida"]) >= 1.0 else Tema.VERDE))
	var medio := float(r["estresse_medio"])
	situacao.por(Kit.linha_valor("Estresse médio", "%d · %s" % [int(round(medio)),
			ModeloEstresse.faixa(medio)], Tema.cor_estresse(medio)))
	m.corpo.add_child(situacao)

	var imposto := float(r["impostos"])
	if imposto >= 0.01:
		var parte := imposto / maxf(renda, 1.0)
		m.texto("Imposto embutido no que você consumiu: %s, o equivalente a %s da sua renda do mês." % [
				Economia.reais(imposto), Economia.porcento(parte, 0)], "pequeno", Tema.TINTA_2)

	if String(r.get("dica", "")) != "":
		m.corpo.add_child(fala_do_guara(String(r["dica"])))
	m.botao("Seguir em frente")
	return m


## Balão com uma fala do Guará, o mentor do jogo.
static func fala_do_guara(texto: String) -> Cartao:
	var c := Cartao.new(Tema.GUARA_CLARO, 22, Color.TRANSPARENT)
	var linha := Kit.hbox(16)
	var logo := TextureRect.new()
	logo.texture = load("res://recursos/logo/guara.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(72, 72)
	logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha.add_child(logo)
	var textos := Kit.vbox(2)
	textos.add_child(Kit.rotulo("GUARÁ", "secao", Tema.GUARA_ESCURO, false))
	textos.add_child(Kit.rotulo(texto, "pequeno"))
	linha.add_child(textos)
	c.por(linha)
	return c


## Tela de fim de partida. [param acoes] recebe as chamadas dos botões:
## {"continuar": Callable, "de_novo": Callable, "titulo": Callable}.
static func fim(sim: Simulacao, resultado: String, acoes: Dictionary) -> ModalBase:
	var m := ModalBase.new()
	m.dispensavel = false
	var vitoria := resultado == "vitoria"
	match resultado:
		"vitoria":
			m.cabecalho("Reserva completa!", "Meta alcançada", "trofeu", Tema.VERDE, Tema.VERDE_CLARO)
			m.texto("Você juntou seis meses do custo de vida e está sem dívida ativa. Daqui para a frente, um imprevisto é só um imprevisto, e não o começo de uma dívida.")
		"esgotamento":
			m.cabecalho("Esgotamento", "Fim da partida", "vida", Tema.VERMELHO, Tema.VERMELHO_CLARO)
			m.texto("O estresse ficou no limite por dias seguidos e o corpo parou antes do bolso. Dívida, cansaço e pressão das redes cobram a mesma conta: a saúde emocional.")
		_:
			m.cabecalho("Falência técnica", "Fim da partida", "alerta", Tema.VERMELHO, Tema.VERMELHO_CLARO)
			if sim.atrasos_graves >= Economia.ATRASOS_GRAVES_FALENCIA:
				m.texto("Três contas essenciais ficaram mais de um mês sem pagamento. Sem renda para cobrir o básico, não há como seguir.")
			else:
				m.texto("Suas dívidas passaram do que a sua renda consegue pagar: só os juros já consomem boa parte do mês. No jogo dá para recomeçar. Na vida real, o caminho é renegociar antes de chegar aqui.")

	var dias := int(sim.estat["dias"])
	var numeros := Cartao.new()
	numeros.por(Kit.secao("A sua partida"))
	numeros.por(Kit.linha_valor("Tempo de jogo", "%d meses e %s" % [
			dias / Economia.DIAS_MES, Kit.dias(dias % Economia.DIAS_MES)]))
	numeros.por(Kit.linha_valor("Patrimônio líquido", Economia.reais(sim.patrimonio()),
			Tema.VERMELHO if sim.patrimonio() < 0.0 else Tema.VERDE))
	numeros.por(Kit.linha_valor("Vacinas cognitivas", "%d de %d" % [
			sim.vacinas.size(), Catalogo.vacinas().size()]))
	numeros.por(Kit.linha_valor("Golpes evitados / sofridos", "%d / %d" % [
			int(sim.estat["golpes_evitados"]), int(sim.estat["golpes_sofridos"])]))
	if float(sim.estat["apostado"]) > 0.0:
		numeros.por(Kit.linha_valor("Apostas: colocou / recebeu", "%s / %s" % [
				Economia.reais(float(sim.estat["apostado"]), false),
				Economia.reais(float(sim.estat["ganho_apostas"]), false)], Tema.VERMELHO))
	numeros.por(Kit.linha_valor("Juros pagos", Economia.reais(float(sim.estat["juros"])),
			Tema.VERMELHO if float(sim.estat["juros"]) >= 1.0 else Tema.TINTA))
	numeros.por(Kit.linha_valor("Rendimento da reserva", Economia.reais(float(sim.estat["rendimentos"])), Tema.VERDE))
	numeros.por(Kit.divisor())
	numeros.por(Kit.linha_valor("Pontuação", str(sim.pontuacao()), Tema.GUARA_ESCURO))
	m.corpo.add_child(numeros)

	if vitoria:
		m.botao("Continuar jogando", "BotaoPrimario", acoes.get("continuar", Callable()))
		m.botao("Nova partida", "BotaoNeutro", acoes.get("de_novo", Callable()))
	else:
		m.corpo.add_child(fala_do_guara("Errar aqui não custa nada, e é para isso que o jogo existe. O que você faria diferente no mês em que as coisas começaram a apertar?"))
		m.botao("Tentar de novo", "BotaoPrimario", acoes.get("de_novo", Callable()))
	m.botao("Tela inicial", "BotaoNeutro", acoes.get("titulo", Callable()))
	return m


## Menu de pausa. [param acoes]: {"como_jogar", "vacinas", "sair"}.
static func menu(acoes: Dictionary) -> ModalBase:
	var m := ModalBase.new()
	m.cabecalho("Jogo pausado", "", "pausa")
	m.botao("Continuar", "BotaoPrimario")
	m.botao("Como jogar", "BotaoNeutro", acoes.get("como_jogar", Callable()))
	m.botao("Vacinas cognitivas", "BotaoNeutro", acoes.get("vacinas", Callable()))
	var vibracao := bool(Database.config("vibracao", true))
	var alternar := m.botao("Vibração: %s" % ("ligada" if vibracao else "desligada"), "BotaoNeutro",
			Callable(), false)
	alternar.pressed.connect(func() -> void:
		var nova := not bool(Database.config("vibracao", true))
		Database.definir_config("vibracao", nova)
		alternar.text = "Vibração: %s" % ("ligada" if nova else "desligada")
		if nova:
			Input.vibrate_handheld(60))
	m.botao("Sair para a tela inicial", "BotaoTexto", acoes.get("sair", Callable()))
	return m
