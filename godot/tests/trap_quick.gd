extends "res://tests/smoke_test.gd"
## 罠の試験だけを手早く回す(smoke_test の _test_trap_motion)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _step(3)
	main.show_make()
	await _step(3)
	main.screen._on_start()
	await _step(3)
	main._on_dive()
	await _step(5)
	main.scripted_input = true
	await _test_trap_motion(main)
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
