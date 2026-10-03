extends Node3D
const WorldBuilder = preload("res://world.gd")
const HUD = preload("res://hud.gd")
const Sound = preload("res://sound.gd")
const TITLES = ["雨港归人", "无声街巷", "潮汐机房", "最后一盏灯"]
const MEMORY_TITLES = ["蓝色发带", "未寄出的信", "停摆的怀表", "半张船票", "值班记录", "生日录音"]
const MEMORY_TEXT = [
	"阿澄把发带系在灯柄上：『这样你每次开灯，就会想起回家。』那时我还不知道，回家也会成为一件需要勇气的事。",
	"哥：我报名了下一班渡轮。不是要离开你，只是想看看海的另一边。等我回来，我们一起修好妈妈留下的收音机。——阿澄",
	"父亲的怀表停在二十三点十七分。表盖内刻着：『人不能让时间停下，但可以决定怎样记住它。』",
	"船票的另一半一直在我的口袋里。那晚她不是独自出海。是我答应送她，最后却没有出现。",
	"23:11，主电网过载。值班员沈砚申请切断灯塔支路，维持城区排水。批准。签字下方有一行反复涂掉的字：『我不知道她还在海上。』",
	"『生日快乐，哥。你总说灯塔替人找路，可是谁替你找路呢？如果哪天你迷路，就听海。不要一直听我的声音。』"
]
var font: Font
var builder
var world: Node3D
var player: CharacterBody3D
var puppet := {}
var camera: Camera3D
var lamp_light: OmniLight3D
var beam_light: SpotLight3D
var beacon: Node3D
var ui
var sound
var items: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var chapter := 0
var stage := 0
var unlocked := 0
var memories: Array = []
var flags := {}
var checkpoint := Vector3(0,0.1,20)
var mode := "menu"
var echo := false
var energy := 100.0
var echo_locked := false
var lure_cooldown := 0.0
var lure_time := 0.0
var lure_position := Vector3.ZERO
var lure_node: Node3D
var danger := 0.0
var flash := 0.0
var clock_time := 0.0
var walk_time := 0.0
var invulnerable := 0.0
var nearest := -1
var dialog_lines: Array = []
var dialog_done := Callable()
var water_values := [0,0,0]
var circuit_values := [0,0,0]
var bell_values: Array = []
var prism_values := [0,0,0]
var hints := 0
var volume := 0.65
var quality := 1
var subtitles := true
var ending := ""
var save_dir := ""
var save_path := ""
var test_mode := false
var screenshot_mode := ""
var screenshot_time := 0.0
var total_seconds := 0.0
var qa_mode := false
var cinematic := false
var benchmark := false
var benchmark_elapsed := 0.0
var benchmark_samples: Array = []

func _ready() -> void:
	var sf:=SystemFont.new()
	sf.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","SimHei"])
	font=sf
	var args:=OS.get_cmdline_user_args()
	test_mode=args.has("--self-test")
	qa_mode=args.has("--walkthrough")
	benchmark=args.has("--benchmark")
	for a in args:
		if a.begins_with("--shot="): screenshot_mode=a.trim_prefix("--shot=")
	save_dir=OS.get_executable_path().get_base_dir().path_join("存档")
	if OS.has_environment("LAST_LIGHT_ROOT"): save_dir=OS.get_environment("LAST_LIGHT_ROOT").path_join("存档")
	if OS.has_feature("editor"): save_dir=ProjectSettings.globalize_path("res://../artifacts/开发存档")
	if test_mode or qa_mode or benchmark or screenshot_mode!="": save_dir=ProjectSettings.globalize_path("res://../artifacts/测试存档") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("测试存档")
	DirAccess.make_dir_recursive_absolute(save_dir)
	save_path=save_dir.path_join("旅程.json")
	load_settings()
	sound=Sound.new()
	add_child(sound)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume)))
	var film_layer:=CanvasLayer.new()
	film_layer.layer=0
	add_child(film_layer)
	var film:=ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var film_mat:=ShaderMaterial.new()
	film_mat.shader=load("res://film.gdshader")
	film.material=film_mat
	film_layer.add_child(film)
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	ui=HUD.new()
	ui.game=self
	canvas.add_child(ui)
	load_meta()
	load_chapter(3 if not test_mode else 0,false)
	if benchmark:
		load_chapter(1,false)
		mode="play"
		player.position=Vector3(1,0.1,9)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1920,1080))
	elif qa_mode:
		var qa=load("res://qa.gd").new()
		qa.game=self
		add_child(qa)
	elif test_mode:
		call_deferred("run_tests")
	elif screenshot_mode!="":
		if screenshot_mode=="menu": show_main()
		else:
			load_chapter(2 if screenshot_mode=="valves" else clampi(int(screenshot_mode),0,3),false)
			mode="play"
			player.position=Vector3(1,0.1,9)
			ui.close_page()
			update_hud()
			if screenshot_mode=="valves": open_puzzle("valves")
	else: show_main()

func load_chapter(index: int, intro: bool = true) -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	if is_instance_valid(camera):
		remove_child(camera)
		camera.queue_free()
	chapter=index
	cinematic=false
	items.clear()
	enemies.clear()
	beacon=null
	lure_node=null
	energy=100
	echo=false
	echo_locked=false
	lure_time=0
	lure_cooldown=0
	danger=0
	invulnerable=3
	builder=WorldBuilder.new()
	world=builder.build(self,chapter)
	player=CharacterBody3D.new()
	player.name="沈砚"
	player.collision_layer=2
	player.collision_mask=1
	add_child(player)
	var c:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.32
	capsule.height=1.6
	c.shape=capsule
	c.position.y=0.82
	player.add_child(c)
	puppet=builder.person(player)
	player.position=checkpoint if intro else Vector3(0,0.1,20)
	lamp_light=builder.light(player,Vector3(0,1.4,0),Color("ffc97b"),2.0,5.5)
	beam_light=SpotLight3D.new()
	player.add_child(beam_light)
	beam_light.position=Vector3(0,1.5,0)
	beam_light.spot_range=12
	beam_light.spot_angle=42
	beam_light.light_color=Color("85ebdf")
	beam_light.light_energy=5
	beam_light.rotation.x=-0.2
	beam_light.visible=false
	camera=Camera3D.new()
	add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=25
	camera.far=240
	camera.position=player.position+Vector3(19,26,23)
	camera.look_at(player.position+Vector3(0,0.5,-2))
	camera.current=true
	populate()
	apply_quality()
	sound.chapter(chapter)
	mode="play"
	ui.close_page()
	update_hud()
	if intro: begin_intro()

