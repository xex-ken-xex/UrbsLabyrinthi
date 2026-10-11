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
	check(_focus() is Button and _focus().text == "坑口広場", "街に着くと、焦点が坑口広場にある")
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_A)
	check(town.location == "smith", "A で武器・防具の店へ入る")
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
	check(_focus() is Button and _focus().text == "武器・防具", "B で左の行き先へ戻る")
	await _press(JOY_BUTTON_START)
	check(main.inventory != null, "Start で持ち物を開く")
	await _press(JOY_BUTTON_B)
	await process_frame
	check(main.inventory == null, "B で持ち物を閉じる")
	check(_focus() is Button and _focus().text == "武器・防具", "持ち物を閉じると、焦点が街に戻る")
	print("==== ALL PASSED" if fails == 0 else "==== %d FAILED" % fails)
	quit(1 if fails > 0 else 0)
