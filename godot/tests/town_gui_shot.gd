extends SceneTree
## 街のボタンと擬音の見た目: xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/town_gui_shot.gd -- 出力フォルダ
## shop.png 店(右下に広場へ、買ったときの チャリン) / inventory.png 持ち物の右下 / sleep.png 宿で眠る / bless.png 加護 / dungeon_log.png 迷宮のログと帯
func _initialize() -> void:
	call_deferred("_run")

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _secs(0.2)
	main.show_make()
	await _secs(0.1)
	main.screen._on_start()
	await _secs(0.3)
	var town: TownScreen = main.screen
	town.report = []
	town._go("general")
	await _secs(1.2)
	town.shop_list.grab_focus()
	town.shop_list.select(0)
	town._on_shop_pick(0)
	await _secs(0.1)
	var b: Button = town.shop_actions.get_child(0)
	b.grab_focus()
	town._buy(-1)
	await _secs(0.25)
	await _shot(out + "/shop.png")
	main.open_inventory()
	await _secs(0.3)
	await _shot(out + "/inventory.png")
	main.close_inventory()
	town._go("inn")
	await _secs(1.2)
	town._rest(60)
	await _secs(1.9)
	await _shot(out + "/sleep.png")
	await _secs(2.5)
	await _shot(out + "/sleep_after.png")
	town._go("temple")
	await _secs(1.2)
	main.gs.silver = 500
	town._bless()
	await _secs(1.1)
	await _shot(out + "/bless.png")
	# 迷宮: ログを8行出して、帯と重ならないか
	main._set_screen(null)
	main.start_day()
	await _secs(0.5)
	for i in 8:
		main.log_msg("ログの行 %d: 縄梯子を登る(〈運動〉 難易度 10)。セラは 2+5 で手を滑らせた" % (i + 1), Color("ff9a8a") if i == 7 else Color.WHITE)
	main.hud.hint = "E: 縄梯子(〈運動〉)"
	await _secs(0.3)
	await _shot(out + "/dungeon_log.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	quit(0)
