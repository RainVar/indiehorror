class_name HouseUI
extends CanvasLayer

signal new_game_requested
signal continue_requested
signal resume_requested
signal restart_requested
signal quit_requested
signal microphone_requested(enabled:bool)
signal ending_replay(kind:String)
signal branch_replay
signal clock_submitted(hour:int,minute:int)
signal interact_touch
signal crouch_touch
signal flashlight_touch
signal journal_touch
signal phone_touch
signal pause_touch
signal touch_look(delta:Vector2)
signal touch_move_changed(value:Vector2)

const INK:=Color(0.052,0.077,0.075,0.98)
const CREAM:=Color(0.89,0.86,0.75)
const GOLD:=Color(0.70,0.59,0.36)
const MUTED:=Color(0.55,0.61,0.57)
var root:Control
var menu:Control
var hud:Control
var modal:Control
var toast_label:Label
var caption_label:Label
var prompt_label:Label
var room_label:Label
var objective_label:Label
var act_label:Label
var noise_bar:ProgressBar
var noise_label:Label
var stamina_bar:ProgressBar
var film:ColorRect
var fade:ColorRect
var debug_label:Label
var serif:Font
var sans:Font
var toast_time:float=0
var caption_time:float=0
var modal_close:Callable
var modal_kind:String=""
var mic_status_label:Label
var hour_spin:SpinBox
var minute_spin:SpinBox
var touch_controls:Control
var left_finger:int=-1
var right_finger:int=-1
var touch_origin:=Vector2.ZERO
var mic_pending:bool=false
var touch_pad:Control
var touch_use_down:=false
var cinema_overlay:Control
var cinema_text:Label
var cinema_skip:Button
var cinema_skip_down:=false

func _ready() -> void:
	layer=10
	serif=load("res://assets/fonts/CormorantGaramond.ttf")
	sans=load("res://assets/fonts/Inter.ttf")
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme:=Theme.new()
	theme.default_font=sans
	theme.default_font_size=18
	root.theme=theme
	film=ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fm:=ShaderMaterial.new()
	fm.shader=load("res://shaders/film.gdshader")
	film.material=fm
	root.add_child(film)
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	_build_hud()
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	modal.hide()
	toast_label=_label(root,"",17,CREAM)
	_place(toast_label,Control.PRESET_CENTER_TOP,Vector2(-360,28),Vector2(720,70))
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_label.hide()
	fade=ColorRect.new()
	fade.color=Color(0,0,0,0)
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	cinema_overlay=Control.new()
	cinema_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinema_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(cinema_overlay)
	cinema_text=_label(cinema_overlay,"",22,CREAM,true)
	_place(cinema_text,Control.PRESET_CENTER_BOTTOM,Vector2(-350,-160),Vector2(700,80))
	cinema_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cinema_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cinema_skip=_button(cinema_overlay,"HOLD TO SKIP",func():pass)
	_place(cinema_skip,Control.PRESET_CENTER_BOTTOM,Vector2(-170,-62),Vector2(340,42))
	cinema_skip.button_down.connect(func():cinema_skip_down=true)
	cinema_skip.button_up.connect(func():cinema_skip_down=false)
	cinema_overlay.hide()
	Session.settings_changed.connect(_settings_changed)
	get_viewport().size_changed.connect(_layout_changed)
	show_title()

