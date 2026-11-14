extends Control
## Cena principal do jogo: cabeçalho com os indicadores (HUD), as cinco abas,
## os avisos rápidos e a fila de janelas modais (eventos, fechamento do mês,
## fim de partida).

const CENA_TITULO := "res://cenas/titulo.tscn"
const ABAS: Array = [
	{"id": "inicio", "nome": "Início", "icone": "inicio", "script": "res://scripts/ui/telas/tela_inicio.gd"},
	{"id": "trabalho", "nome": "Trabalho", "icone": "trabalho", "script": "res://scripts/ui/telas/tela_trabalho.gd"},
	{"id": "banco", "nome": "Banco", "icone": "banco", "script": "res://scripts/ui/telas/tela_banco.gd"},
	{"id": "vida", "nome": "Vida", "icone": "vida", "script": "res://scripts/ui/telas/tela_vida.gd"},
	{"id": "relatorio", "nome": "Relatório", "icone": "relatorio", "script": "res://scripts/ui/telas/tela_relatorio.gd"},
]
const COR_HUD := Color("26160F")
const BRANCO_SUAVE := Color(1, 1, 1, 0.66)
const DURACAO_AVISO := 3.6
const MAX_AVISOS := 2

@onready var _hud: PanelContainer = $Coluna/Hud
@onready var _conteudo: Control = $Coluna/Conteudo
@onready var _barra_abas: PanelContainer = $Coluna/BarraAbas
@onready var _camada_avisos: MarginContainer = $CamadaAvisos
@onready var _camada_modais: Control = $CamadaModais

var _telas: Dictionary = {}
var _botoes_aba: Dictionary = {}
var _aba_atual: String = "inicio"
var _fila: Array[Callable] = []
var _lista_avisos: VBoxContainer
var _faixa_pausa: PanelContainer
var _selo_notificacoes: PanelContainer
var _rotulo_selo: Label

var _rot_mes: Label
var _rot_dia: Label
var _selo_pausa: PanelContainer
var _botoes_velocidade: Array[Button] = []
var _barra_dia: BarraValor
var _rot_saldo: Label
var _rot_reserva: Label
var _barra_reserva: BarraValor
var _rot_divida: Label
var _barra_divida: BarraValor
var _rot_estresse: Label
var _barra_estresse: BarraValor


func _ready() -> void:
	add_to_group("jogo")
	Tema.aplicar(get_tree())
	if not GameManager.tem_partida() and not GameManager.continuar():
		GameManager.nova_partida()
	_montar_hud()
	_montar_abas()
	_montar_faixa_pausa()
	_montar_avisos()
	_mostrar_aba("inicio")
	_atualizar_hud()
	_atualizar_velocidade()
	get_viewport().size_changed.connect(_ao_redimensionar)

	GameManager.estado_mudou.connect(_atualizar_hud)
	GameManager.velocidade_mudou.connect(func(_v: int) -> void: _atualizar_velocidade())
	GameManager.evento_recebido.connect(_ao_receber_evento)
	GameManager.mes_fechado.connect(func(resumo: Dictionary) -> void:
		_enfileirar(func() -> ModalBase: return Modais.fechamento(resumo)))
	GameManager.meta_concluida.connect(func(meta: Dictionary) -> void:
		_mostrar_aviso("Meta concluída: %s" % String(meta["titulo"]), "bom"))
	GameManager.aviso.connect(_mostrar_aviso)
	GameManager.partida_encerrada.connect(func(resultado: String) -> void:
		_enfileirar(func() -> ModalBase: return _modal_fim(resultado)))
	GameManager.vitoria.connect(func() -> void:
		_enfileirar(func() -> ModalBase: return _modal_fim("vitoria")))

	# Ao entrar na cena, abre o que exige atenção imediata.
	var sim := GameManager.sim
	for p: Variant in sim.pendentes:
		if bool(p.get("urgente", false)) or sim.dia_total == 1:
			_ao_receber_evento(p)

	var pasta_tour := _argumento("--tour")
	if pasta_tour != "":
		var tour: Node = (load("res://testes/tour.gd") as GDScript).new()
		add_child(tour)
		tour.call("executar", self, pasta_tour)


func _process(_delta: float) -> void:
	if GameManager.relogio_ativo():
		_barra_dia.valor = GameManager.progresso_dia


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_ao_voltar()


func _unhandled_key_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_ao_voltar()


# ---------------------------------------------------------------------------
# Cabeçalho (HUD)
# ---------------------------------------------------------------------------

