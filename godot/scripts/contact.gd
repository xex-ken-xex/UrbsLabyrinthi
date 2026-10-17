class_name Contact
extends RefCounted
## 体当たりの押し合いと、キャラクター同士が重ならない処理。
##
## 敵と味方: 互いに押し込む力(速さ × HP割合 × 重さ)の差で、境目が動く。
##   敵のHPが削れると、こちらが少しずつ押していける。こちらのHPが削られると、押される。
##   押し込んでいる間は、一定間隔でダメージが入る。
## 仲間どうし: 動いている間はすり抜ける。どちらも止まっていれば、ゆっくり離れて重ならない。
## 魔物どうし: 重さに応じて押しのけ合い、重ならない。
## 話し合える魔物(中立)と仲間: すり抜ける(通路で引っかからない)。
## どちらも壁には食い込まない。壁に押しつけられると、それ以上は下がれない。

## 触れ合う可能性のある、最も遠い x の差(大きい魔物の半径の和 + 余裕。並べ順の乱れも見込む)
const MAX_TOUCH := 72.0

static func step(delta: float, bodies: Array) -> void:
	for b in bodies:
		b.bump_cd = maxf(0.0, b.bump_cd - delta)
		b.hit_now = b.bump_cd <= 0.0
		b.did_hit = false
	# 広い層で、魔物が多く群がっても軽いように、近い組(触れそうな組)だけを、升目で先に拾っておく
	var pairs := _near_pairs(bodies)
	for k in range(0, pairs.size(), 2):
		var a: Body = pairs[k]
		var b: Body = pairs[k + 1]
		if not a.is_alive() or not b.is_alive():
			continue
		var d := b.position - a.position
		var touch := a.radius + b.radius
		var lim := touch + 2.0
		if d.length_squared() > lim * lim:
			continue
		var dist := d.length()
		var nrm := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
		if _passes(a, b):
			if a.is_hero and b.is_hero and _still(a) and _still(b):
				_separate(a, b, nrm, (touch - dist) * minf(1.0, 6.0 * delta))
			continue
		if a.is_hero == b.is_hero:
			_separate(a, b, nrm, touch - dist)
		else:
			_fight(a, b, nrm, touch, delta)
	for b in bodies:
		if b.did_hit:
			b.bump_cd = Balance.BUMP_TICK
	# 混み合っていると、一組を直すと別の組が重なる。数回、重なりだけを解消し直す。
	# 2回目からは、前の回に動いた体を含む組だけを見る(群がっていても軽いように)
	var live: Array = []
	for k in range(0, pairs.size(), 2):
		var a: Body = pairs[k]
		var b: Body = pairs[k + 1]
		if a.is_alive() and b.is_alive() and not _passes(a, b):
			live.append(a)
			live.append(b)
	var moved := {}
	var budget := RELAX_BUDGET
	for pass_i in 16:
		var now := {}
		for k in range(0, live.size(), 2):
			var a: Body = live[k]
			var b: Body = live[k + 1]
			if pass_i > 0 and not moved.has(a) and not moved.has(b):
				continue
			var d := b.position - a.position
			var touch := a.radius + b.radius
			if d.length_squared() >= (touch - 0.05) * (touch - 0.05):
				continue
			var dist := d.length()
			var nrm := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
			_separate(a, b, nrm, touch - dist)
			now[a] = true
			now[b] = true
			budget -= 1
			if budget <= 0:
				break
		if now.is_empty() or budget <= 0:
			break
		moved = now

## 1コマに重なりを解消し直す組の数の上限。大群が群がると解消しきれないが、残りは次のコマで直る
const RELAX_BUDGET := 240

## 触れそうな組(体の縁の間が PAIR_MARGIN 以内)を [a0, b0, a1, b1, ...] で返す。
## 升目(MAX_TOUCH 四方)に分けて、隣り合う升目どうしだけを調べる
const PAIR_MARGIN := 8.0

static func _near_pairs(bodies: Array) -> Array:
	var grid := {}
	for b in bodies:
		var key := Vector2i(floori(b.position.x / MAX_TOUCH), floori(b.position.y / MAX_TOUCH))
		if grid.has(key):
			(grid[key] as Array).append(b)
		else:
			grid[key] = [b]
	var out: Array = []
	for key in grid:
		var here: Array = grid[key]
		# 同じ升目の中の組と、右・下側の4つの升目との組(重ねて数えない)
		for i in here.size():
			for j in range(i + 1, here.size()):
				_add_pair(out, here[i], here[j])
		for dv in [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
			var other: Variant = grid.get(key + dv)
			if other == null:
				continue
			for a in here:
				for b in other:
					_add_pair(out, a, b)
	return out

static func _add_pair(out: Array, a: Body, b: Body) -> void:
	var lim := a.radius + b.radius + PAIR_MARGIN
	if a.position.distance_squared_to(b.position) <= lim * lim:
		out.append(a)
		out.append(b)

## すり抜ける組か(仲間どうし、仲間と中立の魔物、群れの魔物とほかの魔物)
static func _passes(a: Body, b: Body) -> bool:
	if a.is_hero and b.is_hero:
		return true
	if not a.is_hero and not b.is_hero:
		# 群れ(Swarm)は、ほかの魔物とすり抜ける
		return (a is Enemy and (a as Enemy).traits.has("swarm")) or (b is Enemy and (b as Enemy).traits.has("swarm"))
	if a.is_hero != b.is_hero:
		var en: Body = b if a.is_hero else a
		return en is Enemy and (en as Enemy).state == "neutral"
	return false

static func _still(b: Body) -> bool:
	return b.self_move.length() < 0.2

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
