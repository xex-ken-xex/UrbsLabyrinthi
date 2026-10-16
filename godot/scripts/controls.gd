class_name Controls
extends RefCounted
## 操作の割り当て(キーボードとコントローラー)。初期値、保存(user://controls.cfg)、表示用の名前。
## 一つの操作に、キーを2つと、マウスのボタンを1つと、コントローラーの入力を1つ割り当てられる。
## 移動は、左スティックでもいつでもできる(割り当ての外)。

const PATH := "user://controls.cfg"
const VERSION := 3      # 2: 攻撃を足し(Space)、構えを Ctrl に移し、コントローラーのスキルを並べ替え、Esc を持ち物から外した
                        # 3: マウスの枠を足した(左クリックで攻撃、右クリックで構え)
const MOVE := ["move_up", "move_down", "move_left", "move_right"]

## [id, 名前]。この順に設定画面へ並ぶ
const ACTIONS := [
	["move_up", "上へ"], ["move_down", "下へ"], ["move_left", "左へ"], ["move_right", "右へ"],
	["attack", "攻撃(正面へ一撃)"], ["guard", "構え(押している間)"], ["dodge", "転がり"],
	["skill1", "スキル1"], ["skill2", "スキル2"], ["skill3", "スキル3"], ["skill4", "スキル4"],
	["switch", "操作する仲間を替える"], ["interact", "調べる・開ける・拾う"], ["search", "探る(罠と隠し扉)"],
	["quick_heal", "治療薬を使う"], ["rest", "休む(野営)"], ["zoom_in", "ミニマップを拡大"], ["zoom_out", "ミニマップを縮小"], ["inventory", "持ち物(メニュー)"], ["confirm", "決定(報告を閉じる)"],
]
## 割り当てを変えられない操作
const FIXED := {"reload_assets": [KEY_F6], "credits": [KEY_F1]}

## 入力の記録: {"t": "key", "c": 物理キー} / {"t": "btn", "b": ボタン} / {"t": "axis", "a": 軸, "v": ±1}
static func _k(code: int) -> Dictionary:
	return {"t": "key", "c": code}
static func _b(btn: int) -> Dictionary:
	return {"t": "btn", "b": btn}
static func _ax(axis: int, v: int) -> Dictionary:
	return {"t": "axis", "a": axis, "v": v}
static func _m(btn: int) -> Dictionary:
	return {"t": "mouse", "m": btn}

## 初期値。{"keys": [キー1, キー2], "mouse": マウスのボタン, "pad": コントローラー}。無い所は {}
static func defaults() -> Dictionary:
	var d := _default_binds()
	for id in d:
		d[id]["mouse"] = {}
	d["attack"]["mouse"] = _m(MOUSE_BUTTON_LEFT)       # マウスの方向へ振る
	d["guard"]["mouse"] = _m(MOUSE_BUTTON_RIGHT)
	return d

static func _default_binds() -> Dictionary:
	return {
		"move_up": {"keys": [_k(KEY_W), _k(KEY_UP)], "pad": _b(JOY_BUTTON_DPAD_UP)},
		"move_down": {"keys": [_k(KEY_S), _k(KEY_DOWN)], "pad": _b(JOY_BUTTON_DPAD_DOWN)},
		"move_left": {"keys": [_k(KEY_A), _k(KEY_LEFT)], "pad": _b(JOY_BUTTON_DPAD_LEFT)},
		"move_right": {"keys": [_k(KEY_D), _k(KEY_RIGHT)], "pad": _b(JOY_BUTTON_DPAD_RIGHT)},
		"attack": {"keys": [_k(KEY_SPACE), _k(KEY_J)], "pad": _b(JOY_BUTTON_X)},
		"guard": {"keys": [_k(KEY_CTRL), {}], "pad": _b(JOY_BUTTON_LEFT_SHOULDER)},
		"dodge": {"keys": [_k(KEY_SHIFT), {}], "pad": _b(JOY_BUTTON_B)},
		"skill1": {"keys": [_k(KEY_1), {}], "pad": _b(JOY_BUTTON_Y)},
		"skill2": {"keys": [_k(KEY_2), {}], "pad": _ax(JOY_AXIS_TRIGGER_RIGHT, 1)},
		"skill3": {"keys": [_k(KEY_3), {}], "pad": _ax(JOY_AXIS_TRIGGER_LEFT, 1)},
		"skill4": {"keys": [_k(KEY_4), {}], "pad": _b(JOY_BUTTON_RIGHT_STICK)},
		"switch": {"keys": [_k(KEY_Q), {}], "pad": _b(JOY_BUTTON_RIGHT_SHOULDER)},
		"interact": {"keys": [_k(KEY_E), {}], "pad": _b(JOY_BUTTON_A)},
		"search": {"keys": [_k(KEY_F), {}], "pad": _b(JOY_BUTTON_LEFT_STICK)},
		"quick_heal": {"keys": [_k(KEY_R), {}], "pad": _b(JOY_BUTTON_BACK)},
		"rest": {"keys": [_k(KEY_C), {}], "pad": {}},     # コントローラーは、持ち物の「休む」から
		"zoom_in": {"keys": [_k(KEY_SEMICOLON), _k(KEY_KP_ADD)], "pad": {}},     # 日本語キーボードの「+」は ; の位置
		"zoom_out": {"keys": [_k(KEY_MINUS), _k(KEY_KP_SUBTRACT)], "pad": {}},
		"inventory": {"keys": [_k(KEY_TAB), _k(KEY_I)], "pad": _b(JOY_BUTTON_START)},
		"confirm": {"keys": [_k(KEY_ENTER), _k(KEY_KP_ENTER)], "pad": _b(JOY_BUTTON_A)},
	}

