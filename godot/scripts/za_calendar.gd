class_name ZaCalendar
extends RefCounted
## 座暦(大陸共通の暦)。潜った夜の数(GameState.day)から、何年何月何夜かを出す。
## 1月は30夜。12月(空座の月)のあとに、月に属さない座渡しが5夜(ここでは13月として扱う)。
## 196年に一度の大閏の年は、空座の月が79夜になる。座暦2352年は、その大閏の年。
## 物語は、座暦2352年 狩人の月(8月)の1夜から始まる。巡りの節(第一節〜第七節の夜)は、迷宮の夜(day % 7)に合わせる。

const START_YEAR := 2352
const START_MONTH := 8
const START_NIGHT := 1
const MONTH_NAMES := ["", "天秩の月", "大地の母の月", "炉火の月", "潮路の月", "誓剣の月", "星録の月",
	"癒しの月", "狩人の月", "灯火の月", "賽の月", "静寂の月", "空座の月", "座渡し"]
const ZAWATASHI := ["", "座降ろし(沈黙の夜)", "母の三夜(一)", "母の三夜(二)", "母の三夜(三)", "座昇り"]
const SETSU := ["第一節", "第二節", "第三節", "第四節", "第五節", "第六節", "第七節"]

static func is_daiuru(year: int) -> bool:
	return year % 196 == 0

## その月の夜の数(13 は座渡し)
static func month_len(year: int, month: int) -> int:
	if month == 13:
		return 5
	if month == 12 and is_daiuru(year):
		return 79
	return 30

## day 夜目の日付 {year, month, night}
static func date(day: int) -> Dictionary:
	var y := START_YEAR
	var m := START_MONTH
	var n := START_NIGHT + maxi(0, day)
	while n > month_len(y, m):
		n -= month_len(y, m)
		m += 1
		if m > 13:
			m = 1
			y += 1
	return {"year": y, "month": m, "night": n}

static func month_name(month: int) -> String:
	return MONTH_NAMES[clampi(month, 1, 13)]

## 「座暦2352年 灯火の月 12夜」。座渡しと、空座の七七夜は名前で
static func label(day: int) -> String:
	var d := date(day)
	var y := int(d["year"])
	var m := int(d["month"])
	var n := int(d["night"])
	if m == 13:
		return "座暦%d年 座渡し %s" % [y, ZAWATASHI[n]]
	var s := "座暦%d年 %s %d夜" % [y, month_name(m), n]
	if m == 12 and n > 30:
		s += "(空座の七七夜)"
	return s

## 巡りの節の名前(迷宮の夜の名と同じ)
static func setsu(day: int) -> String:
	return SETSU[posmod(day, 7)] + "の夜"
