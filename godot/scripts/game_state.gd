class_name GameState
extends RefCounted
## 冒険の進み具合。パーティ、持ち物、預け金、日数。セーブはこれを JSON にする。

const SAVE_PATH := "user://save.json"

var party: Array = []              # Character
var inventory := {}                # アイテムid → 個数
var bank_silver := 300
var day := 0
var visited_town := false
var blessed := false           # 神殿の加護。次に潜るとき一度だけ効く

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game(chars: Array) -> void:
	party = chars
	inventory = {"potion": 3, "ether": 1}
	bank_silver = 300
	day = 0
	visited_town = false
	blessed = false

# ---------- 持ち物 ----------

func count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1) -> void:
	inventory[id] = count(id) + n

func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	return true

func item_ids() -> Array:
	var ids := inventory.keys()
	ids.sort_custom(func(a, b): return _order(a) < _order(b))
	return ids

func _order(id: String) -> String:
	var it: Dictionary = ItemDB.ITEMS.get(id, {})
	var rank := {"consumable": "1", "weapon": "2", "armor": "3", "acc": "4", "tome": "5", "material": "6"}
	return String(rank.get(String(it.get("kind", "")), "9")) + id

# ---------- 装備 ----------

## 装備する。いま着けているものは持ち物へ戻る。できなければ理由を返す("" なら成功)
func equip(ch: Character, id: String) -> String:
	if count(id) <= 0 or not ItemDB.ITEMS.has(id):
		return "持っていない"
	var slot := ItemDB.slot_of(id)
	if slot == "":
		return "装備できない"
	if not ItemDB.can_equip(id, ch.cls):
		return "%sは装備できない" % Jobs.CLASSES[ch.cls]["name"]
	remove_item(id)
	var old := String(ch.equip[slot])
	if old != "":
		add_item(old)
	ch.equip[slot] = id
	ch.clamp_resources()
	return ""

func unequip(ch: Character, slot: String) -> void:
	var old := String(ch.equip.get(slot, ""))
	if old == "":
		return
	add_item(old)
	ch.equip[slot] = ""
	ch.clamp_resources()

# ---------- 使う ----------

## 消耗品を使う。使えたら説明の文、使えなければ "" を返す
func use_item(id: String, ch: Character) -> String:
	if count(id) <= 0 or not ItemDB.ITEMS.has(id):
		return ""
	var it: Dictionary = ItemDB.ITEMS[id]
	if String(it["kind"]) == "tome":
		return learn_tome(id, ch)
	if String(it["kind"]) != "consumable":
		return ""
	match String(it["use"]):
		"heal_pct":
			if ch.hp <= 0.0 or ch.hp >= ch.max_hp():
				return ""
			var n := maxf(float(it.get("min", 12.0)), ch.max_hp() * float(it["v"]))
			ch.hp = minf(ch.max_hp(), ch.hp + n)
			remove_item(id)
			return "%sのHPが回復した" % ch.name
		"mp_pct":
			if ch.hp <= 0.0 or ch.mp >= ch.max_mp():
				return ""
			ch.mp = minf(ch.max_mp(), ch.mp + ch.max_mp() * float(it["v"]))
			remove_item(id)
			return "%sのMPが回復した" % ch.name
		"revive":
			if ch.hp > 0.0:
				return ""
			ch.hp = maxf(1.0, ch.max_hp() * float(it["v"]))
			remove_item(id)
			return "%sが立ち上がった" % ch.name
	return ""

func learn_tome(id: String, ch: Character) -> String:
	var it: Dictionary = ItemDB.ITEMS[id]
	if not (it["classes"] as Array).has(ch.cls):
		return ""
	if ch.skills.has(String(it["teaches"])):
		return ""
	ch.learn(String(it["teaches"]))
	remove_item(id)
	return "%sは「%s」を覚えた" % [ch.name, Jobs.SKILLS[it["teaches"]]["name"]]

# ---------- 売り買い ----------

func buy(id: String) -> String:
	var price := int(ItemDB.ITEMS[id]["price"])
	if bank_silver < price:
		return "銀貨が足りない"
	bank_silver -= price
	add_item(id)
	return ""

func sell(id: String) -> String:
	if count(id) <= 0:
		return "持っていない"
	remove_item(id)
	bank_silver += ItemDB.sell_price(id)
	return ""

# ---------- 休息など ----------

func rest_all() -> void:
	for ch in party:
		ch.hp = ch.max_hp()
		ch.mp = ch.max_mp()

func party_xp_share(total: int, alive: int) -> int:
	return int(ceil(float(total) / float(maxi(1, alive))))

# ---------- 保存 ----------

func to_dict() -> Dictionary:
	var chars: Array = []
	for c in party:
		chars.append(c.to_dict())
	return {"version": 1, "party": chars, "inventory": inventory, "bank": bank_silver, "day": day, "visited_town": visited_town, "blessed": blessed}

func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true

func load_save() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	party = []
	for d in parsed.get("party", []):
		party.append(Character.from_dict(d))
	inventory = {}
	for k in parsed.get("inventory", {}):
		if ItemDB.ITEMS.has(String(k)):
			inventory[String(k)] = int(parsed["inventory"][k])
	bank_silver = int(parsed.get("bank", 0))
	day = int(parsed.get("day", 0))
	visited_town = bool(parsed.get("visited_town", true))
	blessed = bool(parsed.get("blessed", false))
	return not party.is_empty()
