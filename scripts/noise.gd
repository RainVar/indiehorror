class_name HouseNoise
extends Node
## A single noise event interface for physical sounds, mic amplitude and test input.
signal noise_emitted(position: Vector3, intensity: float, category: String)
signal microphone_status(message: String)

var meter: float = 0.0
var mic_level: float = 0.0
var mic_ready: bool = false
var calibrating: float = 0.0
var calibration_peak: float = 0.0
var mic_player: AudioStreamPlayer
var capture: AudioEffectCapture
var source_position: Vector3 = Vector3.ZERO
var mic_cooldown: float = 0.0
var enabled: bool = false
var floor_level: float = 0.003
var _permission_wait: float = 0.0

const WEB_MIC_START := """
(function () {
  if (window.bulongMic && window.bulongMic.stop) window.bulongMic.stop();
  const mic = {status:'requesting', level:0, stream:null, context:null, raf:0, cancelled:false};
  window.bulongMic = mic;
  mic.stop = function () {
    mic.cancelled = true; cancelAnimationFrame(mic.raf);
    if (mic.stream) mic.stream.getTracks().forEach(t => t.stop());
    if (mic.context) mic.context.close().catch(() => {});
    mic.level = 0; mic.status = 'off';
  };
  if (!navigator.mediaDevices || !window.isSecureContext) {mic.status='unavailable'; return;}
  navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:false}})
    .then(async stream => {
      if (mic.cancelled) {stream.getTracks().forEach(t=>t.stop()); return;}
      mic.stream=stream;
      const ctx=new (window.AudioContext || window.webkitAudioContext)(); mic.context=ctx;
      await ctx.resume();
      const source=ctx.createMediaStreamSource(stream), analyser=ctx.createAnalyser();
      analyser.fftSize=1024; source.connect(analyser);
      const samples=new Float32Array(analyser.fftSize);
      stream.getAudioTracks().forEach(t=>t.addEventListener('ended',()=>{mic.status='ended';}));
      mic.status='ready';
      function poll() {
        if (mic.cancelled || mic.status !== 'ready') return;
        analyser.getFloatTimeDomainData(samples);
        let sum=0; for (const s of samples) sum+=s*s;
        mic.level=Math.sqrt(sum/samples.length); samples.fill(0);
        mic.raf=requestAnimationFrame(poll);
      }
      poll();
    }).catch(() => { if (!mic.cancelled) mic.status='denied'; });
})();
"""

func emit_noise(pos: Vector3, intensity: float, category: String) -> void:
	if not enabled:
		return
	var strength := clampf(intensity, 0.0, 1.0)
	meter = maxf(meter, strength)
	noise_emitted.emit(pos, strength, category)

func start_microphone() -> void:
	if mic_player or Session.mic_enabled:
		stop_microphone()
	Session.mic_enabled = true
	calibrating = 3.0
	calibration_peak = 0.0
	_permission_wait = 0.0
	mic_ready = false
	microphone_status.emit(Story.text("Allow microphone access, then stay quiet for 3 seconds.", "Payagan ang mikropono, saka tumahimik nang 3 segundo."))
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_MIC_START)
		return
	var bus := AudioServer.get_bus_index("Microphone")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Microphone")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.1
	AudioServer.add_bus_effect(bus, capture)
	AudioServer.set_bus_mute(bus, true)
	mic_player = AudioStreamPlayer.new()
	mic_player.bus = "Microphone"
	mic_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	mic_player.stream = AudioStreamMicrophone.new()
	add_child(mic_player)
	mic_player.play()

func stop_microphone() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.bulongMic && window.bulongMic.stop) window.bulongMic.stop();")
	Session.mic_enabled = false
	mic_ready = false
	mic_level = 0.0
	if mic_player:
		mic_player.stop()
		mic_player.queue_free()
		mic_player = null
	var bus := AudioServer.get_bus_index("Microphone")
	if bus >= 0:
		while AudioServer.get_bus_effect_count(bus) > 0:
			AudioServer.remove_bus_effect(bus, 0)
	capture = null
	microphone_status.emit(Story.text("Microphone off. The house still hears in-game sounds.", "Patay ang mikropono. Naririnig pa rin ng bahay ang mga tunog sa laro."))

static func rms_to_strength(rms: float, threshold: float) -> float:
	if rms < threshold:
		return 0.0
	return clampf((rms - threshold) / maxf(0.025, threshold * 2.0) + 0.25, 0.0, 1.0)

func _process(delta: float) -> void:
	meter = move_toward(meter, 0.0, delta * 0.5)
	mic_cooldown -= delta
	if not Session.mic_enabled:
		return
	if OS.has_feature("web"):
		var status=str(JavaScriptBridge.eval("window.bulongMic ? window.bulongMic.status : 'unavailable'"))
		if status in ["denied", "ended", "unavailable"]:
			stop_microphone()
			microphone_status.emit(Story.text("Microphone unavailable. In-game sound mode is active; nothing is lost.","Hindi magamit ang mikropono. Aktibo pa rin ang mga tunog sa laro."))
		elif status == "ready":
			_consume_level(float(JavaScriptBridge.eval("window.bulongMic.level")),delta)
		return
	if capture == null:return
	var frames := capture.get_frames_available()
	if frames <= 0:
		_permission_wait += delta
		if _permission_wait > 12.0 and not mic_ready:
			stop_microphone()
			microphone_status.emit(Story.text("Microphone unavailable. You can play the complete game without it.", "Hindi magamit ang mikropono. Maaari pa ring tapusin ang laro."))
		return
	var samples := capture.get_buffer(frames)
	var sum := 0.0
	for sample in samples:
		sum += sample.length_squared() * 0.5
	var rms := sqrt(sum / maxf(1.0, float(samples.size())))
	_consume_level(rms,delta)

func _consume_level(rms:float,delta:float) -> void:
	mic_level = lerpf(mic_level, rms, 0.35)
	# Samples are discarded after this frame; there is no recorder, file or network sink.
	if calibrating > 0.0:
		calibrating -= delta
		calibration_peak = maxf(calibration_peak, mic_level)
		if calibrating <= 0.0:
			floor_level = calibration_peak
			Session.mic_threshold = clampf(floor_level * 2.5 + 0.018, 0.025, 0.3)
			mic_ready = true
			microphone_status.emit(Story.text("Microphone ready. Use headphones to avoid speaker feedback.", "Handa ang mikropono. Gumamit ng headphones para iwas feedback."))
		return
	if enabled and mic_ready and mic_cooldown <= 0.0:
		var strength := rms_to_strength(mic_level, Session.mic_threshold)
		if strength > 0.0:
			emit_noise(source_position, strength, "microphone")
			mic_cooldown = 0.35
