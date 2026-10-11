class_name Updater
extends Control
## 起動時の更新。GitHub の最新の Release にある、ゲームの中身(.pck)が、いま動いているものと違えば、
## 受け取って、実行ファイルの隣の .pck を置き換え、ゲームを起動し直す。実行ファイル(エンジン)はそのまま。
##
## - 受け取る .pck は、実行ファイルの隣に UrbsLabyrinthi.pck.new として置き、ハッシュを確かめてから入れ替える
## - Windows では、動いているゲームの .pck は置き換えられない。そこで PowerShell を裏で起動し、
##   ゲームが終わるのを待ってから入れ替えて、起動し直してもらう
## - 書き出したビルドで、実行ファイルの隣の .pck から起動したときだけ動く(エディタやテストでは動かない)
## - `--no-update` を付けると確かめない。`--update-url=<URL>` で latest.json の場所を変えられる(確認用)
## - エンジンの版が違う .pck は使わない。そのときはインストーラーか ZIP で入れ直すよう知らせる
## - 実行ファイルのフォルダに書き込めないときは、知らせるだけにする
##
## latest.json: {"tag": "v6", "godot": "4.7.2", "pck": {"Windows": {"url", "sha256", "size"}, "Linux": {...}}}

signal finished(note: String)

const LATEST_URL := "https://github.com/xex-ken-xex/UrbsLabyrinthi/releases/latest/download/latest.json"
const TIMEOUT := 8.0

var http: HTTPRequest
var label: Label
var bar: ProgressBar
var _latest := {}
var _done := false

## 確かめるべき起動か(書き出したビルドで、実行ファイルの隣に .pck がある)
static func should_check() -> bool:
	if OS.has_feature("editor") or not OS.has_feature("template"):
		return false
	if OS.get_cmdline_user_args().has("--no-update"):
		return false
	return FileAccess.file_exists(base_pck())

static func base_pck() -> String:
	var exe := OS.get_executable_path()
	return exe.get_base_dir().path_join(exe.get_file().get_basename() + ".pck")

static func new_pck() -> String:
	return base_pck() + ".new"

static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]

