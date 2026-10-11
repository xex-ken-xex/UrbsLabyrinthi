class_name Birth
extends RefCounted
## 生まれ表(ヴェルガ・ノクスのオリジナル)。出身・前職・転機・潜る理由の4つの表をふる。
## ゲームに効くのは前職の技能2つ(5e の背景の技能に当たる)だけで、ほかは読み物。
## 設計: /mnt/project-files/design/birth-tables.md

## text は「〜で生まれ、」につながる形
const ORIGINS := [
	{"name": "壁下区の下の段", "text": "壁下区の下の段の掘っ立て小屋で生まれた。瘴気が濃く、物心ついたころから煤吐きの咳をしていた"},
	{"name": "壁下区の動く家", "text": "壁下区の動く家で生まれた。戸口の色布を目印に、毎朝、自分の家を探した"},
	{"name": "縁環区の店の上", "text": "縁環区の、店の上の住まいで生まれた。一階の店の景気は、迷宮しだいだった"},
	{"name": "縁環区の裏路地", "text": "縁環区の裏路地の、日干しレンガの家で生まれた。家は夜の鐘のたびに、少しずつ動いた"},
	{"name": "川畑の農村", "text": "濯ぎ川沿いの、川畑の農村で生まれた。夜の鐘が鳴っても動かない土地で育った"},
	{"name": "神殿の孤児院", "text": "神殿の孤児院で育った。子守唄「静寂の七息」で眠った"},
	{"name": "傾いた冠環区の家", "text": "冠環区の家に生まれた。ただし、家は傾き、いまは名ばかり"},
	{"name": "よその土地", "text": "大陸のよその土地で生まれ、南街道を、空の荷車に乗ってやってきた"},
]
const JOBS := [
	{"name": "運び屋", "text": "運び屋として、冒険者の荷と戦利品を担いだ", "skills": ["athletics", "survival"]},
	{"name": "灯守", "text": "灯守として、浅層の通路で灯りを守った", "skills": ["perception", "stealth"]},
	{"name": "屑拾い", "text": "屑拾いとして、捨てられた装備や魔物の素材を拾った", "skills": ["investigation", "sleight"]},
	{"name": "死体洗い", "text": "死体洗いとして、遺体を清め、遺品を届けた", "skills": ["medicine", "religion"]},
	{"name": "鍛冶組の徒弟", "text": "鍛冶組の徒弟として、燐晶の炉の番をした", "skills": ["athletics", "arcana"]},
	{"name": "薬師組の見習い", "text": "薬師組の見習いとして、薬草と解毒を学んだ", "skills": ["medicine", "nature"]},
	{"name": "地図屋の見習い", "text": "地図屋の見習いとして、夜明け前の路地を歩いて地図を描いた", "skills": ["investigation", "history"]},
	{"name": "下級官吏", "text": "下級官吏として、許可証と徴税の帳面をつけた", "skills": ["insight", "deception"]},
	{"name": "闇潜り", "text": "闇潜りとして、許可証なしで浅層に潜った", "skills": ["stealth", "acrobatics"]},
	{"name": "館の下働き", "text": "寝息通りの館の下働きとして、客の相手をし、歌を覚えた", "skills": ["performance", "persuasion"]},
	{"name": "川畑の農夫", "text": "川畑の農夫として、荷を引く獣の世話をした", "skills": ["animal", "nature"]},
	{"name": "見習い僧兵", "text": "護印団の見習い僧兵として、静印塔の守りについた", "skills": ["religion", "intimidation"]},
]
const TURNS := [
	{"name": "封鎖令", "text": "封鎖令が出て、身内が迷宮に取り残された"},
	{"name": "うねり", "text": "うねりが壁下区を襲い、家を失った"},
	{"name": "はぐれた家族", "text": "夜の鐘で家が動き、家族とはぐれたまま会えていない"},
	{"name": "相棒の裏切り", "text": "相棒に裏切られ、遺品を奪われかけた"},
	{"name": "消えた仲間", "text": "闇潜りの仲間が、迷宮から「何か」を持ち帰った夜から、姿を消した"},
	{"name": "煤吐き", "text": "煤吐きをわずらい、長くは働けないと言われた"},
	{"name": "推薦人", "text": "思いがけず推薦人が見つかり、許可証を手にした"},
	{"name": "目覚めの徒", "text": "目覚めの徒の集まりに誘われ、そこから逃げ出した"},
]
## text は「いまは〜」につながる形
const REASONS := [
	{"name": "借金", "text": "許可証の保証金に借りた金を返すために潜る"},
	{"name": "空席の杯", "text": "帰らなかった者を探して潜る。酒場には、その人の空席の杯がまだある"},
	{"name": "上へ", "text": "壁下区から上へ上がるために潜る"},
	{"name": "仕送り", "text": "家族に燐晶を仕送りするために潜る"},
	{"name": "第五層の噂", "text": "第五層で死んだはずの者を見た、という噂を確かめるために潜る"},
	{"name": "大閏の年", "text": "大閏の年に何が起きるのかを、自分の目で見るために潜る"},
	{"name": "名を伏せた依頼", "text": "冠環区の誰かに、名を伏せて頼まれて潜る"},
	{"name": "ほかに道がない", "text": "ほかに生きる道がないから潜る"},
]
const KEYS := ["origin", "job", "turn", "reason"]
const KEY_JP := {"origin": "出身", "job": "前職", "turn": "転機", "reason": "潜る理由"}