func _montar_hud() -> void:
	_estilizar_hud()
	var coluna := Kit.vbox(14)
	_hud.add_child(coluna)

	var topo := Kit.hbox(8)
	var datas := Kit.vbox(0)
	_rot_mes = Kit.rotulo("", "mini", BRANCO_SUAVE, false)
	_rot_dia = Kit.rotulo("", "forte", Tema.BRANCO, false)
	datas.add_child(_rot_mes)
	datas.add_child(_rot_dia)
	topo.add_child(datas)
	_selo_pausa = Kit.etiqueta("PAUSADO", Tema.TINTA, Color("F2C56B"))
	_selo_pausa.visible = false
	topo.add_child(_selo_pausa)
	var rotulos_velocidade: Array = [["pausa", ""], ["play", ""], ["", "2x"], ["", "4x"]]
	for i in rotulos_velocidade.size():
		var b := Button.new()
		b.theme_type_variation = "BotaoHud"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(68, 62)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nome_icone := String(rotulos_velocidade[i][0])
		if nome_icone != "":
			b.icon = Kit.textura(nome_icone)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 30)
		else:
			b.text = String(rotulos_velocidade[i][1])
			b.add_theme_font_size_override("font_size", 23)
		var velocidade := i
		b.pressed.connect(func() -> void: GameManager.definir_velocidade(velocidade))
		_botoes_velocidade.append(b)
		topo.add_child(b)
	var menu := Button.new()
	menu.theme_type_variation = "BotaoHud"
	menu.focus_mode = Control.FOCUS_NONE
	menu.custom_minimum_size = Vector2(56, 62)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.icon = Kit.textura("menu")
	menu.expand_icon = true
	menu.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_theme_constant_override("icon_max_width", 30)
	menu.pressed.connect(_abrir_menu)
	topo.add_child(menu)
	coluna.add_child(topo)

	_barra_dia = BarraValor.new(6, 0.0, Tema.GUARA, Color(1, 1, 1, 0.14))
	coluna.add_child(_barra_dia)

	var conta := Kit.vbox(0)
	conta.add_child(Kit.rotulo("CONTA", "mini", BRANCO_SUAVE, false))
	_rot_saldo = Kit.rotulo("", "numero", Tema.BRANCO, false)
	conta.add_child(_rot_saldo)
	coluna.add_child(conta)

	var indicadores := Kit.hbox(10)
	var reserva := _indicador("RESERVA", "banco")
	_rot_reserva = reserva[1]
	_barra_reserva = reserva[2]
	indicadores.add_child(reserva[0])
	var divida := _indicador("DÍVIDA ATIVA", "banco")
	_rot_divida = divida[1]
	_barra_divida = divida[2]
	indicadores.add_child(divida[0])
	var estresse := _indicador("ESTRESSE", "vida")
	_rot_estresse = estresse[1]
	_barra_estresse = estresse[2]
	indicadores.add_child(estresse[0])
	coluna.add_child(indicadores)
	_atualizar_velocidade()


func _estilizar_hud() -> void:
	var m := AreaSegura.margens(self)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_HUD
	sb.corner_radius_bottom_left = 34
	sb.corner_radius_bottom_right = 34
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.content_margin_left = 24.0 + float(m["left"])
	sb.content_margin_right = 24.0 + float(m["right"])
	sb.content_margin_top = 18.0 + float(m["top"])
	sb.content_margin_bottom = 22.0
	_hud.add_theme_stylebox_override("panel", sb)


## Bloco de indicador do cabeçalho: [painel, rótulo do valor, barra].
## Tocar nele leva à aba indicada.
func _indicador(titulo: String, aba: String) -> Array:
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Tema.caixa(Color(1, 1, 1, 0.09), 18, Color.TRANSPARENT, 0, 16, 12))
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	painel.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
			_mostrar_aba(aba))
	var coluna := Kit.vbox(6)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(Kit.rotulo(titulo, "mini", BRANCO_SUAVE, false))
	var valor := Kit.rotulo("", "pequeno_forte", Tema.BRANCO, false)
	valor.clip_text = true
	coluna.add_child(valor)
	var barra := BarraValor.new(8, 0.0, Tema.BRANCO, Color(1, 1, 1, 0.16))
	coluna.add_child(barra)
	painel.add_child(coluna)
	return [painel, valor, barra]


