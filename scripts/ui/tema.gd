class_name Tema
extends RefCounted
## Identidade visual do jogo: paleta, fontes e o Theme aplicado a toda a
## interface. As cores vêm do lobo-guará (pelagem laranja-avermelhada, pernas
## e focinho escuros) sobre um fundo claro, pensado para leitura em celular.

const FUNDO := Color("F4EFE6")
const SUPERFICIE := Color("FFFFFF")
const SUPERFICIE_2 := Color("FBF6EE")
const TINTA := Color("26160F")
const TINTA_2 := Color("6B5A4F")
const TINTA_3 := Color("9C8C80")
const LINHA := Color("E6DCCD")
const GUARA := Color("C4501B")
const GUARA_ESCURO := Color("8E3410")
const GUARA_CLARO := Color("F8E1D2")
const VERDE := Color("1E7F55")
const VERDE_CLARO := Color("DDF0E5")
const VERMELHO := Color("B42318")
const VERMELHO_CLARO := Color("FBE0DC")
const AMBAR := Color("A86A12")
const AMBAR_CLARO := Color("FBEBC8")
const AZUL := Color("1F5F8B")
const AZUL_CLARO := Color("DCEAF4")
const ROXO := Color("5B3E96")
const ROXO_CLARO := Color("E8E0F5")
const BRANCO := Color("FFFFFF")
const CREME := Color("F6E7D8")

const RAIO := 24
const RAIO_BOTAO := 20
const TAMANHO_CORPO := 26

static var _bases: Dictionary = {}
static var _variacoes: Dictionary = {}
static var _tema: Theme = null


## Fonte na família ("nunito" ou "baloo2") e no peso pedidos.
static func fonte(familia: String, peso: int) -> Font:
	var chave := "%s_%d" % [familia, peso]
	if _variacoes.has(chave):
		return _variacoes[chave]
	var variacao := FontVariation.new()
	variacao.base_font = _base(familia)
	variacao.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): peso,
	}
	_variacoes[chave] = variacao
	return variacao


static func _base(familia: String) -> Font:
	if _bases.has(familia):
		return _bases[familia]
	var caminho := "res://recursos/fontes/%s.woff2" % familia
	var base: Font = ThemeDB.fallback_font
	if ResourceLoader.exists(caminho):
		base = load(caminho)
	_bases[familia] = base
	return base


