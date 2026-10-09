class_name Story
extends RefCounted
## All player-facing narrative lives together for Filipino / English parity.

static func text(en: String, fil: String) -> String:
	return fil if Session.language == "fil" else en

static func objective() -> String:
	return route_objective()

static func route_objective() -> String:
	if not Session.has_flag("arrival"):return text("Enter Lola's house.","Pumasok sa bahay ni Lola.")
	if not Session.has_flag("fuse"):return text("Restore the power beside the front door.","Buksan ang kuryente sa tabi ng pintuan.")
	if not Session.has_flag("rules"):return text("Read Lola's instructions in the sala, west of the foyer.","Basahin ang bilin ni Lola sa sala, sa kaliwa ng bungad.")
	if Session.route==Session.Route.UNDECIDED:
		return text("Offer kitchen rice at the altar, or hold E to play the sala cassette. This chooses your path.","Mag-alay ng kanin sa altar, o pindutin nang matagal ang E para sa cassette sa sala. Pipili ito ng iyong landas.")
	if Session.route==Session.Route.RELEASE:
		if not Session.has_flag("tomas_clue"):return text("Read Tomas's notebook upstairs, in the northeast bedroom.","Basahin ang tala ni Tomas sa kuwarto sa hilagang-silangan sa itaas.")
		if Session.memory_count()<3:return text("Remember him: sala cassette, family-bedroom photo, Lola's unsent letter.","Alalahanin siya: cassette sa sala, larawan sa kuwarto ng pamilya, liham ni Lola.")
		if not Session.has_flag("bindings_done"):return text("Enter a pantry/storeroom hatch. Unbind FACE → HOUR → EMPTY PLACE.","Bumaba sa paminggalan o bodega. Kalagin ang MUKHA → ORAS → BAKANTENG PUWESTO.")
		if not Session.has_flag("photo_restored"):return text("Restore the photograph at the upstairs sewing table.","Buuin ang larawan sa mesa sa silid-tahian sa itaas.")
		if not Session.has_flag("title"):return text("Use the spare key on the downstairs storeroom baul.","Gamitin ang ekstrang susi sa baul sa bodega sa ibaba.")
		if not Session.has_flag("pact"):return text("Read the agreement on the baul.","Basahin ang kasunduan sa baul.")
		if not Session.has_flag("matches"):return text("Take matches from the kitchen table.","Kunin ang posporo sa mesa sa kusina.")
		if not Session.has_flag("lure_used"):return text("Play the sala radio to draw it away, then return to the altar.","Patugtugin ang radyo sa sala upang ilayo ito, saka bumalik sa altar.")
		if not Session.has_flag("pact_burned"):return text("Burn the pact at the altar. Be ready to run.","Sunugin ang kasunduan sa altar. Maghandang tumakbo.")
		return text("ESCAPE TO THE GATE. The kitchen has a service exit.","UMALIS PATUNGO SA TARANGKAHAN. May labasan sa kusina.")
	if not Session.chores_done():return text("Complete Lola's six wards. The winding key is in the upstairs study. [J]","Tapusin ang anim na pananggalang. Nasa silid-aralan sa itaas ang susi ng orasan. [J]")
	if not Session.has_flag("key"):return text("Take the brass key behind the dining-room portrait.","Kunin ang susi sa likod ng larawan sa silid-kainan.")
	if not Session.has_flag("title"):return text("Open the baul in the downstairs storeroom.","Buksan ang baul sa bodega sa ibaba.")
	if not Session.has_flag("pact"):return text("Read the agreement on the baul.","Basahin ang kasunduan sa baul.")
	for i in range(3):
		if not Session.has_flag("trial_%s"%i):
			return text("Light candle %s, left to right, then remain quiet for eight seconds."%(i+1),"Sindihan ang kandila %s mula kaliwa pakanan, saka tumahimik nang walong segundo."%(i+1))
	if not Session.has_flag("sealed"):return text("Seal the pact beneath the altar bowl.","Iselyo ang kasunduan sa ilalim ng mangkok sa altar.")
	return text("Leave through the front gate with the title.","Umalis sa tarangkahan dala ang titulo.")


