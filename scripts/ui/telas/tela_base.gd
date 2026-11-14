class_name TelaBase
extends ScrollContainer
## Base das telas (abas) do jogo: uma coluna rolável de cartões.
##
## A tela é reconstruída a partir do estado da simulação sempre que ele muda,
## mas só quando está visível e o jogador não está tocando nela, para que
## nenhum toque se perca no meio de uma atualização.

var conteudo: VBoxContainer
var _suja: bool = true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.add_theme_constant_override("margin_left", 24)
	margem.add_theme_constant_override("margin_right", 24)
	margem.add_theme_constant_override("margin_top", 22)
	margem.add_theme_constant_override("margin_bottom", 32)
	add_child(margem)
	conteudo = VBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 18)
	margem.add_child(conteudo)


func _ready() -> void:
	GameManager.estado_mudou.connect(marcar_suja)
	visibility_changed.connect(marcar_suja)


func _process(_delta: float) -> void:
	if _suja and is_visible_in_tree() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_suja = false
		reconstruir()


func marcar_suja() -> void:
	_suja = true


func reconstruir() -> void:
	if GameManager.sim == null:
		return
	Kit.limpar(conteudo)
	montar(GameManager.sim)


## Cada tela monta aqui os seus cartões.
func montar(_sim: Simulacao) -> void:
	pass


## Pede uma ação ao GameManager e mostra o retorno como aviso.
func acao(metodo: StringName, argumentos: Array = []) -> void:
	var retorno: Variant = GameManager.agir(metodo, argumentos)
	if retorno is Dictionary and retorno.has("msg"):
		GameManager.aviso.emit(String(retorno["msg"]), "bom" if bool(retorno.get("ok", false)) else "alerta")
	marcar_suja()


func abrir_modal(modal: ModalBase) -> void:
	get_tree().call_group("jogo", "abrir_modal", modal)


## Cartão com título de seção já colocado na tela.
func novo_cartao(titulo: String = "", cor: Color = Tema.SUPERFICIE) -> Cartao:
	var c := Cartao.new(cor)
	if titulo != "":
		c.por(Kit.secao(titulo))
	conteudo.add_child(c)
	return c