func item(id: String, title: String, p: Vector3, hidden: bool = false, memory: bool = false) -> void:
	var n:=Node3D.new()
	world.add_child(n)
	n.position=p
	var color:=Color("70dacf") if hidden else Color("e9b86d")
	if memory:
		builder.cylinder(n,Vector3(0,0.3,0),0.45,0.35,0.6,Color("3a5661"))
		builder.orb(n,Vector3(0,1.0,0),0.18,color,1.4)
	elif id.begins_with("clue"):
		builder.person(n,true)
		builder.light(n,Vector3(0,1.2,0),color,0.8,3)
	elif id.begins_with("lens"):
		builder.cylinder(n,Vector3(0,0.6,0),0.55,0.4,1.2,Color("7b897f"))
		var mirror=builder.box(n,Vector3(0,1.6,0),Vector3(1.2,1.3,0.15),Color("b8b17d"))
		mirror.rotation.z=PI/4
		var glass=builder.box(n,Vector3(0,1.6,0.1),Vector3(0.95,1.05,0.08),color,false,0.5)
		glass.rotation.z=PI/4
	elif id in ["bridge","valves"]:
		builder.box(n,Vector3(0,0.55,0),Vector3(2.2,1.1,0.75),Color("395765"))
		for x in [-0.7,0.0,0.7]:
			var torus:=TorusMesh.new()
			torus.inner_radius=0.23
			torus.outer_radius=0.32
			var wheel=builder.mesh(n,torus,Vector3(x,1.3,0.35),builder.mat(color,0.1))
			wheel.rotation.x=PI/2
			builder.box(n,Vector3(x,1.3,0.35),Vector3(0.55,0.045,0.04),color)
			builder.box(n,Vector3(x,1.3,0.35),Vector3(0.045,0.55,0.04),color)
	elif id=="radio":
		builder.box(n,Vector3(0,0.5,0),Vector3(1.4,1,0.85),Color("635a45"))
		builder.box(n,Vector3(0,1.2,0),Vector3(0.95,0.45,0.55),Color("3e686b"))
		builder.box(n,Vector3(0.25,1.24,0.3),Vector3(0.3,0.12,0.04),color,false,1)
		builder.cylinder(n,Vector3(-0.3,1.8,0),0.025,0.012,1.1,Color("8b9f9c"))
		for x in [-0.35,-0.24,-0.13]: builder.box(n,Vector3(x,1.2,0.3),Vector3(0.04,0.24,0.04),Color("152f3c"))
	elif id=="fuse":
		builder.box(n,Vector3(0,0.25,0),Vector3(0.9,0.5,0.6),Color("4c6c67"))
		builder.cylinder(n,Vector3(0,0.7,0),0.12,0.12,0.4,color,1)
	elif id in ["exit","final"]:
		builder.cylinder(n,Vector3(0,0.08,0),0.7,0.7,0.1,color,0.6)
		builder.light(n,Vector3(0,1.0,0),color,0.6,3)
	elif id in ["log","inscription"]:
		builder.box(n,Vector3(0,0.5,0),Vector3(1.6,1,0.95),Color("576962"))
		var note=builder.box(n,Vector3(0,1.04,0),Vector3(0.75,0.025,0.5),Color("cfc3a1"))
		note.rotation.y=0.2
	else:
		builder.box(n,Vector3(0,0.6,0),Vector3(0.9,1.2,0.7),Color("304c55"))
		builder.box(n,Vector3(0,1.0,0.38),Vector3(0.6,0.22,0.06),color,false,1)
		builder.cylinder(n,Vector3(0,1.45,0),0.13,0.13,0.12,color,1)
	var ring:=TorusMesh.new()
	ring.inner_radius=0.52
	ring.outer_radius=0.58
	ring.rings=16
	ring.ring_segments=12
	var r=builder.mesh(n,ring,Vector3(0,0.1,0),builder.mat(color,0.4))
	items.append({"id":id,"title":title,"node":n,"hidden":hidden,"memory":memory,"ring":r})

func populate() -> void:
	match chapter:
		0:
			item("radio","收听 · 码头无线电",Vector3(3,0,17))
			item("fuse","拾取 · 回声中的保险丝",Vector3(-11,0,-2),true)
			item("power","检修 · 渡桥配电柜",Vector3(7,0,7))
			item("bridge","校准 · 渡桥绞盘",Vector3(5,0,-14))
			item("exit","前往 · 无声街巷",Vector3(0,0,-21))
			item("m0","记忆 · 蓝色发带",Vector3(-14,0,17),true,true)
			item("m1","记忆 · 未寄出的信",Vector3(14,0,-16),true,true)
		1:
			item("clue0","回声 · 邮递员",Vector3(-7,0,3),true)
			item("clue1","回声 · 钟表匠",Vector3(7,0,16),true)
			item("clue2","回声 · 面包师",Vector3(-7,0,-11),true)
			item("bells","操作 · 三声门铃",Vector3(4,0,-18))
			item("exit","前往 · 潮汐机房",Vector3(0,0,-22))
			item("m2","记忆 · 停摆的怀表",Vector3(15,0,5),true,true)
			item("m3","记忆 · 半张船票",Vector3(-15,0,-6),true,true)
			spawn_enemy(Vector3(4,0,5),[Vector3(4,0,5),Vector3(7,0,-7),Vector3(3,0,-14),Vector3(-5,0,-5)])
			spawn_enemy(Vector3(-5,0,15),[Vector3(-5,0,15),Vector3(5,0,19),Vector3(6,0,10),Vector3(-6,0,6)])
		2:
			item("log","阅读 · 防潮值班记录",Vector3(0,0,16))
			item("pump","唤醒 · 旧日水泵",Vector3(-5,0,8),true)
			item("valves","调节 · 三联水阀",Vector3(6,0,7))
			item("circuit","连接 · 灯塔供电线路",Vector3(0,0,-10))
			item("exit","前往 · 灯塔堤岸",Vector3(0,0,-21))
			item("m4","记忆 · 值班记录背面",Vector3(15,0,-3),true,true)
			spawn_enemy(Vector3(-5,0,-14),[Vector3(-5,0,-14),Vector3(5,0,-17),Vector3(6,0,-7),Vector3(-5,0,-7)])
		3:
			item("lens0","校准 · 海之镜",Vector3(-11,0,11))
			item("lens1","校准 · 归之镜",Vector3(11,0,-1))
			item("lens2","校准 · 灯之镜",Vector3(-11,0,-12))
			item("inscription","回声 · 守塔人的刻字",Vector3(8,0,16),true)
			item("final","登塔 · 点亮最后一盏灯",Vector3(0,0,-12))
			item("m5","记忆 · 生日录音",Vector3(14,0,-14),true,true)
			spawn_enemy(Vector3(5,0,11),[Vector3(5,0,11),Vector3(7,0,1),Vector3(-5,0,-3),Vector3(-6,0,5)])
			spawn_enemy(Vector3(5,0,-10),[Vector3(5,0,-10),Vector3(-5,0,-8),Vector3(-6,0,-16),Vector3(6,0,-17)])
	for it in items:
		if it["hidden"]:
			for i in 5:
				var p:Vector3=it["node"].position+Vector3(sin(i*1.3)*0.15,0.07,2+i*0.55)
				var footprint=builder.box(world,p,Vector3(0.13,0.025,0.26),Color("68bfb6"),false,0.5)
				footprint.set_meta("echo_mark",true)
				footprint.visible=false
	refresh_items()

