class_name Body
extends Node2D
## 体当たりで押し合う物の共通部分。仲間(Hero)と魔物(Enemy)が継ぐ。
## 毎フレーム、自分の足で動いた量(self_move)を記録しておき、Contact が押し合いを決める。

var game_floor: FloorInstance
var is_hero := false
var radius := 10.0            # 体の大きさ(押し合い、描画)
var col_radius := 10.0        # 壁との当たり(幅1マスの通路を通れるように、大きな魔物は小さく取る)
var intent := Vector2.ZERO    # このフレームに進もうとした向き(単位ベクトル)。進まなければゼロ
var self_move := Vector2.ZERO
var knock := Vector2.ZERO
var bump_cd := 0.0
var hit_now := false
var did_hit := false
var flash := 0.0
var pop_amount := 0.0
var pop_color := Color.WHITE
var pop_t := 0.0

func is_alive() -> bool:
	return true

func hp_frac() -> float:
	return 1.0

func body_mass() -> float:
	return 1.0

func body_speed() -> float:
	return 100.0

func contact_dps() -> float:
	return 0.0

func receive_contact(_amount: float, _from_pos: Vector2, _src: Body) -> void:
	pass

## 相手の向き n へ押し込む力。HPが減ると弱まる(ハイドライド式の押し合いの肝)
func drive_toward(n: Vector2) -> float:
	if not is_alive():
		return 0.0
	var d := intent.dot(n)
	if d <= 0.0:
		return 0.0
	return d * body_speed() * (Balance.HP_FLOOR + (1.0 - Balance.HP_FLOOR) * hp_frac()) * body_mass()

## 自分の足で歩く。記録され、相手に触れていれば押し合いの計算で取り消される
func walk(step: Vector2) -> void:
	var np := game_floor.map.move_circle(position, step, col_radius)
	self_move += np - position
	position = np

## 外から動かされる(押される、弾かれる)。実際に動けた長さを返す
func shove(step: Vector2) -> float:
	var np := game_floor.map.move_circle(position, step, col_radius)
	var moved := (np - position).length()
	position = np
	return moved

func apply_knock(delta: float) -> void:
	if knock.length() > 1.0:
		shove(knock * delta)
		knock = knock.move_toward(Vector2.ZERO, 520.0 * delta)

func queue_popup(amount: float, color: Color) -> void:
	pop_amount += amount
	pop_color = color

func pop_update(delta: float) -> void:
	pop_t -= delta
	if pop_t <= 0.0:
		if pop_amount >= 0.5:
			game_floor.spawn_text(position + Vector2(0, -radius - 8), str(int(round(pop_amount))), pop_color)
		pop_amount = 0.0
		pop_t = 0.45
