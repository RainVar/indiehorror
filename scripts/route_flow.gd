class_name HouseRoutes
extends RefCounted
var game:Node3D
var ritual_time:=0.0
var trial:=-1
var radio_time:=0.0
const BINDINGS:=["portrait","clock","bowl"]
const WARDS:=["shutter_kitchen","shutter_lola","shutter_family","portrait","clock_stopped","salt_line"]

func _init(owner_game:Node3D) -> void:
	game=owner_game

func reset() -> void:
	ritual_time=0
	trial=-1
	radio_time=0

func say(en:String,fil:String) -> void:
	game.ui.toast(Story.text(en,fil),5)

func keeper() -> bool:
	if Session.route==Session.Route.KEEPER:return true
	say("These are Lola's wards. Choose whether to keep her promise first.","Mga pananggalang ito ni Lola. Piliin muna kung tutuparin ang pangako niya.")
	return false

func handle(id:String) -> bool:
	if id.begins_with("hatch_"):
		if Session.route==Session.Route.UNDECIDED:
			say("Read the instructions. Offer rice or play the tape before going below.","Basahin ang mga bilin. Mag-alay ng kanin o patugtugin ang cassette bago bumaba.")
		else:game.travel_hatch(id)
		return true
	if id in ["crawl_lore","tomas_clue"]:
		if id=="tomas_clue":Session.set_flag("tomas_clue")
		game.show_note(id)
		return true
	if id=="radio":
		if not Session.has_flag("rules"):
			say("Read Lola's note before playing this.","Basahin muna ang sulat ni Lola bago ito patugtugin.")
		elif Session.route==Session.Route.UNDECIDED:
			Session.commit_route(Session.Route.RELEASE)
			Session.set_flag("memory_tape")
			Session.make_checkpoint("sala")
			game.show_note("release")
		elif Session.route==Session.Route.KEEPER:
			say("You promised to keep its voices quiet.","Nangako kang panatilihing tahimik ang mga boses.")
		else:
			radio_time=20
			game.entity.grace=0
			game.noise.emit_noise(game.world.radio_point,0.95,"radio")
			game.sound.play_at("phone",game.world.radio_point,-12,0.65)
			if Session.has_flag("title") and Session.has_flag("photo_restored") and Session.has_flag("matches"):
				Session.set_flag("lure_used")
				Session.make_checkpoint("final")
			say("The recording plays for twenty seconds. It can be played again.","Tutunog ang recording nang dalawampung segundo. Maaari itong ulitin.")
		return true
	if id in ["rice","salt","matches","winding_key"]:
		if not Session.has_flag("rules"):say("Read Lola's note first.","Basahin muna ang bilin ni Lola.");return true
		if id in ["salt","winding_key"] and not keeper():return true
		if id=="matches" and Session.route!=Session.Route.RELEASE:
			say("Keep these in mind if you decide to break the pact.","Tandaan ang posporo kung pipiliin mong putulin ang kasunduan.")
			return true
		Session.set_flag(id)
		say({"rice":"Rice taken. Offering it at the altar commits to Lola's promise.","salt":"Salt taken. The altar doorway is the back threshold.","matches":"Matches taken. Restore the photograph and set the radio lure.","winding_key":"The clock winding key. Return to the dining-room clock."}[id],
			{"rice":"Nakuha ang kanin. Ang pag-alay nito sa altar ay pagtupad sa pangako ni Lola.","salt":"Nakuha ang asin. Nasa pintuan ng altar ang bungad sa likod.","matches":"Nakuha ang posporo. Buuin ang larawan at patugtugin ang pang-akit.","winding_key":"Nakuha ang susi ng orasan. Bumalik sa orasan sa silid-kainan."}[id])
		return true
	if id.begins_with("shutter_") or id in ["portrait","threshold"]:
		if not keeper():return true
		if id=="portrait" and Session.chores_done():
			Session.set_flag("key")
			Session.make_checkpoint("sala")
			say("The brass key is behind the frame. Open the baul in the downstairs storeroom.","Nasa likod ng kuwadro ang susi. Buksan ang baul sa bodega sa ibaba.")
			return true
		if id=="threshold" and not Session.has_flag("salt"):
			say("Take salt from the kitchen first.","Kunin muna ang asin sa kusina.")
			return true
		var flag:="salt_line" if id=="threshold" else id
		if Session.has_flag(flag):say("The ward is already in place.","Nakahanda na ang pananggalang.");return true
		Session.set_flag(flag)
		game.sound.play_at("knock" if id.begins_with("shutter") else "creak",game.player.position,-13)
		game.noise.emit_noise(game.player.position,0.35,"ward")
		check_wards()
		return true
	if id=="clock":
		if not keeper():return true
		if not Session.has_flag("winding_key"):
			say("The winding key is missing. Lola kept it in her upstairs study.","Nawawala ang susi. Itinatago ito ni Lola sa silid-aralan sa itaas.")
		else:
			game._freeze()
			game.ui.show_clock()
		return true
	if id.begins_with("binding_"):
		if Session.route!=Session.Route.RELEASE:
			say("These bindings hold Lola's promise. You chose to keep it.","Mga tali ng pangako ni Lola. Pinili mong panatilihin ito.")
			return true
		if not Session.has_flag("tomas_clue") or Session.memory_count()!=3:
			say("Find all three memories and Tomas's notebook upstairs before disturbing the bindings.","Hanapin ang tatlong alaala at tala ni Tomas sa itaas bago kalagin ang mga tali.")
			return true
		if Session.has_flag("bindings_done"):say("The bindings are already loose.","Maluwag na ang mga tali.");return true
		var count:=0
		for key in BINDINGS:
			if Session.has_flag("binding_"+key):count+=1
		if id!="binding_"+BINDINGS[count]:
			for key in BINDINGS:Session.set_flag("binding_"+key,false)
			game.sound.play_at("knock",game.player.position+Vector3(0,1.6,0),-15)
			say("The cords tighten again. Remember the face, then the hour; leave the place empty.","Hinigpitan muli ang mga tali. Alalahanin ang mukha, saka ang oras; iwang bakante ang puwesto.")
		else:
			Session.set_flag(id)
			game.sound.play_at("creak",game.player.position,-16)
			if count==2:
				Session.set_flag("bindings_done")
				Session.set_flag("key")
				Session.set_flag("photo_fragment")
				Session.make_checkpoint("store")
				say("A spare key and the missing photograph piece fall from the beam. Climb out.","Nahulog ang ekstrang susi at piraso ng larawan mula sa biga. Umahon na.")
		return true
	if id=="sewing":
		if Session.route!=Session.Route.RELEASE or not Session.has_flag("photo_fragment"):
			say("The photograph is missing a face. Look beneath the house.","May nawawalang mukha sa larawan. Hanapin sa ilalim ng bahay.")
		else:
			Session.set_flag("photo_restored")
			Session.make_checkpoint("upper")
			game.show_note("restored")
		return true
	if id=="baul":
		if not Session.has_flag("key"):say("Locked. Follow your route's clues to find a key.","Nakasara. Sundin ang mga pahiwatig ng iyong landas para mahanap ang susi.")
		elif not Session.has_flag("title"):
			Session.set_flag("title")
			Session.make_checkpoint("store")
			game.entity.reset()
			game.entity.grace=24
			say("The land title is yours. Read the pact on the baul.","Nasa iyo na ang titulo. Basahin ang kasunduan sa baul.")
		else:say("You already have the title. Read the agreement.","Nasa iyo na ang titulo. Basahin ang kasunduan.")
		return true
	if id=="altar":
		if Session.route==Session.Route.UNDECIDED:
			if not Session.has_flag("rice"):say("Bring warm rice from the kitchen. Offering it keeps Lola's promise.","Magdala ng kanin mula sa kusina. Ang pag-alay nito ay pagtupad sa pangako ni Lola.")
			else:
				Session.commit_route(Session.Route.KEEPER)
				Session.set_flag("offering")
				Session.make_checkpoint("sala")
				game.show_note("keeper")
		elif Session.route==Session.Route.KEEPER:
			if not Session.has_flag("pact"):say("Finish the wards, retrieve the title, and read the pact.","Tapusin ang mga pananggalang, kunin ang titulo, at basahin ang kasunduan.")
			elif Session.has_flag("ritual_survived"):
				Session.set_flag("sealed")
				Session.make_checkpoint("final")
				game.entity.reset()
				game.entity.grace=9999
				say("The promise is sealed. Leave through the front gate.","Naiselyo na ang pangako. Umalis sa tarangkahan.")
			else:say("Light the altar candles one at a time, from left to right.","Sindihan ang mga kandila mula kaliwa pakanan, nang paisa-isa.")
		else:
			if Session.has_flag("pact_burned"):say("GET OUT. Reach the gate.","LUMABAS KA. Marating ang tarangkahan.");return true
			if not Session.has_flag("pact") or not Session.has_flag("photo_restored") or not Session.has_flag("matches") or not Session.has_flag("lure_used"):
				say("Restore Tomas's photo, retrieve the pact and matches, then play the radio lure.","Buuin ang larawan ni Tomas, kunin ang kasunduan at posporo, saka patugtugin ang pang-akit.")
			else:
				Session.make_checkpoint("final")
				Session.set_flag("pact_burned")
				game.entity.reset()
				game.entity.grace=2.5
				game.entity.chase_locked=true
				game.entity.target_point=game.player.position
				game.entity._change(ListeningEntity.State.HUNT,60)
				game.sound.play_at("match",game.world.altar_point,-10)
				say("The house is burning. Use the galleries or kitchen service exit. Reach the gate.","Nasusunog ang bahay. Gamitin ang mga pasilyo o labasan sa kusina. Marating ang tarangkahan.")
		return true
	if id.begins_with("candle_"):
		if Session.route!=Session.Route.KEEPER or not Session.has_flag("pact"):return true
		var index:=int(id.trim_prefix("candle_"))
		if index>0 and not Session.has_flag("trial_%s"%(index-1)):
			say("Wait until the previous flame settles.","Hintaying pumirmi ang naunang apoy.");return true
		if Session.has_flag("trial_%s"%index):return true
		trial=index
		ritual_time=0
		Session.set_flag(id)
		Session.set_flag("candles")
		game.sound.play_at("match",game.world.altar_point,-15)
		say("Stay near the candle. Eight quiet seconds. Noise resets only this flame.","Manatili malapit sa kandila. Walong tahimik na segundo. Ang ingay ay magpapasimula muli sa apoy na ito.")
		return true
	if id=="gate":
		if Session.route==Session.Route.KEEPER and Session.has_flag("sealed"):game.choose_ending("seal")
		elif Session.route==Session.Route.RELEASE and Session.has_flag("pact_burned"):game.choose_ending("break")
		else:say("You still have unfinished business inside.","May hindi ka pa natatapos sa loob.")
		return true
	return false

