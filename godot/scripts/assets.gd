class_name Assets
extends RefCounted
## 差し替えできる画像(背景、キャラクター、魔物、床や壁、アイコン、ロゴ)とフォント。
##
## 置き場所(上にあるものが優先):
##   1. 実行ファイルと同じフォルダの assets/        例: Deploy/windows/assets/
##   2. user://assets/                              Windows: %APPDATA%\Godot\app_userdata\Urbs Labyrinthi\assets\
##   3. res://override/                             エディタで開発するとき(Godot が取り込む)
## ファイル名は「キー.png」(webp、jpg も可)。無ければ、コードで描いた元の絵になる。
## ゲーム中に F6 で、置いた画像を読み込み直せる。キーの一覧と大きさは godot/assets/OVERRIDE.md。

const EXTS := ["png", "webp", "jpg", "jpeg"]

static var _cache := {}
static var version := 0                      # clear() のたびに増える。描く側が、絵を取り直す目印にする
static var _font_cache: Variant = false     # false: 未確認 / null: 無い / Font

static func search_dirs() -> Array:
	var dirs: Array = []
	var exe := OS.get_executable_path()
	if exe != "":
		dirs.append(exe.get_base_dir().path_join("assets"))
	dirs.append(ProjectSettings.globalize_path("user://assets"))
	return dirs

static func clear() -> void:
	_cache.clear()
	_sheet_cache.clear()
	_font_cache = false
	version += 1

## キーに合う画像を探す。無ければ null
static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for d in search_dirs():
		for e in EXTS:
			var path: String = String(d).path_join("%s.%s" % [key, e])
			if FileAccess.file_exists(path):
				var img := Image.load_from_file(path)
				if img != null and not img.is_empty():
					img.generate_mipmaps()          # 小さく描くときに、ざらつかないように
					tex = ImageTexture.create_from_image(img)
					print("[urbs] 差し替え画像を読み込んだ: ", path)
					break
		if tex != null:
			break
	if tex == null:
		for e in EXTS:
			var rp := "res://override/%s.%s" % [key, e]
			if ResourceLoader.exists(rp):
				tex = load(rp) as Texture2D
				break
	_cache[key] = tex
	return tex

## 候補のキーを順に試す
static func first(keys: Array) -> Texture2D:
	for k in keys:
		var t := texture(String(k))
		if t != null:
			return t
	return null

static func background(style: String, asset_key: String = "") -> Texture2D:
	var keys: Array = []
	if asset_key != "":
		keys.append(asset_key)
	keys.append("bg_" + style)
	return first(keys)

## クラス → スプライトシートの種類(男女 × WARRIOR / CLERIC / FIGHTER / THIEF / MAGE)
const SHEET_TYPE := {"fighter": "WARRIOR", "cleric": "CLERIC", "rogue": "THIEF", "wizard": "MAGE", "barbarian": "FIGHTER", "ranger": "FIGHTER"}
const SHEET_FRAMES := 12                      # 下向き3、左向き3、右向き3、上向き3 を、横一列に

static var _sheet_cache := {}

## スプライトシート(12コマを横一列)。builtin が true なら、ゲームに同梱の絵も探す。最近傍で描くので、ミップマップは作らない
static func sheet(key: String, builtin: bool = true) -> Texture2D:
	var ck := "%s|%s" % [key, builtin]
	if _sheet_cache.has(ck):
		return _sheet_cache[ck]
	var tex: Texture2D = null
	for d in search_dirs():
		for e in EXTS:
			var path: String = String(d).path_join("%s.%s" % [key, e])
			if FileAccess.file_exists(path):
				var img := Image.load_from_file(path)
				if img != null and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
					print("[urbs] 差し替え画像を読み込んだ: ", path)
					break
		if tex != null:
			break
	if tex == null:
		var dirs: Array = ["res://override"]
		if builtin:
			dirs.append("res://assets/sprites")
		for dd in dirs:
			for e in EXTS:
				var rp := "%s/%s.%s" % [dd, key, e]
				if ResourceLoader.exists(rp):
					tex = load(rp) as Texture2D
					break
			if tex != null:
				break
	_sheet_cache[ck] = tex
	return tex

