extends RefCounted
var root: Node3D
var game: Node3D
var mats := {}
var rng := RandomNumberGenerator.new()
var dynamic: Array[Node3D] = []
var amber := Color("e5ac62")
var cyan := Color("64d6cd")

func mat(color: Color, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow) + str(metal)
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65 if metal == 0 else 0.3
	m.metallic = metal
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if color.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false, glow: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var n := mesh(parent, b, pos, mat(color, glow))
	if solid:
		var body := StaticBody3D.new()
		parent.add_child(body)
		body.position = pos
		var coll := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		coll.shape = shape
		body.add_child(coll)
	return n

func cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.bottom_radius = bottom
	s.top_radius = top
	s.height = height
	s.radial_segments = 12
	return mesh(parent, s, pos, mat(color, glow))

func orb(parent: Node3D, pos: Vector3, radius: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2
	s.radial_segments = 12
	s.rings = 8
	return mesh(parent, s, pos, mat(color, glow))

func light(parent: Node3D, pos: Vector3, color: Color, energy: float, distance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	parent.add_child(l)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = distance
	return l

func sign_at(text: String, pos: Vector3, color: Color = Color("e9cf9e"), size: int = 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = game.font
	l.font_size = size
	l.pixel_size = 0.013
	l.modulate = color
	l.outline_size = 5
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	root.add_child(l)
	l.position = pos
	return l

func lamp(pos: Vector3, lit: bool = true) -> void:
	cylinder(root, pos + Vector3(0,1.5,0), 0.07, 0.06, 3, Color("273b46"))
	cylinder(root, pos + Vector3(0,0.12,0), 0.25, 0.15, 0.24, Color("283b43"))
	box(root, pos + Vector3(0,3.05,0), Vector3(0.42,0.62,0.42), amber if lit else Color("41525a"), false, 1.5 if lit else 0)
	cylinder(root, pos + Vector3(0,3.48,0), 0.4, 0.03, 0.3, Color("20303b"))
	if lit: light(root, pos + Vector3(0,2.65,0), amber, 2.2, 7)

func crate(pos: Vector3, size: float = 1.3) -> void:
	box(root,pos + Vector3(0,size/2,0),Vector3.ONE*size,Color("665343"),true)
	for x in [-0.42,0.42]:
		box(root,pos+Vector3(x*size,size/2,0),Vector3(0.08,size+0.04,size+0.04),Color("273d43"))
	box(root,pos+Vector3(0,size/2,0),Vector3(size+0.04,0.09,size+0.04),Color("273d43"))

func house(pos: Vector3, width: float, depth: float, height: float, color: Color) -> void:
	box(root,pos+Vector3(0,height/2,0),Vector3(width,height,depth),color,true)
	box(root,pos+Vector3(0,0.22,0),Vector3(width+0.25,0.44,depth+0.25),Color("203840"))
	var roof := PrismMesh.new()
	roof.size = Vector3(width+0.6,1.7,depth+0.65)
	mesh(root,roof,pos+Vector3(0,height+0.65,0),mat(Color("203a4b")))
	for x in [-0.3,0.3]:
		box(root,pos+Vector3(width*x,height*0.57,depth/2+0.02),Vector3(0.85,1.15,0.09),Color("162e39"))
		box(root,pos+Vector3(width*x,height*0.57,depth/2+0.08),Vector3(0.64,0.9,0.05),amber,false,0.7)
		box(root,pos+Vector3(width*x,height*0.57,depth/2+0.12),Vector3(0.05,0.95,0.03),Color("314751"))
	box(root,pos+Vector3(0,0.9,depth/2+0.03),Vector3(0.9,1.8,0.13),Color("23323b"))
	box(root,pos+Vector3(-width*0.3,height+1.1,-depth*0.15),Vector3(0.65,1.5,0.6),Color("3e5056"))
	for z in range(int(depth/0.45)):
		box(root,pos+Vector3(0,height+0.12,-depth/2+z*0.45),Vector3(width+0.7,0.06,0.045),Color("365669"))
	light(root,pos+Vector3(0,1.8,depth/2+1),amber,0.6,4)

func person(parent: Node3D, ghost: bool = false, enemy: bool = false) -> Dictionary:
	var coat := Color("d2a553")
	if ghost: coat = Color(0.32,0.85,0.8,0.55)
	if enemy: coat = Color("28313e")
	var model := Node3D.new()
	parent.add_child(model)
	cylinder(model,Vector3(0,0.88,0),0.37,0.25,0.96,coat,0.25 if ghost else 0)
	orb(model,Vector3(0,1.55,0),0.32,coat)
	box(model,Vector3(0,1.54,-0.26),Vector3(0.34,0.22,0.1),Color("1c3038") if not enemy else Color("6cd2d3"),false,0.6 if enemy else 0)
	var left := box(model,Vector3(-0.17,0.25,0),Vector3(0.19,0.5,0.26),Color("243b46"))
	var right := box(model,Vector3(0.17,0.25,0),Vector3(0.19,0.5,0.26),Color("243b46"))
	box(model,Vector3(-0.34,0.95,0),Vector3(0.18,0.58,0.22),coat)
	var arm := box(model,Vector3(0.36,1.02,-0.17),Vector3(0.18,0.55,0.22),coat)
	arm.rotation.x = -0.4
	if not enemy:
		box(model,Vector3(0.39,0.85,-0.42),Vector3(0.22,0.31,0.22),amber,false,2)
	return {"model":model,"left":left,"right":right,"arm":arm}

func build(g: Node3D, chapter: int) -> Node3D:
	game = g
	rng.seed = 610 + chapter
	root = Node3D.new()
	root.name = "ChapterWorld"
	g.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("071522")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("709eae")
	e.ambient_light_energy = 0.43
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("102934")
	e.fog_density = 0.008
	env.environment = e
	root.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55,-35,0)
	moon.light_color = Color("89baca")
	moon.light_energy = 0.78
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90
	root.add_child(moon)
	var plane := PlaneMesh.new()
	plane.size = Vector2(220,220)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	var watermat := ShaderMaterial.new()
	watermat.shader = load("res://water.gdshader")
	mesh(root,plane,Vector3(0,-0.8,0),watermat)
	box(root,Vector3(0,-0.45,0),Vector3(36,0.8,48),Color("243d48"),true)
	# Instanced offset cobblestones: 1,152 stones, a single draw call.
	var stones := MultiMesh.new()
	stones.transform_format=MultiMesh.TRANSFORM_3D
	stones.use_colors=true
	var stone := BoxMesh.new()
	stone.size=Vector3(0.96,0.065,1.45)
	stones.mesh=stone
	stones.instance_count=36*32
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color=Color.WHITE
	stone_mat.vertex_color_use_as_albedo=true
	stone_mat.roughness=0.42
	stone_mat.metallic=0.18
	var inst := MultiMeshInstance3D.new()
	inst.multimesh=stones
	inst.material_override=stone_mat
	root.add_child(inst)
	var si:=0
	for x in 36:
		for z in 32:
			var p:=Vector3(-17.5+x+(0.22 if z%2==0 else -0.22),0,-23.2+z*1.5)
			stones.set_instance_transform(si,Transform3D(Basis.IDENTITY,p))
			stones.set_instance_color(si,Color("41575d").lightened(rng.randf_range(-0.09,0.08)))
			si+=1
	for x in [-18.0,18.0]:
		box(root,Vector3(x,0.4,0),Vector3(0.35,0.8,48),Color("243c47"),true)
		for z in range(-23,24,3):
			cylinder(root,Vector3(x,0.75,z),0.12,0.1,1.5,Color("29434d"))
		box(root,Vector3(x,1.24,0),Vector3(0.08,0.08,48),Color("3c5a62"))
	for z in [-24.0,24.0]: box(root,Vector3(0,0.4,z),Vector3(36,0.8,0.35),Color("243c47"),true)
	# Distant islands and a silhouetted waterfront.
	for i in 18:
		var p := Vector3(rng.randf_range(-65,65),0,-rng.randf_range(36,65))
		box(root,p+Vector3(0,2,0),Vector3(rng.randf_range(3,7),rng.randf_range(3,8),5),Color("102c38"))
	for z in [-19,-7,6,18]:
		lamp(Vector3(-16,0,z))
		lamp(Vector3(16,0,z-2))
	match chapter:
		0: harbor()
		1: street()
		2: machinery()
		3: lighthouse()
	dress_scene(chapter)
	var fog_mat:=ShaderMaterial.new()
	fog_mat.shader=load("res://fog.gdshader")
	for z in [-24.0,-7.0,17.0]:
		var fog_plane:=PlaneMesh.new()
		fog_plane.size=Vector2(58,15)
		mesh(root,fog_plane,Vector3(0,1.7,z),fog_mat)
	# Wet flecks break up the pavement without transparent sorting artifacts.
	for i in 65:
		var p := Vector3(rng.randf_range(-17,17),0.048,rng.randf_range(-23,23))
		var patch := box(root,p,Vector3(rng.randf_range(0.1,0.8),0.008,rng.randf_range(0.1,0.55)),Color("335967"))
		patch.rotation.y = rng.randf()*TAU
	return root

func bench(p: Vector3) -> void:
	for x in [-0.8,0.8]:
		box(root,p+Vector3(x,0.35,0),Vector3(0.12,0.7,0.65),Color("243941"))
	for z in [-0.24,0.0,0.24]: box(root,p+Vector3(0,0.65,z),Vector3(2.2,0.12,0.18),Color("796b51"))
	for y in [0.95,1.2]: box(root,p+Vector3(0,y,0.32),Vector3(2.2,0.18,0.1),Color("796b51"))

func barrel(p: Vector3) -> void:
	cylinder(root,p+Vector3(0,0.5,0),0.42,0.38,1,Color("596b68"))
	for y in [0.15,0.8]: cylinder(root,p+Vector3(0,y,0),0.435,0.435,0.08,Color("263e47"))

func dress_scene(chapter: int) -> void:
	for z in range(-20,22,4):
		for x in [-17,17]:
			box(root,Vector3(x,0.075,z),Vector3(0.5,0.06,3.85),Color("667477"))
	if chapter<2:
		for x in [-14.7,14.7]:
			for z in [-19.0,-5.0,8.0]:
				barrel(Vector3(x,0,z))
		for p in [Vector3(-8,0,16),Vector3(8,0,-15)]: bench(p)
		# Coiled dock ropes and loose timber.
		for p in [Vector3(-15,0,21),Vector3(14,0,19),Vector3(12,0,-19)]:
			for i in 3:
				var torus:=TorusMesh.new()
				torus.inner_radius=0.28+i*0.09
				torus.outer_radius=0.33+i*0.09
				torus.rings=20
				mesh(root,torus,p+Vector3(0,0.13,0),mat(Color("9a8661")))
		for x in [-15.0,15.0]:
			cylinder(root,Vector3(x,3.6,1),0.1,0.08,7.2,Color("304854"))
			box(root,Vector3(x,6.7,1),Vector3(2.2,0.13,0.13),Color("304854"))
		for k in [-0.6,0.6]:
			for j in 15:
				var xx:float=-15+j*2
				var yy:float=6.7-sin(float(j)/15*PI)*0.8
				box(root,Vector3(xx,yy,1+k),Vector3(2.08,0.025,0.025),Color("172e39"))
	if chapter==0:
		# Small crane overlooking the fishing boat.
		box(root,Vector3(15,2.5,17),Vector3(0.3,5,0.3),Color("84794f"))
		var arm=box(root,Vector3(17,5,17),Vector3(5.5,0.3,0.35),Color("84794f"))
		arm.rotation.z=-0.2
		box(root,Vector3(19.5,3.2,17),Vector3(0.04,3.4,0.04),Color("697b7e"))
		for z in range(3,21): box(root,Vector3(-20,-0.2,z),Vector3(4,0.15,0.85),Color("524e42"))
		for z in range(4,22,4): cylinder(root,Vector3(-21.5,0,z),0.15,0.12,1.6,Color("453f35"))
	if chapter==1:
		for p in [Vector3(-7,0,13),Vector3(7,0,-10)]:
			box(root,p+Vector3(0,0.35,0),Vector3(1.1,0.7,1.1),Color("6c7363"))
			for i in 4: orb(root,p+Vector3(rng.randf_range(-0.4,0.4),1.0+i*0.2,rng.randf_range(-0.4,0.4)),0.45,Color("426a5e"))
		for x in [-3.5,3.5]:
			box(root,Vector3(x,2.8,-21),Vector3(0.45,5.6,0.5),Color("627472"))
		box(root,Vector3(0,5.3,-21),Vector3(7.4,0.5,0.7),Color("627472"))
		sign_at("北 闸 · 潮 汐 站",Vector3(0,5.8,-21),amber,30)
	if chapter==2:
		for z in [-19.0,18.0]:
			for x in [-15,15]:
				box(root,Vector3(x,3,z),Vector3(0.4,6,0.4),Color("4c6269"))
			box(root,Vector3(0,6,z),Vector3(30,0.45,0.5),Color("4c6269"))
		for x in [-15.0,15.0]:
			var pipe=cylinder(root,Vector3(x,4,0),0.18,0.18,36,Color("668584"))
			pipe.rotation.x=PI/2
		for x in [-3.5,3.5]:
			for z in range(-14,-9): box(root,Vector3(x,0.25,z),Vector3(0.5,0.1,0.4),amber.darkened(0.35))
	if chapter==3:
		for z in range(-10,23,3):
			for x in [-5.0,5.0]:
				box(root,Vector3(x,0.1,z),Vector3(0.5,0.08,0.5),Color("8d8f77"))
		for p in [Vector3(-15,0,5),Vector3(15,0,8),Vector3(-15,0,-18),Vector3(14,0,-20)]:
			for i in 4:
				var rock=orb(root,p+Vector3(rng.randf_range(-1,1),0.2,rng.randf_range(-1,1)),rng.randf_range(0.4,0.9),Color("415b63"))
				rock.scale=Vector3(1.5,0.7,1)

func harbor() -> void:
	house(Vector3(-11,0,9),7,6,4,Color("546266"))
	house(Vector3(12,0,-9),7,7,5,Color("43575c"))
	sign_at("潮 生 港",Vector3(-11,4.7,12.3))
	sign_at("仓库  /  03",Vector3(12,5.7,-5.4),amber,30)
	for p in [Vector3(-10,0,-5),Vector3(-12,0,-6.5),Vector3(8,0,12),Vector3(10,0,13.5),Vector3(-4,0,-15)]: crate(p)
	for z in range(-21,23,3):
		box(root,Vector3(-5,0.06,z),Vector3(0.06,0.03,1.6),amber.darkened(0.6))
	# Docked fishing boat, cabin and mast.
	cylinder(root,Vector3(23,-0.3,11),2.7,2.3,1.1,Color("314f5c")).scale = Vector3(1,1,2.5)
	box(root,Vector3(23,0.5,11),Vector3(3.4,1.8,3.8),Color("6a7778"))
	box(root,Vector3(23,1.2,13),Vector3(2.4,0.55,0.08),amber,false,0.5)
	cylinder(root,Vector3(23,3,9),0.07,0.06,7,Color("344653"))
	box(root,Vector3(23,5.4,9),Vector3(4,0.08,0.08),Color("566972"))
	for x in [-4,4]:
		box(root,Vector3(x,1.1,-19),Vector3(0.3,2.2,4),Color("42606a"))
	for z in range(-22,-16):
		var deck=box(root,Vector3(0,0.12,z),Vector3(7.5,0.14,0.8),Color("615b50"))
		deck.set_meta("bridge_piece",true)
	sign_at("往 灯 塔  ↑",Vector3(0,3.2,-21),cyan,34)

func street() -> void:
	for p in [Vector3(-12,0,14),Vector3(12,0,12),Vector3(-12,0,0),Vector3(12,0,-3),Vector3(-12,0,-15),Vector3(12,0,-18)]:
		house(p,7,7,rng.randf_range(4,6),Color("4b5a62"))
	for z in [13.0,0.0,-13.0]:
		box(root,Vector3(0,0.4,z),Vector3(3.1,0.8,2.1),Color("344b52"),true)
		for i in 7:
			var pos := Vector3(rng.randf_range(-1.2,1.2),1.1,z+rng.randf_range(-0.7,0.7))
			orb(root,pos,0.48,Color("355e58"))
	sign_at("潮汐邮局",Vector3(-12,5,4),amber,32)
	sign_at("银鲸钟表",Vector3(12,6,16),amber,32)
	sign_at("归航面包房",Vector3(-12,5,-11),amber,32)
	for x in [-5.0,5.0]:
		for z in [-8.0,8.0]:
			box(root,Vector3(x,0.65,z),Vector3(2.0,1.3,1.4),Color("405661"),true)
	# Overhead festival flags.
	for z in [-7,7]:
		box(root,Vector3(0,5.6,z),Vector3(20,0.035,0.035),Color("829293"))
		for x in range(-8,9,2):
			var flag := box(root,Vector3(x,5.15,z),Vector3(0.65,0.85,0.035),amber.darkened(0.3) if x%4==0 else Color("527c81"))
			dynamic.append(flag)

func machinery() -> void:
	for x in [-12.0,12.0]:
		for z in [-12.0,10.0]:
			cylinder(root,Vector3(x,2,z),2.7,2.7,4,Color("345a65"))
			box(root,Vector3(x,1.8,z),Vector3(5.3,3.6,5.3),Color(0,0,0,0),true).visible=false
			for y in [0.3,3.6]: cylinder(root,Vector3(x,y,z),2.82,2.82,0.2,Color("7b7460"))
			cylinder(root,Vector3(x,4.3,z),0.6,0.6,0.7,Color("4d7077"))
	for z in [-6.0,4.0]:
		var pipe := cylinder(root,Vector3(0,0.4,z),0.25,0.25,30,Color("826d4d"))
		pipe.rotation.z=PI/2
		# Pipes are step-over scenery, not invisible barriers.
	for x in [-6,6]:
		box(root,Vector3(x,0.8,-1),Vector3(2,1.6,3),Color("35454e"),true)
		box(root,Vector3(x,1.65,-1),Vector3(1.65,0.06,2.65),Color("68837f"))
	box(root,Vector3(0,0.09,-12),Vector3(8,0.1,5),Color("183845"))
	for x in range(-4,5): box(root,Vector3(x,0.18,-12),Vector3(0.08,0.1,5),Color("658089"))
	sign_at("潮 汐 泵 站",Vector3(0,5,-20),cyan,46)
	for x in [-5,5]: lamp(Vector3(x,0,-18))

func lighthouse() -> void:
	for z in [13.0,1.0,-10.0]:
		for x in [-11.0,11.0]:
			cylinder(root,Vector3(x,0.5,z),2.7,2.5,1,Color("415862"))
			cylinder(root,Vector3(x,1.8,z),0.45,0.3,2.5,Color("829088"))
			orb(root,Vector3(x,3.3,z),0.55,cyan,0.8)
			light(root,Vector3(x,3.6,z),cyan,0.9,5)
	for p in [Vector3(-3,0,8),Vector3(4,0,-5)]:
		box(root,p+Vector3(0,0.8,0),Vector3(3,1.6,2),Color("425764"),true)
	cylinder(root,Vector3(0,0.4,-18),4.7,4.7,0.8,Color("546b72"))
	cylinder(root,Vector3(0,5,-18),3.1,2.4,9.4,Color("b5b2a0"))
	for y in [1.5,5.5,9.0]: cylinder(root,Vector3(0,y,-18),3.15-y*0.065,3.15-y*0.065,0.35,Color("47606a"))
	cylinder(root,Vector3(0,10.0,-18),3.1,3.1,0.35,Color("253d49"))
	cylinder(root,Vector3(0,11.1,-18),2.2,2.2,2.1,Color(0.5,0.8,0.77,0.3))
	orb(root,Vector3(0,11.1,-18),0.8,amber,3)
	light(root,Vector3(0,11,-17),amber,4,15)
	for a in 8:
		var angle := a*TAU/8
		cylinder(root,Vector3(cos(angle)*2.25,11,-18+sin(angle)*2.25),0.06,0.06,2.4,Color("27434e"))
	cylinder(root,Vector3(0,12.8,-18),2.9,0.05,1.4,Color("243d4c"))
	cylinder(root,Vector3(0,14,-18),0.06,0.03,1.6,amber)
	box(root,Vector3(0,1.2,-14.9),Vector3(1.6,2.4,0.12),Color("263f4a"))
	for i in 5:
		box(root,Vector3(0,i*0.07,-13.8+i*0.45),Vector3(3-i*0.1,0.15,0.55),Color("74868a"))
	var beacon := Node3D.new()
	root.add_child(beacon)
	beacon.position=Vector3(0,11.2,-18)
	beacon.name="Beacon"
	for signum in [-1,1]:
		var beam := cylinder(beacon,Vector3(signum*11,0,0),0.15,3,22,Color(0.7,0.78,0.57,0.07),0.3)
		beam.rotation.z=signum*PI/2
	game.beacon=beacon
