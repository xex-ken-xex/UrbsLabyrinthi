extends SceneTree
## クレジットとライセンスの表記(ken 10/18): Godot --headless --path godot -s res://tests/credits_test.gd
var fails := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	print("[クレジット]")
	main.toggle_credits()
	await process_frame
	var cr: CreditsScreen = main.credits
	check(cr != null and cr.is_inside_tree(), "クレジットの画面が開く")
	var t: String = cr.text.get_parsed_text()
	check(t.contains(CreditsScreen.SRD_ATTRIBUTION), "SRD 5.1 の帰属表示の文が、そのまま入っている")
	check(t.contains("https://creativecommons.org/licenses/by/4.0/legalcode") and t.contains("Wizards of the Coast LLC"), "ライセンスへのリンクと出典がある")
	check(t.contains("Changes:") and t.contains("translated into Japanese"), "手を加えたことを書いている")
	check(t.contains("not affiliated with, endorsed"), "Wizards of the Coast が認めたものではないと書いている")
	check(t.contains("M+ 1p") and t.contains("Shippori Mincho") and t.contains("Dela Gothic One") and t.contains("SIL Open Font License"), "フォント3つと OFL")
	check(t.contains("Godot Engine contributors") and t.contains("Permission is hereby granted"), "Godot Engine の MIT の許諾文")
	check(t.contains("FreeType") and (t.contains("mbed") or t.contains("Mbed")), "Godot の中の部品(FreeType、mbed TLS など)")
	var lic: Dictionary = Engine.get_license_info()
	var keys: Array = lic.keys()
	keys.sort()
	var tail: String = String(lic[keys[-1]]).strip_edges().right(60)
	check(t.strip_edges().ends_with(tail), "BBCode が崩れていない(ライセンスの全文の最後まで読める)")
	main.toggle_credits()
	for i in 2:
		await process_frame
	check(not is_instance_valid(cr), "もう一度押すと閉じる")
	main.toggle_credits()
	await process_frame
	cr = main.credits
	cr.close_screen()
	for i in 2:
		await process_frame
	check(not is_instance_valid(cr), "閉じるボタンで閉じる")
	main.toggle_credits()
	await process_frame
	check(is_instance_valid(main.credits), "閉じたあと、また開ける")
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
