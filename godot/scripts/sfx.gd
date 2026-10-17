class_name Sfx
extends Node2D
## ベタな擬音の文字(「ギィ…」「バチン!」)。このゲームの手ごたえの本体(ken 10/16: 音は入れない)。
## 文字は擬音用のフォント(UI.cue_font)で、一文字ずつ動く。動き方は STYLE(擬音ごと)で決める:
##   pop 弾けて浮く / slam 大きく叩きつけて縮み、揺れる / bounce 一文字ずつ跳ねながら出る /
##   shake 震え続ける / stretch 一文字ずつ伸びて出る(… や ー が間延びする) / soft ふわっと出て消える /
##   snap 横から素早く滑り込む / wave 波打つ

const CUES := {
	"door": ["ギィ…", Color(0.9, 0.85, 0.75)],
	"door_secret": ["ゴゴゴ…", Color(0.85, 0.8, 1.0)],
	"unlock": ["カチリ", Color(1.0, 0.92, 0.6)],
	"unlock_fail": ["ガチャガチャッ", Color(1.0, 0.6, 0.55)],
	"trap": ["バチン!", Color(1.0, 0.45, 0.4)],
	"trap_alarm": ["キィィィ!", Color(1.0, 0.7, 0.4)],
	"trap_found": ["おや?", Color(1.0, 0.85, 0.5)],
	"disarm": ["カチッ", Color(0.6, 0.9, 0.6)],
	"disarm_fail": ["ガキッ", Color(1.0, 0.65, 0.5)],
	"corpse": ["ゴソゴソ", Color(0.8, 0.8, 0.75)],
	"drink": ["ゴクリ", Color(0.6, 0.9, 0.7)],
	"stairs": ["コツ、コツ…", Color(0.85, 0.85, 0.9)],
	"search": ["ペタペタ", Color(0.75, 0.8, 0.85)],
	"rest": ["パチパチ…", Color(1.0, 0.75, 0.45)],
	"crystal": ["キラッ", Color(0.75, 0.95, 1.0)],
	"crystal_big": ["ゴロッ", Color(0.75, 0.95, 1.0)],
	"stun": ["ピヨピヨ", Color(1.0, 0.95, 0.55)],
	"sunder": ["バキッ", Color(1.0, 0.7, 0.45)],
	"exhale": ["ゴオォォ…", Color(1.0, 0.55, 0.45)],
	"sealed": ["ズン…", Color(0.85, 0.7, 0.95)],
	"charge_full": ["キン", Color(1.0, 0.92, 0.55)],
	# 料理(Cooking)
	"sizzle": ["ジュウ…", Color(1.0, 0.75, 0.45)],
	"simmer": ["グツグツ", Color(0.95, 0.8, 0.55)],
	"burnt": ["プスプス…", Color(0.6, 0.55, 0.55)],
	"munch": ["モグモグ", Color(1.0, 0.88, 0.65)],
	"growl": ["ぐぅ〜", Color(0.95, 0.85, 0.7), 0.85],
	"growl_hard": ["ぐぎゅるる〜", Color(1.0, 0.7, 0.6)],
	"bellyache": ["ギュルル…", Color(0.7, 0.85, 0.5)],
	"charge_hit": ["ドンッ!", Color(1.0, 0.7, 0.4)],
	"charge_miss": ["ブンッ", Color(0.85, 0.85, 0.9)],
	# 罠(TrapFx と Main._trigger_trap)。3つ目の数は、文字の大きさの倍率
	"click": ["カチッ", Color(1.0, 0.8, 0.5)],
	"fuse": ["シュウゥ…", Color(1.0, 0.7, 0.4)],
	"boom": ["どかーーーーん!", Color(1.0, 0.55, 0.25), 2.4],
	"spikes": ["ジャキン", Color(0.9, 0.9, 1.0)],
	"rumble": ["ゴロゴロゴロ…", Color(0.85, 0.75, 0.6), 1.3],
	"smash": ["ドガッ", Color(1.0, 0.6, 0.4), 1.3],
	"creak": ["ミシッ", Color(0.85, 0.75, 0.6)],
	"rubble": ["ガラガラッ", Color(0.85, 0.75, 0.6), 1.3],
	"thud": ["ドスン", Color(0.9, 0.7, 0.5), 1.3],
	"clang": ["ガシャン", Color(1.0, 0.65, 0.35)],
	"flame": ["ゴォォッ", Color(1.0, 0.5, 0.2), 1.4],
	"dart": ["ヒュッヒュッ", Color(0.85, 0.9, 0.8)],
	"grind": ["ゴゴゴゴ…", Color(0.85, 0.7, 0.6), 1.4],
	"crush": ["ドゴォン!", Color(1.0, 0.5, 0.35), 1.6],
	"net": ["バサッ", Color(0.85, 0.75, 0.55)],
	"gas": ["シュー…", Color(0.8, 0.75, 0.95)],
	"swing": ["ブォン", Color(0.85, 0.85, 0.95)],
	"jet": ["ゴッ", Color(1.0, 0.55, 0.25)],
	"pit": ["ガコン!", Color(0.85, 0.7, 0.55), 1.2],
	"warp": ["ﾌｯ", Color(0.75, 0.7, 1.0)],
	"warp_out": ["ﾌｯ", Color(0.75, 0.7, 1.0), 0.75],
	"squeak": ["ギシッ", Color(1.0, 0.85, 0.6)],
	"summon": ["ズモモ…", Color(0.8, 0.5, 0.9), 1.3],
	"rust": ["ジュワッ", Color(0.9, 0.55, 0.35)],
	"spin": ["グルン", Color(0.9, 0.85, 1.0)],
	"trip": ["ステン!", Color(1.0, 0.85, 0.6)],
	"spill": ["ジャラ", Color(0.75, 0.95, 1.0)],
	"needle": ["チクッ", Color(0.6, 0.95, 0.5)],
	"poison": ["プシュッ", Color(0.6, 0.95, 0.5)],
	"slide": ["ズザザッ", Color(0.75, 0.85, 0.7)],
	"flash": ["ピカッ", Color(1.0, 1.0, 0.75)],
	"wail": ["オォォ…", Color(0.75, 0.7, 1.0)],
	"chill": ["ヒュオォ…", Color(0.75, 0.9, 1.0)],
	"teeth": ["ガチン!", Color(1.0, 0.7, 0.5)],
	"lift": ["フワッ", Color(0.85, 0.85, 1.0)],
	# 倒れる・起きる・強くなる・倒す・転がる
	"down": ["バタッ", Color(1.0, 0.5, 0.45), 1.2],
	"revive": ["ハッ!", Color(0.7, 1.0, 0.75)],
	"levelup": ["パァァッ", Color(0.6, 0.85, 1.0), 1.2],
	"kill": ["ドサッ", Color(0.8, 0.75, 0.7)],
	"dodge": ["サッ", Color(0.85, 0.9, 1.0), 0.85],
	# 魔物の特徴(MonTraits)
	"ambush": ["ガバッ!", Color(1.0, 0.5, 0.45), 1.2],
	"glue": ["ネチャッ", Color(0.75, 0.9, 0.55)],
	"rise": ["ムクッ", Color(0.8, 0.85, 0.7)],
	"mon_charge": ["ドドドッ", Color(1.0, 0.6, 0.45)],
	"leap": ["ピョン", Color(0.75, 1.0, 0.7)],
	"ram": ["ドカッ!", Color(1.0, 0.55, 0.4), 1.2],
	"burst": ["パンッ!", Color(1.0, 0.7, 0.45), 1.2],
	"emerge": ["スゥ…", Color(0.75, 0.75, 1.0)],
	"sniff": ["クンクン", Color(0.9, 0.85, 0.7)],
	# 冒険日記帳と実績
	"jot": ["サラサラ", Color(0.85, 0.85, 0.75), 0.85],
	"trophy": ["パンパカパーン!", Color(1.0, 0.85, 0.35), 1.3],
	# 迷宮で使う道具
	"glass": ["パリン", Color(0.85, 0.95, 1.0)],
	"ignite": ["ボッ", Color(1.0, 0.8, 0.4)],
	"recall": ["シュワワ…", Color(0.75, 0.85, 1.0)],
	# スキル(SKILL_CUE)
	"sk_rush": ["ダダダッ", Color(1.0, 0.8, 0.55)],
	"sk_power": ["フンッ!", Color(1.0, 0.7, 0.45)],
	"sk_wall": ["ガシィン", Color(0.85, 0.9, 1.0)],
	"sk_sweep": ["ブオンッ", Color(0.9, 0.9, 1.0)],
	"sk_rage": ["ウオォォ!", Color(1.0, 0.45, 0.35), 1.2],
	"sk_charge": ["ドドドッ", Color(1.0, 0.75, 0.5)],
	"sk_roar": ["ガアァッ!", Color(1.0, 0.55, 0.4), 1.3],
	"sk_quake": ["ズズゥン", Color(0.9, 0.75, 0.55), 1.3],
	"sk_throw": ["シュッ", Color(0.9, 0.9, 0.95)],
	"sk_haste": ["シュタッ", Color(0.8, 1.0, 0.9)],
	"sk_smoke": ["ボフッ", Color(0.8, 0.8, 0.85)],
	"sk_stab": ["ズブッ", Color(1.0, 0.55, 0.5)],
	"sk_bolt": ["ピシュン", Color(0.75, 0.8, 1.0)],
	"sk_fire": ["ボウッ", Color(1.0, 0.55, 0.25), 1.2],
	"sk_frost": ["パキパキッ", Color(0.7, 0.9, 1.0)],
	"sk_thunder": ["バリバリッ!", Color(1.0, 1.0, 0.6), 1.2],
	"sk_heal": ["ポワッ", Color(0.6, 1.0, 0.7)],
	"sk_holy": ["カッ!", Color(1.0, 0.95, 0.7), 1.2],
	"sk_bless": ["キラキラ", Color(1.0, 0.95, 0.7)],
	"sk_mass_heal": ["ポワァァ…", Color(0.6, 1.0, 0.7)],
	"sk_arrow": ["ヒュンッ", Color(0.85, 0.95, 0.85)],
	"sk_triple": ["ヒュヒュヒュッ", Color(0.85, 0.95, 0.85)],
	"sk_snare": ["ビシッ", Color(0.9, 0.85, 0.6)],
	"sk_snipe": ["ズドンッ", Color(1.0, 0.8, 0.5), 1.2],
	"sk_shield": ["キィィン", Color(0.75, 0.85, 1.0)],
	"sk_sleep": ["モワモワ…", Color(0.8, 0.75, 0.95)],
	"sk_regen": ["ポワァ…", Color(0.7, 1.0, 0.8)],
	"sk_spin": ["グルンッ", Color(0.9, 0.9, 1.0)],
	"sk_twin": ["シュシュッ", Color(0.9, 0.9, 1.0)],
	"sk_cleave": ["ガゴンッ", Color(1.0, 0.7, 0.45), 1.2],
	"sk_bonk": ["ゴンッ", Color(1.0, 0.8, 0.5)],
	"sk_pierce": ["ズドッ", Color(1.0, 0.75, 0.55)],
	"sk_aim": ["キリキリ…", Color(0.9, 0.9, 0.8)],
	"sk_focus": ["ブゥン…", Color(0.7, 0.75, 1.0)],
	"sk_shadow": ["ズッ", Color(0.7, 0.6, 0.9)],
	"sk_rend": ["ドゴォッ", Color(1.0, 0.6, 0.35), 1.4],
	"sk_comet": ["ギュオッ", Color(0.75, 0.9, 1.0)],
	# 魔物の特徴 第二弾
	"glare": ["ジリッ", Color(1.0, 0.95, 0.65)],
	"splash": ["ザバッ!", Color(0.6, 0.85, 1.0), 1.2],
	"drop": ["ストン", Color(0.85, 0.85, 0.8)],
	"shape": ["ニタァ…", Color(0.85, 0.6, 0.9), 1.1],
	"web_shot": ["ビュッ", Color(0.95, 0.95, 0.9)],
	"web": ["ネバッ", Color(0.95, 0.95, 0.88)],
	"squeeze": ["ニュルッ", Color(0.7, 0.9, 0.55)],
	"gaze": ["ギロッ", Color(0.9, 1.0, 0.5), 1.1],
	"stone": ["ピキピキッ", Color(0.8, 0.8, 0.78), 1.2],
	"stench": ["モワァ…", Color(0.7, 0.8, 0.45)],
	# 魔物の特徴 第三弾(呪文など)
	"chant": ["ブツブツ…", Color(0.85, 0.7, 1.0), 0.85],
	"ms_fire": ["ボボッ", Color(1.0, 0.55, 0.25)],
	"ms_lightning": ["ピシャーン!", Color(1.0, 1.0, 0.6), 1.2],
	"ms_missile": ["ピュピュピュン", Color(0.8, 0.65, 1.0)],
	"ms_frost": ["ヒュオッ", Color(0.65, 0.9, 1.0)],
	"ms_guide": ["ピカーッ", Color(1.0, 0.95, 0.65)],
	"ms_hold": ["ピタッ", Color(0.85, 0.75, 1.0)],
	"ms_sleep": ["ふわぁ…", Color(0.8, 0.8, 1.0)],
	"ms_charm": ["ぽわわん", Color(1.0, 0.6, 0.85)],
	"ms_vine": ["シュルシュルッ", Color(0.55, 0.85, 0.45)],
	"ms_heat": ["ジリジリッ", Color(1.0, 0.5, 0.3)],
	"ms_dark": ["ドロォ…", Color(0.6, 0.5, 0.75), 1.1],
	"ms_vanish": ["スッ…", Color(0.8, 0.8, 0.9)],
	"shrug": ["フンッ!", Color(1.0, 0.85, 0.45), 1.1],
	"burn": ["ジュッ", Color(1.0, 0.55, 0.3)],
	"mist": ["シュウゥ…", Color(0.85, 0.85, 0.95)],
	# 能力値のロール(DiceFx。サイコロ3つぶん。ken 10/17: かわいく、コロコロと淡い色)
	"dice_1": ["コロコロ", Color(1.0, 0.72, 0.82)],
	"dice_2": ["コロ", Color(0.68, 0.95, 0.8)],
	"dice_3": ["コロコロコロ", Color(0.72, 0.85, 1.0)],
}
## 擬音ごとの動き方(無いものは pop)
const STYLE := {
	"door": "stretch", "door_secret": "shake", "unlock": "pop", "unlock_fail": "shake",
	"trap": "slam", "trap_alarm": "shake", "trap_found": "soft", "disarm": "pop", "disarm_fail": "slam",
	"corpse": "bounce", "drink": "pop", "stairs": "bounce", "search": "bounce", "rest": "bounce",
	"crystal": "soft", "crystal_big": "slam", "stun": "wave", "sunder": "slam", "exhale": "shake", "sealed": "slam",
	"charge_full": "pop", "charge_hit": "slam", "charge_miss": "snap",
	"sizzle": "stretch", "simmer": "bounce", "burnt": "soft", "munch": "bounce", "growl": "wave", "growl_hard": "wave", "bellyache": "shake",
	"click": "pop", "fuse": "stretch", "boom": "slam", "spikes": "snap", "rumble": "shake", "smash": "slam", "creak": "shake",
	"rubble": "shake", "thud": "slam", "clang": "slam", "flame": "stretch", "dart": "snap", "grind": "shake", "crush": "slam",
	"net": "snap", "gas": "stretch", "swing": "snap", "jet": "pop", "pit": "slam", "warp": "soft", "warp_out": "soft",
	"squeak": "pop", "summon": "wave", "rust": "stretch", "spin": "wave", "trip": "slam", "spill": "bounce", "needle": "pop",
	"poison": "pop", "slide": "snap", "flash": "slam", "wail": "wave", "chill": "stretch", "teeth": "slam", "lift": "soft",
	"dice_1": "bounce", "dice_2": "bounce", "dice_3": "bounce",
	"down": "slam", "revive": "pop", "levelup": "stretch", "kill": "pop", "dodge": "snap",
	"glass": "snap", "ignite": "pop", "recall": "stretch",
	"ambush": "slam", "glue": "stretch", "rise": "pop", "mon_charge": "shake", "leap": "bounce", "ram": "slam", "burst": "slam",
	"emerge": "soft", "sniff": "bounce", "jot": "stretch", "trophy": "bounce",
	"glare": "shake", "splash": "slam", "drop": "pop", "shape": "wave", "web_shot": "snap", "web": "stretch",
	"squeeze": "stretch", "gaze": "snap", "stone": "shake", "stench": "wave",
	"chant": "bounce", "ms_fire": "pop", "ms_lightning": "slam", "ms_missile": "snap", "ms_frost": "stretch", "ms_guide": "pop",
	"ms_hold": "pop", "ms_sleep": "wave", "ms_charm": "wave", "ms_vine": "stretch", "ms_heat": "shake", "ms_dark": "stretch",
	"ms_vanish": "soft", "shrug": "slam", "burn": "pop", "mist": "stretch",
	"sk_rush": "snap", "sk_power": "slam", "sk_wall": "slam", "sk_sweep": "snap", "sk_rage": "shake", "sk_charge": "shake",
	"sk_roar": "slam", "sk_quake": "slam", "sk_throw": "snap", "sk_haste": "snap", "sk_smoke": "soft", "sk_stab": "pop",
	"sk_bolt": "snap", "sk_fire": "slam", "sk_frost": "shake", "sk_thunder": "shake", "sk_heal": "soft", "sk_holy": "slam",
	"sk_bless": "bounce", "sk_mass_heal": "stretch", "sk_arrow": "snap", "sk_triple": "snap", "sk_snare": "pop",
	"sk_snipe": "slam", "sk_shield": "stretch", "sk_sleep": "wave", "sk_regen": "soft", "sk_spin": "wave", "sk_twin": "snap",
	"sk_cleave": "slam", "sk_bonk": "slam", "sk_pierce": "snap", "sk_aim": "stretch", "sk_focus": "shake", "sk_shadow": "soft",
	"sk_rend": "slam", "sk_comet": "snap",
}

