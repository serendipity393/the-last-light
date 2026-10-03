extends Control
var game: Node3D
var top: Label
var objective: Label
var prompt: Label
var bottom: Label
var message: Label
var watermark: Label
var dialogue: PanelContainer
var speaker: Label
var speech: Label
var page: Control
var time := 0.0
var message_time := 0.0
var speech_full := ""
var speech_time := 0.0
var rain_points: Array[Vector2] = []
var gold := Color("e9bb76")
var ivory := Color("ede5d3")
var aqua := Color("83cfc6")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t := Theme.new()
	t.default_font = game.font
	t.default_font_size = 20
	for state in ["normal","hover","pressed","focus","disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color("102832") if state=="normal" else Color("24464c")
		if state=="disabled": st.bg_color=Color("132127")
		st.border_color=Color("a18358") if state=="focus" else Color("496064")
		st.set_border_width_all(1)
		st.content_margin_left=22
		st.content_margin_right=22
		st.content_margin_top=12
		st.content_margin_bottom=12
		t.set_stylebox(state,"Button",st)
	t.set_color("font_color","Button",ivory)
	t.set_color("font_hover_color","Button",gold)
	t.set_color("font_disabled_color","Button",Color("647473"))
	theme=t
	top=label_at(Vector2(44,34),Vector2(680,60),22,gold)
	objective=label_at(Vector2(985,35),Vector2(410,90),19,ivory)
	objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	prompt=label_at(Vector2(390,657),Vector2(660,70),22,ivory)
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bottom=label_at(Vector2(44,841),Vector2(1100,36),16,Color("a4b7b7"))
	message=label_at(Vector2(365,124),Vector2(710,92),21,gold)
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	watermark=label_at(Vector2(1220,845),Vector2(175,28),14,Color(0.72,0.79,0.76,0.70))
	watermark.text="郑智新原创"
	watermark.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	dialogue=PanelContainer.new()
	dialogue.position=Vector2(230,645)
	dialogue.size=Vector2(980,205)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.025,0.075,0.095,0.97)
	style.border_color=Color("a28c64")
	style.border_width_top=2
	style.content_margin_left=32
	style.content_margin_right=32
	style.content_margin_top=20
	style.content_margin_bottom=20
	dialogue.add_theme_stylebox_override("panel",style)
	add_child(dialogue)
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",12)
	dialogue.add_child(v)
	speaker=Label.new()
	speaker.add_theme_color_override("font_color",gold)
	speaker.add_theme_font_size_override("font_size",18)
	v.add_child(speaker)
	speech=Label.new()
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size=Vector2(910,90)
	speech.add_theme_color_override("font_color",ivory)
	speech.add_theme_font_size_override("font_size",23)
	v.add_child(speech)
	var next:=Label.new()
	next.text="E / 空格 / 点击    继续"
	next.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	next.add_theme_font_size_override("font_size",15)
	next.modulate=Color("86a5a6")
	v.add_child(next)
	dialogue.hide()
	var rng:=RandomNumberGenerator.new()
	rng.seed=62
	for i in 100: rain_points.append(Vector2(rng.randf()*1440,rng.randf()*900))

func label_at(pos: Vector2, sz: Vector2, fontsize: int, color: Color) -> Label:
	var l:=Label.new()
	l.position=pos
	l.size=sz
	l.add_theme_font_size_override("font_size",fontsize)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",2)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l

func _process(delta: float) -> void:
	time+=delta
	message_time=maxf(0,message_time-delta)
	message.visible=message_time>0
	if dialogue.visible:
		speech_time+=delta
		speech.visible_characters=int(speech_time*38) if game.subtitles else -1
	queue_redraw()