static var binds := {}

static func action_name(id: String) -> String:
	for a in ACTIONS:
		if a[0] == id:
			return String(a[1])
	return id

## 起動時に一度。保存した割り当てを読み、InputMap に入れる
static func setup() -> void:
	binds = defaults()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for a in ACTIONS:
			var id: String = a[0]
			if cf.has_section_key("binds", id):
				var v = cf.get_value("binds", id)
				if v is Dictionary:
					binds[id] = _sanitize(v, binds[id])
		if int(cf.get_value("meta", "version", 1)) < 2:
			_migrate_v1()
		if int(cf.get_value("meta", "version", 1)) < 3:
			var d := defaults()
			for a in ACTIONS:
				binds[a[0]]["mouse"] = d[a[0]]["mouse"]
	for id in FIXED:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		for k in FIXED[id]:
			InputMap.action_add_event(id, to_event(_k(k)))
	apply()

static func _sanitize(v: Dictionary, fallback: Dictionary) -> Dictionary:
	var keys: Array = v.get("keys", []) if v.get("keys", []) is Array else []
	var out := {"keys": [{}, {}], "pad": {}, "mouse": {}}
	for i in 2:
		if i < keys.size() and keys[i] is Dictionary and to_event(keys[i]) != null and String(keys[i].get("t", "")) == "key":
			out["keys"][i] = keys[i]
	var p = v.get("pad", {})
	if p is Dictionary and to_event(p) != null and String(p.get("t", "")) in ["btn", "axis"]:
		out["pad"] = p
	var ms = v.get("mouse", {})
	if ms is Dictionary and to_event(ms) != null and String(ms.get("t", "")) == "mouse":
		out["mouse"] = ms
	if (out["keys"] as Array).all(func(x): return (x as Dictionary).is_empty()) and (out["pad"] as Dictionary).is_empty() and (out["mouse"] as Dictionary).is_empty():
		return fallback   # 何も割り当てが無いと遊べないので、初期値に戻す
	return out

## binds を InputMap に入れる
static func apply() -> void:
	for a in ACTIONS:
		var id: String = a[0]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		InputMap.action_set_deadzone(id, 0.4)
		var b: Dictionary = binds[id]
		for d in b["keys"]:
			var ev := to_event(d)
			if ev != null:
				InputMap.action_add_event(id, ev)
		var pe := to_event(b["pad"])
		if pe != null:
			InputMap.action_add_event(id, pe)
		var me := to_event(b.get("mouse", {}))
		if me != null:
			InputMap.action_add_event(id, me)
	# 左スティックの移動(割り当ての外。いつでも使える)
	var stick := {"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}
	for id in stick:
		var m := InputEventJoypadMotion.new()
		m.axis = stick[id][0]
		m.axis_value = stick[id][1]
		InputMap.action_add_event(id, m)
	# Tab は持ち物を開け閉めするキー。Godot の初期設定では、ボタンの焦点送り(ui_focus_next)が Tab を先に取ってしまい、
	# 持ち物が閉じないことがあった。焦点送りは十字キーで行うので、Tab と Shift+Tab を外す
	for fa in ["ui_focus_next", "ui_focus_prev"]:
		for ev in InputMap.action_get_events(fa):
			if ev is InputEventKey and ((ev as InputEventKey).keycode == KEY_TAB or (ev as InputEventKey).physical_keycode == KEY_TAB):
				InputMap.action_erase_event(fa, ev)
	# 画面のボタン操作(決定・戻る)。Godot の初期設定にはコントローラーが無いので、A で決定、B で戻る を足す
	for ui in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		for ev in InputMap.action_get_events(ui[0]):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(ui[0], ev)
		var jb := InputEventJoypadButton.new()
		jb.button_index = ui[1]
		InputMap.action_add_event(ui[0], jb)

## 版1で保存した割り当てを、版2の決まりに合わせる(コントローラーのスキルと探るは新しい初期値、Esc は戻る専用)
static func _migrate_v1() -> void:
	var d := defaults()
	for id in ["attack", "skill1", "skill2", "skill3", "skill4", "search"]:
		binds[id]["pad"] = d[id]["pad"]
	# 攻撃は Space、構えは Ctrl に移した
	binds["attack"]["keys"] = d["attack"]["keys"].duplicate(true)
	for i in (binds["guard"]["keys"] as Array).size():
		if (binds["guard"]["keys"][i] as Dictionary).get("c", -1) == KEY_SPACE:
			binds["guard"]["keys"][i] = d["guard"]["keys"][i] if i == 0 else {}
	var keys: Array = binds["inventory"]["keys"]
	for i in keys.size():
		if (keys[i] as Dictionary).get("c", -1) == KEY_ESCAPE:
			keys[i] = d["inventory"]["keys"][i]

static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", VERSION)
	for a in ACTIONS:
		cf.set_value("binds", a[0], binds[a[0]])
	cf.save(PATH)

static func reset() -> void:
	binds = defaults()
	apply()
	save()

static func set_bind(id: String, slot: String, d: Dictionary) -> void:
	# slot: "k0" / "k1" / "mouse" / "pad"
	if slot == "pad" or slot == "mouse":
		binds[id][slot] = d
	else:
		binds[id]["keys"][int(slot.substr(1))] = d
	apply()
	save()

static func to_event(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("c", 0)) as Key
			return k if k.physical_keycode != KEY_NONE else null
		"btn":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("b", 0)) as JoyButton
			return b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d.get("a", 0)) as JoyAxis
			m.axis_value = 1.0 if int(d.get("v", 1)) >= 0 else -1.0
			return m
		"mouse":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(d.get("m", 0)) as MouseButton
			return mb if mb.button_index in MOUSE_OK else null
	return null

