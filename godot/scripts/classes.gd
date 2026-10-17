class_name Jobs
extends RefCounted
## 種族、クラス、スキルの定義。数値は初版の設計値で、遊んで直す前提。
## 能力値の補正は 5e と同じ(能力値−10)÷2 の切り捨て。

const ABILS := ["str", "dex", "con", "int", "wis", "cha"]
const ABIL_JP := {"str": "筋力", "dex": "敏捷", "con": "耐久", "int": "知力", "wis": "判断", "cha": "魅力"}

const RACES := {
	"human": {"name": "人間", "bonus": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}, "hp_lv": 0.0, "light": 0,
		"desc": "万能。全能力値+1。縁環区にも壁下区にも多い。"},
	"elf": {"name": "エルフ", "bonus": {"dex": 2, "int": 1}, "hp_lv": 0.0, "light": 1,
		"desc": "敏捷+2、知力+1。暗がりに強く、灯りの届く半径が+1マス。"},
	"dwarf": {"name": "ドワーフ", "bonus": {"con": 2, "str": 1}, "hp_lv": 1.0, "light": 0,
		"desc": "耐久+2、筋力+1。頑健で、レベルごとにHP+1。鍛冶組に多い。"},
	"halfling": {"name": "ハーフリング", "bonus": {"dex": 2, "cha": 1}, "hp_lv": 0.0, "light": 0,
		"desc": "敏捷+2、魅力+1。小柄で素早く、運び屋に多い。"},
}

## hit: ヒットダイス / bump: 体当たりの基礎火力 / atk: 体当たりに効く能力値 / cast: 技の威力に効く能力値
## armor: 着られる鎧の種類 / weapons: 使える武器の種類 / skills: [習得レベル, スキルid]
const CLASSES := {
	"fighter": {"name": "戦士", "hit": 10, "bump": 6.0, "atk": "str", "cast": "str", "mp0": 4, "mp_lv": 1.5,
		"prime": ["str", "con", "dex", "wis", "cha", "int"],
		"armor": ["none", "light", "medium", "heavy"], "weapons": ["sword", "axe", "blunt", "spear", "dagger"],
		"skills": [[1, "rush"], [2, "power_up"], [4, "ironwall"], [6, "sweep"]],
		"color": "d9a441",
		"desc": "前に出て押し込む。HPと体当たりが高く、重い鎧を着られる。"},
	"barbarian": {"name": "蛮族", "hit": 12, "bump": 6.5, "atk": "str", "cast": "str", "mp0": 3, "mp_lv": 1.2,
		"prime": ["str", "con", "dex", "wis", "cha", "int"],
		"armor": ["none", "light", "medium"], "weapons": ["axe", "sword", "blunt", "spear"],
		"skills": [[1, "rage"], [2, "charge"], [4, "roar"], [6, "quake"]],
		"color": "c4513a",
		"desc": "HPがもっとも多い。激昂で押し込みを一気に強める。"},
	"rogue": {"name": "盗賊", "hit": 8, "bump": 4.5, "atk": "dex", "cast": "dex", "mp0": 4, "mp_lv": 1.6,
		"prime": ["dex", "con", "cha", "int", "wis", "str"],
		"armor": ["none", "light"], "weapons": ["dagger", "sword", "bow"],
		"skills": [[1, "knife"], [2, "haste"], [3, "smoke"], [5, "crit"]],
		"color": "7a8ca8",
		"desc": "素早い。技能の習熟が多く、盗賊道具で解錠と罠の解除ができる。急所突きで一撃を狙う。"},
	"wizard": {"name": "魔術師", "hit": 6, "bump": 2.5, "atk": "int", "cast": "int", "mp0": 10, "mp_lv": 3.2,
		"prime": ["int", "con", "dex", "wis", "cha", "str"],
		"armor": ["none"], "weapons": ["staff", "dagger"],
		"skills": [[1, "bolt"], [3, "fireball"], [5, "frost"], [7, "thunder"]],
		"color": "8a6ad0",
		"desc": "HPは低いが、魔弾と火球で遠くから削る。MPが多い。"},
	"cleric": {"name": "僧侶", "hit": 8, "bump": 3.5, "atk": "wis", "cast": "wis", "mp0": 8, "mp_lv": 2.6,
		"prime": ["wis", "con", "str", "cha", "dex", "int"],
		"armor": ["none", "light", "medium"], "weapons": ["blunt", "staff"],
		"skills": [[1, "heal"], [2, "smite"], [3, "bless"], [5, "mass_heal"]],
		"color": "e8e4c8",
		"desc": "味方を癒し、聖撃で押し返す。PTに一人は欲しい。"},
	"ranger": {"name": "野伏", "hit": 10, "bump": 4.0, "atk": "dex", "cast": "dex", "mp0": 5, "mp_lv": 1.8,
		"prime": ["dex", "con", "wis", "str", "int", "cha"],
		"armor": ["none", "light", "medium"], "weapons": ["bow", "sword", "dagger", "spear", "axe"],
		"skills": [[1, "arrow"], [2, "triple"], [4, "snare"], [6, "snipe"]],
		"color": "5fa05a",
		"desc": "弓で戦い、足止めの矢で押し込みを助ける。〈知覚〉や〈隠密〉など、技能の習熟が多い。"},
}