func spawn_enemy(pos: Vector3, path: Array) -> void:
	var body:=CharacterBody3D.new()
	body.collision_layer=4
	body.collision_mask=1
	world.add_child(body)
	body.position=pos
	var c:=CollisionShape3D.new()
	var cap:=CapsuleShape3D.new()
	cap.radius=0.35
	cap.height=1.7
	c.shape=cap
	c.position.y=0.9
	body.add_child(c)
	var model=builder.person(body,false,true)
	model["model"].scale=Vector3(1,1.25,1)
	var glow=builder.light(body,Vector3(0,1.6,0),Color("73c9c9"),0.7,3)
	enemies.append({"body":body,"model":model,"path":path,"index":0,"state":"巡逻","alert":0.0,"last":pos,"lost":0.0,"home":pos,"light":glow})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	clock_time+=delta
	flash=maxf(0,flash-delta*2)
	if is_instance_valid(beacon): beacon.rotation.y+=delta*0.22
	for it in items:
		if it["id"].begins_with("lens"):
			var index:=int(it["id"].trim_prefix("lens"))
			it["node"].rotation.y=lerp_angle(it["node"].rotation.y,prism_values[index]*PI/2,delta*4)
	for piece in world.get_children():
		if piece.has_meta("bridge_piece"):
			piece.rotation.x=lerpf(piece.rotation.x,0.0 if flags.get("bridge",false) else -0.7,delta*2)
	for flag in builder.dynamic:
		if is_instance_valid(flag): flag.rotation.x=sin(clock_time*1.7+flag.position.x)*0.12
	if mode=="menu":
		var target:=Vector3(-6,3,-12) if chapter==3 else Vector3(0,0,-4)
		camera.size=lerpf(camera.size,33,delta*2)
		camera.position=camera.position.lerp(target+Vector3(24,30,29),delta*2)
		camera.look_at(target)
	elif cinematic:
		var target:=Vector3(-3,9,-18)
		camera.size=lerpf(camera.size,22,delta*2)
		camera.position=camera.position.lerp(target+Vector3(17,13,23),delta*2)
		camera.look_at(target)
	elif mode=="play":
		total_seconds+=delta
		invulnerable=maxf(0,invulnerable-delta)
		lure_cooldown=maxf(0,lure_cooldown-delta)
		lure_time=maxf(0,lure_time-delta)
		var want_echo:=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if echo_locked and energy>=28: echo_locked=false
		var was_echo:=echo
		echo=want_echo and not echo_locked and energy>0
		energy=clampf(energy+(-11.0 if echo else 16.0)*delta,0,100)
		if energy<=0: echo_locked=true
		if echo and not was_echo: sound.play_fx("echo")
		beam_light.visible=echo
		lamp_light.light_color=Color("8de9dc") if echo else Color("ffc97b")
		lamp_light.omni_range=8 if echo else 5.5
		var v:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		v=v.normalized()
		var right:=camera.global_basis.x
		right.y=0
		right=right.normalized()
		var forward:=camera.global_basis.z
		forward.y=0
		forward=forward.normalized()
		var direction:Vector3=right*v.x+forward*v.y
		var speed:=2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.2
		player.velocity=direction*speed
		player.velocity.y=-2
		player.move_and_slide()
		player.position.x=clampf(player.position.x,-17.35,17.35)
		player.position.z=clampf(player.position.z,-23.35,23.35)
		var aim=mouse_world()
		var facing:Vector3=aim-player.position
		facing.y=0
		if facing.length()>0.2:
			var angle:=atan2(-facing.x,-facing.z)
			puppet["model"].rotation.y=lerp_angle(puppet["model"].rotation.y,angle,delta*14)
			beam_light.rotation.y=angle
		if direction.length()>0:
			walk_time+=delta*speed*2.8
			puppet["left"].rotation.x=sin(walk_time)*0.5
			puppet["right"].rotation.x=-sin(walk_time)*0.5
			puppet["model"].position.y=absf(sin(walk_time))*0.04
			if int(clock_time*2.8)!=int((clock_time-delta)*2.8): sound.play_fx("step")
		else:
			puppet["left"].rotation.x=lerpf(puppet["left"].rotation.x,0,delta*10)
			puppet["right"].rotation.x=lerpf(puppet["right"].rotation.x,0,delta*10)
		camera.position=camera.position.lerp(player.position+Vector3(19,26,23),minf(delta*4,1))
		update_enemies(delta)
		refresh_items()
		update_nearest()
		update_hud()
	if screenshot_mode!="":
		screenshot_time+=delta
		if screenshot_time>3:
			var path:=ProjectSettings.globalize_path("res://../artifacts/画面-"+screenshot_mode+".png") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("画面-"+screenshot_mode+".png")
			get_viewport().get_texture().get_image().save_png(path)
			print("SCREENSHOT ",path)
			get_tree().quit()

func _process(delta: float) -> void:
	if not benchmark: return
	benchmark_elapsed+=delta
	invulnerable=10
	if benchmark_elapsed>3:
		benchmark_samples.append(delta)
	if benchmark_elapsed>15:
		var total:=0.0
		for d in benchmark_samples: total+=float(d)
		benchmark_samples.sort()
		var result={"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1920x1080","quality":"精致","chapter":1,"samples":benchmark_samples.size(),"average_fps":benchmark_samples.size()/total,"p95_frame_ms":float(benchmark_samples[int(benchmark_samples.size()*0.95)])*1000,"note":"12秒固定街巷场景；不代表所有设备或全程帧率"}
		var f:=FileAccess.open(save_dir.path_join("benchmark.json"),FileAccess.WRITE)
		f.store_string(JSON.stringify(result,"\t"))
		f.close()
		print("BENCHMARK ",JSON.stringify(result))
		get_tree().quit()

func mouse_world() -> Vector3:
	var m:=get_viewport().get_mouse_position()
	var origin:=camera.project_ray_origin(m)
	var direction:=camera.project_ray_normal(m)
	var hit=Plane(Vector3.UP,0.7).intersects_ray(origin,direction)
	return hit if hit!=null else player.position+Vector3.FORWARD