func check_wards() -> void:
	var count:=0
	for flag in WARDS:
		if Session.has_flag(flag):count+=1
	if count==6:
		say("All six wards hold. Look behind the dining-room portrait.","Nakahanda na ang anim na pananggalang. Tingnan ang likod ng larawan sa silid-kainan.")
	elif count>=3 and not Session.has_flag("mid_checkpoint"):
		Session.set_flag("mid_checkpoint")
		Session.make_checkpoint("sala")
		say("Three wards complete. Checkpoint saved.","Natapos ang tatlong pananggalang. Nai-save ang checkpoint.")

func update(delta:float) -> void:
	if radio_time>0:
		var previous:=radio_time
		radio_time-=delta
		if int(previous/3)!=int(radio_time/3):
			game.noise.emit_noise(game.world.radio_point,0.95,"radio")
			game.sound.play_at("phone",game.world.radio_point,-15,0.65)
	if trial>=0:
		if game.player.position.distance_to(game.world.altar_point)>3.4 or game.noise.meter>=0.25:ritual_time=0
		else:ritual_time+=delta
		game.ritual_time=ritual_time
		if ritual_time>=8:
			Session.set_flag("trial_%s"%trial)
			var finished:=trial
			trial=-1
			if finished==2:Session.set_flag("ritual_survived")
			Session.make_checkpoint("final")
			say("The flame is still. "+("Seal the pact beneath the bowl." if finished==2 else "Light the next candle."),
				"Pumirmi ang apoy. "+("Iselyo ang kasunduan sa ilalim ng mangkok." if finished==2 else "Sindihan ang kasunod na kandila."))
