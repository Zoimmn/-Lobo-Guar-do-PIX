class_name Kit
extends RefCounted
## Peças de interface reutilizadas por todas as telas: rótulos, botões,
## ícones, linhas "chave e valor" e etiquetas. Tudo é montado com Control
## Nodes e Containers nativos da Godot, para se ajustar a qualquer tela.

## Estilos de texto: [família, peso, tamanho].
const ESTILOS := {
	"numero": ["baloo2", 800, 62],
	"numero_medio": ["baloo2", 700, 40],
	"titulo": ["baloo2", 700, 38],
	"subtitulo": ["baloo2", 700, 30],
	"secao": ["nunito", 800, 21],
	"corpo": ["nunito", 600, 26],
	"forte": ["nunito", 800, 26],
	"pequeno": ["nunito", 600, 22],
	"pequeno_forte": ["nunito", 800, 22],
	"mini": ["nunito", 700, 19],
}

static var _icones: Dictionary = {}


static func rotulo(texto: String, estilo: String = "corpo", cor: Color = Tema.TINTA,
		quebra: bool = true) -> Label:
	var r := Label.new()
	r.text = texto
	estilizar(r, estilo, cor)
	if quebra:
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


static func estilizar(r: Label, estilo: String, cor: Color = Tema.TINTA) -> void:
	var e: Array = ESTILOS.get(estilo, ESTILOS["corpo"])
	r.add_theme_font_override("font", Tema.fonte(String(e[0]), int(e[1])))
	r.add_theme_font_size_override("font_size", int(e[2]))
	r.add_theme_color_override("font_color", cor)
	if String(e[0]) == "baloo2":
		# A Baloo tem muito espaço vertical: aproxima as linhas.
		r.add_theme_constant_override("line_spacing", -10)


## Título de seção em caixa alta.
static func secao(texto: String) -> Label:
	var r := rotulo(texto.to_upper(), "secao", Tema.TINTA_2, false)
	return r


static func botao(texto: String, variacao: String = "BotaoPrimario",
		acao: Callable = Callable(), nome_icone: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.theme_type_variation = variacao
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 92)
	b.focus_mode = Control.FOCUS_NONE
	if nome_icone != "":
		b.icon = textura(nome_icone)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
	if acao.is_valid():
		b.pressed.connect(acao)
	return b


## Botão pequeno, para ações secundárias dentro de um cartão.
static func botao_pequeno(texto: String, variacao: String = "BotaoSuave",
		acao: Callable = Callable()) -> Button:
	var b := botao(texto, variacao, acao)
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 23)
	return b


static func textura(nome: String) -> Texture2D:
	if _icones.has(nome):
		return _icones[nome]
	var caminho := "res://recursos/icones/%s.svg" % nome
	var t: Texture2D = null
	if ResourceLoader.exists(caminho):
		t = load(caminho)
	_icones[nome] = t
	return t


## Ícone branco tingido com [param cor].
static func icone(nome: String, tamanho: int = 40, cor: Color = Tema.TINTA) -> TextureRect:
	var r := TextureRect.new()
	r.texture = textura(nome)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(tamanho, tamanho)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.modulate = cor
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Ícone dentro de um círculo colorido.
static func icone_em_circulo(nome: String, cor: Color, fundo: Color, diametro: int = 76) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.caixa(fundo, diametro / 2))
	p.custom_minimum_size = Vector2(diametro, diametro)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := icone(nome, int(diametro * 0.54), cor)
	p.add_child(i)
	return p


## Linha com um texto à esquerda e um valor à direita.
static func linha_valor(chave: String, valor: String, cor_valor: Color = Tema.TINTA,
		estilo: String = "corpo", cor_chave: Color = Tema.TINTA_2) -> HBoxContainer:
	var h := HBoxContainer.new()
	var esquerda := rotulo(chave, estilo, cor_chave)
	h.add_child(esquerda)
	var estilo_valor := "forte" if estilo == "corpo" else "pequeno_forte"
	var direita := rotulo(valor, estilo_valor, cor_valor, false)
	direita.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	direita.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(direita)
	return h


## Etiqueta arredondada (pílula).
static func etiqueta(texto: String, cor_texto: Color, cor_fundo: Color, estilo: String = "mini") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.caixa(cor_fundo, 16, Color.TRANSPARENT, 0, 14, 5))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rotulo(texto, estilo, cor_texto, false))
	return p


static func espaco(altura: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, altura)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Ocupa o espaço livre de um HBox ou VBox.
static func mola() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func divisor() -> ColorRect:
	var c := ColorRect.new()
	c.color = Tema.LINHA
	c.custom_minimum_size = Vector2(0, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hbox(separacao: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separacao)
	return h


static func vbox(separacao: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separacao)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


## Remove todos os filhos de um nó.
static func limpar(no: Node) -> void:
	for filho in no.get_children():
		no.remove_child(filho)
		filho.queue_free()


## Número com vírgula decimal: 1.5 -> "1,5".
static func decimal(valor: float, casas: int = 1) -> String:
	return (("%." + str(casas) + "f") % valor).replace(".", ",")


static func dias(quantidade: int) -> String:
	return "1 dia" if quantidade == 1 else "%d dias" % quantidade