## 割り当てられるマウスのボタン(ホイールは画面の拡縮に使うので外す)
const MOUSE_OK := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
const MOUSE_JP := {MOUSE_BUTTON_LEFT: "左クリック", MOUSE_BUTTON_RIGHT: "右クリック", MOUSE_BUTTON_MIDDLE: "中クリック",
	MOUSE_BUTTON_XBUTTON1: "マウス戻る", MOUSE_BUTTON_XBUTTON2: "マウス進む"}

## 押された入力を記録の形にする(設定画面の「押してください」で使う)。使えない入力なら {}
static func from_event(e: InputEvent) -> Dictionary:
	if e is InputEventKey and e.pressed and not e.echo:
		var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		return _k(code) if code != KEY_NONE else {}
	if e is InputEventJoypadButton and e.pressed:
		return _b(e.button_index)
	if e is InputEventJoypadMotion and absf(e.axis_value) > 0.6:
		return _ax(e.axis, 1 if e.axis_value > 0.0 else -1)
	if e is InputEventMouseButton and e.pressed and e.button_index in MOUSE_OK:
		return _m(e.button_index)
	return {}

const BTN_JP := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_DPAD_UP: "十字↑", JOY_BUTTON_DPAD_DOWN: "十字↓", JOY_BUTTON_DPAD_LEFT: "十字←", JOY_BUTTON_DPAD_RIGHT: "十字→",
}

static func label(d: Dictionary) -> String:
	match String(d.get("t", "")):
		"key":
			# 物理キーの名前(US 配列での名前)。文字キーと特殊キーは、日本語配列でも同じ
			return OS.get_keycode_string(int(d["c"]))
		"btn":
			return String(BTN_JP.get(int(d["b"]), "ボタン%d" % int(d["b"])))
		"mouse":
			return String(MOUSE_JP.get(int(d["m"]), "マウス%d" % int(d["m"])))
		"axis":
			var a := int(d["a"])
			var v := int(d["v"])
			match a:
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
				JOY_AXIS_LEFT_X: return "左スティック" + ("→" if v > 0 else "←")
				JOY_AXIS_LEFT_Y: return "左スティック" + ("↓" if v > 0 else "↑")
				JOY_AXIS_RIGHT_X: return "右スティック" + ("→" if v > 0 else "←")
				JOY_AXIS_RIGHT_Y: return "右スティック" + ("↓" if v > 0 else "↑")
			return "軸%d%s" % [a, "+" if v > 0 else "-"]
	return ""

## 画面の説明に出す、その操作のキー(1つ目のキー。無ければコントローラー)
static func hint(id: String) -> String:
	if binds.is_empty():
		binds = defaults()
	var b: Dictionary = binds.get(id, {})
	if b.is_empty():
		return "?"
	for d in b["keys"]:
		if not (d as Dictionary).is_empty():
			return label(d)
	return label(b["pad"]) if not (b["pad"] as Dictionary).is_empty() else "なし"

## 同じ入力を、ほかの操作にも割り当てているか(決定と調べるは、場面が違うので重なってよい)
const SHARE_OK := [["interact", "confirm"]]

static func conflicts(id: String, d: Dictionary) -> Array:
	var out: Array = []
	if d.is_empty():
		return out
	for a in ACTIONS:
		var other: String = a[0]
		if other == id:
			continue
		var ok := false
		for pair in SHARE_OK:
			if pair.has(id) and pair.has(other):
				ok = true
		if ok:
			continue
		var b: Dictionary = binds[other]
		var all: Array = (b["keys"] as Array).duplicate()
		all.append(b["pad"])
		all.append(b.get("mouse", {}))
		for x in all:
			if x == d:
				out.append(other)
	return out