## kind: projectile / burst_self / burst_ahead / rush / buff_self / buff_party / heal / heal_all / regen_party
## dmg + 補正×stat + レベル×lv が威力。slow / stun は魔物を遅くする・止める秒数。
const SKILLS := {
	"rush": {"name": "突進", "mp": 3, "cd": 5.0, "kind": "rush", "dmg": 5.0, "stat": 0.8, "lv": 1.0, "dist": 150.0, "knock": 220.0,
		"desc": "前へ突っ込み、当たった敵を弾き飛ばす。突進中は無敵。"},
	"power_up": {"name": "気合", "mp": 3, "cd": 14.0, "kind": "buff_self", "dur": 8.0, "mult": {"power": 1.7},
		"desc": "8秒間、体当たりの威力が1.7倍。"},
	"ironwall": {"name": "鉄壁", "mp": 4, "cd": 16.0, "kind": "buff_self", "dur": 6.0, "mult": {"guard": 0.35, "mass": 2.0},
		"desc": "6秒間、受けるダメージが大きく減り、押されにくくなる。"},
	"sweep": {"name": "薙ぎ払い", "mp": 5, "cd": 9.0, "kind": "burst_self", "dmg": 7.0, "stat": 0.8, "lv": 1.2, "radius": 72.0, "knock": 150.0,
		"desc": "周囲の敵をまとめて斬り、弾き飛ばす。"},
	"rage": {"name": "激昂", "mp": 4, "cd": 18.0, "kind": "buff_self", "dur": 8.0, "mult": {"power": 1.9, "guard": 0.75},
		"desc": "8秒間、体当たりが1.9倍になり、受けるダメージも減る。"},
	"charge": {"name": "猛進", "mp": 5, "cd": 8.0, "kind": "rush", "dmg": 9.0, "stat": 1.0, "lv": 1.4, "dist": 200.0, "knock": 300.0,
		"desc": "長い距離を突っ込み、敵を大きく弾く。"},
	"roar": {"name": "咆哮", "mp": 4, "cd": 12.0, "kind": "burst_self", "dmg": 2.0, "stat": 0.3, "lv": 0.4, "radius": 96.0, "knock": 170.0, "slow": 3.0,
		"desc": "周囲の敵を怯ませて遅くし、押し返す。"},
	"quake": {"name": "地鳴らし", "mp": 7, "cd": 10.0, "kind": "burst_self", "dmg": 12.0, "stat": 1.0, "lv": 1.6, "radius": 104.0, "knock": 190.0,
		"desc": "地面を叩いて、周囲に大ダメージ。"},
	"knife": {"name": "投げナイフ", "mp": 1, "cd": 0.5, "kind": "projectile", "dmg": 4.0, "stat": 0.9, "lv": 0.8, "range": 240.0, "speed": 380.0,
		"desc": "素早くナイフを投げる。"},
	"haste": {"name": "速攻", "mp": 3, "cd": 12.0, "kind": "buff_self", "dur": 7.0, "mult": {"speed": 1.35, "power": 1.25},
		"desc": "7秒間、足が速くなり、体当たりも少し強まる。"},
	"smoke": {"name": "煙玉", "mp": 3, "cd": 12.0, "kind": "burst_self", "dmg": 0.0, "radius": 90.0, "slow": 4.0, "knock": 0.0,
		"desc": "周囲の敵を4秒間、遅くする。"},
	"crit": {"name": "急所突き", "mp": 4, "cd": 14.0, "kind": "buff_self", "dur": 5.0, "mult": {"power": 2.4},
		"desc": "5秒間、体当たりが2.4倍。"},
	"bolt": {"name": "魔弾", "mp": 2, "cd": 0.6, "kind": "projectile", "dmg": 5.0, "stat": 1.0, "lv": 1.0, "range": 260.0, "speed": 340.0, "spell": true,
		"desc": "魔力の弾を撃つ。"},
	"fireball": {"name": "火球", "mp": 6, "cd": 5.0, "kind": "burst_ahead", "dmg": 11.0, "stat": 1.2, "lv": 1.6, "radius": 68.0, "ahead": 110.0, "knock": 120.0, "spell": true, "elem": "fire",
		"desc": "前方で爆ぜる火の玉。範囲ダメージ。"},
	"frost": {"name": "氷結", "mp": 6, "cd": 7.0, "kind": "burst_ahead", "dmg": 6.0, "stat": 0.8, "lv": 1.0, "radius": 76.0, "ahead": 100.0, "slow": 5.0, "spell": true, "elem": "cold",
		"desc": "前方を凍らせる。敵を5秒間、遅くする。"},
	"thunder": {"name": "雷光", "mp": 7, "cd": 6.0, "kind": "projectile", "dmg": 14.0, "stat": 1.3, "lv": 1.8, "range": 360.0, "speed": 460.0, "pierce": true, "spell": true, "elem": "lightning",
		"desc": "敵を貫く雷。一列をまとめて撃つ。"},
	"heal": {"name": "治癒", "mp": 3, "cd": 2.0, "kind": "heal", "amount": 12.0, "stat": 1.6, "lv": 2.0, "range": 260.0, "spell": true,
		"desc": "もっとも傷ついた仲間のHPを回復する。"},
	"smite": {"name": "聖撃", "mp": 3, "cd": 6.0, "kind": "burst_self", "dmg": 6.0, "stat": 1.0, "lv": 1.2, "radius": 66.0, "knock": 130.0, "spell": true, "elem": "radiant",
		"desc": "周囲に聖なる衝撃を放ち、敵を押し返す。"},
	"bless": {"name": "祝福", "mp": 5, "cd": 25.0, "kind": "buff_party", "dur": 15.0, "mult": {"power": 1.25, "guard": 0.8}, "spell": true,
		"desc": "15秒間、仲間全員の体当たりが強まり、受けるダメージが減る。"},
	"mass_heal": {"name": "大治癒", "mp": 8, "cd": 12.0, "kind": "heal_all", "amount": 8.0, "stat": 1.0, "lv": 1.6, "spell": true,
		"desc": "仲間全員のHPを回復する。"},
	"arrow": {"name": "速射", "mp": 1, "cd": 0.45, "kind": "projectile", "dmg": 4.0, "stat": 1.0, "lv": 0.9, "range": 300.0, "speed": 440.0,
		"desc": "矢を素早く放つ。"},
	"triple": {"name": "三連射", "mp": 4, "cd": 4.0, "kind": "projectile", "dmg": 4.0, "stat": 0.8, "lv": 0.8, "range": 280.0, "speed": 440.0, "count": 3, "spread": 0.26,
		"desc": "矢を三方向へ同時に放つ。"},
	"snare": {"name": "足止めの矢", "mp": 3, "cd": 6.0, "kind": "projectile", "dmg": 4.0, "stat": 0.8, "lv": 0.8, "range": 300.0, "speed": 420.0, "slow": 4.0,
		"desc": "当たった敵を4秒間、遅くする。"},
	"snipe": {"name": "狙撃", "mp": 6, "cd": 7.0, "kind": "projectile", "dmg": 13.0, "stat": 1.2, "lv": 1.6, "range": 420.0, "speed": 520.0, "pierce": true,
		"desc": "敵を貫く強力な一矢。"},
	# 魔法屋で買える呪文書で覚える
	"mana_shield": {"name": "魔法の盾", "mp": 4, "cd": 18.0, "kind": "buff_self", "dur": 8.0, "mult": {"guard": 0.5}, "spell": true,
		"desc": "8秒間、受けるダメージが半分になる。"},
	"sleep": {"name": "眠りの雲", "mp": 4, "cd": 10.0, "kind": "burst_ahead", "dmg": 0.0, "radius": 80.0, "ahead": 110.0, "slow": 3.0, "stun": 3.0, "spell": true,
		"desc": "前方の敵を3秒間、眠らせて動けなくする。"},
	"regen_light": {"name": "再生の光", "mp": 6, "cd": 20.0, "kind": "regen_party", "dur": 12.0, "amount": 1.0, "stat": 0.4, "spell": true,
		"desc": "12秒間、仲間全員のHPがじわじわ回復する。"},
	# 武器の技(装備している武器の種類で決まる。WEAPON_TECH。珍しい武器は items.gd の tech で固有の技)
	# kind strike: 正面へ打つ。reach(体の縁から届く画素)、arc(左右の角度)、hits(当たる回数)、stun / slow / sunder(被ダメージ増の秒)
	"w_spin": {"name": "回転斬り", "mp": 3, "cd": 8.0, "kind": "burst_self", "dmg": 6.0, "stat": 0.8, "lv": 1.0, "radius": 60.0, "knock": 140.0, "weapon": true,
		"desc": "剣の技。その場で回り、周りの敵をまとめて斬る。"},
	"w_twin": {"name": "二連突き", "mp": 2, "cd": 4.0, "kind": "strike", "dmg": 3.0, "stat": 0.7, "lv": 0.6, "reach": 20.0, "arc": 35.0, "hits": 2, "weapon": true,
		"desc": "短剣の技。正面の敵を素早く二度突く。"},
	"w_cleave": {"name": "叩き割り", "mp": 3, "cd": 8.0, "kind": "strike", "dmg": 7.0, "stat": 0.9, "lv": 1.1, "reach": 24.0, "arc": 50.0, "sunder": 6.0, "knock": 120.0, "weapon": true,
		"desc": "斧の技。重い一撃で守りを割り、6秒間、受けるダメージを増やす。"},
	"w_stun": {"name": "気絶打ち", "mp": 3, "cd": 8.0, "kind": "strike", "dmg": 4.0, "stat": 0.7, "lv": 0.8, "reach": 22.0, "arc": 45.0, "stun": 1.5, "knock": 160.0, "weapon": true,
		"desc": "鈍器の技。頭を打ち、1.5秒間、気絶させる。"},
	"w_pierce": {"name": "突き通し", "mp": 3, "cd": 6.0, "kind": "strike", "dmg": 6.0, "stat": 0.9, "lv": 1.0, "reach": 80.0, "arc": 10.0, "knock": 160.0, "weapon": true,
		"desc": "槍の技。一列に並んだ敵をまとめて、遠くまで突き通す。"},
	"w_aim": {"name": "狙い撃ち", "mp": 3, "cd": 6.0, "kind": "projectile", "dmg": 9.0, "stat": 1.1, "lv": 1.2, "range": 400.0, "speed": 560.0, "pierce": true, "weapon": true,
		"desc": "弓の技。狙いを定めた一矢が、敵を貫いて遠くまで飛ぶ。"},
	"w_focus": {"name": "魔力の溜め", "mp": 0, "cd": 20.0, "kind": "buff_self", "dur": 8.0, "mult": {"spell": 1.4}, "weapon": true,
		"desc": "杖の技。8秒間、呪文の威力が1.4倍になる。"},
	# 珍しい武器の固有の技
	"w_shadow": {"name": "影縫い", "mp": 3, "cd": 7.0, "kind": "strike", "dmg": 3.0, "stat": 0.7, "lv": 0.6, "reach": 20.0, "arc": 40.0, "hits": 3, "stun": 0.8, "weapon": true,
		"desc": "影縫いの短剣の技。影を三度刺し、0.8秒間、縫い止める。"},
	"w_rend": {"name": "大地割り", "mp": 5, "cd": 10.0, "kind": "burst_ahead", "dmg": 11.0, "stat": 1.0, "lv": 1.4, "radius": 70.0, "ahead": 50.0, "knock": 220.0, "sunder": 6.0, "weapon": true,
		"desc": "坑夫の大鶴嘴の技。前の床ごと叩き割り、まわりの敵の守りも割る。"},
	"w_comet": {"name": "流星投げ", "mp": 4, "cd": 7.0, "kind": "projectile", "dmg": 12.0, "stat": 1.0, "lv": 1.4, "range": 360.0, "speed": 600.0, "pierce": true, "slow": 2.0, "weapon": true,
		"desc": "流星の槍の技。光る穂先を投げ、一列を貫いて足を止める(槍は手元に戻る)。"},
	"flash": {"name": "閃光", "mp": 4, "cd": 12.0, "kind": "burst_self", "dmg": 0.0, "radius": 100.0, "stun": 1.8, "spell": true,
		"desc": "周囲の敵を1.8秒間、怯ませて止める。"},
}

## 武器の種類 → 武器の技
const WEAPON_TECH := {"sword": "w_spin", "dagger": "w_twin", "axe": "w_cleave", "blunt": "w_stun", "spear": "w_pierce", "bow": "w_aim", "staff": "w_focus"}

static func class_color(cls: String) -> Color:
	return Color.html(String(CLASSES[cls]["color"]))

static func class_initial(cls: String) -> String:
	return String(CLASSES[cls]["name"]).substr(0, 1)

## 標準配列(15,14,13,12,10,8)を、クラスの優先順に割り振る
static func auto_stats(cls: String) -> Dictionary:
	var arr := [15, 14, 13, 12, 10, 8]
	var out := {}
	var prime: Array = CLASSES[cls]["prime"]
	for i in prime.size():
		out[prime[i]] = arr[i]
	return out

## ポイントバイ(27点)。8〜15。コストは 8:0 9:1 10:2 11:3 12:4 13:5 14:7 15:9
static func point_cost(v: int) -> int:
	if v <= 13:
		return v - 8
	return (v - 8) + (v - 13)

static func points_used(stats: Dictionary) -> int:
	var t := 0
	for a in ABILS:
		t += point_cost(int(stats[a]))
	return t
