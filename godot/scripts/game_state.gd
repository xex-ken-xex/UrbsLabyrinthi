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
var insured := false           # 坑口館の帰還積立。次に潜るとき一度だけ効く(全滅しても、灯手隊が装備と持ち物の半分を拾ってくる)
var quests: Array = []         # 坑口館で受けた依頼 {"id", "n", "reward", "client"}
var food: Array = []           # 作った料理 {"id", "q"(出来ばえ), "until"(傷む時刻), "n"}。Cooking
var clock := float(Balance.DIVE_START_MIN)   # 世界の時刻(通しの分)。潜った夜の数×24時間 + 迷宮の中の時刻。戻ることはない

## 坑口館の掲示板に出る依頼。[品物, 依頼主, 最少, 最多, 一言]
const REQUESTS := [
	["sakebi_take", "薬師組", 2, 4, "鳴子の材料にする。"],
	["doku_take", "薬師組", 2, 4, "毒消しを作る。"],
	["nemuri_take", "癒院", 2, 3, "眠り薬にする。"],
	["hikari_goke", "星録の書院", 3, 5, "夜の写本の灯りにする。"],
	["komori_fun", "川沿いの農家", 3, 5, "畑の肥料にする。"],
	["sabi_goke", "鍛冶組", 2, 4, "焼き入れに使う。"],
	["iwa_jio", "止まり木亭", 2, 4, "塩が切れた。"],
	["kemono_niku", "止まり木亭", 3, 5, "胃袋スープの具にする。"],
	["kemono_kawa", "鍛冶組", 2, 3, "鎧の裏打ちにする。"],
	["kiba", "細工師", 2, 4, "飾りを彫る。"],
	["nenneki", "灯守の店", 2, 4, "磨き粉にする。"],
	["honekuzu", "川沿いの農家", 3, 5, "骨粉にして、畑に撒く。"],
	["hakatsuchi", "静寂派の神殿", 2, 3, "清めて、弔いに使う。"],
	["tetsukuzu", "鍛冶組", 2, 4, "溶かして使う。"],
	["ma_ha", "薬師組", 2, 4, "薬草より効く薬にする。"],
]
const MAX_QUESTS := 3

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game(chars: Array) -> void:
	party = chars
	inventory = {"potion": 3, "ether": 1}
	bank_silver = 300
	day = 0
	visited_town = false
	blessed = false
	insured = false
	quests = []
	food = []
	clock = float(Balance.DIVE_START_MIN)
	Cooking.clock = clock

# ---------- 時刻 ----------

## 世界の時刻を進める(戻しはしない)。迷宮の中では Main が毎フレーム、街では夜の朝7時
func set_clock(t: float) -> void:
	clock = maxf(clock, t)
	Cooking.clock = clock

## 街にいるときの時刻(その夜の朝7時)
func town_clock() -> float:
	return day * 1440.0 + Balance.DIVE_START_MIN

# ---------- 料理 ----------

## 作った料理を積む。同じ料理・同じ出来・同じ期限なら、まとめる
func add_food(id: String, q: int, until: float, n: int = 1) -> void:
	for s in food:
		if String(s["id"]) == id and int(s["q"]) == q and absf(float(s["until"]) - until) < 0.5:
			s["n"] = int(s["n"]) + n
			return
	food.append({"id": id, "q": q, "until": until, "n": n})
	food.sort_custom(func(a, b): return float(a["until"]) < float(b["until"]))

## i 番目から一皿とる
func take_food(i: int) -> void:
	food[i]["n"] = int(food[i]["n"]) - 1
	if int(food[i]["n"]) <= 0:
		food.remove_at(i)

func food_count() -> int:
	var n := 0
	for s in food:
		n += int(s["n"])
	return n

## くさった料理を捨てる。捨てた皿の数を返す
func throw_rotten() -> int:
	var n := 0
	for i in range(food.size() - 1, -1, -1):
		if Cooking.rotten(food[i], clock):
			n += int(food[i]["n"])
			food.remove_at(i)
	return n

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

## 全滅したときに失う。持ち物と、仲間が着けている装備を全部(武器・防具も)。失った数を返す
## 酒場で加えた仲間と別れる。装備は外して、持ち物へ戻す(ただし作ったときの二人とは別れない)
func dismiss(ch: Character) -> bool:
	if not ch.hired or not party.has(ch):
		return false
	for slot in ["weapon", "armor", "acc"]:
		if String(ch.equip.get(slot, "")) != "":
			unequip(ch, slot)
	party.erase(ch)
	save()
	return true

func lose_everything() -> int:
	var n := food_count()
	food.clear()
	for id in inventory:
		n += int(inventory[id])
	inventory.clear()
	for c in party:
		for slot in c.equip:
			if String(c.equip[slot]) != "":
				n += 1
				c.equip[slot] = ""
		c.clamp_resources()
	return n

## 帰還積立に入っていて全滅したとき。装備は着けたまま戻り、持ち物は品ごとに半分(切り捨て)を失う。失った数を返す
func lose_half() -> int:
	var n := 0
	for id in inventory.keys():
		var lost := int(inventory[id]) - int(floor(int(inventory[id]) / 2.0))
		n += lost
		remove_item(id, lost)
	for i in range(food.size() - 1, -1, -1):
		var lost_f := int(food[i]["n"]) - int(floor(int(food[i]["n"]) / 2.0))
		n += lost_f
		food[i]["n"] = int(food[i]["n"]) - lost_f
		if int(food[i]["n"]) <= 0:
			food.remove_at(i)
	return n