static func journal() -> String:
	if Session.route==Session.Route.UNDECIDED:
		return text("TWO INSTRUCTIONS\n\nLola asks for silence and a warm offering. Placing rice on the altar means keeping her promise.\n\nThe cassette in the sala asks you to remember someone the house has erased. Playing it means rejecting her rules.\n\nHold E / USE to commit. Examining the cassette does not play it.\n\nMain stairs: east of the foyer. Service stairs: northwest kitchen. Both floors loop around the courtyard.",
			"DALAWANG BILIN\n\nHumihingi si Lola ng katahimikan at mainit na alay. Ang paglalagay ng kanin sa altar ay pagtupad sa pangako niya.\n\nHinihiling ng cassette sa sala na alalahanin ang taong binura ng bahay. Ang pagpatugtog nito ay pagtanggi sa mga bilin niya.\n\nPindutin nang matagal ang E / GAMITIN upang piliin ang landas. Hindi nagpapatugtog ang pagsusuri sa cassette.\n\nPangunahing hagdan: silangan ng bungad. Hagdan sa kusina: hilagang-kanluran. Umiikot sa bakuran ang dalawang palapag.")
	if Session.route==Session.Route.RELEASE:
		var out:=text("RETURN HIS NAME\n\n","IBALIK ANG PANGALAN NIYA\n\n")
		for row in [
			["tomas_clue","Read Tomas's upstairs notebook.","Basahin ang tala ni Tomas sa itaas."],
			["memory_photo","Family bedroom: cut photograph.","Kuwarto ng pamilya: ginupit na larawan."],
			["memory_letter","Lola's bedroom: unsent letter.","Kuwarto ni Lola: liham."],
			["memory_tape","Sala: forbidden cassette.","Sala: ipinagbabawal na cassette."],
			["bindings_done","Below the house: PORTRAIT → CLOCK → BOWL.","Ilalim ng bahay: LARAWAN → ORASAN → MANGKOK."],
			["photo_restored","Restore the photograph in the sewing room.","Buuin ang larawan sa silid-tahian."],
			["title","Retrieve the land title and pact from the baul.","Kunin ang titulo at kasunduan sa baul."],
			["matches","Kitchen: take matches.","Kusina: kunin ang posporo."],
			["lure_used","Set the radio recording as a lure.","Patugtugin ang recording bilang pang-akit."],
			["pact_burned","Burn the agreement at the altar and escape.","Sunugin ang kasunduan sa altar at tumakas."]
		]:out+=("[x] " if Session.has_flag(row[0]) else "[ ] ")+text(row[1],row[2])+"\n\n"
		return out+text("A wrong binding order tightens all three again. The radio can be replayed. You do not need Lola's six wards. No microphone or spoken password is required.",
			"Muling hihigpit ang tatlong tali kapag mali ang pagkakasunod. Maaaring ulitin ang radyo. Hindi kailangan ang anim na pananggalang. Walang kailangang mikropono o binibigkas na password.")
	var title := text("LOLA'S LAST INSTRUCTIONS", "HULING BILIN NI LOLA")
	var text := title + "\n\n"
	var chores := [
		["shutter_kitchen", "Latch the kitchen window.", "Isara ang bintana sa kusina."],
		["shutter_lola", "Latch the window in Lola's room.", "Isara ang bintana sa kuwarto ni Lola."],
		["shutter_family", "Latch the upstairs guest-bedroom window.", "Isara ang bintana sa kuwarto ng bisita sa itaas."],
		["portrait", "Turn the family portrait toward the wall.", "Iharap sa dingding ang larawan ng pamilya."],
		["clock_stopped", "Study: take the winding key. Dining room: stop the clock at 6:15.", "Kunin ang susi sa silid-aralan. Ihinto sa 6:15 ang orasan sa silid-kainan."],
		["salt_line", "Lay a line of salt across the back threshold.", "Maglagay ng asin sa bungad ng pintuan sa likod."]]
	for row in chores:
		text += ("[x]  " if Session.has_flag(row[0]) else "[  ]  ") + text(row[1], row[2]) + "\n\n"
	text += text("Walk softly. Crouch to move more quietly. Hiding behind furniture breaks its line of sight. The house listens most closely when the lamp turns red.\n\nA phone can be thrown to lure it away. [Q] Tap its light to retrieve it after the danger passes.", "Dahan-dahan sa paglakad. Yumuko para humina ang yabag. Magtago sa likod ng mga kasangkapan. Mas nakikinig ang bahay kapag namumula ang ilaw.\n\nMaaaring ihagis ang telepono para ilayo ito. [Q] Pulutin matapos ang panganib.")
	return text

