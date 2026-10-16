extends "res://tests/smoke_test.gd"
## 迷宮の中の記録だけを手早く回す(smoke_test の _test_dive_save)

func _run() -> void:
	await _test_dive_save()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
