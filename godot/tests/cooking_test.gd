extends "res://tests/smoke_test.gd"
## 料理だけを手早く回す(smoke_test の _test_cooking_state と _test_cooking_dive)

func _run() -> void:
	_test_cooking_state()
	await _test_cooking_dive()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