static func note(id: String) -> Dictionary:
	var fresh:=expanded_note(id)
	if not fresh.is_empty():return fresh
	var notes := {
		"arrival": ["MAMA · 8:43 PM", "MAMA · 8:43 NG", "Anak, the title is in Lola's baul. Bring it tomorrow. I left the key where she always kept it.\n\nAnd don't sleep there. The neighbors said the lights have been turning on by themselves.\n\nPS: Take the rice cooker if it still works. Sayang naman.", "Anak, nasa baul ni Lola ang titulo. Dalhin mo bukas. Iniwan ko ang susi sa dati niyang taguan.\n\nHuwag kang matulog diyan. Sabi ng kapitbahay, kusang bumubukas ang ilaw.\n\nPS: Kunin mo na rin ang rice cooker kung gumagana pa. Sayang naman."],
		"rules": ["A NOTE IN LOLA'S HANDWRITING", "SULAT-KAMAY NI LOLA", "Mika,\n\nIf I am gone before you read this, finish what I could not. Shut all three windows. Turn our photograph to the wall. Stop the clock at quarter past six. Salt the back threshold.\n\nOnly then will you find the key.\n\nWhen it listens, do not let it hear you. If it calls with my voice, it is not me.\n\nI am sorry I taught you to be quiet before I taught you why.\n\n— Lola\n\n[Your journal keeps the six instructions.]", "Mika,\n\nKung wala na ako pagdating mo, tapusin mo ang hindi ko natapos. Isara ang tatlong bintana. Iharap sa dingding ang larawan natin. Ihinto ang orasan sa alas-sais kinse. Asinan ang bungad sa likod.\n\nSaka mo makikita ang susi.\n\nKapag nakikinig ito, huwag kang magpahuli sa ingay. Kung tawagin ka gamit ang boses ko, hindi ako iyon.\n\nPatawad. Tinuruan kitang tumahimik bago ko naipaliwanag kung bakit.\n\n— Lola\n\n[Nasa talaan ang anim na bilin.]"],
		"memory_photo": ["A FAMILY PHOTOGRAPH · 1998", "LARAWAN NG PAMILYA · 1998", "The photograph shows you, Mama, and Lola at a birthday table. Someone cut out the fourth person.\n\nOn the back: 'For the one who stayed. We have not forgotten your name.'\n\nYou remember being told that the empty chair was for a guest who was always late.", "Nasa larawan kayong tatlo nina Mama at Lola sa isang kaarawan. Ginupit ang ikaapat na tao.\n\nSa likod: 'Para sa naiwan. Hindi namin kinalimutan ang pangalan mo.'\n\nNaaalala mong ang bakanteng upuan ay para raw sa bisitang laging nahuhuli."],
		"memory_letter": ["AN UNSENT LETTER", "LIHAM NA HINDI NAIPADALA", "Dear Elena,\n\nIt learned our footsteps first. Then our prayers. Yesterday I heard your brother coughing in the kitchen. He has been dead for eleven years.\n\nThe agreement says one of us must always listen. I thought that meant me. Now I hear it whispering your daughter's name.\n\nDo not bring Mika home.\n\n— Nanay", "Mahal kong Elena,\n\nUna nitong natutuhan ang yabag natin. Sumunod ang mga dasal. Kahapon, narinig kong umuubo ang kapatid mo sa kusina. Labing-isang taon na siyang patay.\n\nSabi sa kasunduan, dapat may isa sa ating laging nakikinig. Akala ko ako iyon. Ngayon, pangalan ng anak mo ang ibinubulong nito.\n\nHuwag mong iuwi si Mika.\n\n— Nanay"],
		"memory_tape": ["THE LABEL ON A CASSETTE", "TATAK SA CASSETTE", "'Mika's first words — DO NOT PLAY'\n\nUnderneath, in a different hand: 'It cannot invent a voice. It can only keep what we give it.'\n\nThere is no tape inside. Only a carefully folded slip of paper:\n\n'My name is Tomas. I was her son. I was not the first.'", "'Unang salita ni Mika — HUWAG PATUGTUGIN'\n\nSa ilalim, ibang sulat-kamay: 'Hindi ito nakakalikha ng boses. Iniingatan lang nito ang ibinibigay natin.'\n\nWalang tape sa loob. Isang nakatiklop na papel lang:\n\n'Ako si Tomas. Anak niya ako. Hindi ako ang una.'"],
		"pact": ["THE AGREEMENT · 1954", "ANG KASUNDUAN · 1954", "In exchange for shelter, a place shall be kept at the table.\n\nIn exchange for protection, a name shall be kept in silence.\n\nWhen the keeper dies, the next shall serve rice, light three candles, and wait without a sound.\n\nThen seal the agreement beneath the bowl.\n\nLola added one line in red:\n\n'Fire releases what silence keeps. But it takes the house with it.'\n\nThe title is yours. So is the decision.", "Kapalit ng tahanan, maglalaan ng isang lugar sa hapag.\n\nKapalit ng kaligtasan, mag-iingat ng isang pangalan sa katahimikan.\n\nPagpanaw ng tagapag-ingat, ang susunod ay maghahain ng kanin, magsisindi ng tatlong kandila, at maghihintay nang walang imik.\n\nPagkatapos, iseselyo ang kasunduan sa ilalim ng mangkok.\n\nMay idinagdag si Lola sa pulang tinta:\n\n'Pinakakawalan ng apoy ang ikinukulong ng katahimikan. Ngunit kasama ang bahay.'\n\nSa iyo ang titulo. Sa iyo rin ang pasya."],
		"clock_hint": ["THE CLOCK", "ANG ORASAN", "The hands are stuck. The little brass dial still turns.\n\nLola said it was always dinner time in this house.\n\nSet the hour to SIX and the minute to FIFTEEN, then pull the winding key.", "Nakabara ang mga kamay. Naiikot pa ang tansong pihitan.\n\nSabi ni Lola, palaging oras ng hapunan sa bahay na ito.\n\nItakda ang oras sa ANIM at minuto sa KINSE, saka bunutin ang susi."]
	}
	if not notes.has(id):
		return {"title": id, "body": ""}
	var n: Array = notes[id]
	return {"title": text(n[0], n[1]), "body": text(n[2], n[3])}

