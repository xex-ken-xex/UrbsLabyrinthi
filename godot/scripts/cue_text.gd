class_name CueText
extends RefCounted
## 擬音の文字を、一文字ずつ動かして描く(Sfx、DiceFx、UnlockFx が使う)。
## 動き方の名前は Sfx の説明を見る。t は出てからの秒、life は消えるまでの秒、px は文字の大きさ。
## dir は drop / roll / fly の向き(転がる・飛ぶ向き。ZERO なら右へ)。
## 動きの緩急はリリックモーション(歌詞を動かす文字の映像)の手を借りた: 行き過ぎて戻る、速く出て遅く止まる。

## 行き過ぎて戻る(0→1)
static func ease_back(k: float, over: float = 1.7) -> float:
	k = clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + k * k * ((over + 1.0) * k + over)

## 速く出て、ゆっくり止まる(0→1)
static func ease_out(k: float) -> float:
	k = 1.0 - clampf(k, 0.0, 1.0)
	return 1.0 - k * k * k

## 一語を、origin を中心に描く
static func draw_word(ci: CanvasItem, chars: PackedStringArray, style: String, t: float, life: float, px: float, color: Color, seed: float = 0.0, big: bool = false, origin: Vector2 = Vector2.ZERO, dir: Vector2 = Vector2.ZERO) -> void:
	var font := UI.cue_font()
	var n := chars.size()
	if n == 0:
		return
	var fade := (1.0 - clampf((t - (life - 0.35)) / 0.35, 0.0, 1.0)) * color.a
	var rise := -t * 14.0
	var scale := 1.0
	var tilt := 0.0
	var shake := Vector2.ZERO
	var spread := 0.0
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var slide := Vector2.ZERO      # 語全体のずれ(fly)
	match style:
		"pop":
			# 小さく出て、ふくらみすぎてから戻る
			scale = lerpf(0.55, 1.0, ease_back(t / 0.16, 2.6))
		"slam":
			# 大きく出て、行き過ぎて戻る。出た直後は揺れる
			var k := clampf(t / 0.14, 0.0, 1.0)
			scale = lerpf(2.3 if big else 1.9, 1.0, k) + 0.12 * sin(k * PI) * (1.0 - k)
			if t >= 0.14 and t < 0.24:
				scale = 1.0 - 0.1 * sin((t - 0.14) / 0.1 * PI)
			var sk := maxf(0.0, 1.0 - t / 0.35) * (6.0 if big else 3.5)
			shake = Vector2(sin(t * 90.0 + seed) * sk, cos(t * 77.0 + seed) * sk)
			tilt = -0.08
			rise = -maxf(0.0, t - 0.3) * 8.0
		"shake":
			rise = -t * 6.0
		"stretch":
			spread = minf(t, 0.6) * px * 0.35
			rise = -t * 10.0
		"soft":
			fade *= clampf(t / 0.18, 0.0, 1.0)
			scale = lerpf(0.8, 1.0, clampf(t / 0.25, 0.0, 1.0))
			rise = -t * 22.0
		"snap":
			# 横から滑り込み、少し行き過ぎて止まる
			var k2 := ease_back(t / 0.11, 2.2)
			shake.x = -(1.0 - k2) * px * 2.0
			tilt = -0.18 * (1.0 - clampf(t / 0.11, 0.0, 1.0)) - 0.05
			rise = -t * 8.0
		"drop":
			rise = -maxf(0.0, t - 0.4) * 10.0
		"roll":
			rise = -maxf(0.0, t - 0.5) * 8.0
		"fly":
			# 飛んできた向きへ、速く出て遅く止まる。止まってからも少し流れる
			var kf := ease_out(t / 0.16)
			slide = d * (-(1.0 - kf) * px * 4.0 + t * px * 0.8)
			tilt = clampf(d.x, -1.0, 1.0) * 0.12 * (1.0 - kf) + d.y * 0.1
			rise = -t * 4.0
		"wave", "bounce":
			rise = -t * 10.0
	# 文字の幅
	var widths: Array = []
	var total := 0.0
	for c in chars:
		var w := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px)).x
		widths.append(w)
		total += w
	total += spread * (n - 1)
	var x := -total / 2.0
	var outline := maxi(3, int(px * 0.22))
	for i in n:
		var w: float = widths[i]
		var off := Vector2.ZERO
		var a := fade
		var cs := scale
		var sq := Vector2.ONE       # 縦横の伸び縮み(着地でつぶれる)
		var rot := tilt
		match style:
			"bounce":
				# 一文字ずつ、跳ねながら出る
				var ti := t - i * 0.06
				if ti < 0.0:
					x += w + spread
					continue
				var hop := clampf(ti / 0.22, 0.0, 1.0)
				off.y = -sin(hop * PI) * px * 0.55
				cs = 1.0 + 0.25 * (1.0 - clampf(ti / 0.1, 0.0, 1.0))
			"stretch":
				var ts := t - i * 0.07
				if ts < 0.0:
					x += w + spread
					continue
				cs = lerpf(0.4, 1.0, ease_back(ts / 0.16, 2.0))
				a *= clampf(ts / 0.08, 0.0, 1.0)
			"drop":
				# 一文字ずつ上から落ちて、着地でつぶれ、小さく跳ね返る(ドスン、ストン)
				var td := t - i * 0.05
				if td < 0.0:
					x += w + spread
					continue
				const FALL := 0.15
				if td < FALL:
					var kd := td / FALL
					off.y = -(1.0 - kd * kd) * px * 3.2
					sq = Vector2(0.85, 1.25)
					a *= clampf(td / 0.05, 0.0, 1.0)
				else:
					var tl := td - FALL
					var squash := maxf(0.0, 1.0 - tl / 0.16)
					sq = Vector2(1.0 + 0.4 * squash, 1.0 - 0.35 * squash)
					off.y = -sin(clampf((tl - 0.06) / 0.18, 0.0, 1.0) * PI) * px * 0.25
					off.y += px * 0.12 * squash      # つぶれた分、足もとへ寄せる
			"roll":
				# 一文字ずつ転がってきて、行き過ぎずに止まる(ゴロゴロ、ゴロッ)
				var tr := t - i * 0.07
				if tr < 0.0:
					x += w + spread
					continue
				var kr := ease_out(tr / 0.5)
				var dist := (1.0 - kr) * px * 3.5
				off = -d * dist
				off.y -= absf(sin(dist / px * 1.6)) * px * 0.18
				rot = (1.0 if d.x >= 0.0 else -1.0) * dist / (px * 0.5)
				a *= clampf(tr / 0.08, 0.0, 1.0)
			"fly":
				# 後ろの文字ほど遅れてついてくる(語が尾を引いて伸びる)
				var j := (n - 1 - i) if d.x >= 0.0 else i
				var kc := ease_out((t - j * 0.025) / 0.16)
				off = -d * (1.0 - kc) * px * 0.9 * j
			"shake":
				var amp := px * 0.08
				off = Vector2(sin(t * 61.0 + i * 2.3 + seed) * amp, cos(t * 53.0 + i * 1.7 + seed) * amp)
			"wave":
				off.y = sin(t * 9.0 - i * 0.9 + seed) * px * 0.18
				rot = sin(t * 7.0 - i * 0.9) * 0.12
		var cx := x + w / 2.0 + off.x + shake.x + slide.x
		var cy := rise + off.y + shake.y + slide.y
		var col := Color(color.r, color.g, color.b, a)
		if style == "fly" and t < 0.2:
			# 残像: 来た向きに薄い文字を二つ
			for g: int in [2, 1]:
				var ga: float = a * 0.22 * (1.0 - t / 0.2) * (3 - g) / 2.0
				ci.draw_set_transform(origin + Vector2(cx, cy) - d * px * 0.7 * g, rot, Vector2(cs, cs))
				ci.draw_string(font, Vector2(-w / 2.0, px * 0.35), chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), Color(color.r, color.g, color.b, ga))
		ci.draw_set_transform(origin + Vector2(cx, cy), rot, Vector2(cs, cs) * sq)
		ci.draw_string_outline(font, Vector2(-w / 2.0, px * 0.35), chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), outline, Color(0.05, 0.03, 0.06, 0.9 * a))
		ci.draw_string(font, Vector2(-w / 2.0, px * 0.35), chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), col)
		x += w + spread
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func split(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in s.length():
		out.append(s.substr(i, 1))
	return out
