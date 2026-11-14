class_name Cartao
extends PanelContainer
## Cartão: painel arredondado com uma coluna de conteúdo em [member corpo].

var corpo: VBoxContainer


func _init(cor: Color = Tema.SUPERFICIE, margem: int = 26, borda: Color = Tema.LINHA,
		raio: int = Tema.RAIO, separacao: int = 14) -> void:
	var largura_borda := 2 if borda.a > 0.0 else 0
	add_theme_stylebox_override("panel", Tema.caixa(cor, raio, borda, largura_borda, margem, margem))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", separacao)
	add_child(corpo)


## Acrescenta um nó ao corpo e o devolve.
func por(no: Control) -> Control:
	corpo.add_child(no)
	return no