static func _sha(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

## latest.json から、この OS の .pck を取り出す。読めなければ {}
static func parse_latest(d) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var pk = (d as Dictionary).get("pck")
	if not (pk is Dictionary):
		return {}
	var p = (pk as Dictionary).get(OS.get_name(), {})
	if not (p is Dictionary) or String(p.get("sha256", "")) == "" or String(p.get("url", "")) == "":
		return {}
	return {"tag": String(d.get("tag", "")), "godot": String(d.get("godot", "")), "sha": String(p["sha256"]).to_lower(), "url": String(p["url"])}

## PowerShell の文字列(単引用符)。中の単引用符は2つ重ねる
static func ps_quote(x: String) -> String:
	return "'" + x.replace("'", "''") + "'"

## Windows で、ゲームが終わるのを待って .pck を入れ替え、起動し直す PowerShell の命令
static func windows_script(pid: int, src: String, dst: String, exe: String, user: PackedStringArray) -> String:
	var argl := ""
	if not user.is_empty():
		var parts: Array = [ps_quote("--")]
		for u in user:
			parts.append(ps_quote(u))
		argl = " -ArgumentList " + ",".join(parts)
	var ps := "$ErrorActionPreference='SilentlyContinue'\n"
	ps += "Wait-Process -Id %d -Timeout 30\n" % pid
	ps += "for($i=0;$i -lt 60;$i++){ try { Move-Item -LiteralPath %s -Destination %s -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 250 } }\n" % [ps_quote(src), ps_quote(dst)]
	ps += "Start-Process -FilePath %s%s\n" % [ps_quote(exe), argl]
	return ps

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var v := UIKit.vbox(10)
	cc.add_child(v)
	label = UIKit.label("新しい版を確かめている…", 18, UIKit.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 18)
	bar.show_percentage = false
	bar.visible = false
	v.add_child(bar)
	var skip := UIKit.label("Esc で飛ばす", 14, UIKit.DIM)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(skip)
	http = HTTPRequest.new()
	http.use_threads = true
	http.timeout = TIMEOUT
	http.max_redirects = 10
	add_child(http)
	http.request_completed.connect(_on_latest)
	var url := LATEST_URL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="):
			url = a.substr("--update-url=".length())
	if http.request(url) != OK:
		_finish("更新を確かめられなかった")

func _process(_d: float) -> void:
	if bar.visible and http.get_body_size() > 0:
		bar.max_value = http.get_body_size()
		bar.value = http.get_downloaded_bytes()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not _done:
		get_viewport().set_input_as_handled()
		http.cancel_request()
		DirAccess.remove_absolute(new_pck())
		_finish("更新の確認を飛ばした")

func _on_latest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if _done:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish("更新を確かめられなかった(%d / %d)" % [result, code])
		return
	_latest = parse_latest(JSON.parse_string(body.get_string_from_utf8()))
	if _latest.is_empty():
		_finish("更新の情報が読めなかった")
		return
	var want: String = _latest["sha"]
	if _sha(base_pck()) == want:
		DirAccess.remove_absolute(new_pck())
		_finish("")
		return
	if _latest["godot"] != "" and _latest["godot"] != engine_version():
		_finish("新しい版 %s は、入れ直しが要る(インストーラーか ZIP で入れ直す)" % _latest["tag"])
		return
	if _sha(new_pck()) == want:
		_apply()
		return
	var probe := FileAccess.open(new_pck(), FileAccess.WRITE)
	if probe == null:
		_finish("新しい版 %s がある。ゲームのフォルダに書き込めないので、インストーラーか ZIP で入れ直す" % _latest["tag"])
		return
	probe.close()
	label.text = "新しい版 %s を受け取っている…" % _latest["tag"]
	bar.visible = true
	http.request_completed.disconnect(_on_latest)
	http.request_completed.connect(_on_pck)
	http.timeout = 0.0
	http.download_file = new_pck()
	if http.request(String(_latest["url"])) != OK:
		_finish("新しい版を受け取れなかった")

func _on_pck(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if _done:
		return
	bar.visible = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(new_pck())
		_finish("新しい版を受け取れなかった(%d / %d)" % [result, code])
		return
	if _sha(new_pck()) != String(_latest["sha"]):
		DirAccess.remove_absolute(new_pck())
		_finish("受け取った版が壊れていたので、使わなかった")
		return
	_apply()

## .pck.new を .pck に入れ替えて、起動し直す
func _apply() -> void:
	_done = true
	label.text = "新しい版 %s に入れ替えて、起動し直す…" % _latest.get("tag", "")
	var exe := OS.get_executable_path()
	var user := OS.get_cmdline_user_args()
	if OS.get_name() == "Windows":
		var ps := windows_script(OS.get_process_id(), new_pck().replace("/", "\\"), base_pck().replace("/", "\\"), exe.replace("/", "\\"), user)
		var enc := Marshalls.raw_to_base64(ps.to_utf16_buffer())
		var pid := OS.create_process("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-EncodedCommand", enc])
		if pid <= 0:
			_done = false
			_finish("入れ替えの手伝い(PowerShell)を起動できなかった。次の起動でもう一度試す")
			return
	else:
		# Linux などは、動いている .pck も、名前を替えて置き換えられる
		if DirAccess.rename_absolute(new_pck(), base_pck()) != OK:
			_done = false
			_finish("新しい版に入れ替えられなかった")
			return
		var args := PackedStringArray()
		if not user.is_empty():
			args.append("--")
			args.append_array(user)
		if OS.create_process(exe, args) <= 0:
			_done = false
			_finish("入れ替えた。起動し直せなかったので、もう一度起動する")
			return
	get_tree().quit()

func _finish(note: String) -> void:
	_done = true
	finished.emit(note)
