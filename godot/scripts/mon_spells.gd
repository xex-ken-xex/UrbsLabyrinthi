class_name MonSpells
extends RefCounted
## 魔物の呪文(SRD の Innate Spellcasting / Spellcasting)。データには呪文の一覧が無いので、
## SRD の呪文から、迷宮で映えるものを魔物ごとに選んだ(KITS)。無い魔物は種別で決める(BY_TYPE)。
## 唱え方: 仲間が射程の中に見えていると、頭上に呪文の名前を出して詠唱(ブツブツ…、CAST_TIME 秒)し、それから放つ。
## 詠唱の間は足が止まる。気絶・眠りで詠唱は途切れる。呪文ごとの待ち時間は cd 秒。
##   bolt    飛ぶ呪文(火の矢、稲妻、魔法の矢、冷たい光線、導きの光)。elem の傷
##   hold    金縛り(狙った一人が動けない)
##   sleep   眠り(狙った所のまわりの仲間が眠る)
##   charm   魅了(狙った一人の前後左右が逆になる)
##   vine    絡みつく蔓(狙った所のまわりの仲間が絡まる。連打で抜ける)
##   heat    灼熱(狙った一人の装備が焼ける。火の傷)
##   dark    闇(狙った所のまわりの仲間の、見える範囲が狭まる)
##   heal    癒し(傷ついた仲間の魔物を癒す)
##   vanish  姿を消す(しばらく、ほとんど見えない)
##   blink   霧の歩み(仲間に詰め寄られたら、離れた所へ跳ぶ)

const CAST_TIME := 0.8

const SPELLS := {
	"fire_bolt": {"name": "火の矢", "kind": "bolt", "elem": "fire", "mult": 1.3, "range": 7.0, "cd": 6.0, "color": Color(1.0, 0.5, 0.2), "cue": "ms_fire"},
	"lightning": {"name": "稲妻", "kind": "bolt", "elem": "lightning", "mult": 1.5, "range": 8.0, "cd": 8.0, "color": Color(1.0, 1.0, 0.55), "cue": "ms_lightning", "speed": 420.0},
	"magic_missile": {"name": "魔法の矢", "kind": "bolt", "elem": "force", "mult": 0.5, "range": 7.0, "cd": 6.0, "color": Color(0.75, 0.6, 1.0), "cue": "ms_missile", "count": 3},
	"ray_frost": {"name": "冷たい光線", "kind": "bolt", "elem": "cold", "mult": 0.9, "range": 6.0, "cd": 6.0, "color": Color(0.6, 0.9, 1.0), "cue": "ms_frost", "chill": 3.0},
	"guiding": {"name": "導きの光", "kind": "bolt", "elem": "radiant", "mult": 1.2, "range": 7.0, "cd": 7.0, "color": Color(1.0, 0.95, 0.65), "cue": "ms_guide"},
	"hold": {"name": "金縛り", "kind": "hold", "range": 6.0, "cd": 12.0, "secs": 1.6, "cue": "ms_hold"},
	"sleep": {"name": "眠りの呪文", "kind": "sleep", "range": 6.0, "cd": 12.0, "secs": 2.2, "radius": 64.0, "cue": "ms_sleep"},
	"charm": {"name": "魅了", "kind": "charm", "range": 6.0, "cd": 12.0, "secs": 3.5, "cue": "ms_charm"},
	"vine": {"name": "絡みつく蔓", "kind": "vine", "range": 6.0, "cd": 10.0, "secs": 1.6, "radius": 56.0, "cue": "ms_vine"},
	"heat": {"name": "灼熱の金属", "kind": "heat", "range": 6.0, "cd": 8.0, "mult": 1.1, "cue": "ms_heat"},
	"dark": {"name": "闇", "kind": "dark", "range": 6.0, "cd": 14.0, "secs": 6.0, "radius": 90.0, "cue": "ms_dark"},
	"heal": {"name": "癒し", "kind": "heal", "range": 6.0, "cd": 8.0, "frac": 0.3, "cue": "sk_heal"},
	"vanish": {"name": "姿消し", "kind": "vanish", "range": 5.0, "cd": 16.0, "secs": 5.0, "cue": "ms_vanish"},
	"blink": {"name": "霧の歩み", "kind": "blink", "range": 2.0, "cd": 9.0, "cells": 5, "cue": "warp"},
}

## 魔物の index → 呪文。SRD の呪文の一覧から、迷宮で映えるもの
const KITS := {
	"drow": ["dark"], "drider": ["dark"], "deep-gnome-svirfneblin": ["vanish"],
	"dust-mephit": ["sleep"], "ice-mephit": ["ray_frost"], "magma-mephit": ["heat"], "steam-mephit": ["vanish"],
	"dryad": ["vine", "charm"], "green-hag": ["vanish", "charm"], "night-hag": ["magic_missile", "sleep"],
	"lamia": ["charm", "vanish"], "glabrezu": ["dark", "charm"], "rakshasa": ["charm", "hold"],
	"couatl": ["heal", "sleep"], "unicorn": ["heal", "vine"], "oni": ["vanish", "sleep"], "cloud-giant": ["vanish"],
	"deva": ["heal", "hold"], "djinni": ["lightning", "vanish"], "efreeti": ["fire_bolt", "vanish"],
	"storm-giant": ["lightning"], "planetar": ["heal", "hold"], "pit-fiend": ["fire_bolt", "hold"], "solar": ["heal", "hold"],
	"acolyte": ["heal", "guiding"], "cult-fanatic": ["hold", "guiding"], "druid": ["vine", "heal"], "priest": ["heal", "guiding"],
	"mage": ["magic_missile", "fire_bolt", "blink"], "archmage": ["lightning", "magic_missile", "blink"],
	"spirit-naga": ["lightning", "charm", "hold"], "guardian-naga": ["heal", "fire_bolt", "hold"],
	"gynosphinx": ["lightning", "vanish"], "androsphinx": ["fire_bolt", "heal"],
	"mummy-lord": ["hold", "guiding"], "lich": ["fire_bolt", "lightning", "hold", "blink"],
}
const BY_TYPE := {"fiend": ["fire_bolt"], "celestial": ["heal"], "fey": ["charm"], "undead": ["hold"]}

## 魔物の呪文の一覧(唱えない魔物は空)
static func kit_for(m: Dictionary, mtype: String) -> Array:
	var k: Array = KITS.get(String(m.get("index", "")), [])
	if k.is_empty():
		k = BY_TYPE.get(mtype, ["magic_missile"])
	return k.duplicate()

static func def(id: String) -> Dictionary:
	return SPELLS.get(id, {})
