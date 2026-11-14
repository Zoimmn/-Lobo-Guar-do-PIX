class_name ModalEvento
extends ModalBase
## Modal de uma notificação: mostra a mensagem, as escolhas e, depois da
## decisão, o que aconteceu e a vacina cognitiva correspondente.
##
## Eventos com relógio contam o tempo de verdade: quando ele acaba, vale a
## escolha padrão do evento. É a mecânica de "escolha rápida" do FOMO.

const ICONE_CANAL := {
	"Mensagem": "mensagem", "SMS": "mensagem", "Ligação": "telefone", "Rede social": "pessoa",
	"App do banco": "banco", "Notificação": "sino", "Vida real": "alerta", "Trabalho": "trabalho",
}

var _pendente: Dictionary = {}
var _evento: Dictionary = {}
var _tempo_total: float = 0.0
var _restante: float = 0.0
var _barra_tempo: BarraValor = null
var _rotulo_tempo: Label = null
var _aberto_em: int = 0
var _respondido: bool = false


## Prepara o modal para [param pendente]. Devolve false se a notificação já
## não existe (por exemplo, expirou enquanto esperava na fila).
func configurar(pendente: Dictionary) -> bool:
	var sim := GameManager.sim
	if sim == null:
		return false
	var uid := int(pendente.get("uid", -1))
	var atual := {}
	for p: Variant in sim.pendentes:
		if int(p["uid"]) == uid:
			atual = p
	if atual.is_empty():
		return false
	_pendente = atual
	_evento = sim.evento_de(atual)
	_tempo_total = sim.tempo_evento(_evento)
	_restante = _tempo_total
	dispensavel = not bool(atual.get("urgente", false))
	_montar_pergunta()
	return true


func abrir(camada: Node) -> void:
	super.abrir(camada)
	_aberto_em = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if _respondido or _tempo_total <= 0.0:
		return
	_restante -= delta
	if _barra_tempo != null:
		var fracao := clampf(_restante / _tempo_total, 0.0, 1.0)
		_barra_tempo.valor = fracao
		_barra_tempo.cor = Tema.VERMELHO if fracao < 0.3 else Tema.AMBAR
		_rotulo_tempo.text = "%d s" % int(ceil(maxf(_restante, 0.0)))
	if _restante <= 0.0:
		_responder(String(_evento.get("padrao", "")), true)


func _montar_pergunta() -> void:
	var sim := GameManager.sim
	var canal := String(_evento.get("canal", "Mensagem"))
	var linha := Kit.hbox(16)
	linha.add_child(Kit.icone_em_circulo(String(ICONE_CANAL.get(canal, "mensagem")),
			Tema.GUARA_ESCURO, Tema.GUARA_CLARO))
	var quem := Kit.vbox(0)
	quem.add_child(Kit.secao(canal))
	quem.add_child(Kit.rotulo(String(_evento.get("remetente", "")), "forte"))
	quem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(quem)
	corpo.add_child(linha)

	if _tempo_total > 0.0:
		var relogio := Kit.hbox(12)
		relogio.add_child(Kit.icone("relogio", 34, Tema.AMBAR))
		_barra_tempo = BarraValor.new(14, 1.0, Tema.AMBAR)
		_barra_tempo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		relogio.add_child(_barra_tempo)
		_rotulo_tempo = Kit.rotulo("%d s" % int(ceil(_tempo_total)), "pequeno_forte", Tema.AMBAR, false)
		_rotulo_tempo.custom_minimum_size = Vector2(64, 0)
		_rotulo_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		relogio.add_child(_rotulo_tempo)
		corpo.add_child(relogio)

	var mensagem := Cartao.new(Tema.SUPERFICIE, 26)
	mensagem.por(Kit.rotulo(String(_evento.get("titulo", "")), "subtitulo"))
	mensagem.por(Kit.rotulo(sim.texto_evento(_evento), "corpo"))
	corpo.add_child(mensagem)

	# Quem já aprendeu a vacina deste evento reconhece o padrão.
	var vacina_id := String(_evento.get("vacina", ""))
	if vacina_id != "" and sim.vacinas.has(vacina_id):
		var dica := Kit.hbox(10)
		dica.add_child(Kit.icone("escudo", 34, Tema.VERDE))
		dica.add_child(Kit.rotulo("Você já viu este padrão: %s." % String(Catalogo.vacina(vacina_id).get("nome", "")),
				"pequeno_forte", Tema.VERDE))
		corpo.add_child(dica)

	for escolha: Variant in _evento.get("escolhas", []):
		var motivo := sim.motivo_indisponivel(escolha)
		var rotulo_escolha := String(escolha["texto"])
		if motivo != "":
			rotulo_escolha += "\n(%s)" % motivo
		var b := Kit.botao(rotulo_escolha, "BotaoNeutro")
		b.disabled = motivo != ""
		var id := String(escolha["id"])
		b.pressed.connect(func() -> void: _responder(id, false))
		rodape.add_child(b)
	if dispensavel:
		rodape.add_child(Kit.botao("Decidir depois", "BotaoTexto", fechar))