func _label(parent:Node,text:String,size:int=18,color:Color=CREAM,heading:bool=false) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_override("font",serif if heading else sans)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	label.add_theme_constant_override("shadow_offset_y",1)
	label.add_theme_constant_override("shadow_outline_size",1)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(bg:Color,border:Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=bg
	style.border_color=border
	style.set_border_width_all(1)
	style.content_margin_left=20
	style.content_margin_right=20
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

func _place(control:Control,preset:int,offset:Vector2,extent:Vector2) -> void:
	control.set_anchors_and_offsets_preset(preset)
	control.offset_left=offset.x
	control.offset_top=offset.y
	control.offset_right=offset.x+extent.x
	control.offset_bottom=offset.y+extent.y

func _button(parent:Node,text:String,callback:Callable,primary:bool=false) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(0,48)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_stylebox_override("normal",_style(CREAM if primary else Color(0.03,0.05,0.045,0.7),GOLD if primary else Color(0.3,0.34,0.28,0.45)))
	button.add_theme_stylebox_override("hover",_style(GOLD,GOLD))
	button.add_theme_stylebox_override("pressed",_style(Color(0.47,0.42,0.28),GOLD))
	button.add_theme_stylebox_override("focus",_style(Color(0.2,0.24,0.19,0.25),CREAM))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear(node:Node) -> void:
	for child in node.get_children():
		child.queue_free()
		node.remove_child(child)

func show_title() -> void:
	_clear(menu)
	menu.show()
	hud.hide()
	modal.hide()
	modal_kind=""
	# Transparent left wash preserves the real-time house behind the title.
	var wash:=ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color=Color(0.015,0.032,0.03,0.32)
	wash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu.add_child(wash)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",74)
	margin.add_theme_constant_override("margin_top",55)
	margin.add_theme_constant_override("margin_right",64)
	margin.add_theme_constant_override("margin_bottom",36)
	menu.add_child(margin)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	margin.add_child(column)
	_label(column,Story.text("A PHILIPPINE FOLKLORE HORROR","ISANG KUWENTONG KATATAKUTAN"),13,GOLD)
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=40
	column.add_child(spacer)
	var title:=_label(column,"BULONG\nSA BAHAY",86,CREAM,true)
	title.add_theme_constant_override("line_spacing",-22)
	_label(column,Story.text("The house hears you.","Naririnig ka ng bahay."),23,Color(0.71,0.73,0.63),true)
	var gap:=Control.new()
	gap.custom_minimum_size.y=30
	column.add_child(gap)
	var buttons:=VBoxContainer.new()
	buttons.custom_minimum_size.x=330
	buttons.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	buttons.add_theme_constant_override("separation",8)
	column.add_child(buttons)
	if Session.can_continue():
		_button(buttons,Story.text("CONTINUE THE NIGHT  →","ITULOY ANG GABI  →"),func():continue_requested.emit(),true)
	_button(buttons,Story.text("ENTER THE HOUSE  →","PUMASOK SA BAHAY  →"),func():show_start(),not Session.can_continue())
	_button(buttons,Story.text("SETTINGS","MGA SETTING"),func():show_settings(func():show_title()))
	_button(buttons,Story.text("CREDITS & CONTENT NOTES","MGA KREDITO AT PAALALA"),func():show_credits())
	if not Session.endings.is_empty():_button(buttons,Story.text("ENDING MEMORIES","MGA NAKITANG WAKAS"),show_ending_gallery)
	var stretch:=Control.new()
	stretch.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(stretch)
	var bottom:=HBoxContainer.new()
	column.add_child(bottom)
	var tag:=_label(bottom,Story.text("HEADPHONES RECOMMENDED  ·  A SHORT HORROR STORY","GUMAMIT NG HEADPHONES  ·  ISANG MAIKLING KUWENTO"),11,MUTED)
	tag.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_label(bottom,"v0.2  /  A NIGHT IN SOUTHERN LUZON",11,MUTED)
	_layout_changed()

func show_start() -> void:
	var body:=_modal_shell(Story.text("BEFORE YOU ENTER","BAGO KA PUMASOK"),Story.text("A quiet house. A final request.","Isang tahimik na bahay. Isang huling bilin."))
	_body(body,Story.text("You are Mika. After Lola's funeral, Mama asks you to retrieve the land title from her old house. A storm has cut off the road.\n\nMove quietly. Read carefully. Something in the house has been waiting for a new keeper.","Ikaw si Mika. Pagkatapos ng libing ni Lola, pinakukuha ni Mama ang titulo sa lumang bahay. Bumaha na ang daan dahil sa bagyo.\n\nDahan-dahan. Basahing mabuti ang mga bilin. May naghihintay sa bahay ng bagong tagapag-ingat."))
	_body(body,Story.text("WASD  Move     MOUSE  Look     E  Interact\nC  Crouch     SHIFT  Sprint     F  Flashlight\nJ  Journal     Q  Throw phone     ESC  Pause\n\nOn a touchscreen: drag the left side to move, swipe the right to look.","WASD  Lakad     MOUSE  Tingin     E  Gamitin\nC  Yuko     SHIFT  Takbo     F  Flashlight\nJ  Talaan     Q  Ihagis ang telepono     ESC  Hinto\n\nSa touchscreen: kaliwa para lumakad, kanan para tumingin."),16)
	var microphone:=CheckButton.new()
	microphone.text=Story.text("Optional: let the house hear my microphone","Opsyonal: iparinig sa bahay ang mikropono ko")
	microphone.button_pressed=false
	body.add_child(microphone)
	_body(body,Story.text("Microphone audio is analyzed on your device and immediately discarded. No recording, speech recognition, or upload. The full story works without it. Use headphones if enabled.","Sinusuri ang lakas ng mikropono sa device mo at agad itinatapon. Walang recording, pagkilala sa pananalita, o upload. Kumpleto ang laro kahit wala ito. Gumamit ng headphones kapag naka-on."),14,MUTED)
	_button(body,Story.text("BEGIN THE NIGHT  →","SIMULAN ANG GABI  →"),func():
		mic_pending=microphone.button_pressed
		close_modal()
		new_game_requested.emit()
		if mic_pending:microphone_requested.emit(true),true)
	_button(body,Story.text("BACK","BUMALIK"),func():show_title())

func _modal_shell(kicker:String,title:String) -> VBoxContainer:
	_clear(modal)
	modal.show()
	modal_kind="panel"
	var shade:=ColorRect.new()
	shade.color=Color(0.006,0.014,0.014,0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",maxi(30,int(root.size.x*0.16)))
	margin.add_theme_constant_override("margin_right",maxi(30,int(root.size.x*0.16)))
	margin.add_theme_constant_override("margin_top",35)
	margin.add_theme_constant_override("margin_bottom",35)
	modal.add_child(margin)
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(INK,Color(0.34,0.33,0.23)))
	margin.add_child(panel)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",17)
	scroll.add_child(body)
	_label(body,kicker,12,GOLD)
	var title_label:=_label(body,title,42,CREAM,true)
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return body

func _body(parent:Node,text:String,font_size:int=20,color:Color=CREAM) -> Label:
	var label:=_label(parent,text,font_size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("line_spacing",5)
	return label

func show_note(id:String,callback:Callable) -> void:
	var data:=Story.note(id)
	var body:=_modal_shell(Story.text("FOUND IN THE HOUSE","NATAGPUAN SA BAHAY"),data.title)
	_body(body,data.body)
	_button(body,Story.text("PUT IT DOWN  →","IBABA  →"),func():close_modal();callback.call(),true)
	modal_close=callback
	modal_kind="note"

func show_journal(callback:Callable) -> void:
	var body:=_modal_shell(Story.text("MIKA'S JOURNAL","TALAAN NI MIKA"),Story.text("What the house keeps","Mga lihim ng bahay"))
	_body(body,Story.journal(),18)
	_body(body,Story.text("MEMORIES FOUND: ","NAHANAP NA ALAALA: ")+str(Session.memory_count())+" / 3",14,GOLD)
	_button(body,Story.text("CLOSE JOURNAL","ISARA ANG TALAAN"),func():close_modal();callback.call(),true)
	modal_close=callback
	modal_kind="journal"

func show_pause() -> void:
	var body:=_modal_shell(Story.text("THE NIGHT IS PAUSED","NAKAHINTO ANG GABI"),Story.text("Take a breath.","Huminga muna."))
	_button(body,Story.text("RETURN TO THE HOUSE  →","BUMALIK SA BAHAY  →"),func():close_modal();resume_requested.emit(),true)
	_button(body,Story.text("SETTINGS & MICROPHONE","MGA SETTING AT MIKROPONO"),func():show_settings(func():show_pause()))
	_button(body,Story.text("RESTART CHECKPOINT","ULITIN ANG CHECKPOINT"),func():close_modal();restart_requested.emit())
	_button(body,Story.text("RETURN TO TITLE","BUMALIK SA PAMAGAT"),func():quit_requested.emit())
	_body(body,Story.text("Progress saves at chapter checkpoints. Pausing stops both the creature and microphone gameplay.","Nagse-save sa mga checkpoint ng kabanata. Humihinto ang nilalang at pakikinig ng mikropono habang naka-pause."),14,MUTED)
	modal_kind="pause"

func show_settings(back:Callable) -> void:
	var body:=_modal_shell("BULONG SA BAHAY",Story.text("Settings","Mga setting"))
	_option(body,Story.text("Language","Wika"),["English","Filipino"],0 if Session.language=="en" else 1,func(index):Session.language="en" if index==0 else "fil";Session.save_settings();show_settings(back))
	_option(body,Story.text("Graphics","Grapika"),["Low · 60% resolution","Medium · 80% resolution","High · native + flashlight shadows"],["low","medium","high"].find(Session.quality),func(index):Session.quality=["low","medium","high"][index];Session.save_settings())
	_slider(body,Story.text("Master volume","Lakas ng tunog"),0,1,Session.volume,func(value):Session.volume=value;Session.save_settings())
	_slider(body,Story.text("Brightness","Liwanag"),0.7,1.5,Session.brightness,func(value):Session.brightness=value;Session.save_settings())
	_slider(body,Story.text("Look sensitivity","Bilis ng pagtingin"),0.04,0.3,Session.sensitivity,func(value):Session.sensitivity=value;Session.save_settings())
	_check(body,Story.text("Reduce camera motion and film grain","Bawasan ang galaw ng camera at grain"),Session.reduced_motion,func(on):Session.reduced_motion=on;Session.save_settings())
	_check(body,Story.text("Sound captions","Mga caption ng tunog"),Session.subtitles,func(on):Session.subtitles=on;Session.save_settings())
	_check(body,Story.text("Touch controls","Mga kontrol sa touchscreen"),Session.touch_mode,func(on):Session.touch_mode=on;Session.save_settings())
	_check(body,Story.text("Microphone listening (optional)","Pakikinig ng mikropono (opsyonal)"),Session.mic_enabled,func(on):microphone_requested.emit(on))
	mic_status_label=_body(body,Story.text("Local loudness only. Nothing is recorded or uploaded. Headphones recommended.","Lokal na lakas ng tunog lamang. Walang nire-record o ina-upload. Gumamit ng headphones."),14,MUTED)
	_button(body,Story.text("BACK","BUMALIK"),back,true)
	modal_kind="settings"

func _option(parent:Node,text:String,items:Array,index:int,callback:Callable) -> void:
	_label(parent,text,15,MUTED)
	var option:=OptionButton.new()
	for item in items:option.add_item(item)
	option.select(index)
	option.custom_minimum_size.y=40
	option.item_selected.connect(callback)
	parent.add_child(option)

func _slider(parent:Node,text:String,minimum:float,maximum:float,value:float,callback:Callable) -> void:
	var row:=HBoxContainer.new()
	parent.add_child(row)
	var label:=_label(row,text,15,MUTED)
	label.custom_minimum_size.x=230
	var slider:=HSlider.new()
	slider.min_value=minimum
	slider.max_value=maximum
	slider.step=0.01
	slider.value=value
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size=Vector2(120,28)
	slider.value_changed.connect(callback)
	row.add_child(slider)

func _check(parent:Node,text:String,value:bool,callback:Callable) -> void:
	var check:=CheckButton.new()
	check.text=text
	check.button_pressed=value
	check.toggled.connect(callback)
	parent.add_child(check)

func show_credits() -> void:
	var body:=_modal_shell("BULONG SA BAHAY",Story.text("The people. The house.","Ang mga tao. Ang bahay."))
	_body(body,Story.text("An original fictional horror story set in Southern Luzon. Its entity and ritual are invented for the game, not a representation of a specific community's sacred practice.\n\nContains grief, death, supernatural pursuit, loud scares, and references to family loss. No graphic gore.\n\nHeadphones and a dark room are recommended. You can disable camera motion, adjust brightness, and play entirely without a microphone.","Isang kathang kuwentong katatakutan sa Timog Luzon. Inimbento para sa laro ang nilalang at ritwal; hindi ito paglalarawan ng sagradong gawain ng isang komunidad.\n\nMay pagluluksa, kamatayan, habulan, malalakas na gulat, at pagkawala ng kapamilya. Walang detalyadong karahasan.\n\nMainam ang headphones at madilim na silid. Maaaring bawasan ang galaw, baguhin ang liwanag, at maglaro nang walang mikropono."),18)
	_body(body,"Furniture foundations — Kenney · CC0\nTypography — Cormorant Garamond & Inter · SIL OFL\nEngine — Godot · MIT\n\nArchitecture, creature, story, textures and synthesized sound design — original for Bulong sa Bahay.\n\nBuilt with assistance from OpenAI Codex.\nFull source credits and license texts accompany the download.",15,MUTED)
	_button(body,Story.text("BACK","BUMALIK"),func():show_title(),true)

func show_clock() -> void:
	var body:=_modal_shell(Story.text("THE SALA CLOCK","ORASAN SA SALA"),Story.text("A quarter past six.","Alas-sais kinse."))
	_body(body,Story.note("clock_hint").body,18)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	body.add_child(row)
	hour_spin=SpinBox.new()
	hour_spin.min_value=1
	hour_spin.max_value=12
	hour_spin.value=3
	hour_spin.custom_minimum_size=Vector2(160,50)
	row.add_child(hour_spin)
	_label(row,":",30,GOLD,true)
	minute_spin=SpinBox.new()
	minute_spin.min_value=0
	minute_spin.max_value=55
	minute_spin.step=5
	minute_spin.value=0
	minute_spin.custom_minimum_size=Vector2(160,50)
	row.add_child(minute_spin)
	_button(body,Story.text("PULL THE WINDING KEY","BUNUTIN ANG SUSI"),func():clock_submitted.emit(int(hour_spin.value),int(minute_spin.value)),true)
	_button(body,Story.text("LEAVE THE CLOCK","IWAN ANG ORASAN"),func():close_modal();resume_requested.emit())
	modal_kind="clock"


func show_ending(kind:String) -> void:
	hud.hide()
	var data:=Story.ending(kind)
	var body:=_modal_shell(Story.text("ENDING I / II" if kind=="seal" else "ENDING II / II","WAKAS I / II" if kind=="seal" else "WAKAS II / II"),data.title)
	_body(body,data.body,23)
	_body(body,data.post,20,GOLD)
	var record:Dictionary=Session.ending_records.get(kind,{"memories":Session.memory_count(),"seconds":Session.play_seconds,"catches":Session.catches})
	_body(body,Story.text("Memories: ","Mga alaala: ")+str(record.memories)+" / 3     ·     "+Story.text("Time: ","Oras: ")+str(int(record.seconds/60))+"m     ·     "+Story.text("Caught: ","Nahuli: ")+str(record.catches),14,MUTED)
	_button(body,Story.text("REPLAY THIS CUTSCENE","ULITIN ANG EKSENA"),func():close_modal();ending_replay.emit(kind),true)
	_button(body,Story.text("REPLAY FROM THE EARLY BRANCH","BUMALIK SA UNANG SANGANG-DAAN"),func():close_modal();branch_replay.emit())
	_button(body,Story.text("RETURN TO TITLE","BUMALIK SA PAMAGAT"),func():quit_requested.emit())
	modal_kind="ending"

func show_ending_gallery() -> void:
	var body:=_modal_shell(Story.text("ENDING MEMORIES","MGA NAKITANG WAKAS"),Story.text("What the house kept.","Ang iningatan ng bahay."))
	for kind in ["seal","break"]:
		if kind in Session.endings:_button(body,Story.ending(kind).title,func():close_modal();ending_replay.emit(kind))
	_button(body,Story.text("BACK","BUMALIK"),func():close_modal();show_title())
	modal_kind="gallery"

func show_cinema() -> void:
	menu.hide()
	hud.hide()
	modal.hide()
	toast_label.hide()
	cinema_skip_down=false
	cinema_overlay.show()
	modal_kind="cinema"

func close_modal() -> void:
	modal.hide()
	modal_kind=""
	modal_close=Callable()

func _build_hud() -> void:
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	act_label=_label(hud,"",11,GOLD)
	act_label.position=Vector2(35,28)
	room_label=_label(hud,"",28,CREAM,true)
	room_label.position=Vector2(35,48)
	objective_label=_label(hud,"",16,CREAM)
	_place(objective_label,Control.PRESET_BOTTOM_LEFT,Vector2(35,-86),Vector2(610,65))
	objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var cross:=_label(hud,"·",25,CREAM)
	_place(cross,Control.PRESET_CENTER,Vector2(-5,-18),Vector2(12,30))
	prompt_label=_label(hud,"",17,CREAM)
	_place(prompt_label,Control.PRESET_CENTER,Vector2(-330,62),Vector2(660,55))
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption_label=_label(hud,"",15,Color(0.72,0.79,0.76))
	_place(caption_label,Control.PRESET_CENTER_BOTTOM,Vector2(-350,-120),Vector2(700,40))
	caption_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	noise_label=_label(hud,"THE HOUSE IS QUIET",11,MUTED)
	_place(noise_label,Control.PRESET_BOTTOM_RIGHT,Vector2(-253,-84),Vector2(215,20))
	noise_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	noise_bar=ProgressBar.new()
	noise_bar.show_percentage=false
	var empty_bar:=StyleBoxFlat.new()
	empty_bar.bg_color=Color(0.17,0.2,0.18)
	var filled_bar:=StyleBoxFlat.new()
	filled_bar.bg_color=GOLD
	noise_bar.add_theme_stylebox_override("background",empty_bar)
	noise_bar.add_theme_stylebox_override("fill",filled_bar)
	hud.add_child(noise_bar)
	_place(noise_bar,Control.PRESET_BOTTOM_RIGHT,Vector2(-253,-54),Vector2(215,4))
	stamina_bar=ProgressBar.new()
	stamina_bar.show_percentage=false
	stamina_bar.add_theme_stylebox_override("background",empty_bar)
	stamina_bar.add_theme_stylebox_override("fill",filled_bar)
	hud.add_child(stamina_bar)
	_place(stamina_bar,Control.PRESET_BOTTOM_RIGHT,Vector2(-253,-39),Vector2(215,2))
	debug_label=_label(hud,"",13,Color.GREEN)
	debug_label.position=Vector2(35,95)
	debug_label.hide()
	touch_controls=Control.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(touch_controls)
	touch_pad=load("res://scripts/touch_pad.gd").new()
	touch_pad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	touch_controls.add_child(touch_pad)
	_place(touch_pad,Control.PRESET_BOTTOM_LEFT,Vector2(48,-186),Vector2(120,120))
	for item in [["USE",Vector2(-122,-120),func():pass],["CROUCH",Vector2(-232,-95),func():crouch_touch.emit()],["LIGHT",Vector2(-122,-190),func():flashlight_touch.emit()],["PHONE",Vector2(-232,-170),func():phone_touch.emit()],["NOTES",Vector2(-232,20),func():journal_touch.emit()],["PAUSE",Vector2(-122,20),func():pause_touch.emit()]]:
		var b:=_button(touch_controls,item[0],item[2])
		if item[0]=="USE":
			b.button_down.connect(func():touch_use_down=true;interact_touch.emit())
			b.button_up.connect(func():touch_use_down=false)
		b.name="Touch_"+item[0]
		b.add_theme_font_size_override("font_size",13)
		_place(b,Control.PRESET_BOTTOM_RIGHT if item[1].y<0 else Control.PRESET_TOP_RIGHT,item[1],Vector2(95,55))
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
	touch_controls.visible=Session.touch_mode

func show_game() -> void:
	menu.hide()
	modal.hide()
	hud.show()
	modal_kind=""
	touch_controls.visible=Session.touch_mode

func update_hud(room:String,prompt:String,meter:float,stamina:float,threat:float,listening:bool,mic:bool) -> void:
	room_label.text=room
	act_label.text=Story.text("CHAPTER ","KABANATA ")+str(Session.act())+"  /  03"
	objective_label.text=Story.objective()
	prompt_label.text=("[E]  " if not Session.touch_mode else Story.text("[USE]  ","[GAMITIN]  "))+prompt if prompt!="" else ""
	noise_bar.value=meter*100
	stamina_bar.value=stamina*100
	stamina_bar.visible=stamina<0.99
	noise_label.text=Story.text("IT HEARS YOU","NARIRINIG KA NIYA") if threat>0.8 else (Story.text("THE HOUSE IS LISTENING","NAKIKINIG ANG BAHAY") if listening else Story.text("WALK SOFTLY","DAHAN-DAHAN"))
	if mic:noise_label.text+=" · MIC"
	film.material.set_shader_parameter("danger",threat)
	if debug_label.visible:
		debug_label.text="%d FPS  |  %d draws  |  %d triangles  |  %.1f MB VRAM" % [Engine.get_frames_per_second(),int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0]

func toast(message:String,seconds:float=4.0) -> void:
	toast_label.text=message
	toast_label.show()
	toast_time=seconds

func caption(en:String,fil:String) -> void:
	if Session.subtitles:
		caption_label.text=Story.text(en,fil)
		caption_time=3.2

func mic_status(message:String) -> void:
	toast(message,6.0)
	if is_instance_valid(mic_status_label):mic_status_label.text=message

func _settings_changed() -> void:
	touch_controls.visible=Session.touch_mode
	var labels:={"USE":["USE","GAMITIN"],"CROUCH":["CROUCH","YUKO"],"LIGHT":["LIGHT","ILAW"],"PHONE":["PHONE","TELEPONO"],"NOTES":["NOTES","TALAAN"],"PAUSE":["PAUSE","HINTO"]}
	for key in labels:
		var button:=touch_controls.get_node_or_null("Touch_"+key)
		if button:button.text=Story.text(labels[key][0],labels[key][1])
	film.material.set_shader_parameter("reduced_motion",Session.reduced_motion)
	film.material.set_shader_parameter("grain_strength",0.0 if Session.reduced_motion or Session.quality=="low" else 0.018)
	_layout_changed()

func _layout_changed() -> void:
	if not is_instance_valid(objective_label):return
	var width:=get_viewport().get_visible_rect().size.x
	objective_label.size.x=maxf(260,width*0.5)
	if Session.touch_mode:
		objective_label.offset_top=-245
		objective_label.offset_bottom=-175
		objective_label.size.x=width-70
		noise_label.offset_top=-43
		noise_label.offset_bottom=-23
		noise_bar.offset_top=-18
		noise_bar.offset_bottom=-14
	else:
		objective_label.offset_top=-86
		objective_label.offset_bottom=-21
		noise_label.offset_top=-84
		noise_label.offset_bottom=-64
		noise_bar.offset_top=-54
		noise_bar.offset_bottom=-50

func _process(delta:float) -> void:
	toast_time-=delta
	if toast_time<=0:toast_label.hide()
	caption_time-=delta
	if caption_time<=0:caption_label.text=""

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_F3:
		debug_label.visible=not debug_label.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and modal.visible:
		if modal_kind in ["note","journal"] and modal_close.is_valid():
			var callback:=modal_close
			close_modal()
			callback.call()
			get_viewport().set_input_as_handled()
		elif modal_kind=="pause":
			close_modal()
			resume_requested.emit()
			get_viewport().set_input_as_handled()
	if not Session.touch_mode or not hud.visible or modal.visible:return
	var size:=get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x<size.x*0.38 and event.position.y>size.y*0.42:
				left_finger=event.index
				touch_origin=event.position
			elif event.position.x>size.x*0.38 and event.position.y>size.y*0.18 and event.position.y<size.y*0.69:
				right_finger=event.index
		else:
			if event.index==left_finger:
				left_finger=-1
				touch_pad.direction=Vector2.ZERO
				touch_move_changed.emit(Vector2.ZERO)
			if event.index==right_finger:right_finger=-1
	if event is InputEventScreenDrag:
		if event.index==left_finger:
			touch_pad.direction=((event.position-touch_origin)/65.0).limit_length()
			touch_move_changed.emit(touch_pad.direction)
		if event.index==right_finger:touch_look.emit(event.relative*1.6)
