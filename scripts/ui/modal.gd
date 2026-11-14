class_name ModalBase
extends Control
## Janela modal: uma folha que ocupa a base da tela, sobre um fundo escuro.
##
## O conteúdo vai em [member corpo] (rolável) e os botões em [member rodape]
## (sempre visíveis). Enquanto um modal de jogo está aberto, o relógio da
## simulação fica parado.

signal fechado

const MARGEM_TOPO := 96
const MARGEM_LATERAL := 30

var corpo: VBoxContainer
var rodape: VBoxContainer
## Pode ser fechado tocando fora ou com o botão "voltar" do Android.
var dispensavel: bool = true
## Para o relógio da simulação enquanto está aberto.
var pausa_o_tempo: bool = true

var _fundo: ColorRect
var _painel: PanelContainer
var _rolagem: ScrollContainer
var _aberto: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_fundo = ColorRect.new()
	_fundo.color = Color(0.12, 0.07, 0.04, 0.62)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.gui_input.connect(_ao_tocar_no_fundo)
	add_child(_fundo)

	var area := MarginContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_theme_constant_override("margin_top", MARGEM_TOPO)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)

	_painel = PanelContainer.new()
	_painel.size_flags_vertical = Control.SIZE_SHRINK_END
	area.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 22)
	_painel.add_child(coluna)

	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)

	corpo = VBoxContainer.new()
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 18)
	_rolagem.add_child(corpo)

	rodape = VBoxContainer.new()
	rodape.add_theme_constant_override("separation", 12)
	coluna.add_child(rodape)

	corpo.minimum_size_changed.connect(_ajustar_altura)
	rodape.minimum_size_changed.connect(_ajustar_altura)
	resized.connect(_ajustar_altura)


## Mostra o modal dentro de [param camada].
func abrir(camada: Node) -> void:
	camada.add_child(self)
	_aberto = true
	if pausa_o_tempo:
		GameManager.bloquear_tempo()
	_estilizar_painel()
	_ajustar_altura()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.14)


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	if pausa_o_tempo:
		GameManager.liberar_tempo()
	fechado.emit()
	queue_free()


## Fecha se o modal puder ser dispensado. Devolve se fechou.
func tentar_fechar() -> bool:
	if dispensavel:
		fechar()
		return true
	return false


func _exit_tree() -> void:
	# Segurança: se o modal sair da árvore sem fechar(), devolve o relógio.
	if _aberto and pausa_o_tempo:
		_aberto = false
		GameManager.liberar_tempo()


## Cabeçalho padrão: ícone em círculo, título e, se houver, uma linha acima.
func cabecalho(titulo: String, sobretitulo: String = "", nome_icone: String = "",
		cor: Color = Tema.GUARA, fundo_icone: Color = Tema.GUARA_CLARO) -> void:
	var linha := Kit.hbox(18)
	if nome_icone != "":
		linha.add_child(Kit.icone_em_circulo(nome_icone, cor, fundo_icone))
	var textos := Kit.vbox(0)
	if sobretitulo != "":
		textos.add_child(Kit.secao(sobretitulo))
	textos.add_child(Kit.rotulo(titulo, "subtitulo"))
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(textos)
	corpo.add_child(linha)


func texto(conteudo: String, estilo: String = "corpo", cor: Color = Tema.TINTA) -> Label:
	var r := Kit.rotulo(conteudo, estilo, cor)
	corpo.add_child(r)
	return r


func botao(rotulo_botao: String, variacao: String = "BotaoPrimario",
		acao: Callable = Callable(), fecha: bool = true) -> Button:
	var b := Kit.botao(rotulo_botao, variacao)
	b.pressed.connect(func() -> void:
		if acao.is_valid():
			acao.call()
		if fecha:
			fechar())
	rodape.add_child(b)
	return b


func _estilizar_painel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tema.FUNDO
	sb.corner_radius_top_left = 40
	sb.corner_radius_top_right = 40
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.content_margin_left = MARGEM_LATERAL
	sb.content_margin_right = MARGEM_LATERAL
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30.0 + float(AreaSegura.margens(self)["bottom"])
	_painel.add_theme_stylebox_override("panel", sb)


## A folha tem a altura do conteúdo, até o limite da tela; acima disso, rola.
func _ajustar_altura() -> void:
	if not is_inside_tree():
		return
	var estilo := _painel.get_theme_stylebox("panel")
	var fixo := rodape.get_combined_minimum_size().y + 22.0
	if estilo != null:
		fixo += estilo.content_margin_top + estilo.content_margin_bottom
	var maximo := maxf(size.y - float(MARGEM_TOPO) - fixo, 200.0)
	var desejado := minf(corpo.get_combined_minimum_size().y, maximo)
	if absf(_rolagem.custom_minimum_size.y - desejado) > 0.5:
		_rolagem.custom_minimum_size.y = desejado


func _ao_tocar_no_fundo(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and dispensavel:
		fechar()