func _draw() -> void:
	# Light rain and a restrained film vignette, independent of frame rate.
	for i in rain_points.size():
		var p:=rain_points[i]
		p.y=fmod(p.y+time*(180+i%7*22),930)-20
		p.x=fmod(p.x-time*40+100000,1480)-20
		draw_line(p,p+Vector2(-5,17),Color(0.6,0.8,0.85,0.13),1,true)
	for i in 18:
		var alpha:float=(1.0-float(i)/18)*0.018
		draw_rect(Rect2(i*5,i*4,1440-i*10,900-i*8),Color(0.0,0.02,0.035,alpha),false,12)
	if is_instance_valid(page): return
	draw_rect(Rect2(0,0,1440,119),Color(0.018,0.05,0.067,0.75))
	draw_line(Vector2(44,107),Vector2(1396,107),Color(0.5,0.65,0.65,0.28),1)
	draw_rect(Rect2(0,807,1440,93),Color(0.018,0.05,0.067,0.77))
	draw_circle(Vector2(66,786),8,gold if game.echo else Color("55717b"))
	draw_rect(Rect2(88,781,175,8),Color("23404a"))
	draw_rect(Rect2(88,781,175*game.energy/100.0,8),aqua if game.echo else gold)
	draw_string(game.font,Vector2(279,793),"回声灯  %03d%%" % int(game.energy),HORIZONTAL_ALIGNMENT_LEFT,-1,16,ivory)
	if game.lure_cooldown>0:
		draw_string(game.font,Vector2(467,793),"诱饵恢复  %ds" % ceili(game.lure_cooldown),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("80999f"))
	# A small chart maps the entire playable island; only discovered goals appear.
	var center:=Vector2(1320,725)
	draw_circle(center,76,Color(0.025,0.08,0.10,0.85))
	draw_arc(center,76,0,TAU,64,Color("566d6b"),1,true)
	draw_line(center+Vector2(-55,0),center+Vector2(55,0),Color(0.3,0.5,0.5,0.25))
	draw_line(center+Vector2(0,-59),center+Vector2(0,59),Color(0.3,0.5,0.5,0.25))
	draw_string(game.font,center+Vector2(-7,-82),"北",HORIZONTAL_ALIGNMENT_LEFT,-1,13,gold)
	if is_instance_valid(game.player):
		var p:Vector3=game.player.position
		draw_circle(center+Vector2(p.x,p.z)*2.4,4,gold)
		for item in game.items:
			if item["node"].visible and not item.get("memory",false):
				var ip:Vector3=item["node"].position
				draw_circle(center+Vector2(ip.x,ip.z)*2.4,2.8,aqua)
		if game.echo:
			for enemy in game.enemies:
				var ep:Vector3=enemy["body"].position
				draw_circle(center+Vector2(ep.x,ep.z)*2.4,3,Color("d9786c"))
	if game.danger>0:
		draw_rect(Rect2(0,0,1440,900),Color(0.6,0.15,0.09,game.danger*0.08))
	if game.flash>0: draw_rect(Rect2(0,0,1440,900),Color(0.35,0.75,0.78,game.flash*0.15))

func toast(text: String, duration: float = 4.0) -> void:
	message.text=text
	message_time=duration

func say(who: String, text: String) -> void:
	dialogue.show()
	speaker.text=who
	speech.text=text
	speech_full=text
	speech_time=0
	prompt.text=""

func close_page() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page=null
	top.show()
	objective.show()
	bottom.show()

func make_page(title: String, subtitle: String, wide: bool = false) -> VBoxContainer:
	close_page()
	dialogue.hide()
	top.hide()
	objective.hide()
	bottom.hide()
	prompt.text=""
	page=Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(page)
	move_child(message,get_child_count()-1)
	move_child(watermark,get_child_count()-1)
	var bg:=ColorRect.new()
	bg.color=Color(0.018,0.055,0.075,0.97 if wide else 0.92)
	bg.position=Vector2(0,0)
	bg.size=Vector2(1440 if wide else 650,900)
	page.add_child(bg)
	var line:=ColorRect.new()
	line.position=Vector2(64,80)
	line.size=Vector2(52,3)
	line.color=gold
	page.add_child(line)
	var v:=VBoxContainer.new()
	v.position=Vector2(64,112)
	v.size=Vector2(1312 if wide else 520,700)
	v.add_theme_constant_override("separation",10)
	page.add_child(v)
	var brand:=Label.new()
	brand.text="THE LAST LIGHT   /   潮生港 · 1997"
	brand.add_theme_font_size_override("font_size",15)
	brand.modulate=aqua
	v.add_child(brand)
	var h:=Label.new()
	h.text=title
	h.add_theme_font_size_override("font_size",48)
	h.modulate=ivory
	v.add_child(h)
	var sub:=Label.new()
	sub.text=subtitle
	sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size=Vector2(510,70)
	sub.add_theme_font_size_override("font_size",19)
	sub.modulate=Color("a4babb")
	v.add_child(sub)
	return v

func button(parent: Control, text: String, action: Callable, disabled: bool = false) -> Button:
	var b:=Button.new()
	b.text=text
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size=Vector2(0,51)
	b.disabled=disabled
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func body_text(parent: Control, text: String, fontsize: int = 20) -> Label:
	var l:=Label.new()
	l.text=text
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",fontsize)
	l.modulate=ivory
	parent.add_child(l)
	return l