static func table(key: String) -> Array:
	match key:
		"origin": return ORIGINS
		"job": return JOBS
		"turn": return TURNS
	return REASONS

static func roll(rng: RandomNumberGenerator = null) -> Dictionary:
	var out := {}
	for k in KEYS:
		var n := table(k).size()
		out[k] = rng.randi_range(0, n - 1) if rng else randi_range(0, n - 1)
	return out

static func valid(b: Dictionary) -> bool:
	for k in KEYS:
		if not b.has(k):
			return false
		var i := int(b[k])
		if i < 0 or i >= table(k).size():
			return false
	return true

static func sanitize(d) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var out := {}
	for k in KEYS:
		out[k] = int((d as Dictionary).get(k, -1))
	return out if valid(out) else {}

static func job_skills(b: Dictionary) -> Array:
	if not valid(b):
		return []
	return (JOBS[int(b["job"])]["skills"] as Array).duplicate()

static func text(b: Dictionary) -> String:
	if not valid(b):
		return ""
	return "%s。%s。%s。いまは、%s。" % [ORIGINS[int(b["origin"])]["text"], JOBS[int(b["job"])]["text"],
		TURNS[int(b["turn"])]["text"], REASONS[int(b["reason"])]["text"]]

## 前職の技能を、生い立ちの2つにした技能の選び方を返す。
## クラスの分は、いまの選び方からなるべく残す。前職の技能がクラスや種族と重なったら、5e の背景と同じく別の技能で埋める
static func apply_to_picks(b: Dictionary, cls: String, race: String, picks: Array) -> Array:
	var js := job_skills(b)
	if js.is_empty():
		return picks
	var cp: Dictionary = Talents.CLASS_PROF[cls]
	var from: Array = cp["from"]
	var cnt := int(cp["count"])
	var fixed: Array = Talents.RACE_PROF.get(race, [])
	var cls_part: Array = []
	# 前職の技能がクラスの一覧にあれば、それもクラスの分に数えてよい(重なりが減る)
	for src in [picks, Talents.DEFAULT_PICKS[cls], from]:
		for p in src:
			if cls_part.size() >= cnt:
				break
			if from.has(p) and not fixed.has(p) and not cls_part.has(p) and not js.has(p):
				cls_part.append(p)
	var out := cls_part.duplicate()
	for p in js:
		if not fixed.has(p) and not out.has(p):
			out.append(p)
	# 重なって足りない分は、いま選んでいる技能、それから一覧の順で埋める
	var need := cnt + Talents.BACKGROUND_COUNT
	for src in [picks, Talents.SKILL_ORDER]:
		for p in src:
			if out.size() >= need:
				break
			if not fixed.has(p) and not out.has(p):
				out.append(p)
	return out
