class_name Catalogo
extends RefCounted
## Dados do jogo, lidos uma única vez dos arquivos JSON em res://dados.
##
## Empregos, cursos, bens, lazer, metas, vacinas e eventos ficam fora do
## código para que o conteúdo possa ser ajustado sem programar.

static var _cache: Dictionary = {}
static var _indices: Dictionary = {}


static func _lista(nome: String) -> Array:
	if _cache.has(nome):
		return _cache[nome]
	var caminho := "res://dados/%s.json" % nome
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not (dados is Array):
		push_error("Catálogo inválido ou ausente: " + caminho)
		dados = []
	_cache[nome] = dados
	var indice := {}
	for item: Variant in dados:
		if item is Dictionary and item.has("id"):
			indice[String(item["id"])] = item
	_indices[nome] = indice
	return dados


static func _item(nome: String, id: String) -> Dictionary:
	_lista(nome)
	return _indices[nome].get(id, {})


static func empregos() -> Array:
	return _lista("empregos")


static func emprego(id: String) -> Dictionary:
	return _item("empregos", id)


static func cursos() -> Array:
	return _lista("cursos")


static func curso(id: String) -> Dictionary:
	return _item("cursos", id)


static func bens() -> Array:
	return _lista("bens")


static func bem(id: String) -> Dictionary:
	return _item("bens", id)


static func lazeres() -> Array:
	return _lista("lazer")


static func lazer(id: String) -> Dictionary:
	return _item("lazer", id)


static func metas() -> Array:
	return _lista("metas")


static func vacinas() -> Array:
	return _lista("vacinas")


static func vacina(id: String) -> Dictionary:
	return _item("vacinas", id)


static func eventos() -> Array:
	return _lista("eventos")


static func evento(id: String) -> Dictionary:
	return _item("eventos", id)


## Esvazia o cache (usado pelos testes).
static func recarregar() -> void:
	_cache.clear()
	_indices.clear()