func update_enemies(delta: float) -> void:
	danger=0
	for en in enemies:
		var body:CharacterBody3D=en["body"]
		var distance:=body.position.distance_to(player.position)
		var q:=PhysicsRayQueryParameters3D.create(body.position+Vector3(0,1.0,0),player.position+Vector3(0,1.0,0),1)
		var clear:=world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		var detection:=10.5 if echo else (2.2 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0)
		var seen:=clear and distance<detection and invulnerable<=0
		if seen:
			en["alert"]=minf(1,en["alert"]+delta*(0.9 if echo else 0.55))
			en["last"]=player.position
			en["lost"]=0.0
			if en["alert"]>=1:
				if en["state"]!="追逐": sound.play_fx("alarm")
				en["state"]="追逐"
			elif en["state"]!="追逐": en["state"]="察觉"
		else:
			en["alert"]=maxf(0,en["alert"]-delta*0.35)
			en["lost"]+=delta
			if en["state"]=="追逐" and en["lost"]>3: en["state"]="返回"
			if en["state"]=="察觉" and en["alert"]<=0: en["state"]="返回"
		var target:Vector3=en["path"][en["index"]]
		var speed:=1.25
		if en["state"]=="追逐":
			target=en["last"]
			speed=3.15
		elif lure_time>0 and body.position.distance_to(lure_position)<17:
			target=lure_position
			en["state"]="察觉"
			speed=2.0
		elif en["state"]=="察觉" and seen: target=player.position; speed=0.6
		elif body.position.distance_to(target)<0.8:
			en["index"]=(en["index"]+1)%en["path"].size()
			en["state"]="巡逻"
		var move:=target-body.position
		move.y=0
		# Local obstacle steering keeps agents from pushing forever against cover.
		if move.length()>0.25:
			move=move.normalized()
			var check:=PhysicsRayQueryParameters3D.create(body.position+Vector3(0,0.7,0),body.position+Vector3(0,0.7,0)+move*1.2,1)
			if not world.get_world_3d().direct_space_state.intersect_ray(check).is_empty():
				var side:=Vector3(-move.z,0,move.x)
				var test:=PhysicsRayQueryParameters3D.create(body.position+Vector3(0,0.7,0),body.position+Vector3(0,0.7,0)+side*1.3,1)
				move=side if world.get_world_3d().direct_space_state.intersect_ray(test).is_empty() else -side
			body.velocity=move*speed
			body.velocity.y=-2
			body.move_and_slide()
			en["model"]["model"].rotation.y=lerp_angle(en["model"]["model"].rotation.y,atan2(-move.x,-move.z),delta*5)
			en["model"]["left"].rotation.x=sin(clock_time*7)*0.4
			en["model"]["right"].rotation.x=-sin(clock_time*7)*0.4
		en["light"].light_color=Color("e58066") if en["state"]=="追逐" else Color("73c9c9")
		danger=maxf(danger,en["alert"])
		if distance<0.8 and invulnerable<=0 and en["state"]=="追逐":
			caught()
			return
	if is_instance_valid(lure_node):
		lure_node.visible=lure_time>0
		lure_node.scale=Vector3.ONE*(1.0+sin(clock_time*8)*0.15)

func refresh_items() -> void:
	for it in items:
		var visible:=true
		var id:String=it["id"]
		if it["memory"] and memories.has(int(id.trim_prefix("m"))): visible=false
		if id=="fuse" and flags.get("fuse",false): visible=false
		if it["hidden"]:
			visible=visible and echo and player.position.distance_to(it["node"].position)<9
		it["node"].visible=visible
		it["ring"].rotation.y=clock_time*0.4
	for child in world.get_children():
		if child.has_meta("echo_mark"): child.visible=echo and player.position.distance_to(child.position)<10

func update_nearest() -> void:
	nearest=-1
	var closest:=2.3
	for i in items.size():
		var it=items[i]
		if not it["node"].visible: continue
		var d:=player.position.distance_to(it["node"].position)
		if d<closest: closest=d; nearest=i
	ui.prompt.text="[ E ]  "+items[nearest]["title"] if nearest>=0 else ""
	if nearest<0 and echo_locked: ui.prompt.text="灯芯正在冷却……松开右键可恢复能量"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F11:
			toggle_fullscreen()
		elif event.physical_keycode==KEY_ESCAPE:
			if mode=="play": show_pause()
			elif mode=="pause": resume()
			elif mode=="puzzle": resume()
		elif event.physical_keycode in [KEY_E,KEY_SPACE]:
			if mode=="dialog": next_dialog()
			elif mode=="play" and nearest>=0: interact(items[nearest]["id"])
		elif event.physical_keycode==KEY_Q and mode=="play": throw_lure()
		elif event.physical_keycode==KEY_H and mode=="play": hint()
		elif event.physical_keycode==KEY_J and mode=="play": show_journal()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mode=="dialog": next_dialog()

func throw_lure() -> void:
	if lure_cooldown>0: ui.toast("诱饵正在恢复，稍等片刻。",2); return
	var dest:=mouse_world()
	var delta:=dest-player.position
	delta.y=0
	if delta.length()>8: delta=delta.normalized()*8
	lure_position=player.position+delta
	lure_position.x=clampf(lure_position.x,-17,17)
	lure_position.z=clampf(lure_position.z,-23,23)
	lure_position.y=0.2
	lure_time=7
	lure_cooldown=11
	if not is_instance_valid(lure_node):
		lure_node=Node3D.new()
		world.add_child(lure_node)
		builder.orb(lure_node,Vector3.ZERO,0.16,Color("f1c77e"),2)
		builder.light(lure_node,Vector3(0,0.4,0),Color("e9bb76"),1.5,4)
	lure_node.position=lure_position
	sound.play_fx("lure")
	ui.toast("声音诱饵已投出 · 绕开声音聚集的方向",2.5)

func caught() -> void:
	player.position=checkpoint
	energy=100
	echo=false
	invulnerable=5
	danger=0
	flash=1
	for en in enemies:
		en["body"].position=en["home"]
		en["alert"]=0.0
		en["state"]="巡逻"
		en["lost"]=0.0
	ui.toast("你在灯火边醒来。进度已保留。\n慢行、遮挡或投出诱饵，可以避开失声者。",5)
	sound.play_fx("alarm")

func update_hud() -> void:
	ui.top.text="%02d  /  %s\n潮生港 · 暴雨之夜" % [chapter+1,TITLES[chapter]]
	ui.objective.text="当前目标\n"+objective_text()
	ui.bottom.text="WASD 移动    鼠标瞄准 / 右键回声灯    E 交互    Shift 慢行    Q 诱饵    H 提示    J 手记    Esc 暂停"

func objective_text() -> String:
	match chapter:
		0:
			if not flags.get("radio",false): return "收听码头的无线电"
			if not flags.get("fuse",false): return "用回声灯寻找仓库旁的保险丝"
			if not flags.get("power",false): return "将保险丝装入渡桥配电柜"
			if not flags.get("bridge",false): return "校准绞盘，放下通往街巷的渡桥"
			return "沿码头北行，进入无声街巷"
		1:
			if not flags.get("bells",false): return "寻找三段居民回声，解开门铃顺序"
			return "穿过街巷北门，进入潮汐机房"
		2:
			if not flags.get("pump",false): return "读值班记录，用回声灯唤醒水泵"
			if not flags.get("valves",false): return "将水位调至 2 / 1 / 3"
			if not flags.get("circuit",false): return "连接线路，为灯塔恢复供电"
			return "离开泵站，前往灯塔堤岸"
		3:
			if not all_lenses(): return "寻找守塔人的刻字，校准三面镜子"
			return "进入灯塔，回应阿澄的呼唤"
	return ""

func begin_intro() -> void:
	var scenes=[
		[["沈砚 · 手记","十年了。渡船把我放在旧码头，像放下一封无人认领的信。城里没有灯，只有海水还记得回来的路。"],["无线电 · 阿澄","……哥？如果你听得见，别让灯再灭一次。我在灯塔等你。"],["沈砚","这个声音不可能还在。阿澄已经……先看看码头的无线电。"],["行动提示","WASD 移动，靠近物体按 E。按住鼠标右键，旧灯会照见过去。地图上的青色点是可见的机关；H 随时提供提示。"]],
		[["沈砚","街上的窗户还亮着，玻璃后却一个人也没有。像是有人匆忙离开，把生活留在了原处。"],["无线电 · 阿澄","别跟着没有脚步声的人。它们只听得见你手里的灯。"],["行动提示","按住 Shift 慢行，借建筑和花坛遮挡视线。Q 向鼠标方向投出声音诱饵。回声灯能看见居民留下的线索，也会引来失声者。"]],
		[["沈砚","泵站的门没有锁。值班桌上放着一页纸，签名是我的。"],["无线电 · 阿澄","你一直以为，忘了那一夜，天就会亮。可灯塔还在等你。"],["沈砚","如果把供电恢复，也许我就能知道那晚发生了什么。"]],
		[["沈砚","堤岸尽头，灯塔像一根扎进黑夜的针。我的手在抖。这一次不是因为冷。"],["无线电 · 阿澄","海之镜看向黎明，归之镜望着暮色，灯之镜指向归来的路。那是爸爸教我们的。你还记得吗？"],["沈砚","记得。天亮以前，我会把灯点起来。"]]
	]
	talk(scenes[chapter])

