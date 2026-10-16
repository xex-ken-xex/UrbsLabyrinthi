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
	"unlock_fail": ["ガチャ…", Color(1.0, 0.6, 0.55)],
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
	"stun": ["ピヨ…", Color(1.0, 0.95, 0.55)],
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
	"growl_hard": ["ぐぅぅ〜…", Color(1.0, 0.7, 0.6)],
	"bellyache": ["グルル…", Color(0.7, 0.85, 0.5)],
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
	"pit": ["ズボッ", Color(0.85, 0.7, 0.55)],
	"warp": ["ﾌｯ", Color(0.75, 0.7, 1.0)],
	"warp_out": ["ﾌｯ", Color(0.75, 0.7, 1.0), 0.75],
	"squeak": ["キュッ", Color(1.0, 0.85, 0.6)],
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
	# 能力値のロール(DiceFx。サイコロ3つぶん)
	"dice_1": ["ゴロゴロ", Color(1.0, 0.92, 0.7)],
	"dice_2": ["ゴロ", Color(0.95, 0.85, 0.65)],
	"dice_3": ["ゴロゴロゴロ", Color(1.0, 0.95, 0.8)],
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
