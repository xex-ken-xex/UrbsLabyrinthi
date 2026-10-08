class_name Contact
extends RefCounted
## 体当たりの押し合いと、キャラクター同士が重ならない処理。
##
## 敵と味方: 互いに押し込む力(速さ × HP割合 × 重さ)の差で、境目が動く。
##   敵のHPが削れると、こちらが少しずつ押していける。こちらのHPが削られると、押される。
##   押し込んでいる間は、一定間隔でダメージが入る。
## 同じ側どうし: 重さに応じて押しのけ合い、重ならない。
## どちらも壁には食い込まない。壁に押しつけられると、それ以上は下がれない。

static func step(delta: float, bodies: Array) -> void:
	for b in bodies:
		b.bump_cd = maxf(0.0, b.bump_cd - delta)
		b.hit_now = b.bump_cd <= 0.0
		b.did_hit = false
	var n := bodies.size()
	for i in n:
		var a: Body = bodies[i]
		if not a.is_alive():
			continue
		for j in range(i + 1, n):
			var b: Body = bodies[j]
			if not b.is_alive():
				continue
			var d := b.position - a.position
			var touch := a.radius + b.radius
			var lim := touch + 2.0
			if d.length_squared() > lim * lim:
				continue
			var dist := d.length()
			var nrm := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
			if a.is_hero == b.is_hero:
				_separate(a, b, nrm, touch - dist)
			else:
				_fight(a, b, nrm, touch, delta)
	for b in bodies:
		if b.did_hit:
			b.bump_cd = Balance.BUMP_TICK
	# 混み合っていると、一組を直すと別の組が重なる。数回、重なりだけを解消し直す
	for pass_i in 16:
		var moved := false
		for i in n:
			var a: Body = bodies[i]
			if not a.is_alive():
				continue
			for j in range(i + 1, n):
				var b: Body = bodies[j]
				if not b.is_alive():
					continue
				var d := b.position - a.position
				var touch := a.radius + b.radius
				if d.length_squared() >= (touch - 0.05) * (touch - 0.05):
					continue
				var dist := d.length()
				var nrm := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
				_separate(a, b, nrm, touch - dist)
				moved = true
		if not moved:
			break

## att が tgt を、触れているだけで攻撃してよいか。toward は、相手へ向かう動きの成分(−1〜1)
static func _auto_attacks(att: Body, tgt: Body, toward: float) -> bool:
	if toward < -0.5:
		return false
	# 話し合える魔物(交渉の余地あり)は、こちらから押し込まない限り、うっかり殴らない
	if att.is_hero and tgt is Enemy and (tgt as Enemy).state == "neutral" and toward <= 0.2:
		return false
	return true

static func _separate(a: Body, b: Body, n: Vector2, overlap: float) -> void:
	if overlap <= 0.0:
		return
	var wa := 1.0 / a.body_mass()
	var wb := 1.0 / b.body_mass()
	var fa := wa / (wa + wb)
	var ma := a.shove(-n * overlap * fa)
	var mb := b.shove(n * overlap * (1.0 - fa))
	var rest := overlap - ma - mb
	if rest > 0.01:
		# 片方が壁で動けないとき、もう片方が引き受ける
		if ma < overlap * fa - 0.01:
			b.shove(n * rest)
		else:
			a.shove(-n * rest)

static func _fight(a: Body, b: Body, n: Vector2, touch: float, delta: float) -> void:
	var dist := (b.position - a.position).length()
	var overlap := touch - dist
	# 1. 相手へ向かって自分で進んだぶんのうち、食い込んだ分だけを取り消す
	if overlap > 0.0:
		var ta := maxf(0.0, a.self_move.dot(n))
		var tb := maxf(0.0, b.self_move.dot(-n))
		var tot := ta + tb
		if tot > 0.001:
			var ca := minf(ta, overlap * ta / tot)
			var cb := minf(tb, overlap * tb / tot)
			if ca > 0.0:
				a.shove(-n * ca)
			if cb > 0.0:
				b.shove(n * cb)
	# 2. 押し合い。力の差が、境目の動く速さになる
	var fa := a.drive_toward(n)
	var fb := b.drive_toward(-n)
	var net := (fa - fb) / (a.body_mass() + b.body_mass()) * Balance.PUSH_SCALE
	var shift := net * delta
	var loser: Body = b if shift >= 0.0 else a
	var winner: Body = a if shift >= 0.0 else b
	var dir_l: Vector2 = n if loser == b else -n
	if absf(shift) > 0.0001:
		var moved := loser.shove(dir_l * absf(shift))
		winner.shove(dir_l * moved)
	# 3. 体当たりのダメージ
	# 触れていれば、押し込んでいなくても自動で攻撃する。背を向けて離れようとしているときだけ、攻撃しない
	if _auto_attacks(a, b, a.intent.dot(n)) and a.hit_now and a.contact_dps() > 0.0:
		b.receive_contact(a.contact_dps() * Balance.BUMP_TICK, a.position, a)
		a.did_hit = true
		a.lunge = n * 5.0
	if _auto_attacks(b, a, b.intent.dot(-n)) and b.hit_now and b.contact_dps() > 0.0:
		a.receive_contact(b.contact_dps() * Balance.BUMP_TICK, b.position, b)
		b.did_hit = true
		b.lunge = -n * 5.0
	# 4. 重なりが残っていれば、負けた側を下げる。壁で下がれなければ勝った側が引く
	var d2 := b.position - a.position
	var overlap2 := touch - d2.length()
	if overlap2 > 0.0:
		var m2 := loser.shove(dir_l * overlap2)
		if overlap2 - m2 > 0.01:
			winner.shove(-dir_l * (overlap2 - m2))