func talk(lines: Array, done: Callable = Callable()) -> void:
	dialog_lines=lines.duplicate(true)
	dialog_done=done
	mode="dialog"
	echo=false
	beam_light.visible=false
	ui.close_page()
	show_dialog_line()

func show_dialog_line() -> void:
	if dialog_lines.is_empty():
		ui.dialogue.hide()
		mode="play"
		invulnerable=maxf(invulnerable,1.5)
		if dialog_done.is_valid():
			var done:=dialog_done
			dialog_done=Callable()
			done.call()
		return
	var line=dialog_lines.pop_front()
	ui.say(line[0],line[1])
	sound.play_fx("talk")

func next_dialog() -> void:
	if ui.speech.visible_characters<ui.speech.text.length() and ui.speech.visible_characters>=0:
		ui.speech_time=1000
		ui.speech.visible_characters=-1
	else: show_dialog_line()

func commit(key: String, text: String = "") -> void:
	flags[key]=true
	stage+=1
	checkpoint=player.position
	save_game()
	sound.play_fx("success")
	if text!="": ui.toast(text)
	update_hud()

func interact(id: String) -> void:
	if id.begins_with("m") and id.length()==2:
		var index:=int(id.substr(1))
		if not memories.has(index):
			memories.append(index)
			save_game()
			talk([["拾回的记忆 · "+MEMORY_TITLES[index],MEMORY_TEXT[index]]])
		return
	match id:
		"radio":
			commit("radio")
			talk([["无线电 · 阿澄","你带着那盏旧灯吗？仓库旁边有一只保险丝。现在看不见了，要照着它从前的位置。"],["沈砚","码头西侧，仓库和木箱之间。闭上眼，我甚至还记得那条路。"]])
		"fuse":
			commit("fuse","已获得保险丝 · 前往东侧配电柜")
			talk([["沈砚","保险丝竟然还有温度。过去的东西，为什么能被带到现在？"]])
		"power":
			if flags.get("power",false): ui.toast("渡桥已通电。去北侧绞盘校准齿轮。"); return
			if not flags.get("fuse",false): talk([["沈砚","保险丝烧断了。用回声灯照照西侧仓库周围，也许过去留下了备用件。"]]); return
			commit("power","电流恢复 · 北侧绞盘已启动")
			talk([["配电柜 · 维护标签","电桥校准：让三个齿轮的刻线全部朝上。左轮带动中轮，中轮带动右轮，右轮只转动自身。"],["无线电 · 阿澄","你看，灯还愿意听你的话。"]])
		"bridge":
			if not flags.get("power",false): ui.toast("绞盘没有电。先修复东侧配电柜。"); return
			if flags.get("bridge",false): ui.toast("渡桥已放下，北面的路通了。"); return
			open_puzzle("bridge")
		"clue0":
			commit("clue0")
			talk([["回声 · 邮递员","警报响起后，我先去了钟表店。老周不肯走，一定要等他的钟敲完。"],["回声线索","门铃第一声：钟。"]])
		"clue1":
			commit("clue1")
			talk([["回声 · 钟表匠","邮递员敲门时，面包已经送到码头。送面包的小姑娘说，等我们上船后，才会把那封信寄出去。"],["回声线索","钟声之后是麦穗，最后才是信。"]])
		"clue2":
			commit("clue2")
			talk([["回声 · 面包师","阿澄买了两份面包。她说哥哥答应陪她看海。直到最后，她还站在码头等。"],["沈砚","我答应过她。为什么我连这件事都忘了？"]])
		"bells":
			if flags.get("bells",false): ui.toast("北门已经开启。"); return
			open_puzzle("bells")
		"log":
			commit("log")
			talk([["值班日志 · 23:11","主电网过载。城内排水与灯塔供电，仅可保留一项。值班员沈砚决定切断灯塔支路。"],["沈砚","我救下了街上的人，却让最后一班渡轮失去了航标。不是灯塔坏了。是我亲手关掉了它。"],["值班日志 · 维护页","备用水泵仅能在回声状态下唤醒。三座水箱的安全刻度：2、1、3。每只阀门为自身注水，并向下一只水箱补入一格。"]])
		"pump":
			if not flags.get("pump",false): commit("pump","旧水泵启动 · 回到三联水阀调节水位")
			else: ui.toast("水泵正在运行。")
		"valves":
			if not flags.get("pump",false): ui.toast("水泵尚未运行。用回声灯寻找西侧旧泵。"); return
			if flags.get("valves",false): ui.toast("水位稳定，北侧电路板可以使用。"); return
			open_puzzle("valves")
		"circuit":
			if not flags.get("valves",false): ui.toast("电缆槽仍被海水淹没。先稳定三座水箱。"); return
			if flags.get("circuit",false): ui.toast("灯塔的电力已经恢复。"); return
			open_puzzle("circuit")
		"inscription":
			commit("inscription")
			talk([["守塔人的刻字","海向东，归向西，灯向南。光不必追逐黑暗，只要照见归途。"],["沈砚","海之镜朝东，归之镜朝西，灯之镜朝南。先把这三束光带回灯塔。"]])
		"lens0","lens1","lens2":
			open_puzzle(id)
		"final":
			if not all_lenses(): ui.toast("三束光尚未汇合。先校准堤岸上的三面镜子。"); return
			cinematic=true
			player.position=Vector3(0,10.3,-16)
			talk([["阿澄","你终于来了。这里的海永远停在那一刻，只要灯不亮，我就不用离开。"],["沈砚","我试过把所有事都忘掉。可是每一次听见海，我还是会回到这里。对不起，那天我没能来。"],["阿澄","你救下了很多人，哥。我不是回来让你再选一次的。"],["阿澄","点亮它吧。或者留下一点光，让这段记忆陪你走。无论怎样，你都该回家了。"]],show_choice)
		"exit":
			var complete:bool=flags.get(["bridge","bells","circuit"][mini(chapter,2)],false)
			if not complete: ui.toast("前路尚未打开。"+objective_text()); return
			next_chapter()

