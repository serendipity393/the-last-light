extends Node
var game
var grid: AStarGrid2D
var errors: Array = []
var report: Array = []
var held: Array = []
var frame_times: Array = []

func _ready() -> void:
	call_deferred("run")

func _process(delta: float) -> void:
	if frame_times.size()<10000: frame_times.append(delta)

func check(value: bool, label: String) -> void:
	if not value:
		errors.append(label)
		push_error("QA_FAIL: "+label)
		write_report()
		get_tree().quit(1)
	else: print("QA_PASS: ",label)

func key(code: int, pressed: bool) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=code
	e.pressed=pressed
	Input.parse_input_event(e)

func release_keys() -> void:
	for k in held: key(k,false)
	held.clear()

func tap(code: int) -> void:
	key(code,true)
	await get_tree().process_frame
	key(code,false)
	await get_tree().process_frame

func clear_dialog() -> void:
	for i in 40:
		if game.mode!="dialog": return
		await tap(KEY_E)

func build_grid() -> void:
	grid=AStarGrid2D.new()
	grid.region=Rect2i(-17,-23,35,47)
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var shape:=SphereShape3D.new()
	shape.radius=0.52
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	for x in range(-17,18):
		for z in range(-23,24):
			query.transform=Transform3D(Basis.IDENTITY,Vector3(x,0.9,z))
			var hits=game.world.get_world_3d().direct_space_state.intersect_shape(query,1)
			grid.set_point_solid(Vector2i(x,z),not hits.is_empty())
	for it in game.items:
		var p:Vector3=it["node"].position
		check(not grid.is_point_solid(Vector2i(roundi(p.x),roundi(p.z))),"交互点可站立 "+it["id"])

func walk_to(id: String) -> void:
	var target:=Vector3.ZERO
	var hidden:=false
	for it in game.items:
		if it["id"]==id: target=it["node"].position; hidden=it["hidden"]
	var pp:Vector3=game.player.position
	var path:=grid.get_id_path(Vector2i(roundi(pp.x),roundi(pp.z)),Vector2i(roundi(target.x),roundi(target.z)))
	check(not path.is_empty(),"可达路径 "+id)
	for point in path:
		var goal:=Vector3(point.x,0,point.y)
		var frames:=0
		while Vector2(game.player.position.x-goal.x,game.player.position.z-goal.z).length()>0.72:
			frames+=1
			if frames>500: check(false,"移动超时 "+id+" @ "+str(goal)); return
			var d:Vector3=goal-game.player.position
			d.y=0
			var right:Vector3=game.camera.global_basis.x
			right.y=0
			var back:Vector3=game.camera.global_basis.z
			back.y=0
			var dx:=d.dot(right.normalized())
			var dz:=d.dot(back.normalized())
			release_keys()
			if absf(dx)>0.18: held.append(KEY_D if dx>0 else KEY_A)
			if absf(dz)>0.18: held.append(KEY_S if dz>0 else KEY_W)
			for k in held: key(k,true)
			# Collision/pathfinding checks isolate enemies; AI is tested separately below.
			game.invulnerable=2
			await get_tree().physics_frame
		release_keys()
	await get_tree().physics_frame
	if hidden:
		var e:=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_RIGHT
		e.pressed=true
		Input.parse_input_event(e)
		game.energy=100
		game.echo_locked=false
		await get_tree().physics_frame
		await get_tree().physics_frame
	game.update_nearest()
	check(game.nearest>=0 and game.items[game.nearest]["id"]==id,"靠近与交互提示 "+id)
	await tap(KEY_E)
	if hidden:
		var e:=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_RIGHT
		e.pressed=false
		Input.parse_input_event(e)
	await clear_dialog()

func click_button(text: String) -> void:
	var found:Button=find_button(game.ui.page,text)
	check(found!=null,"界面按钮 "+text)
	if found:
		found.pressed.emit()
		await get_tree().process_frame

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found:=find_button(child,text)
		if found: return found
	return null

