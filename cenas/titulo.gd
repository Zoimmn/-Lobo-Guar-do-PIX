extends Control
## Tela de título: continuar, nova partida, como jogar e vacinas.

const CENA_JOGO := "res://cenas/jogo.tscn"

@onready var _area: MarginContainer = $AreaSegura
@onready var _coluna: VBoxContainer = $AreaSegura/Coluna
@onready var _camada_modais: Control = $CamadaModais


func _ready() -> void:
	Tema.aplicar(get_tree())
	AreaSegura.aplicar(_area, 36)
	get_viewport().size_changed.connect(func() -> void: AreaSegura.aplicar(_area, 36))
	_montar()
	# Apoio ao desenvolvimento: capturas automáticas de tela pela linha de comando.
	if _argumento("--captura") != "":
		await _capturar(_argumento("--captura"))
		get_tree().quit()
	elif _argumento("--tour") != "":
		GameManager.nova_partida(20261114)
		get_tree().change_scene_to_file.call_deferred(CENA_JOGO)


func _capturar(caminho: String) -> void:
	# Sem isto, o modo de economia de energia não redesenha a tela parada.
	OS.low_processor_usage_mode = false
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(caminho)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var modais := _camada_modais.get_children()
		if not modais.is_empty():
			(modais.back() as ModalBase).tentar_fechar()
		else:
			get_tree().quit()


func _montar() -> void:
	Kit.limpar(_coluna)
	_coluna.add_theme_constant_override("separation", 14)
	_coluna.add_child(Kit.mola())

	var logo := TextureRect.new()
	logo.texture = load("res://recursos/logo/guara.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 250)
	_coluna.add_child(logo)

	var nome := Kit.rotulo("Lobo-Guará\ndo PIX", "numero", Tema.TINTA, false)
	nome.add_theme_font_size_override("font_size", 82)
	nome.add_theme_constant_override("line_spacing", -34)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(nome)

	var lema := Kit.rotulo("Sobreviva ao corre do mês.", "subtitulo", Tema.GUARA)
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(lema)
	var descricao := Kit.rotulo("Renda que oscila, PIX, bets, cartão e a pressão das redes: um simulador de decisões financeiras da vida real brasileira.",
			"pequeno", Tema.TINTA_2)
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(descricao)
	_coluna.add_child(Kit.mola())

	if GameManager.tem_partida_salva():
		_coluna.add_child(Kit.botao("Continuar", "BotaoPrimario", _continuar))
		_coluna.add_child(Kit.botao("Nova partida", "BotaoSecundario", _pedir_nova_partida))
	else:
		_coluna.add_child(Kit.botao("Começar", "BotaoPrimario", _nova_partida))
	var linha := Kit.hbox(14)
	var como := Kit.botao("Como jogar", "BotaoNeutro", func() -> void: Modais.como_jogar().abrir(_camada_modais))
	como.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(como)
	var vacinas := Kit.botao("Vacinas", "BotaoNeutro", func() -> void:
		Modais.vacinas(Database.vacinas_adquiridas()).abrir(_camada_modais))
	vacinas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(vacinas)
	_coluna.add_child(linha)

	_coluna.add_child(Kit.espaco(10))
	var rodape := Kit.rotulo("Projeto de pesquisa · Universidade Católica de Santa Catarina\nVersão %s · Dados: %s" % [
			String(ProjectSettings.get_setting("application/config/version", "0.1.0")), Database.mecanismo()],
			"mini", Tema.TINTA_3)
	rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(rodape)


func _continuar() -> void:
	if GameManager.continuar():
		get_tree().change_scene_to_file(CENA_JOGO)
	else:
		_montar()


func _pedir_nova_partida() -> void:
	var modal := Modais.confirmar("Começar de novo?",
			"A partida em andamento será encerrada. As vacinas que você já descobriu continuam na sua coleção.",
			"Começar nova partida", _nova_partida)
	modal.pausa_o_tempo = false
	modal.abrir(_camada_modais)


func _nova_partida() -> void:
	GameManager.nova_partida()
	get_tree().change_scene_to_file(CENA_JOGO)


func _argumento(nome: String) -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with(nome):
			var partes := argumento.split("=", true, 1)
			return partes[1] if partes.size() > 1 else "1"
	return ""