func open_puzzle(kind: String) -> void:
	mode="puzzle"
	echo=false
	beam_light.visible=false
	var v
	match kind:
		"bridge":
			v=ui.make_page("渡桥绞盘","三枚刻线全部朝上，渡桥才会落下。\n左轮带动中轮，中轮带动右轮；右轮独立。")
			ui.body_text(v,"刻线方向：   "+directions(circuit_values))
			for i in 3: ui.button(v,["转动左轮","转动中轮","转动右轮"][i],func(): turn_bridge(i))
			ui.button(v,"确认校准",func(): solve_puzzle("bridge"))
		"bells":
			v=ui.make_page("三声门铃","门牌刻着三枚符号。\n居民的回声里，藏着离开这条街的顺序。")
			var seq:=""
			for b in bell_values: seq+=["钟  ","麦穗  ","信  "][int(b)]
			ui.body_text(v,"已敲响： "+(seq if seq!="" else "等待第一声"))
			for i in 3: ui.button(v,["敲响 · 钟","敲响 · 麦穗","敲响 · 信"][i],func(): ring_bell(i))
			ui.button(v,"重新开始",func(): bell_values.clear(); open_puzzle("bells"))
		"valves":
			v=ui.make_page("三联水阀","目标水位：2 / 1 / 3。每格水位在 0—3 之间循环。\n转动任一阀门，会使自身与右侧水箱各增加一格。")
			ui.body_text(v,"当前水位：   %d  /  %d  /  %d" % water_values,30)
			for i in 3: ui.button(v,"转动 %s 阀" % ["左","中","右"][i],func(): turn_valve(i))
			ui.button(v,"检查水位",func(): solve_puzzle("valves"))
			ui.button(v,"清空水箱",func(): water_values=[0,0,0]; open_puzzle("valves"))
		"circuit":
			v=ui.make_page("灯塔供电","将三段导线的方向调整为：东、南、东。\n每个开关独立旋转一段导线。")
			ui.body_text(v,"当前方向：   "+directions(circuit_values),26)
			for i in 3: ui.button(v,"旋转第 %d 段" % (i+1),func(): circuit_values[i]=(circuit_values[i]+1)%4; open_puzzle("circuit"))
			ui.button(v,"接通电路",func(): solve_puzzle("circuit"))
		_:
			var index:=int(kind.trim_prefix("lens"))
			v=ui.make_page(["海之镜","归之镜","灯之镜"][index],"校准这面镜子的朝向，使光抵达灯塔。\n守塔人的刻字，在堤岸南端的回声里。")
			ui.body_text(v,"当前方向： "+["北 ↑","东 →","南 ↓","西 ←"][prism_values[index]],30)
			ui.button(v,"顺时针转动",func(): prism_values[index]=(prism_values[index]+1)%4; open_puzzle(kind))
			ui.button(v,"锁定镜面",func(): solve_puzzle(kind))
	ui.button(v,"返回场景  /  Esc",resume)
	ui.button(v,"查看提示",func(): hint())

func directions(values: Array) -> String:
	var text:=""
	for v in values: text += ["北 ↑    ","东 →    ","南 ↓    ","西 ←    "][int(v)]
	return text

func turn_bridge(i: int) -> void:
	circuit_values[i]=(circuit_values[i]+1)%4
	if i<2: circuit_values[i+1]=(circuit_values[i+1]+1)%4
	sound.play_fx("talk")
	open_puzzle("bridge")

func turn_valve(i: int) -> void:
	water_values[i]=(water_values[i]+1)%4
	water_values[(i+1)%3]=(water_values[(i+1)%3]+1)%4
	sound.play_fx("talk")
	open_puzzle("valves")

func ring_bell(i: int) -> void:
	bell_values.append(i)
	sound.play_fx("lure")
	if bell_values.size()==3: solve_puzzle("bells")
	else: open_puzzle("bells")

func solve_puzzle(kind: String) -> void:
	var solved:=false
	match kind:
		"bridge": solved=circuit_values==[0,0,0]
		"bells": solved=bell_values==[0,1,2]
		"valves": solved=water_values==[2,1,3]
		"circuit": solved=circuit_values==[1,2,1]
		_:
			var index:=int(kind.trim_prefix("lens"))
			solved=prism_values[index]==[1,3,2][index]
	if not solved:
		if kind=="bells": bell_values.clear(); open_puzzle("bells")
		ui.toast("机关尚未对齐。没有损失，可以继续调整。\n按 H 或点击「查看提示」获得帮助。",4)
		sound.play_fx("talk")
		return
	resume()
	commit(kind,"机关已完成 · 进度已保存")
	if kind=="bridge": talk([["沈砚","渡桥落下了。海水里好像有许多人影，可桥的另一端只有风。"],["无线电 · 阿澄","沿着街往北走。别忘了，光也会让它们看见你。"]])
	if kind=="valves":
		circuit_values=[3,0,2]
		save_game()
		talk([["沈砚","水位降下去了。北边的线路板露了出来。只要接上，灯塔就能重新得到电。"]])
	if kind=="circuit": talk([["沈砚","这一次，我不用再切断任何一盏灯。"],["无线电 · 阿澄","那就来吧。我等了很久，但没有怪过你。"]])

func all_lenses() -> bool:
	return flags.get("lens0",false) and flags.get("lens1",false) and flags.get("lens2",false)

func hint() -> void:
	hints+=1
	var text:=""
	match chapter:
		0:
			if not flags.get("fuse",false): text="保险丝在西侧仓库以北（地图左侧，木箱附近）。靠近后按住右键，再按 E 拾取。"
			elif not flags.get("power",false): text="配电柜位于东侧、起点往北不远的位置。装入保险丝即可启动绞盘。"
			else: text="先转左轮直到左轮朝北，再转中轮直到中轮朝北，最后只转右轮。全部朝北后确认。"
		1: text="用回声灯照亮居民。门铃正确顺序为：钟 → 麦穗 → 信。慢行并绕花坛走，可避开失声者。" if hints>1 else "邮局在西侧中段，钟表店在东南，面包房在西北。居民只在回声灯中出现。"
		2:
			if not flags.get("pump",false): text="旧泵位于入口西北方，用右键照亮它并按 E。"
			elif not flags.get("valves",false): text="清空水箱后依次转动：中阀 1 次、右阀 2 次。水位即为 2 / 1 / 3。" if hints>1 else "每次转阀影响两个水箱；右阀的下一只水箱是左边的第一只。可先清空再试。"
			else: text="北侧线路板的三段导线分别朝东、南、东，确认接通后走向北门。"
		3: text="三面镜子对应：海之镜朝东、归之镜朝西、灯之镜朝南。锁定全部镜面后，前往灯塔门口。" if hints>1 else "入口东侧的回声刻字记着方向。黎明在东，暮色在西，归来的路在南。"
	ui.toast(text,9)

func next_chapter() -> void:
	chapter+=1
	unlocked=maxi(unlocked,chapter)
	stage=0
	flags={}
	checkpoint=Vector3(0,0.1,20)
	circuit_values=[1,2,3]
	water_values=[0,0,0]
	bell_values=[]
	prism_values=[0,0,0]
	hints=0
	save_game()
	load_chapter(chapter,true)

func show_choice() -> void:
	mode="choice"
	var v=ui.make_page("灯亮以前","有些告别，是把一盏灯交还给海。\n有些记住，是带着它继续走。")
	ui.body_text(v,"你已拾回 %d / 6 段记忆。\n两种选择都将结束这个夜晚。" % memories.size())
	ui.button(v,"点亮灯塔 · 让回声归于大海",func(): finish("release"))
	ui.button(v,"保留灯芯 · 带着记忆回家",func(): finish("keep"))

