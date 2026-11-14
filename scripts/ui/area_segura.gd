class_name AreaSegura
extends RefCounted
## Margens da área segura da tela (entalhe da câmera, barra de gestos),
## convertidas para as unidades do viewport do jogo.


## Devolve {left, top, right, bottom} em unidades do viewport de [param no].
static func margens(no: Control) -> Dictionary:
	var m := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if not no.is_inside_tree():
		return m
	var janela := Vector2(DisplayServer.window_get_size())
	var segura := Rect2(DisplayServer.get_display_safe_area())
	var visivel := no.get_viewport().get_visible_rect().size
	if janela.x <= 0.0 or janela.y <= 0.0 or segura.size.x <= 0.0 or segura.size.y <= 0.0:
		return m
	var escala_x := visivel.x / janela.x
	var escala_y := visivel.y / janela.y
	m["left"] = int(maxf(segura.position.x, 0.0) * escala_x)
	m["top"] = int(maxf(segura.position.y, 0.0) * escala_y)
	m["right"] = int(maxf(janela.x - segura.end.x, 0.0) * escala_x)
	m["bottom"] = int(maxf(janela.y - segura.end.y, 0.0) * escala_y)
	return m


## Aplica as margens seguras a um MarginContainer, somadas a [param extra].
static func aplicar(container: MarginContainer, extra: int = 0) -> void:
	var m := margens(container)
	for lado: String in m.keys():
		container.add_theme_constant_override("margin_" + lado, int(m[lado]) + extra)