## Caixa de cor sólida com cantos arredondados.
static func caixa(cor: Color, raio: int = RAIO, borda: Color = Color.TRANSPARENT,
		largura_borda: int = 0, margem_h: int = 0, margem_v: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.corner_detail = 6
	if largura_borda > 0:
		sb.set_border_width_all(largura_borda)
		sb.border_color = borda
	sb.content_margin_left = margem_h
	sb.content_margin_right = margem_h
	sb.content_margin_top = margem_v
	sb.content_margin_bottom = margem_v
	sb.anti_aliasing = true
	return sb


## Cor do nível de estresse: verde, âmbar e vermelho conforme a faixa.
static func cor_estresse(estresse: float) -> Color:
	if estresse >= ModeloEstresse.NO_LIMITE:
		return VERMELHO
	if estresse >= ModeloEstresse.ANSIOSO:
		return Color("C8501B")
	if estresse >= ModeloEstresse.TENSO:
		return AMBAR
	if estresse >= 30.0:
		return Color("7A8A2A")
	return VERDE


## Cores (texto, fundo) de um tipo de aviso: "bom", "ruim", "alerta" ou "info".
static func cores_tipo(tipo: String) -> Array[Color]:
	match tipo:
		"bom":
			return [VERDE, VERDE_CLARO]
		"ruim":
			return [VERMELHO, VERMELHO_CLARO]
		"alerta":
			return [AMBAR, AMBAR_CLARO]
	return [AZUL, AZUL_CLARO]


static func aplicar(arvore: SceneTree) -> void:
	arvore.root.theme = tema()


static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = fonte("nunito", 600)
	t.default_font_size = TAMANHO_CORPO

	t.set_color("font_color", "Label", TINTA)
	t.set_constant("line_spacing", "Label", 2)

	_botao(t, "Button", GUARA, GUARA_ESCURO, BRANCO, Color.TRANSPARENT)
	_botao(t, "BotaoPrimario", GUARA, GUARA_ESCURO, BRANCO, Color.TRANSPARENT)
	_botao(t, "BotaoSecundario", SUPERFICIE, GUARA_CLARO, GUARA_ESCURO, GUARA)
	_botao(t, "BotaoSuave", GUARA_CLARO, Color("F1CDB6"), GUARA_ESCURO, Color.TRANSPARENT)
	_botao(t, "BotaoNeutro", SUPERFICIE, SUPERFICIE_2, TINTA, LINHA)
	_botao(t, "BotaoPerigo", VERMELHO, Color("8C1A12"), BRANCO, Color.TRANSPARENT)
	_botao(t, "BotaoVerde", VERDE, Color("155F40"), BRANCO, Color.TRANSPARENT)
	_botao(t, "BotaoEscuro", Color("3A2519"), Color("4D3324"), BRANCO, Color.TRANSPARENT)
	_botao(t, "BotaoTexto", Color.TRANSPARENT, Color(0, 0, 0, 0.06), GUARA_ESCURO, Color.TRANSPARENT)
	# Botões compactos do cabeçalho (velocidade e menu) e das abas.
	_botao(t, "BotaoHud", Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.22), BRANCO, Color.TRANSPARENT, 8, 6, 16)
	_botao(t, "BotaoHudAtivo", GUARA, GUARA_ESCURO, BRANCO, Color.TRANSPARENT, 8, 6, 16)
	_botao(t, "BotaoAba", Color.TRANSPARENT, Color(0, 0, 0, 0.05), TINTA_3, Color.TRANSPARENT, 4, 8, 18)
	_botao(t, "BotaoAbaAtiva", GUARA_CLARO, GUARA_CLARO, GUARA_ESCURO, Color.TRANSPARENT, 4, 8, 18)
	for aba: String in ["BotaoAba", "BotaoAbaAtiva", "BotaoHud", "BotaoHudAtivo"]:
		t.set_font_size("font_size", aba, 19)

	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)

	var trilho := StyleBoxEmpty.new()
	trilho.content_margin_left = 3
	trilho.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", trilho)
	t.set_stylebox("scroll_focus", "VScrollBar", trilho)
	for estado: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(estado, "VScrollBar", caixa(Color(0.15, 0.09, 0.06, 0.22), 3))
	_tema = t
	return t


static func _botao(t: Theme, tipo: String, fundo: Color, pressionado: Color, texto: Color,
		borda: Color, margem_h: int = 26, margem_v: int = 18, raio: int = RAIO_BOTAO) -> void:
	if tipo != "Button":
		t.set_type_variation(tipo, "Button")
	var largura := 2 if borda.a > 0.0 else 0
	var normal := caixa(fundo, raio, borda, largura, margem_h, margem_v)
	var apertado := caixa(pressionado, raio, borda, largura, margem_h, margem_v)
	var inativo := caixa(Color("E9E2D7"), raio, Color.TRANSPARENT, 0, margem_h, margem_v)
	t.set_stylebox("normal", tipo, normal)
	t.set_stylebox("hover", tipo, normal)
	t.set_stylebox("pressed", tipo, apertado)
	t.set_stylebox("hover_pressed", tipo, apertado)
	t.set_stylebox("disabled", tipo, inativo)
	t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
	for nome: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		t.set_color(nome, tipo, texto)
	t.set_color("font_disabled_color", tipo, TINTA_3)
	for nome: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(nome, tipo, texto)
	t.set_color("icon_disabled_color", tipo, TINTA_3)
	t.set_font("font", tipo, fonte("nunito", 800))
	t.set_font_size("font_size", tipo, TAMANHO_CORPO)
	t.set_constant("h_separation", tipo, 12)