func finish(choice: String) -> void:
	ending=choice
	flags["completed"]=true
	unlocked=3
	save_game()
	var lines:Array=[]
	if choice=="release":
		lines=[["阿澄","你看，天亮了。以后每一次日出，都不必再等我。"],["沈砚 · 尾声","灯光越过海面，街上的窗户一扇扇熄灭。她没有转身，只是朝远处挥了挥手。"],["沈砚 · 尾声","清晨，第一班渡船靠了岸。我把旧灯留在塔顶，带着那封信回家。这一次，我记得全部。"]]
	else:
		lines=[["阿澄","那就带我去看看，海的另一边吧。但要答应我，不许再困在这里。"],["沈砚 · 尾声","我卸下旧灯的灯芯。小小的光落进掌心，像一句没有说完的晚安。灯塔用新的灯照亮了海。"],["沈砚 · 尾声","后来，我修好了那台收音机。里面不再传来她的声音。可每逢雨夜，我仍会为窗边留一盏灯。"]]
	if memories.size()==6: lines.append(["完整的记忆","在信封背面，你找到她留下的最后一句话：『我这一生，拥有过很多幸福。不要只记得最后那一晚。』"])
	talk(lines,show_ending)

func show_ending() -> void:
	mode="ending"
	var v=ui.make_page("天亮以后" if ending=="release" else "带光归航","《最后一盏灯》 · 终\n谢谢你，陪他们走完这个夜晚。")
	ui.body_text(v,"记忆收集  %d / 6     ·     旅程用时  %d 分钟\n\n原创故事、美术模型与合成配乐\n在潮生港，献给所有学着告别的人。" % [memories.size(),maxi(1,int(total_seconds/60))])
	ui.button(v,"重返塔顶 · 体验另一种告别",func(): flags.erase("completed"); ending=""; show_choice())
	ui.button(v,"阅读收集的手记",show_journal)
	ui.button(v,"返回主菜单",show_main)
	ui.button(v,"退出游戏",func(): get_tree().quit())

func resume() -> void:
	ui.close_page()
	mode="play"
	invulnerable=maxf(invulnerable,1.2)
	update_hud()

func show_main() -> void:
	mode="menu"
	cinematic=false
	ui.dialogue.hide()
	var v=ui.make_page("最后一盏灯","当整座城忘记了黎明，\n你还记得，为谁留一盏灯吗？")
	ui.button(v,"继续旅程",continue_game,not FileAccess.file_exists(save_path))
	ui.button(v,"开始新的旅程",confirm_new)
	ui.button(v,"章节回望",show_chapters)
	ui.button(v,"设置与操作",func(): show_settings("menu"))
	ui.button(v,"制作与致谢",show_credits)
	ui.button(v,"退出游戏",func(): get_tree().quit())

func confirm_new() -> void:
	if not FileAccess.file_exists(save_path): new_game(); return
	var v=ui.make_page("重新启航","新旅程会重置当前章节进度和记忆收集。\n已经解锁的章节仍然保留。")
	ui.button(v,"开始新旅程",new_game)
	ui.button(v,"保留当前旅程",show_main)

func new_game() -> void:
	chapter=0
	stage=0
	flags={}
	memories=[]
	ending=""
	total_seconds=0
	checkpoint=Vector3(0,0.1,20)
	circuit_values=[1,2,3]
	water_values=[0,0,0]
	prism_values=[0,0,0]
	bell_values=[]
	hints=0
	save_game()
	load_chapter(0,true)

func show_pause() -> void:
	mode="pause"
	echo=false
	beam_light.visible=false
	var v=ui.make_page("雨暂时停下","进度会在完成机关、拾取记忆时自动保存。\n也可以在这里保存当前位置。")
	ui.button(v,"继续旅程",resume)
	ui.button(v,"保存当前位置",func(): checkpoint=player.position; save_game(); ui.toast("旅程已保存"))
	ui.button(v,"拾回的手记",show_journal)
	ui.button(v,"设置与操作",func(): show_settings("pause"))
	ui.button(v,"返回主菜单",func(): checkpoint=player.position; save_game(); show_main())
	ui.button(v,"保存并退出",func(): checkpoint=player.position; save_game(); get_tree().quit())

func show_settings(back: String) -> void:
	mode="settings"
	var v=ui.make_page("设置与操作","WASD 移动 · 右键回声灯 · E 交互\nShift 慢行 · Q 诱饵 · H 提示 · J 手记 · F11 全屏")
	ui.body_text(v,"总音量")
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=0.05
	slider.value=volume
	slider.custom_minimum_size=Vector2(0,30)
	slider.value_changed.connect(func(value: float): volume=value; AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume))); save_settings())
	v.add_child(slider)
	ui.button(v,"画质："+["流畅","精致"][quality],func(): quality=1-quality; apply_quality(); save_settings(); show_settings(back))
	ui.button(v,"切换窗口 / 全屏",toggle_fullscreen)
	ui.button(v,"字幕呈现："+("逐字显示" if subtitles else "立即显示"),func(): subtitles=not subtitles; save_settings(); show_settings(back))
	ui.body_text(v,"故事文字始终保留。流畅画质关闭动态阴影与抗锯齿。\n提示不消耗资源，也不会影响结局。",16)
	ui.button(v,"返回",show_main if back=="menu" else show_pause)

func apply_quality() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_2X if quality==1 else Viewport.MSAA_DISABLED
	for child in world.get_children():
		if child is DirectionalLight3D: child.shadow_enabled=quality==1

func toggle_fullscreen() -> void:
	var full:=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	save_settings()

func show_chapters() -> void:
	mode="chapters"
	var v=ui.make_page("章节回望","选择已解锁的章节，从该章开头重玩。\n这会覆盖当前旅程进度，保留已收集记忆。")
	for i in 4:
		ui.button(v,"%02d  /  %s%s" % [i+1,TITLES[i],"" if i<=unlocked else "  · 未解锁"],func(): restart_chapter(i),i>unlocked)
	ui.button(v,"返回",show_main)

func restart_chapter(index: int) -> void:
	chapter=index
	stage=0
	flags={}
	checkpoint=Vector3(0,0.1,20)
	circuit_values=[1,2,3]
	water_values=[0,0,0]
	prism_values=[0,0,0]
	bell_values=[]
	ending=""
	hints=0
	save_game()
	load_chapter(index,true)

func show_journal() -> void:
	var from_ending:=mode=="ending"
	mode="journal"
	var v=ui.make_page("拾回的手记","%d / 6 段记忆。它们不会改变那一晚，却能让你记起更完整的她。" % memories.size(),true)
	var sc:=ScrollContainer.new()
	sc.custom_minimum_size=Vector2(0,430)
	v.add_child(sc)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",22)
	sc.add_child(list)
	for i in 6:
		ui.body_text(list,"%02d · %s" % [i+1,MEMORY_TITLES[i] if memories.has(i) else "尚未拾回"],22)
		ui.body_text(list,MEMORY_TEXT[i] if memories.has(i) else "用回声灯寻找场景角落里的微光。",18)
	var clue_text:="线索记录\n"
	for i in 3:
		if flags.get("clue"+str(i),false): clue_text+=["邮递员：先去钟表店。\n","钟表匠：钟声之后是麦穗，最后才是信。\n","面包师：阿澄一直在码头等哥哥。\n"][i]
	if flags.get("inscription",false): clue_text+="守塔人：海向东，归向西，灯向南。"
	if flags.get("log",false): clue_text+="安全水位：2 / 1 / 3。"
	ui.body_text(list,clue_text,18)
	ui.button(v,"返回",show_ending if from_ending else resume)