func _atualizar_hud() -> void:
	var sim := GameManager.sim
	if sim == null:
		return
	_rot_mes.text = "%s · MÊS %d" % [sim.nome_mes().to_upper(), sim.mes()]
	_rot_dia.text = "Dia %d" % sim.dia_do_mes()
	_rot_saldo.text = Economia.reais(sim.saldo)
	_rot_saldo.add_theme_color_override("font_color", Color("FF9B8A") if sim.saldo < 0.0 else Tema.BRANCO)

	_rot_reserva.text = "%s meses" % Kit.decimal(sim.meses_reserva())
	_barra_reserva.valor = sim.reserva / sim.meta_reserva()
	_barra_reserva.cor = Color("7DC4F0")

	var divida := sim.divida_ativa()
	_rot_divida.text = Economia.reais(divida, false)
	_rot_divida.add_theme_color_override("font_color", Color("FF9B8A") if divida >= 1.0 else Tema.BRANCO)
	_barra_divida.valor = sim.razao_divida() / Economia.RAZAO_DIVIDA_FALENCIA
	_barra_divida.cor = Color("FF7A66")

	var estresse := sim.estresse()
	_rot_estresse.text = "%d · %s" % [int(round(estresse)), ModeloEstresse.faixa(estresse)]
	_barra_estresse.valor = estresse / 100.0
	_barra_estresse.cor = Tema.cor_estresse(estresse).lightened(0.35)

	var pendentes := sim.pendentes.size()
	_selo_notificacoes.visible = pendentes > 0
	_rotulo_selo.text = str(pendentes)
	if not GameManager.relogio_ativo():
		_barra_dia.valor = GameManager.progresso_dia


func _atualizar_velocidade() -> void:
	for i in _botoes_velocidade.size():
		_botoes_velocidade[i].theme_type_variation = \
				"BotaoHudAtivo" if i == GameManager.velocidade else "BotaoHud"
	_selo_pausa.visible = GameManager.velocidade == 0
	if _faixa_pausa != null:
		_faixa_pausa.visible = GameManager.velocidade == 0


# ---------------------------------------------------------------------------
# Abas
# ---------------------------------------------------------------------------

func _montar_abas() -> void:
	var m := AreaSegura.margens(self)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.SUPERFICIE
	sb.border_width_top = 2
	sb.border_color = Tema.LINHA
	sb.content_margin_left = 10.0 + float(m["left"])
	sb.content_margin_right = 10.0 + float(m["right"])
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0 + float(m["bottom"])
	_barra_abas.add_theme_stylebox_override("panel", sb)
	var linha := Kit.hbox(6)
	_barra_abas.add_child(linha)
	for aba: Variant in ABAS:
		var id := String(aba["id"])
		var tela: TelaBase = (load(String(aba["script"])) as GDScript).new()
		tela.name = "Tela" + id.capitalize()
		tela.visible = false
		_conteudo.add_child(tela)
		_telas[id] = tela

		var b := Button.new()
		b.text = String(aba["nome"])
		b.theme_type_variation = "BotaoAba"
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Kit.textura(String(aba["icone"]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _mostrar_aba(id))
		linha.add_child(b)
		_botoes_aba[id] = b

	# Selo com o número de notificações sobre a aba Início.
	_selo_notificacoes = PanelContainer.new()
	_selo_notificacoes.add_theme_stylebox_override("panel", Tema.caixa(Tema.VERMELHO, 16, Color.TRANSPARENT, 0, 9, 1))
	_selo_notificacoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo_selo = Kit.rotulo("0", "mini", Tema.BRANCO, false)
	_selo_notificacoes.add_child(_rotulo_selo)
	var botao_inicio: Button = _botoes_aba["inicio"]
	botao_inicio.add_child(_selo_notificacoes)
	_selo_notificacoes.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_selo_notificacoes.position += Vector2(30, 2)
	_selo_notificacoes.visible = false


func _mostrar_aba(id: String) -> void:
	_aba_atual = id
	for chave: Variant in _telas.keys():
		(_telas[chave] as Control).visible = chave == id
		(_botoes_aba[chave] as Button).theme_type_variation = \
				"BotaoAbaAtiva" if chave == id else "BotaoAba"


# ---------------------------------------------------------------------------
# Avisos rápidos
# ---------------------------------------------------------------------------

## Faixa fixa entre o cabeçalho e o conteúdo enquanto o tempo está parado.
## Tocar nela põe o dia para andar.
func _montar_faixa_pausa() -> void:
	_faixa_pausa = PanelContainer.new()
	var sb := Tema.caixa(Color("F2C56B"), 0, Color.TRANSPARENT, 0, 26, 14)
	_faixa_pausa.add_theme_stylebox_override("panel", sb)
	_faixa_pausa.mouse_filter = Control.MOUSE_FILTER_STOP
	var linha := Kit.hbox(12)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(Kit.icone("play", 30, Tema.TINTA))
	linha.add_child(Kit.rotulo("Tempo parado. Toque aqui para o dia andar.", "pequeno_forte", Tema.TINTA))
	_faixa_pausa.add_child(linha)
	_faixa_pausa.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed:
			GameManager.definir_velocidade(1))
	var coluna: VBoxContainer = $Coluna
	coluna.add_child(_faixa_pausa)
	coluna.move_child(_faixa_pausa, _conteudo.get_index())


