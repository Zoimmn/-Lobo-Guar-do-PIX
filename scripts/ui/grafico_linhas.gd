class_name GraficoLinhas
extends Control
## Gráfico da partida: patrimônio líquido (eixo da esquerda, em reais) e
## estresse (eixo da direita, de 0 a 100) ao longo dos dias.
##
## Mostra, lado a lado, como as decisões financeiras e a saúde emocional
## caminham juntas.

const MARGEM_ESQUERDA := 118.0
const MARGEM_DIREITA := 56.0
const MARGEM_TOPO := 16.0
const MARGEM_BASE := 44.0
const MAX_PONTOS := 220

var _dados: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(0, 380)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## [param serie]: lista de {dia, patrimonio, estresse}, em ordem de dia.
func definir(serie: Array) -> void:
	_dados = serie
	if _dados.size() > MAX_PONTOS:
		var reduzido: Array = []
		var passo := float(_dados.size() - 1) / float(MAX_PONTOS - 1)
		for i in MAX_PONTOS:
			reduzido.append(_dados[int(round(float(i) * passo))])
		_dados = reduzido
	queue_redraw()


func _draw() -> void:
	var fonte := Tema.fonte("nunito", 700)
	var area := Rect2(MARGEM_ESQUERDA, MARGEM_TOPO,
			size.x - MARGEM_ESQUERDA - MARGEM_DIREITA, size.y - MARGEM_TOPO - MARGEM_BASE)
	if area.size.x <= 10.0 or area.size.y <= 10.0:
		return
	if _dados.size() < 2:
		draw_string(fonte, Vector2(0, size.y / 2.0), "O gráfico aparece depois dos primeiros dias.",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Tema.TINTA_3)
		return

	var minimo := INF
	var maximo := -INF
	for d: Variant in _dados:
		minimo = minf(minimo, float(d["patrimonio"]))
		maximo = maxf(maximo, float(d["patrimonio"]))
	minimo = minf(minimo, 0.0)
	maximo = maxf(maximo, 500.0)
	var folga := (maximo - minimo) * 0.08
	minimo -= folga if minimo < 0.0 else 0.0
	maximo += folga

	# Grade e eixos
	for i in 5:
		var fracao := float(i) / 4.0
		var y := area.position.y + area.size.y * (1.0 - fracao)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Tema.LINHA, 2.0)
		var valor := lerpf(minimo, maximo, fracao)
		draw_string(fonte, Vector2(0, y + 7.0), _reais_curto(valor), HORIZONTAL_ALIGNMENT_RIGHT,
				MARGEM_ESQUERDA - 12.0, 19, Tema.GUARA_ESCURO)
		draw_string(fonte, Vector2(area.end.x + 10.0, y + 7.0), str(int(round(fracao * 100.0))),
				HORIZONTAL_ALIGNMENT_LEFT, MARGEM_DIREITA - 10.0, 19, Tema.ROXO)
	if minimo < 0.0:
		var y_zero := area.position.y + area.size.y * (1.0 - (0.0 - minimo) / (maximo - minimo))
		draw_line(Vector2(area.position.x, y_zero), Vector2(area.end.x, y_zero), Tema.TINTA_3, 2.0)

	var primeiro_dia := int(_dados[0]["dia"])
	var ultimo_dia := int(_dados[_dados.size() - 1]["dia"])
	var intervalo := maxf(float(ultimo_dia - primeiro_dia), 1.0)
	var linha_patrimonio := PackedVector2Array()
	var linha_estresse := PackedVector2Array()
	for d: Variant in _dados:
		var x := area.position.x + area.size.x * float(int(d["dia"]) - primeiro_dia) / intervalo
		var fracao_p := (float(d["patrimonio"]) - minimo) / (maximo - minimo)
		linha_patrimonio.append(Vector2(x, area.position.y + area.size.y * (1.0 - fracao_p)))
		var fracao_e := clampf(float(d["estresse"]) / 100.0, 0.0, 1.0)
		linha_estresse.append(Vector2(x, area.position.y + area.size.y * (1.0 - fracao_e)))
	draw_polyline(linha_estresse, Tema.ROXO, 3.0, true)
	draw_polyline(linha_patrimonio, Tema.GUARA, 5.0, true)

	# Marcas de mês no eixo horizontal
	var total_meses := int(ceil(float(ultimo_dia) / float(Economia.DIAS_MES)))
	var passo_mes := maxi(int(ceil(float(total_meses) / 6.0)), 1)
	var mes := 1
	while mes <= total_meses:
		var dia_do_mes := (mes - 1) * Economia.DIAS_MES + 1
		if dia_do_mes >= primeiro_dia:
			var x_mes := area.position.x + area.size.x * float(dia_do_mes - primeiro_dia) / intervalo
			draw_line(Vector2(x_mes, area.end.y), Vector2(x_mes, area.end.y + 8.0), Tema.TINTA_3, 2.0)
			draw_string(fonte, Vector2(x_mes - 40.0, area.end.y + 32.0), "mês %d" % mes,
					HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Tema.TINTA_2)
		mes += passo_mes


func _reais_curto(valor: float) -> String:
	var sinal := "-" if valor <= -0.5 else ""
	var absoluto := absf(valor)
	if absoluto >= 1000.0:
		return "%sR$ %s mil" % [sinal, Kit.decimal(absoluto / 1000.0)]
	return "%sR$ %d" % [sinal, int(round(absoluto))]