## 仲間の見た目。{tex, sheet}。順番は、差し替えのシート → 差し替えの1枚絵 → 同梱のシート
static func hero_visual(char_name: String, cls: String, race: String, look: String) -> Dictionary:
	var keys := ["sheet_" + char_name, "sheet_%s_%s" % [cls, look], "sheet_%s_%s" % [look, String(SHEET_TYPE.get(cls, "WARRIOR"))]]
	for k in keys:
		var t := sheet(String(k), false)
		if t != null:
			return {"tex": t, "sheet": true}
	var one := hero_texture(char_name, cls, race)
	if one != null:
		return {"tex": one, "sheet": false}
	var b := sheet(String(keys[2]), true)
	if b != null:
		return {"tex": b, "sheet": true}
	return {"tex": null, "sheet": false}

## 魔物の見た目。{tex, sheet}。esheet_<index> → esheet_type_<種別> → 1枚絵(enemy_*)の順
static func enemy_visual(index: String, type: String) -> Dictionary:
	for k in ["esheet_" + index, "esheet_type_" + type]:
		var t := sheet(String(k), true)
		if t != null:
			return {"tex": t, "sheet": true}
	var one := enemy_texture(index, type)
	if one != null:
		return {"tex": one, "sheet": false}
	return {"tex": null, "sheet": false}

## 向きから、シートの向きの番号(0 下、1 左、2 右、3 上)
static func sheet_dir(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 1 if v.x < 0.0 else 2
	return 0 if v.y >= 0.0 else 3

## 歩きの3コマを、0、1、2、1 の順に回す。止まっているときは、真ん中(1)
static func sheet_frame(dir: int, walk_t: float, moving: bool) -> int:
	var step := 1
	if moving:
		step = [0, 1, 2, 1][int(walk_t) % 4]
	return dir * 3 + step

## シートの一コマを描く。feet は、足もとの y。size は、1コマを描く大きさ
static func draw_sheet_frame(ci: CanvasItem, tex: Texture2D, frame: int, size: float, feet_y: float, tint: Color = Color.WHITE) -> void:
	var cw := float(tex.get_width()) / SHEET_FRAMES
	var ch := float(tex.get_height())
	ci.draw_texture_rect_region(tex, Rect2(-size / 2.0, feet_y - size, size, size), Rect2(frame * cw, 0.0, cw, ch), tint)

## 仲間の絵: hero_<名前> → hero_<クラスid>_<種族id> → hero_<クラスid>
static func hero_texture(char_name: String, cls: String, race: String = "") -> Texture2D:
	return first(["hero_" + char_name, "hero_%s_%s" % [cls, race], "hero_" + cls])

## 魔物の絵: enemy_<SRDのindex> → enemy_<種別>
static func enemy_texture(index: String, type: String) -> Texture2D:
	return first(["enemy_" + index, "enemy_type_" + type])

static func font() -> Font:
	if typeof(_font_cache) == TYPE_BOOL:
		_font_cache = null
		for d in search_dirs():
			for e in ["ttf", "otf", "woff2", "woff"]:
				var path: String = String(d).path_join("font.%s" % e)
				if FileAccess.file_exists(path):
					var f := FontFile.new()
					f.load_dynamic_font(path)
					_font_cache = f
					break
			if _font_cache != null:
				break
	return _font_cache as Font

## 画面いっぱいに、縦横比を保って覆うように描く(はみ出す分は切る)
static func draw_cover(ci: CanvasItem, tex: Texture2D, dst: Rect2, modulate: Color = Color.WHITE) -> void:
	var ts := tex.get_size()
	var k := maxf(dst.size.x / ts.x, dst.size.y / ts.y)
	var src_size := dst.size / k
	var src := Rect2((ts - src_size) / 2.0, src_size)
	ci.draw_texture_rect_region(tex, dst, src, modulate)
