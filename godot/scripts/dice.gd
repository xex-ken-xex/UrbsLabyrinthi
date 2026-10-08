class_name Dice
extends RefCounted
## SRD のダメージ式("1d4+2 piercing"、"1 piercing + 3d4 poison"、"4d10")を読んで振る。

static var rng := RandomNumberGenerator.new()
static var _re: RegEx

static func d(sides: int) -> int:
	return rng.randi_range(1, sides)

static func d20() -> int:
	return rng.randi_range(1, 20)

static func _parts(expr: String) -> Array:
	# [個数, 面数, 補正] の配列。面数0は固定値
	if _re == null:
		_re = RegEx.new()
		_re.compile("^\\s*(\\d+)(?:d(\\d+))?\\s*(?:([+-])\\s*(\\d+))?")
	var out: Array = []
	for part in expr.split(" + "):
		var m := _re.search(part)
		if m == null:
			continue
		var n := int(m.get_string(1))
		var sides_s := m.get_string(2)
		var bonus := 0
		if m.get_string(4) != "":
			bonus = int(m.get_string(4)) * (-1 if m.get_string(3) == "-" else 1)
		if sides_s == "":
			out.append([0, 0, n + bonus])
		else:
			out.append([n, int(sides_s), bonus])
	return out

static func average(expr: String) -> float:
	var t := 0.0
	for p in _parts(expr):
		t += p[0] * (p[1] + 1) / 2.0 + p[2]
	return t

static func roll(expr: String) -> int:
	var t := 0
	for p in _parts(expr):
		for i in p[0]:
			t += rng.randi_range(1, p[1])
		t += p[2]
	return t
