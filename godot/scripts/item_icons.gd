class_name ItemIcons
extends RefCounted
## アイテムの絵。16列のシート(items_sheet.png、1マス 32×32)から、idで切り出す。
## 差し替え: 実行ファイルのそばの assets/ に items_sheet.png(同じ並び。マスの大きさは、横幅÷16)、
## または 1つだけ item_<id>.png を置く。索引は data/item-icons.json、絵は tools/make-items.py が描く。

const COLS := 16
const FALLBACK := "relic_tools"

static var _index := {}
static var _cache := {}
static var _ver := -1

static func _prepare() -> void:
	if _index.is_empty():
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/item-icons.json"))
		if typeof(j) == TYPE_DICTIONARY:
			_index = j["icons"]
	if _ver != Assets.version:
		_ver = Assets.version
		_cache.clear()

static func has_icon(id: String) -> bool:
	_prepare()
	return _index.has(id) or Assets.texture("item_" + id, false) != null

## id の絵。無ければ、汎用の絵
static func texture(id: String) -> Texture2D:
	_prepare()
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = Assets.texture("item_" + id, false)
	if tex == null:
		var sheet := Assets.texture("items_sheet")
		var key: String = id if _index.has(id) else FALLBACK
		if sheet != null and _index.has(key):
			var n := int(_index[key])
			var cell := float(sheet.get_width()) / COLS
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((n % COLS) * cell, (n / COLS) * cell, cell, cell)
			tex = at
	_cache[id] = tex
	return tex