func _montar_avisos() -> void:
	_lista_avisos = VBoxContainer.new()
	_lista_avisos.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_lista_avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_avisos.add_theme_constant_override("separation", 8)
	_camada_avisos.add_child(_lista_avisos)
	_camada_avisos.add_theme_constant_override("margin_left", 22)
	_camada_avisos.add_theme_constant_override("margin_right", 22)
	_hud.resized.connect(_posicionar_avisos)
	_posicionar_avisos()


func _posicionar_avisos() -> void:
	_camada_avisos.add_theme_constant_override("margin_top", int(_hud.size.y) + 12)


func _mostrar_aviso(texto: String, tipo: String = "info") -> void:
	if texto == "":
		return
	while _lista_avisos.get_child_count() >= MAX_AVISOS:
		var antigo := _lista_avisos.get_child(0)
		_lista_avisos.remove_child(antigo)
		antigo.queue_free()
	var cores := Tema.cores_tipo(tipo)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Tema.caixa(cores[1], 18, cores[0], 2, 18, 12))
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	painel.add_child(Kit.rotulo(texto, "pequeno_forte", cores[0]))
	painel.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed:
			painel.queue_free())
	_lista_avisos.add_child(painel)
	# O tween pertence ao painel: se o aviso for fechado antes, ele some junto.
	var espera := painel.create_tween()
	espera.tween_interval(DURACAO_AVISO)
	espera.tween_property(painel, "modulate:a", 0.0, 0.25)
	espera.tween_callback(painel.queue_free)


# ---------------------------------------------------------------------------
# Modais
# ---------------------------------------------------------------------------

func _modal_aberto() -> bool:
	for filho in _camada_modais.get_children():
		if not filho.is_queued_for_deletion():
			return true
	return false


## Abre um modal imediatamente (chamado pelas telas).
func abrir_modal(modal: ModalBase) -> void:
	modal.fechado.connect(func() -> void: _processar_fila.call_deferred())
	modal.abrir(_camada_modais)


## Abre a notificação tocada na aba Início.
func abrir_evento(pendente: Dictionary) -> void:
	if _modal_aberto():
		return
	var modal := _criar_modal_evento(pendente)
	if modal != null:
		abrir_modal(modal)


func _criar_modal_evento(pendente: Dictionary) -> ModalBase:
	var modal := ModalEvento.new()
	if not modal.configurar(pendente):
		modal.free()
		return null
	return modal


## Põe um modal na fila: eles aparecem um de cada vez, na ordem de chegada.
func _enfileirar(criar: Callable) -> void:
	_fila.append(criar)
	_processar_fila.call_deferred()


func _processar_fila() -> void:
	while not _fila.is_empty() and not _modal_aberto():
		var criar: Callable = _fila.pop_front()
		var modal: ModalBase = criar.call()
		if modal != null:
			abrir_modal(modal)


func _ao_receber_evento(pendente: Dictionary) -> void:
	_enfileirar(func() -> ModalBase: return _criar_modal_evento(pendente))


func _modal_fim(resultado: String) -> ModalBase:
	return Modais.fim(GameManager.sim, resultado, {
		"continuar": Callable(),
		"de_novo": _nova_partida,
		"titulo": _ir_para_o_titulo,
	})


func _abrir_menu() -> void:
	if _modal_aberto():
		return
	abrir_modal(Modais.menu({
		"como_jogar": func() -> void: abrir_modal.call_deferred(Modais.como_jogar()),
		"vacinas": func() -> void: abrir_modal.call_deferred(Modais.vacinas(Database.vacinas_adquiridas())),
		"sair": _ir_para_o_titulo,
	}))


## Botão "voltar" do Android (ou Esc no computador).
func _ao_voltar() -> void:
	var modais := _camada_modais.get_children()
	for i in range(modais.size() - 1, -1, -1):
		if not modais[i].is_queued_for_deletion():
			(modais[i] as ModalBase).tentar_fechar()
			return
	_abrir_menu()


func _nova_partida() -> void:
	GameManager.nova_partida()
	get_tree().reload_current_scene.call_deferred()


func _ir_para_o_titulo() -> void:
	GameManager.sair_para_o_titulo()
	get_tree().change_scene_to_file.call_deferred(CENA_TITULO)


func _ao_redimensionar() -> void:
	_estilizar_hud()
	_posicionar_avisos()


func _argumento(nome: String) -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with(nome):
			var partes := argumento.split("=", true, 1)
			return partes[1] if partes.size() > 1 else "1"
	return ""
