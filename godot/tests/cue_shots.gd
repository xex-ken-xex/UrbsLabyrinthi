extends SceneTree
## 擬音の動き方を、時間を追って並べた写真にする(見た目の確かめ用)
##   xvfb-run -a godot --path godot --rendering-driver opengl3 -s res://tests/cue_shots.gd -- 出力先
## 動き方ごとに1行。左から右へ、出てから 0.04 / 0.1 / 0.18 / 0.3 / 0.55 秒

const SAMPLES := [["pop", "revive"], ["slam", "sk_fire"], ["bounce", "munch"], ["shake", "sk_thunder"],
	["stretch", "levelup"], ["soft", "sk_heal"], ["snap", "dodge"], ["wave", "growl_hard"],
	["drop", "thud"], ["roll", "rumble"], ["fly", "dart"]]
const TIMES := [0.04, 0.1, 0.18, 0.3, 0.55]
const ROW := 60.0
const COL := 240.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = Color("1c1a24")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var layer := Node2D.new()
	layer.scale = Vector2(2, 2)     # 迷宮の画面の拡大(×2)くらいで見る
	root.add_child(layer)
	for c in SAMPLES.size():
		var lab := Label.new()
		lab.text = SAMPLES[c][0]
		lab.position = Vector2(12, 22 + c * ROW)
		root.add_child(lab)
		for r in TIMES.size():
			Sfx.cue(layer, Vector2(150 + r * COL, 80 + c * ROW) / 2.0, SAMPLES[c][1])
			var f: Sfx = layer.get_child(layer.get_child_count() - 1)
			f.set_process(false)
			f.age = TIMES[r]
			f.queue_redraw()
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("cue_styles.png"))
	quit()
