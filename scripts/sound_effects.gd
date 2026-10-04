extends Node

# Procedural Audio Synthesizer for Retro/Modern Arcade Sounds
# Zero external assets required, crystal-clear sound on all platforms (Android, Windows, iOS, Web)

var drop_player: AudioStreamPlayer
var land_player: AudioStreamPlayer
var perfect_player: AudioStreamPlayer
var game_over_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var align_player: AudioStreamPlayer
var milestone_player: AudioStreamPlayer

var is_muted: bool = false
var align_tick_stream: AudioStreamWAV = null

# Musical scale for ascending combo chimes (Pentatonic Major scale: C5, D5, E5, G5, A5, C6, D6, E6)
const COMBO_FREQUENCIES = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51, 1567.98]

func _ready() -> void:
	drop_player = _create_player()
	land_player = _create_player()
	perfect_player = _create_player()
	game_over_player = _create_player()
	click_player = _create_player()
	align_player = _create_player()
	milestone_player = _create_player()
	
	align_tick_stream = _generate_tone_sweep(1800.0, 1200.0, 0.022, 0.16, "sine")

func _create_player() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = &"Master"
	add_child(p)
	return p

func toggle_mute() -> bool:
	is_muted = !is_muted
	return is_muted

func play_align_tick() -> void:
	if is_muted: return
	if align_tick_stream:
		align_player.stream = align_tick_stream
		align_player.play()

func play_drop() -> void:
	if is_muted: return
	var stream = _generate_tone_sweep(520.0, 180.0, 0.10, 0.42, "sine")
	drop_player.stream = stream
	drop_player.play()

func play_land() -> void:
	if is_muted: return
	# Satisfying physical thump with deep body resonance
	var stream = _generate_tone_sweep(280.0, 70.0, 0.11, 0.65, "triangle")
	land_player.stream = stream
	land_player.play()

func play_perfect(combo: int) -> void:
	if is_muted: return
	var idx = clamp(combo - 1, 0, COMBO_FREQUENCIES.size() - 1)
	var freq = COMBO_FREQUENCIES[idx]
	var stream = _generate_bell_chime(freq, 0.38, 0.65)
	perfect_player.stream = stream
	perfect_player.play()

func play_milestone() -> void:
	if is_muted: return
	var stream = _generate_milestone_fanfare()
	milestone_player.stream = stream
	milestone_player.play()

func play_game_over() -> void:
	if is_muted: return
	var stream = _generate_game_over_sound(0.7)
	game_over_player.stream = stream
	game_over_player.play()

func play_click() -> void:
	if is_muted: return
	var stream = _generate_tone_sweep(600.0, 400.0, 0.05, 0.3, "sine")
	click_player.stream = stream
	click_player.play()

# Generates frequency sweep with exponential decay envelope
func _generate_tone_sweep(start_freq: float, end_freq: float, duration: float, volume: float, wave_type: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2) # 16-bit mono

	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var current_freq: float = lerp(start_freq, end_freq, t)
		var envelope: float = (1.0 - t) * (1.0 - t)
		
		phase += current_freq / float(sample_rate)
		if phase > 1.0:
			phase -= floor(phase)
		
		var sample_val: float = 0.0
		if wave_type == "sine":
			sample_val = sin(phase * TAU)
		elif wave_type == "triangle":
			sample_val = (4.0 * abs(phase - 0.5) - 1.0)
		elif wave_type == "square":
			sample_val = 1.0 if phase < 0.5 else -1.0
		
		var final_val: int = int(clamp(sample_val * envelope * volume * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, final_val)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# Generates harmonic bell chime (fundamental + 2nd + 3rd harmonic)
func _generate_bell_chime(fundamental: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)

	var p1: float = 0.0
	var p2: float = 0.0
	var p3: float = 0.0
	
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var env1: float = exp(-4.0 * t)
		var env2: float = exp(-7.0 * t) * 0.5
		var env3: float = exp(-10.0 * t) * 0.25
		
		p1 = fmod(p1 + fundamental / sample_rate, 1.0)
		p2 = fmod(p2 + (fundamental * 2.00) / sample_rate, 1.0)
		p3 = fmod(p3 + (fundamental * 3.01) / sample_rate, 1.0)
		
		var sample_val: float = (sin(p1 * TAU) * env1) + (sin(p2 * TAU) * env2) + (sin(p3 * TAU) * env3)
		var final_val: int = int(clamp(sample_val * volume * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, final_val)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _generate_game_over_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)

	var p1: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / float(num_samples)
		var freq: float = lerp(220.0, 65.0, t * t)
		var env: float = (1.0 - t)
		
		p1 = fmod(p1 + freq / sample_rate, 1.0)
		var sample_val: float = (sin(p1 * TAU) * 0.6) + ((4.0 * abs(p1 - 0.5) - 1.0) * 0.4)
		var final_val: int = int(clamp(sample_val * env * 0.5 * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, final_val)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _generate_milestone_fanfare() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.52
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	
	var freqs = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	var seg: int = int(num_samples / freqs.size())
	var phase: float = 0.0
	
	for i in range(num_samples):
		var note_idx: int = min(int(i / seg), freqs.size() - 1)
		var freq: float = freqs[note_idx]
		var t_note: float = float(i % seg) / float(seg)
		var env: float = exp(-4.0 * t_note)
		phase = fmod(phase + freq / float(sample_rate), 1.0)
		var val: float = sin(phase * TAU) * env * 0.55
		data.encode_s16(i * 2, int(clamp(val * 32767.0, -32768.0, 32767.0)))
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

