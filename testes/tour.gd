extends Node
## Roteiro automático de capturas de tela, para conferir a interface sem
## precisar de um celular. Só é usado no desenvolvimento.
##
## Uso (precisa de tela, real ou virtual):
##   godot --path . --resolution 720x1280 -- --tour=/pasta/de/saida

var _jogo: Control
var _pasta: String
var _contador: int = 0


func executar(jogo: Control, pasta: String) -> void:
	_jogo = jogo
	_pasta = pasta
	DirAccess.make_dir_recursive_absolute(pasta)
	OS.low_processor_usage_mode = false
	GameManager.definir_velocidade(0)
	var sim := GameManager.sim

	await _quadros(12)
	await _foto("evento_boas_vindas")
	_responder_modal("ok")
	await _foto("resultado_com_vacina")
	_fechar_modais()
	await _foto("inicio_primeiro_dia")

	await _avancar(12)
	sim.matricular("atendimento")
	await _aba("inicio", "inicio")
	await _aba("trabalho", "trabalho", true)
	await _aba("banco", "banco", true)
	await _aba("vida", "vida", true)

	# Evento com relógio: golpe da falsa central.
	sim.saldo = maxf(sim.saldo, 420.0)
	sim._criar_pendente(Catalogo.evento("falsa_central"), {})
	await _quadros(40)
	await _foto("evento_com_relogio")
	_responder_modal("transferir")
	await _foto("resultado_golpe")
	_fechar_modais()

	# Oferta de influenciador com o cartão ativo.
	sim.cartao_ativo = true
	sim.limite = maxf(sim.limite, 1500.0)
	sim._criar_pendente(Catalogo.evento("drop_tenis"), {})
	await _quadros(20)
	await _foto("evento_fomo")
	_responder_modal("comprar")
	await _foto("resultado_fomo")
	_fechar_modais()

	# Fechamento do primeiro mês.
	while sim.dia_do_mes() != 1 or sim.mes() < 2:
		await _avancar(1)
	_limpar_avisos()
	_jogo.call("abrir_modal", Modais.fechamento(sim.historico_meses[sim.historico_meses.size() - 1]))
	await _foto("fechamento_do_mes")
	_fechar_modais()

	# Alguns meses de partida com um jogador automático "regular".
	var bot := BotJogador.new("regular", 7)
	for dia in 150:
		if sim.fim:
			break
		bot.decidir(sim)
		bot.agir(sim)
		_jogo.set("_fila", [] as Array[Callable])
		_fechar_modais()
		GameManager.avancar_dia()
	_jogo.set("_fila", [] as Array[Callable])
	_fechar_modais()
	_limpar_avisos()
	await _aba("inicio", "inicio_meses_depois", true)
	await _aba("trabalho", "trabalho_meses_depois", true)
	await _aba("banco", "banco_meses_depois", true)
	await _aba("vida", "vida_meses_depois", true)
	await _aba("relatorio", "relatorio", true)

	_jogo.call("abrir_modal", Modais.como_jogar())
	await _foto("como_jogar")
	_fechar_modais()
	_jogo.call("abrir_modal", Modais.vacinas(sim.vacinas.keys()))
	await _foto("vacinas")
	_fechar_modais()
	_jogo.call("_abrir_menu")
	await _foto("menu")
	_fechar_modais()
	_jogo.call("abrir_modal", Modais.valor("Guardar na reserva", "Saldo na conta: R$ 640,00", 640.0,
			[50.0, 100.0, 200.0, 500.0, 1000.0], "Guardar", func(_v: float) -> void: pass, "reserva"))
	await _foto("escolha_de_valor")
	_fechar_modais()
	_jogo.call("abrir_modal", Modais.fim(sim, "vitoria", {}))
	await _foto("fim_vitoria")
	_fechar_modais()
	_jogo.call("abrir_modal", Modais.fim(sim, "esgotamento", {}))
	await _foto("fim_esgotamento")
	_fechar_modais()
	print("Tour concluído: %d capturas em %s" % [_contador, _pasta])
	get_tree().quit()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await _quadros(8)
	await RenderingServer.frame_post_draw
	_contador += 1
	var caminho := "%s/%02d_%s.png" % [_pasta, _contador, nome]
	get_viewport().get_texture().get_image().save_png(caminho)


func _modais() -> Array:
	var lista: Array = []
	for filho in (_jogo.get("_camada_modais") as Control).get_children():
		if not filho.is_queued_for_deletion():
			lista.append(filho)
	return lista


func _responder_modal(escolha: String) -> void:
	for modal: Variant in _modais():
		if modal is ModalEvento:
			modal.call("_responder", escolha, false)
			return
	push_warning("Tour: não havia modal de evento para responder " + escolha)


func _limpar_avisos() -> void:
	Kit.limpar(_jogo.get("_lista_avisos") as Node)


func _fechar_modais() -> void:
	for modal: Variant in _modais():
		(modal as ModalBase).fechar()


func _aba(id: String, nome: String, rolar: bool = false) -> void:
	_jogo.call("_mostrar_aba", id)
	var tela: ScrollContainer = (_jogo.get("_telas") as Dictionary)[id]
	tela.scroll_vertical = 0
	await _foto(nome)
	if rolar:
		var maximo := int(tela.get_v_scroll_bar().max_value - tela.size.y)
		var posicao := 0
		var parte := 2
		while posicao < maximo and parte <= 4:
			posicao = mini(posicao + int(tela.size.y) - 80, maximo)
			tela.scroll_vertical = posicao
			await _foto("%s_%d" % [nome, parte])
			parte += 1


## Avança dias respondendo às notificações com a opção padrão.
func _avancar(dias: int, limpar_modais: bool = true) -> void:
	var sim := GameManager.sim
	for i in dias:
		for p: Variant in sim.pendentes.duplicate():
			var ev := sim.evento_de(p)
			GameManager.responder(int(p["uid"]), String(ev["padrao"]), -1, true)
		GameManager.avancar_dia()
		if limpar_modais:
			_jogo.set("_fila", [] as Array[Callable])
			_fechar_modais()
	await _quadros(4)