func _responder(escolha_id: String, por_tempo: bool) -> void:
	if _respondido:
		return
	_respondido = true
	var tempo_ms := -1 if por_tempo else Time.get_ticks_msec() - _aberto_em
	var resultado := GameManager.responder(int(_pendente["uid"]), escolha_id, tempo_ms, por_tempo)
	if resultado.is_empty():
		fechar()
		return
	_montar_resultado(resultado)


func _montar_resultado(r: Dictionary) -> void:
	Kit.limpar(corpo)
	Kit.limpar(rodape)
	dispensavel = true
	var tipo := String(r.get("tipo", "neutra"))
	if bool(r.get("por_tempo", false)):
		cabecalho("O tempo acabou", String(r.get("titulo", "")), "relogio", Tema.AMBAR, Tema.AMBAR_CLARO)
	else:
		match tipo:
			"golpe":
				cabecalho("Era uma armadilha", String(r.get("titulo", "")), "alerta", Tema.VERMELHO, Tema.VERMELHO_CLARO)
			"segura":
				cabecalho("Boa decisão", String(r.get("titulo", "")), "check", Tema.VERDE, Tema.VERDE_CLARO)
			"arriscada":
				cabecalho("Decisão de risco", String(r.get("titulo", "")), "raio", Tema.AMBAR, Tema.AMBAR_CLARO)
			_:
				cabecalho("Feito", String(r.get("titulo", "")), "check", Tema.AZUL, Tema.AZUL_CLARO)
	if String(r.get("texto", "")) != "":
		texto(String(r["texto"]))

	var deltas: Dictionary = r.get("deltas", {})
	var efeitos := HFlowContainer.new()
	efeitos.add_theme_constant_override("h_separation", 10)
	efeitos.add_theme_constant_override("v_separation", 10)
	_etiqueta_delta(efeitos, "Conta", float(deltas.get("saldo", 0.0)), true, true)
	_etiqueta_delta(efeitos, "Reserva", float(deltas.get("reserva", 0.0)), true, true)
	_etiqueta_delta(efeitos, "Dívidas", float(deltas.get("devido", 0.0)), false, true)
	_etiqueta_delta(efeitos, "Estresse", float(deltas.get("estresse", 0.0)), false, false)
	if efeitos.get_child_count() > 0:
		corpo.add_child(efeitos)
	else:
		efeitos.free()

	var vacina: Dictionary = r.get("vacina", {})
	if not vacina.is_empty():
		corpo.add_child(Modais.cartao_vacina(vacina, bool(vacina.get("nova", false))))
	botao("Continuar")


## Etiqueta de consequência. [param mais_e_bom] diz se aumento é boa notícia.
func _etiqueta_delta(pai: Control, nome: String, delta: float, mais_e_bom: bool, em_reais: bool) -> void:
	var limite := 0.005 if em_reais else 0.5
	if absf(delta) < limite:
		return
	var bom := (delta > 0.0) == mais_e_bom
	var valor_texto: String
	if em_reais:
		valor_texto = ("+" if delta > 0.0 else "") + Economia.reais(delta)
	else:
		valor_texto = "%+d" % int(round(delta))
	var cores := Tema.cores_tipo("bom" if bom else "ruim")
	pai.add_child(Kit.etiqueta("%s %s" % [nome, valor_texto], cores[0], cores[1], "pequeno_forte"))
