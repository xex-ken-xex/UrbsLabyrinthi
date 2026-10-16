extends "res://tests/smoke_test.gd"
## 自宅と魔法実験だけを手早く回す(smoke_test の _test_home_state と _test_home_town)

func _run() -> void:
	_test_home_state()
	await _test_home_town()
	print("\n==== ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