static func expanded_note(id:String) -> Dictionary:
	var entries:={
		"rules":["LOLA'S LAST INSTRUCTIONS","HULING BILIN NI LOLA",
			"Mika,\n\nIf you keep my promise, bring warm rice from the kitchen to the old altar, in the northeast corner downstairs. Then close the kitchen, my bedroom, and guest-bedroom windows. Turn our dining-room portrait away. Stop the dining-room clock at 6:15; its winding key is in my study upstairs. Salt the altar doorway.\n\nThe brass key will be behind the portrait only when all six wards hold.\n\nDo not play the cassette beside the sala radio. If you play it, you are choosing to return the voices I kept quiet. I cannot protect you on that path.\n\nIf it calls with my voice, it is not me.\n\n— Lola\n\n[Offer rice or play the cassette to choose your path. Your journal keeps the clues.]",
			"Mika,\n\nKung tutuparin mo ang pangako ko, magdala ng kanin mula kusina sa lumang altar sa hilagang-silangan sa ibaba. Isara ang bintana ng kusina, kuwarto ko, at kuwarto ng bisita. Iharap sa dingding ang larawan sa silid-kainan. Ihinto sa 6:15 ang orasan; nasa silid-aralan ko sa itaas ang susi. Asinan ang pintuan ng altar.\n\nMakikita ang susi sa likod ng larawan kapag nakahanda na ang anim na pananggalang.\n\nHuwag patugtugin ang cassette sa tabi ng radyo sa sala. Ang pagpatugtog nito ay pagpiling ibalik ang mga boses na pinatahimik ko. Hindi kita mapoprotektahan sa landas na iyon.\n\nKung tawagin ka gamit ang boses ko, hindi ako iyon.\n\n— Lola\n\n[Mag-alay ng kanin o patugtugin ang cassette para piliin ang landas. Nasa talaan ang mga pahiwatig.]"],
		"keeper":["A PLACE KEPT","ISANG INILAANG PUWESTO",
			"The bowl settles before you let go. Somewhere above, a window closes by itself.\n\nYou have chosen Lola's promise. Complete the six wards in your journal. Then retrieve the title and agreement, light the candles from left to right, and keep each flame still with eight quiet seconds.\n\nThe promise will not ask you to choose again.",
			"Pumirmi ang mangkok bago mo pa bitawan. May bintanang kusang nagsara sa itaas.\n\nPinili mo ang pangako ni Lola. Tapusin ang anim na pananggalang sa talaan. Kunin ang titulo at kasunduan, sindihan ang mga kandila mula kaliwa pakanan, at patatagin ang bawat apoy sa walong tahimik na segundo.\n\nHindi ka na muling papipiliin ng pangako."],
		"release":["A VOICE RETURNED","ISANG IBINALIK NA BOSES",
			"The damaged recording is not a warning. It is a name trying to finish itself.\n\nT—\n\nThere is a bedroom upstairs your family never talks about. Read the notebook there. Find the photograph, letter, and cassette label. Together they explain the bindings beneath the house.\n\nYou have rejected Lola's rules. Remembering, not obedience, is your way through.",
			"Hindi babala ang sirang recording. Isa itong pangalang gustong mabuo.\n\nT—\n\nMay kuwarto sa itaas na hindi pinag-uusapan ng pamilya mo. Basahin ang tala roon. Hanapin ang larawan, liham, at tatak ng cassette. Ipinapaliwanag ng mga ito ang mga tali sa ilalim ng bahay.\n\nTinanggihan mo ang mga bilin ni Lola. Pag-alala, hindi pagsunod, ang landas mo."],
		"memory_tape":["THE FORBIDDEN CASSETTE","ANG IPINAGBABAWAL NA CASSETTE",
			"“Mika's first words — DO NOT PLAY.”\n\nThe tape inside has been repaired with red thread. Beneath the label:\n\n“It cannot invent a voice. It can only keep what we give it.”\n\nA folded slip: “My name is Tomas. I was her son. I was not the first.”\n\n[Examining is safe. Hold E on the radio to play it and reject Lola's rules.]",
			"“Unang salita ni Mika — HUWAG PATUGTUGIN.”\n\nTinahi ng pulang sinulid ang tape. Sa ilalim ng tatak:\n\n“Hindi ito nakakalikha ng boses. Iniingatan lang nito ang ibinibigay natin.”\n\nNakatiklop na papel: “Ako si Tomas. Anak niya ako. Hindi ako ang una.”\n\n[Ligtas ang pagsusuri. Pindutin nang matagal ang E sa radyo para patugtugin at tanggihan ang bilin ni Lola.]"],
		"tomas_clue":["TOMAS'S NOTEBOOK","TALA NI TOMAS",
			"She hid my face, stopped my hour, and kept my place at the table.\n\nBelow the house, loosen what holds me:\n\nFirst remember the FACE. Then remember the HOUR. Finally leave the PLACE EMPTY.\n\nPORTRAIT → CLOCK → BOWL.\n\nFind all three memories first. The last binding holds the spare baul key and the missing piece of the photograph. The sewing table can put my face back.\n\nI am not the thing wearing our voices.",
			"Itinago niya ang mukha ko, inihinto ang oras ko, at iningatan ang puwesto ko sa hapag.\n\nSa ilalim ng bahay, kalagin ang pumipigil sa akin:\n\nUnahin ang MUKHA. Saka ang ORAS. Huling iwan ang BAKANTENG PUWESTO.\n\nLARAWAN → ORASAN → MANGKOK.\n\nHanapin muna ang tatlong alaala. Nasa huling tali ang ekstrang susi ng baul at nawawalang piraso ng larawan. Maibabalik ng mesa sa silid-tahian ang mukha ko.\n\nHindi ako ang gumagamit ng mga boses natin."],
		"crawl_lore":["THE WOOD REMEMBERS","NAALALA NG KAHOY",
			"Names scratched into a beam, one beneath another. Tomas is not the oldest.\n\nAn extra plate is drawn beside every name.\n\nThe cords lead upward into the rooms. Even down here, the house expects you to stand in somebody else's place.",
			"Mga pangalang nakaukit sa biga, magkakapatong. Hindi si Tomas ang pinakamatanda.\n\nMay dagdag na platong iginuhit sa bawat pangalan.\n\nUmaakyat sa mga kuwarto ang mga tali. Kahit dito, inaasahan ng bahay na pumalit ka sa iba."],
		"restored":["A FACE IN THE PHOTOGRAPH","MUKHA SA LARAWAN",
			"The fourth person is a young man. Mama's brother. Tomas.\n\nThe empty chair was never for a late guest.\n\nTake the title and pact from the baul. Find matches in the kitchen. Set the sala recording as a lure, then burn the agreement at the altar. Fire takes the house; do not stay to watch.",
			"Binata ang ikaapat na tao. Kapatid ni Mama. Si Tomas.\n\nHindi para sa nahuling bisita ang bakanteng upuan.\n\nKunin ang titulo at kasunduan sa baul. Hanapin ang posporo sa kusina. Patugtugin ang recording sa sala bilang pang-akit, saka sunugin ang kasunduan sa altar. Kukunin ng apoy ang bahay; huwag manatili para manood."]
	}
	if not entries.has(id):return {}
	var n:Array=entries[id]
	return {"title":text(n[0],n[1]),"body":text(n[2],n[3])}