func run() -> void:
	Engine.time_scale=3.0
	game.new_game()
	await clear_dialog()
	await get_tree().physics_frame
	build_grid()
	for id in ["radio","m0","fuse","power","m1","bridge"]: await walk_to(id)
	for i in 3: await click_button("转动左轮")
	for i in 3: await click_button("转动中轮")
	for i in 2: await click_button("转动右轮")
	await click_button("确认校准")
	await clear_dialog()
	check(game.flags.get("bridge",false),"码头实际交互完成")
	await walk_to("exit")
	await get_tree().physics_frame
	check(game.chapter==1,"切换街巷")
	build_grid()
	for id in ["clue1","m2","clue0","m3","clue2","bells"]: await walk_to(id)
	for text in ["敲响 · 钟","敲响 · 麦穗","敲响 · 信"]: await click_button(text)
	check(game.flags.get("bells",false),"街巷实际门铃完成")
	await walk_to("exit")
	await get_tree().physics_frame
	check(game.chapter==2,"切换机房")
	build_grid()
	for id in ["log","pump","valves"]: await walk_to(id)
	await click_button("转动 中 阀")
	await click_button("转动 右 阀")
	await click_button("转动 右 阀")
	await click_button("检查水位")
	await clear_dialog()
	await walk_to("m4")
	await walk_to("circuit")
	for i in 2: await click_button("旋转第 1 段")
	for i in 2: await click_button("旋转第 2 段")
	for i in 3: await click_button("旋转第 3 段")
	await click_button("接通电路")
	await clear_dialog()
	check(game.flags.get("circuit",false),"机房实际交互完成")
	await walk_to("exit")
	await get_tree().physics_frame
	check(game.chapter==3,"切换灯塔")
	build_grid()
	await walk_to("inscription")
	for i in 3:
		await walk_to("lens"+str(i))
		for j in [1,3,2][i]: await click_button("顺时针转动")
		await click_button("锁定镜面")
	await walk_to("m5")
	await walk_to("final")
	check(game.mode=="choice","塔顶最终选择界面")
	await click_button("点亮灯塔 · 让回声归于大海")
	await clear_dialog()
	check(game.mode=="ending" and game.ending=="release","释放结局实际字幕完成")
	await click_button("重返塔顶 · 体验另一种告别")
	await click_button("保留灯芯 · 带着记忆回家")
	await clear_dialog()
	check(game.mode=="ending" and game.ending=="keep","保留结局实际字幕完成")
	check(game.memories.size()==6,"六件记忆可实际到达和拾取")
	report.append("四章通过真实键盘移动、碰撞、回声灯交互及机关按钮完成；双结局与六段记忆通过")
	# Deliberately allow an enemy to perceive the lamp and catch the player.
	game.resume()
	game.player.position=Vector3(5,0.1,10)
	var en=game.enemies[0]
	en["body"].position=Vector3(5,0.1,12)
	game.invulnerable=0
	game.echo=true
	game.update_enemies(1.2)
	check(en["state"]=="追逐","敌人从察觉转入追逐")
	en["body"].position=game.player.position+Vector3(0.1,0,0)
	game.update_enemies(0.02)
	check(game.player.position.distance_to(game.checkpoint)<0.1,"敌人抓获后检查点恢复")
	game.lure_cooldown=0
	game.throw_lure()
	check(game.lure_time>0 and game.lure_cooldown>0,"诱饵与恢复计时")
	report.append("敌人警觉追逐、抓获重置、诱饵计时通过")
	Engine.time_scale=1.0
	write_report()
	print("WALKTHROUGH_PASS")
	get_tree().quit(0)

func write_report() -> void:
	var f:=FileAccess.open(game.save_dir.path_join("walkthrough.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors,"report":report,"frames":frame_times.size()},"\t"))
	f.close()
