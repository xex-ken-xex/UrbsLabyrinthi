class_name CueText
extends RefCounted
## 擬音の文字を、一文字ずつ動かして描く(Sfx、DiceFx、UnlockFx が使う)。
## 動き方の名前は Sfx の説明を見る。t は出てからの秒、life は消えるまでの秒、px は文字の大きさ。
## dir は drop / roll / fly の向き(転がる・飛ぶ向き。ZERO なら右へ)。
## 動きの緩急はリリックモーション(歌詞を動かす文字の映像)の手を借りた: 行き過ぎて戻る、速く出て遅く止まる。
## 語末の標識(ッ = 収束、ン = 余韻。陳 2022)はどの動き方にも「仕上げ」として足す: ッ で終わる語は最後の字が
## 叩き込まれて止まり、ン で終わる語は出きったあとに揺れ戻す。flutter / stagger / tremble / loom は
## ゲーム・映像・SNS の用例から(tools/onomatopoeia/docs/05)。

## 行き過ぎて戻る(0→1)
static func ease_back(k: float, over: float = 1.7) -> float:
	k = clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + k * k * ((over + 1.0) * k + over)

## 速く出て、ゆっくり止まる(0→1)
static func ease_out(k: float) -> float:
	k = 1.0 - clampf(k, 0.0, 1.0)
	return 1.0 - k * k * k

## 語末の標識: "ッ"(収束)/ "ン"(余韻)/ ""。! ? は読み飛ばす。戻り値は [標識, その字の番号]
static func ending(chars: PackedStringArray) -> Array:
	var i := chars.size() - 1
	while i >= 0 and (chars[i] == "!" or chars[i] == "?" or chars[i] == "！" or chars[i] == "？"):
		i -= 1
	if i < 0:
		return ["", -1]
	var c := chars[i].unicode_at(0)
	if c == 0x30C3 or c == 0x3063:          # ッ っ
		return ["ッ", i]
	if c == 0x30F3 or c == 0x3093:          # ン ん
		return ["ン", i]
	return ["", i]

## 動き方ごとの、一文字ずつ出る間(秒)
static func char_delay(style: String) -> float:
	match style:
		"bounce": return 0.06
		"stretch", "roll": return 0.07
		"drop": return 0.05
		"stagger": return 0.04
	return 0.0

## 音節の番号(小書き・ー・濁点・読点は前の字につく)。flutter が使う
static func syllables(chars: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	var k := -1
	for i in chars.size():
		var c := chars[i].unicode_at(0)
		var small := c in [0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3083, 0x3085, 0x3087, 0x308E, 0x30FC, 0x301C, 0xFF5E, 0x2026, 0x3001, 0x3099, 0x309A, 0x30C3, 0x3063]
		if i == 0 or not small:
			k += 1
		out.append(maxi(k, 0))
	return out

## 0〜1 の決まった乱数(字の番号と種から)
static func hash01(i: int, seed: float, salt: float = 0.0) -> float:
	var v := sin(float(i) * 12.9898 + seed * 7.13 + salt) * 43758.5453
	return v - floor(v)

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
		"wave", "bounce", "flutter":
			rise = -t * 10.0
		"stagger":
			# 一字ずつ大きく叩き込む(ペルソナ5 の総攻撃)。語全体も出た直後は揺れる
			var sk2 := maxf(0.0, 1.0 - t / 0.4) * (4.0 if big else 2.5)
			shake = Vector2(sin(t * 80.0 + seed) * sk2, cos(t * 70.0 + seed) * sk2)
			rise = -maxf(0.0, t - 0.4) * 8.0
		"tremble":
			# 震えが時間とともに強くなる(Celeste の叫ぶ台詞、ガクブル)
			scale = lerpf(1.0, 1.08, clampf(t / 1.0, 0.0, 1.0))
			rise = -t * 5.0
		"loom":
			# 字がばらばらの高さに散って、ゆっくり漂う気配(JoJo の ゴゴゴゴ)
			var kl := clampf(t / 0.6, 0.0, 1.0)
			scale = lerpf(0.8, 1.05, kl)
			fade *= kl
			spread = px * 0.1
			rise = -t * px * 0.25
	var endm: Array = ending(chars)
	var dly := char_delay(style)
	var syl := syllables(chars) if style == "flutter" else PackedInt32Array()
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
			"flutter":
				# 音節ごとに左右へ向きを変えて舞う(ひらひら、カラン、コロン)
				var sy := syl[i]
				var tf := t - sy * 0.12
				if tf < 0.0:
					x += w + spread
					continue
				var sg := -1.0 if sy % 2 == 0 else 1.0
				var kf2 := sin(clampf(tf / 0.5, 0.0, 1.0) * PI)
				off.x = sg * kf2 * px * 0.5
				off.y = -sin(tf * 8.0 - sy * 1.2) * px * 0.15
				rot = sg * kf2 * 0.3
				a *= clampf(tf / 0.08, 0.0, 1.0)
			"stagger":
				var tg := t - i * dly
				if tg < 0.0:
					x += w + spread
					continue
				var kg := ease_back(tg / 0.2, 2.2)
				cs = lerpf(3.0, 1.0, kg)
				rot = (-1.0 if i % 2 == 0 else 1.0) * lerpf(0.4, 0.12, kg)
				off.y = -(1.0 - kg) * px * 0.5
			"tremble":
				var amp2 := px * lerpf(0.04, 0.16, clampf(t / 1.0, 0.0, 1.0))
				off = Vector2(sin(t * 61.0 + i * 2.3 + seed) * amp2, cos(t * 53.0 + i * 1.7 + seed) * amp2)
			"loom":
				off.x = (hash01(i, seed, 1.0) - 0.5) * px * 0.5
				off.y = (hash01(i, seed, 2.0) - 0.5) * px * 1.8
				rot = (hash01(i, seed, 3.0) - 0.5) * 0.5
		# 語末の仕上げ: ッ で終わる語は最後の字が叩き込まれて止まる、ン で終わる語は出きったあとに揺れ戻す
		if endm[0] == "ッ" and i == endm[1] and style != "slam" and style != "stagger":
			var te := t - i * dly
			if te >= 0.0:
				cs *= lerpf(1.7, 1.0, ease_out(te / 0.09))
		elif endm[0] == "ン" and style != "shake" and style != "wave" and style != "tremble":
			var tn := t - ((n - 1) * dly + 0.15)
			if tn > 0.0:
				rot += sin(tn * 14.0) * 0.08 * exp(-tn * 4.0)
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

## 一文字ずつに切る。濁点・半濁点(U+3099 U+309A、半角の ﾞ ﾟ)は前の字にくっつけて一字にする(ギンッ゙! の ッ゙)
static func split(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in s.length():
		var c := s.unicode_at(i)
		if (c == 0x3099 or c == 0x309A or c == 0xFF9E or c == 0xFF9F) and out.size() > 0:
			out[out.size() - 1] += s.substr(i, 1)
		else:
			out.append(s.substr(i, 1))
	return out