static func ending(kind: String) -> Dictionary:
	var remembered := int(Session.ending_records.get(kind,{}).get("memories",Session.memory_count())) == 3
	if kind == "seal":
		return {"title": text("THE NEW KEEPER", "ANG BAGONG TAGAPAG-INGAT"), "body": text("At dawn, the rain stops. You leave with the title.\n\nMama asks why you set an extra plate at breakfast.\n\nYou tell her you don't remember doing it.", "Pagsikat ng araw, tumila ang ulan. Dala mo ang titulo.\n\nTinanong ni Mama kung bakit may dagdag na plato sa almusal.\n\nSabi mo, hindi mo maalalang inilagay mo iyon."), "post": text("Behind you, a voice almost says: 'Thank you, Mika.'", "Sa likod mo, halos marinig ang: 'Salamat, Mika.'") if remembered else text("Somewhere in the house, a clock begins to tick.", "Sa kung saan, muling tumiktak ang orasan.")}
	return {"title": text("A NAME IN THE ASHES", "PANGALAN SA ABO"), "body": text("The neighbors say the house burned without a sound.\n\nYou find Mama at the gate. She is crying before you tell her.\n\nFor the first time, she speaks her brother's name.", "Sabi ng mga kapitbahay, tahimik na nasunog ang bahay.\n\nNakita mo si Mama sa tarangkahan. Umiiyak na siya bago ka pa magsalita.\n\nSa unang pagkakataon, binigkas niya ang pangalan ng kapatid niya."), "post": text("'Tomas,' you say. The wind carries nothing back.\n\nYou remembered them all.", "'Tomas,' sabi mo. Walang ibinulong ang hangin.\n\nNaalala mo silang lahat.") if remembered else text("There were names you never learned.\n\nThree memories still wait in the dark.", "May mga pangalang hindi mo nalaman.\n\nMay tatlong alaala pang naiwan sa dilim.")}
