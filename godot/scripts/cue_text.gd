class_name CueText
extends RefCounted
## 擬音の文字を、一文字ずつ動かして描く(Sfx、DiceFx、UnlockFx が使う)。
## 動き方の名前は Sfx の説明を見る。t は出てからの秒、life は消えるまでの秒、px は文字の大きさ。

## 一語を、origin を中心に描く
static func draw_word(ci: CanvasItem, chars: PackedStringArray, style: String, t: float, life: float, px: float, color: Color, seed: float = 0.0, big: bool = false, origin: Vector2 = Vector2.ZERO) -> void:
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
	match style:
		"pop":
			scale = 1.0 + 0.3 * (1.0 - clampf(t / 0.12, 0.0, 1.0))
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
			var k2 := clampf(t / 0.09, 0.0, 1.0)
			shake.x = -(1.0 - k2) * px * 2.0
			tilt = -0.18 * (1.0 - k2) - 0.05
			rise = -t * 8.0
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
				cs = lerpf(0.4, 1.0, clampf(ts / 0.12, 0.0, 1.0))
				a *= clampf(ts / 0.08, 0.0, 1.0)
			"shake":
				var amp := px * 0.08
				off = Vector2(sin(t * 61.0 + i * 2.3 + seed) * amp, cos(t * 53.0 + i * 1.7 + seed) * amp)
			"wave":
				off.y = sin(t * 9.0 - i * 0.9 + seed) * px * 0.18
				rot = sin(t * 7.0 - i * 0.9) * 0.12
		var cx := x + w / 2.0 + off.x + shake.x
		var cy := rise + off.y + shake.y
		ci.draw_set_transform(origin + Vector2(cx, cy), rot, Vector2(cs, cs))
		var col := Color(color.r, color.g, color.b, a)
		ci.draw_string_outline(font, Vector2(-w / 2.0, px * 0.35), chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), outline, Color(0.05, 0.03, 0.06, 0.9 * a))
		ci.draw_string(font, Vector2(-w / 2.0, px * 0.35), chars[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), col)
		x += w + spread
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func split(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in s.length():
		out.append(s.substr(i, 1))
	return out