func show_credits() -> void:
	mode="credits"
	var v=ui.make_page("制作与致谢","一个关于记忆、责任与告别的短篇故事。")
	ui.body_text(v,"故事、关卡、程序化模型及合成音效\n为本项目原创制作\n\n引擎：Godot 4.4.1 · MIT License\n字体：使用 Windows 系统中文字体\n\n完整源码、构建说明与许可随游戏提供。\n本作不需要联网，不收集玩家信息。",20)
	ui.button(v,"返回",show_main)

func save_game() -> bool:
	var data={"version":1,"chapter":chapter,"stage":stage,"unlocked":unlocked,"memories":memories,"flags":flags,"checkpoint":[checkpoint.x,checkpoint.y,checkpoint.z],"water":water_values,"circuit":circuit_values,"prisms":prism_values,"ending":ending,"seconds":total_seconds}
	var temp:=save_path+".tmp"
	var f:=FileAccess.open(temp,FileAccess.WRITE)
	if f==null:
		if is_instance_valid(ui): ui.toast("无法写入存档，请把游戏解压到有写入权限的文件夹。",7)
		return false
	f.store_string(JSON.stringify(data,"\t"))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path,save_path+".bak")
	var err:=DirAccess.rename_absolute(temp,save_path)
	if err!=OK:
		# Windows may not atomically overwrite; retain backup while replacing.
		DirAccess.remove_absolute(save_path)
		err=DirAccess.rename_absolute(temp,save_path)
	return err==OK

func read_save() -> Dictionary:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))!=OK: continue
		var parsed=parser.data
		if not parsed is Dictionary: continue
		if int(parsed.get("version",0))!=1: continue
		if not parsed.get("flags") is Dictionary or not parsed.get("memories") is Array: continue
		if not parsed.get("checkpoint") is Array or parsed["checkpoint"].size()!=3: continue
		return parsed
	return {}

func load_meta() -> void:
	var data:=read_save()
	unlocked=clampi(int(data.get("unlocked",0)),0,3)

func continue_game() -> void:
	var data:=read_save()
	if data.is_empty(): ui.toast("未找到有效存档，可以开始新的旅程。",5); return
	chapter=clampi(int(data.get("chapter",0)),0,3)
	stage=int(data.get("stage",0))
	unlocked=clampi(int(data.get("unlocked",chapter)),chapter,3)
	memories=data.get("memories",[])
	flags=data.get("flags",{})
	var p:Array=data.get("checkpoint",[0,0.1,20])
	checkpoint=Vector3(clampf(float(p[0]),-17,17),0.1,clampf(float(p[2]),-23,23))
	water_values=integer_triplet(data.get("water",[0,0,0]))
	circuit_values=integer_triplet(data.get("circuit",[1,2,3]))
	prism_values=integer_triplet(data.get("prisms",[0,0,0]))
	ending=str(data.get("ending",""))
	total_seconds=float(data.get("seconds",0))
	load_chapter(chapter,false)
	player.position=checkpoint
	if flags.get("completed",false): show_ending()
	else: resume(); ui.toast("旅程已继续 · "+TITLES[chapter],3)

func integer_triplet(value: Variant) -> Array:
	if not value is Array or value.size()!=3: return [0,0,0]
	return [posmod(int(value[0]),4),posmod(int(value[1]),4),posmod(int(value[2]),4)]

func save_settings() -> void:
	var f:=FileAccess.open(save_dir.path_join("设置.json"),FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"volume":volume,"quality":quality,"subtitles":subtitles,"fullscreen":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN}))
		f.close()

func load_settings() -> void:
	var path:=save_dir.path_join("设置.json")
	if not FileAccess.file_exists(path): return
	var d=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary: return
	volume=clampf(float(d.get("volume",0.65)),0,1)
	quality=clampi(int(d.get("quality",1)),0,1)
	subtitles=bool(d.get("subtitles",true))
	if d.get("fullscreen",false) and not test_mode: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func run_tests() -> void:
	var checks:=[]
	new_game()
	mode="play"
	ui.dialogue.hide()
	interact("power")
	assert(not flags.get("power",false),"missing fuse must block power")
	interact("radio")
	interact("fuse")
	interact("power")
	assert(flags.get("power",false))
	circuit_values=[1,2,3]
	turn_bridge(0); turn_bridge(0); turn_bridge(0)
	turn_bridge(1); turn_bridge(1); turn_bridge(1)
	turn_bridge(2); turn_bridge(2)
	solve_puzzle("bridge")
	assert(flags.get("bridge",false),"coupled gear solution")
	checks.append("码头：前置条件、保险丝、电力、耦合齿轮")
	interact("m0"); interact("m0")
	assert(memories.count(0)==1)
	interact("m1")
	interact("exit")
	assert(chapter==1)
	bell_values=[2,1,0]
	solve_puzzle("bells")
	assert(not flags.get("bells",false))
	for i in 3: interact("clue"+str(i))
	bell_values=[0,1,2]
	solve_puzzle("bells")
	assert(flags.get("bells",false))
	interact("m2"); interact("m3")
	var before:=flags.duplicate(true)
	caught()
	assert(flags==before and player.position==checkpoint)
	checks.append("街巷：回声线索、门铃错误重试、死亡保留进度")
	interact("exit")
	assert(chapter==2)
	interact("pump")
	water_values=[0,0,0]
	turn_valve(1); turn_valve(2); turn_valve(2)
	solve_puzzle("valves")
	assert(flags.get("valves",false))
	circuit_values=[1,2,1]
	solve_puzzle("circuit")
	assert(flags.get("circuit",false))
	interact("m4")
	checks.append("机房：水泵、联动水阀、供电线路")
	interact("exit")
	assert(chapter==3)
	prism_values=[1,3,2]
	for i in 3: solve_puzzle("lens"+str(i))
	assert(all_lenses())
	interact("m5")
	assert(memories.size()==6)
	finish("release")
	assert(ending=="release")
	finish("keep")
	assert(ending=="keep")
	assert(save_game())
	continue_game()
	assert(chapter==3 and all_lenses() and ending=="keep")
	checks.append("灯塔：三面镜子、六件记忆、双结局、存档往返")
	# Corrupt primary save to verify recovery from the previous complete write.
	var broken:=FileAccess.open(save_path,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	assert(not read_save().is_empty(),"backup recovery")
	save_game()
	checks.append("损坏存档自动读取备份")
	print("SELF_TEST_PASS ",JSON.stringify(checks))
	var report:=FileAccess.open(save_dir.path_join("test-results.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":true,"checks":checks},"\t"))
	report.close()
	get_tree().quit(0)
