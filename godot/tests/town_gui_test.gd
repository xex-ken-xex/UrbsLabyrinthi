extends SceneTree
## 街のボタンと擬音(ken 10/18): Godot --headless --path godot -s res://tests/town_gui_test.gd
## 広場へは右下、タイトルへと操作の設定は持ち物の画面から、宿に泊まると翌朝、加護の演出、街の擬音
var main: Node
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _sfx_count(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		if c is Sfx:
			k += 1
	return k

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.show_make()
	await _frames(2)
	main.screen._on_start()
	await _frames(5)
	var town: TownScreen = main.screen
	town.report = []
	town._go("hub")
	await _frames(3)
	check(not town.back_btn.visible, "広場では「広場へ」を出さない")
	town._go("smith")
	await _frames(3)
	var vs: Vector2 = town.size
	var r: Rect2 = town.back_btn.get_global_rect()
	check(town.back_btn.visible and town.back_btn.text.begins_with("広場へ") and r.position.x > vs.x * 0.7 and r.position.y > vs.y * 0.8,
		"店では右下に「広場へ」がある (%s)" % str(r))
	check(_sfx_count(town) >= 1, "店に入ると擬音が出る(炉火の槌 カーン、カーン)")
	var texts: Array = []
	for b in town.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	check(not texts.has("タイトルへ") and not texts.has("操作の設定"), "街の画面には、タイトルへ・操作の設定が無い")
	town.back_btn.pressed.emit()
	await _frames(2)
	check(town.location == "hub", "「広場へ」で広場へ出る")
	# 持ち物の画面: 閉じる・操作の設定・タイトルへ
	main.open_inventory()
	await _frames(3)
	var inv: InventoryScreen = main.inventory
	check(inv.close_btn.visible and inv.keys_btn.visible and inv.title_btn.visible, "持ち物の画面に、閉じる・操作の設定・タイトルへがある(街)")
	var cr: Rect2 = inv.close_btn.get_global_rect()
	check(cr.position.x > vs.x * 0.7 and cr.position.y > vs.y * 0.8, "閉じるは右下 (%s)" % str(cr))
	inv.keys_btn.pressed.emit()
	await _frames(3)
	check(main.key_config != null, "持ち物の画面から操作の設定を開ける")
	main.close_key_config()
	await _frames(3)
	check(main.inventory != null, "操作の設定を閉じると、持ち物の画面に戻る")
	inv.close_btn.pressed.emit()
	await _frames(3)
	check(main.inventory == null, "閉じるで持ち物を閉じる")
	# 宿に泊まる: 暗転して翌朝
	town._go("inn")
	await _frames(2)
	var c: Character = main.gs.party[0]
	c.hp = 1.0
	var day0: int = main.gs.day
	var silver0: int = main.gs.silver
	town._rest(60)
	await _frames(2)
	check(town.busy and town.find_children("*", "TownFx", false, false).size() == 1, "泊まると暗転の演出が始まる")
	await _secs(1.0)
	check(main.gs.day == day0 + 1 and absf(c.hp - c.max_hp()) < 0.01 and main.gs.silver == silver0 - 60, "暗くなると、一日が過ぎて全快する (日 %d → %d)" % [day0, main.gs.day])
	await _secs(3.2)
	check(not town.busy and town.find_children("*", "TownFx", false, false).is_empty(), "明けると演出が消えて、また操作できる")
	check(town.msg.text.contains("翌朝"), "下の帯に「翌朝」の一行 (%s)" % town.msg.text)
	# 加護を願う
	town._go("temple")
	await _frames(2)
	main.gs.silver = 500
	town._bless()
	await _frames(2)
	check(main.gs.blessed and town.find_children("*", "TownFx", false, false).size() == 1, "加護を願うと キラキラ フワァ〜〜〜 が出る")
	# 擬音: 買う、売る、噂
	town._go("general")
	await _frames(2)
	town.sel_id = "potion"
	var n0 := _sfx_count(town)
	town._buy(-1)
	check(_sfx_count(town) > n0, "買うと チャリン")
	# 持ち物からタイトルへ(2度押し)
	main.open_inventory()
	await _frames(3)
	main.inventory.title_btn.pressed.emit()
	await _frames(2)
	check(main.inventory != null and main.inventory.title_btn.text == "本当に戻る", "タイトルへは、一度目は確かめる")
	main.inventory.title_btn.pressed.emit()
	await _frames(3)
	check(main.phase == "title" and main.inventory == null, "二度目でタイトルへ戻る")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
