class_name BarraValor
extends Control
## Barra de progresso arredondada, com cor livre.

var valor: float = 0.0:
	set(novo):
		valor = clampf(novo, 0.0, 1.0)
		queue_redraw()

var cor: Color = Tema.GUARA:
	set(nova):
		cor = nova
		queue_redraw()

var cor_fundo: Color = Tema.LINHA:
	set(nova):
		cor_fundo = nova
		queue_redraw()


func _init(altura: int = 16, valor_inicial: float = 0.0, cor_inicial: Color = Tema.GUARA,
		fundo: Color = Tema.LINHA) -> void:
	custom_minimum_size = Vector2(0, altura)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	valor = valor_inicial
	cor = cor_inicial
	cor_fundo = fundo


func _draw() -> void:
	var raio := int(size.y / 2.0)
	draw_style_box(Tema.caixa(cor_fundo, raio), Rect2(Vector2.ZERO, size))
	if valor > 0.0:
		var largura := maxf(size.x * valor, size.y)
		draw_style_box(Tema.caixa(cor, raio), Rect2(0, 0, minf(largura, size.x), size.y))