## スキルを使ったときの擬音(スキルの id → CUES の id)
const SKILL_CUE := {
	"rush": "sk_rush", "power_up": "sk_power", "ironwall": "sk_wall", "sweep": "sk_sweep", "rage": "sk_rage", "charge": "sk_charge",
	"roar": "sk_roar", "quake": "sk_quake", "knife": "sk_throw", "haste": "sk_haste", "smoke": "sk_smoke", "crit": "sk_stab",
	"bolt": "sk_bolt", "fireball": "sk_fire", "frost": "sk_frost", "thunder": "sk_thunder", "heal": "sk_heal", "smite": "sk_holy",
	"bless": "sk_bless", "mass_heal": "sk_mass_heal", "arrow": "sk_arrow", "triple": "sk_triple", "snare": "sk_snare",
	"snipe": "sk_snipe", "mana_shield": "sk_shield", "sleep": "sk_sleep", "regen_light": "sk_regen", "w_spin": "sk_spin",
	"w_twin": "sk_twin", "w_cleave": "sk_cleave", "w_stun": "sk_bonk", "w_pierce": "sk_pierce", "w_aim": "sk_aim",
	"w_focus": "sk_focus", "w_shadow": "sk_shadow", "w_rend": "sk_rend", "w_comet": "sk_comet", "flash": "flash",
}
const LIFE := 0.9

