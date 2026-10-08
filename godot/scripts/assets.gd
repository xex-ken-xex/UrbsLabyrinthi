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
