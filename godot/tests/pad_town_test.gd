extends SceneTree
## コントローラーだけで街を回れるかを確かめる(Godot --headless --path godot -s res://tests/pad_town_test.gd)
var main: Node
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func _focus() -> Control:
	return root.gui_get_focus_owner()

func _press(btn: int) -> void:
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = p
		Input.parse_input_event(e)
		for i in 3:
			await process_frame

func check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main.show_make()
	await process_frame
	main.screen._on_start()
	for i in 5:
		await process_frame
	var town: TownScreen = main.screen
	check(_focus() is Button and _focus().text == "報告を閉じる", "街に着くと、まず報告を読む(焦点は「報告を閉じる」)")
	await _press(JOY_BUTTON_A)
	check(_focus() is Button and _focus().name == "sign_dive", "報告を閉じると、焦点が坑口の看板にある")
	await _press(JOY_BUTTON_DPAD_LEFT)
	check(_focus() is Button and String(_focus().name).begins_with("sign_") and _focus().name != "sign_dive", "十字キーで、ほかの看板へ移る (%s)" % _focus().name)
	(town.signs.find_child("sign_smith", true, false) as Button).grab_focus()
	await _press(JOY_BUTTON_A)
	check(town.location == "smith", "A で看板の店(炉火の槌)へ入る")
	check(_focus() == town.shop_list, "店に入ると、品物の一覧を操れる")
	await _press(JOY_BUTTON_DPAD_DOWN)
	check(town.sel_id != "", "十字キーで品物を選ぶと説明が出る")
	var silver := town.gs.bank_silver
	await _press(JOY_BUTTON_A)
	check(_focus() is Button and _focus().text == "購入する", "A で購入のボタンへ移る")
	await _press(JOY_BUTTON_A)
	check(town.gs.bank_silver < silver, "A で買える")
	check(_focus() != null, "買ったあとも焦点が残る")
	if _focus() != town.shop_list:
		await _press(JOY_BUTTON_B)
		check(_focus() == town.shop_list, "B で品物の一覧へ戻る")
	await _press(JOY_BUTTON_B)
	check(town.location == "hub" and _focus() is Button and _focus().name == "sign_smith", "B で広場へ出て、焦点はいま出てきた店の看板")
	await _press(JOY_BUTTON_START)
	check(main.inventory != null, "Start で持ち物を開く")
	await _press(JOY_BUTTON_B)
	await process_frame
	check(main.inventory == null, "B で持ち物を閉じる")
	check(_focus() is Button and _focus().name == "sign_smith", "持ち物を閉じると、焦点が街に戻る")
	print("==== ALL PASSED" if fails == 0 else "==== %d FAILED" % fails)
	quit(1 if fails > 0 else 0)