var text := ""
var color := Color.WHITE
var size := 1.0
var style := "pop"
var age := 0.0
var _chars: PackedStringArray = []
var _seed := 0.0

## 擬音を出す。parent は層(FloorInstance)など、pos はその中の位置
static func cue(parent: Node, pos: Vector2, id: String) -> void:
	if parent == null or not CUES.has(id):
		return
	var f := Sfx.new()
	f.text = String(CUES[id][0])
	f.color = CUES[id][1]
	f.size = float(CUES[id][2]) if (CUES[id] as Array).size() > 2 else 1.0
	f.style = String(STYLE.get(id, "pop"))
	f.position = pos + Vector2(0, -22)
	f.z_index = 21
	parent.add_child(f)

func _ready() -> void:
	_chars = PackedStringArray()
	for i in text.length():
		_chars.append(text.substr(i, 1))
	_seed = randf() * 10.0

## 消えるまでの秒(大きいもの、文字の多いもの、伸びるものは長め)
func life() -> float:
	var l := LIFE * (1.0 + (size - 1.0) * 0.3)
	match style:
		"bounce", "stretch": l += 0.06 * _chars.size()
		"slam", "shake", "wave": l += 0.2
	return l

func _process(delta: float) -> void:
	age += delta
	if age >= life():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	CueText.draw_word(self, _chars, style, age, life(), 14.0 * size, color, _seed, size >= 2.0)