# ---------- 坑口館 ----------

## 帰還積立の掛け金(仲間のレベルの合計で決まる)
func insurance_cost() -> int:
	var lv := 0
	for c in party:
		lv += c.level
	return 20 + 10 * lv

## その日の掲示板に出る依頼(日ごとに3つ。受けた品は出ない)
func offered_quests() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("quests%d" % day)
	var pool := REQUESTS.duplicate()
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var r: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var n := rng.randi_range(int(r[2]), int(r[3]))
		var reward := int(ceil(int(ItemDB.ITEMS[r[0]]["price"]) * n * 2.0 / 5.0)) * 5 + 20
		if has_quest(String(r[0])):
			continue
		out.append({"id": r[0], "n": n, "reward": reward, "client": r[1], "line": r[4]})
	return out

func has_quest(id: String) -> bool:
	for q in quests:
		if String(q["id"]) == id:
			return true
	return false

func accept_quest(q: Dictionary) -> String:
	if quests.size() >= MAX_QUESTS:
		return "受けられる依頼は%d件まで" % MAX_QUESTS
	if has_quest(String(q["id"])):
		return "同じ品の依頼を、もう受けている"
	quests.append({"id": q["id"], "n": q["n"], "reward": q["reward"], "client": q["client"]})
	save()
	return ""

## 納品する。報酬を返す(足りなければ -1)
func deliver_quest(i: int) -> int:
	var q: Dictionary = quests[i]
	if count(String(q["id"])) < int(q["n"]):
		return -1
	remove_item(String(q["id"]), int(q["n"]))
	bank_silver += int(q["reward"])
	quests.remove_at(i)
	save()
	return int(q["reward"])

func drop_quest(i: int) -> void:
	quests.remove_at(i)
	save()

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
			var n := maxf(float(it.get("min", 12.0)), ch.max_hp() * float(it["v"])) * best_heal_mult()
			ch.hp = minf(ch.max_hp(), ch.hp + n)
			ch.belly = minf(Cooking.BELLY_MAX, ch.belly + Cooking.raw_belly(id))
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

## パーティ(倒れていない人)で、その技能の効き目がいちばん大きい値
func party_skill_fx(id: String) -> float:
	var best := 0.0
	for c in party:
		if c.hp > 0.0:
			best = maxf(best, c.skill_fx(id))
	return best

## 治療薬の回復の倍率(〈医術〉、癒し手のいちばん高い人)
func best_heal_mult() -> float:
	var best := 1.0
	for c in party:
		if c.hp > 0.0:
			best = maxf(best, c.heal_mult())
	return best

## 店の値段(〈説得〉で安くなる)
func buy_price(id: String) -> int:
	return maxi(1, int(round(int(ItemDB.ITEMS[id]["price"]) * (1.0 - party_skill_fx("persuasion")))))

## 買い取り(〈ペテン〉で高くなる)。買値を超えないようにする
func sell_price(id: String) -> int:
	return mini(int(round(ItemDB.sell_price(id) * (1.0 + party_skill_fx("deception")))), buy_price(id))

func buy(id: String) -> String:
	var price := buy_price(id)
	if bank_silver < price:
		return "銀貨が足りない"
	bank_silver -= price
	add_item(id)
	return ""

func sell(id: String) -> String:
	if count(id) <= 0:
		return "持っていない"
	remove_item(id)
	bank_silver += sell_price(id)
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
	return {"version": 1, "party": chars, "inventory": inventory, "bank": bank_silver, "day": day, "visited_town": visited_town, "blessed": blessed, "insured": insured, "quests": quests,
		"food": food, "clock": clock}

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
	var has_hired := false
	for d in parsed.get("party", []):
		party.append(Character.from_dict(d))
		has_hired = has_hired or (d as Dictionary).has("hired")
	if not has_hired:
		for i in range(2, party.size()):
			party[i].hired = true      # 別れる操作より前の記録: 3人目からは酒場で加えた仲間
	inventory = {}
	for k in parsed.get("inventory", {}):
		if ItemDB.ITEMS.has(String(k)):
			inventory[String(k)] = int(parsed["inventory"][k])
	bank_silver = int(parsed.get("bank", 0))
	day = int(parsed.get("day", 0))
	visited_town = bool(parsed.get("visited_town", true))
	blessed = bool(parsed.get("blessed", false))
	insured = bool(parsed.get("insured", false))
	quests = []
	for q in parsed.get("quests", []):
		if typeof(q) == TYPE_DICTIONARY and ItemDB.ITEMS.has(String(q.get("id", ""))):
			quests.append({"id": String(q["id"]), "n": int(q.get("n", 1)), "reward": int(q.get("reward", 0)), "client": String(q.get("client", ""))})
	food = []
	for f in parsed.get("food", []):
		if typeof(f) == TYPE_DICTIONARY and not Cooking.recipe(String(f.get("id", ""))).is_empty():
			food.append({"id": String(f["id"]), "q": int(f.get("q", 1)), "until": float(f.get("until", 0.0)), "n": int(f.get("n", 1))})
	clock = 0.0
	set_clock(maxf(float(parsed.get("clock", 0.0)), town_clock()))
	return not party.is_empty()
