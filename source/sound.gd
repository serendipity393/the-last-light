extends Node
var music: AudioStreamPlayer
var rain: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var sample_rate := 22050

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	rain = AudioStreamPlayer.new()
	add_child(rain)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		effects.append(p)
	rain.stream = make_rain()
	rain.volume_db = -18
	rain.play()
	chapter(0)

func wav(data: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = sample_rate
	s.data = data
	if looped:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = data.size() / 2
	return s

func make_rain() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(sample_rate * 6 * 2)
	var filtered := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in sample_rate * 6:
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.25)
		var v := filtered * (0.48 + 0.12 * sin(float(i) / sample_rate * TAU / 6.0))
		data.encode_s16(i * 2, int(v * 24000))
	return wav(data, true)

func chapter(index: int) -> void:
	var data := PackedByteArray()
	var duration := 16.0
	data.resize(int(sample_rate * duration) * 2)
	var roots := [130.81, 146.83, 110.0, 164.81]
	var root: float = roots[index % 4]
	var notes := [1.0, 1.5, 2.0, 1.25, 1.5, 2.25, 2.0, 1.5]
	for i in int(sample_rate * duration):
		var t := float(i) / sample_rate
		var beat := fmod(t, 2.0)
		var n: float = notes[int(t / 2.0) % 8]
		var pad := (sin(TAU * root * t) + 0.4 * sin(TAU * root * 1.5 * t) + 0.3 * sin(TAU * root * 2.0 * t)) * 0.055
		var bell := sin(TAU * root * n * 2.0 * t) * exp(-beat * 2.8) * 0.14
		var fade := minf(1.0, minf(t, duration - t) * 2.0)
		data.encode_s16(i * 2, int((pad + bell) * fade * 29000))
	music.stream = wav(data, true)
	music.volume_db = -13
	music.play()

func play_fx(kind: String) -> void:
	var duration := 0.2
	var freq := 440.0
	match kind:
		"step": duration = 0.065; freq = 110.0
		"success": duration = 0.8; freq = 660.0
		"alarm": duration = 0.6; freq = 120.0
		"echo": duration = 0.5; freq = 330.0
		"lure": duration = 0.5; freq = 880.0
		"talk": duration = 0.12; freq = 520.0
	var data := PackedByteArray()
	data.resize(int(duration * sample_rate) * 2)
	for i in int(duration * sample_rate):
		var t := float(i) / sample_rate
		var f := freq * (1.0 + t * 0.3)
		var v := sin(TAU * f * t) * exp(-t * 8.0) * 0.22
		if kind == "step": v = (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.15
		data.encode_s16(i * 2, int(v * 25000))
	for p in effects:
		if not p.playing:
			p.stream = wav(data, false)
			p.volume_db = -8
			p.play()
			return
