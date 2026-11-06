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
var zen_bgm_player: AudioStreamPlayer
var zen_bgm_tween: Tween = null
var zen_ambient_stream: AudioStreamWAV = null

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
	zen_bgm_player = _create_player()
	
	align_tick_stream = _generate_tone_sweep(1800.0, 1200.0, 0.022, 0.16, "sine")

func _create_player() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = &"Master"
	add_child(p)
	return p

func toggle_mute() -> bool:
	is_muted = !is_muted
	if is_instance_valid(zen_bgm_player) and zen_bgm_player.playing:
		zen_bgm_player.volume_db = -80.0 if is_muted else -8.0
	return is_muted

func start_zen_ambient(fade_duration: float = 1.0) -> void:
	if not zen_ambient_stream:
		zen_ambient_stream = _generate_lofi_ambient_track()
	
	if zen_bgm_tween:
		zen_bgm_tween.kill()
	
	if not is_instance_valid(zen_bgm_player):
		return
		
	zen_bgm_player.stream = zen_ambient_stream
	if not zen_bgm_player.playing:
		zen_bgm_player.play()
	
	var target_vol = -8.0 if not is_muted else -80.0
	zen_bgm_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zen_bgm_player.volume_db = -40.0
	zen_bgm_tween.tween_property(zen_bgm_player, "volume_db", target_vol, fade_duration)

func stop_zen_ambient(fade_duration: float = 0.8) -> void:
	if not is_instance_valid(zen_bgm_player) or not zen_bgm_player.playing:
		return
	if zen_bgm_tween:
		zen_bgm_tween.kill()
	zen_bgm_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zen_bgm_tween.tween_property(zen_bgm_player, "volume_db", -60.0, fade_duration)
	zen_bgm_tween.tween_callback(func():
		if is_instance_valid(zen_bgm_player):
			zen_bgm_player.stop()
	)

func is_zen_ambient_playing() -> bool:
	return is_instance_valid(zen_bgm_player) and zen_bgm_player.playing

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

func _generate_lofi_ambient_track() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 16.0 # 4 bars of 4 seconds each (60 BPM)
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	
	# 4 rich neo-soul / lo-fi chill chords:
	# 1. Cmaj9 (C3, G3, B3, E4, D5)
	# 2. Am9 (A2, E3, G3, C4, B4)
	# 3. Fmaj7#11 (F2, C3, E3, A3, B4)
	# 4. G13 / Em9 (G2, D3, F3, B3, E4)
	var chord_progressions = [
		[130.81, 196.00, 246.94, 329.63, 587.33],
		[110.00, 164.81, 196.00, 261.63, 493.88],
		[87.31, 130.81, 164.81, 220.00, 493.88],
		[98.00, 146.83, 174.61, 246.94, 329.63]
	]
	
	# Gentle lo-fi melodic sparkle notes on top
	var melody_notes = [
		{"time": 1.5, "freq": 659.25, "dur": 1.8}, # E5
		{"time": 3.0, "freq": 587.33, "dur": 1.5}, # D5
		{"time": 5.5, "freq": 523.25, "dur": 1.8}, # C5
		{"time": 7.0, "freq": 493.88, "dur": 1.5}, # B4
		{"time": 9.5, "freq": 587.33, "dur": 1.8}, # D5
		{"time": 11.0, "freq": 659.25, "dur": 1.5}, # E5
		{"time": 13.5, "freq": 493.88, "dur": 1.8}, # B4
		{"time": 15.0, "freq": 392.00, "dur": 1.5}  # G4
	]
	
	var chord_duration = 4.0
	
	# Phase accumulators for up to 5 voices per chord
	var chord_phases = [0.0, 0.0, 0.0, 0.0, 0.0]
	var chord_sub_phases = [0.0, 0.0, 0.0, 0.0, 0.0]
	
	# Simple 1-pole filter state for warm lo-fi tape sound
	var lp_state: float = 0.0
	var filter_coeff: float = 0.18 # Low-pass warmth (~1.5kHz cutoff)
	
	for i in range(num_samples):
		var global_t = float(i) / float(sample_rate)
		var chord_idx = int(global_t / chord_duration) % chord_progressions.size()
		var chord = chord_progressions[chord_idx]
		var local_t = fmod(global_t, chord_duration)
		
		# Chord envelope: gentle attack, warm sustained bloom, smooth decay
		var att = min(local_t / 0.45, 1.0)
		var chord_env = att * (0.65 + 0.35 * exp(-0.6 * local_t))
		
		# Tape flutter / wow (slow 0.4 Hz pitch drift)
		var flutter = sin(global_t * 0.4 * TAU) * 0.003
		
		var sample_sum: float = 0.0
		
		# 1. Warm Rhodes / Electric Piano chord synthesis
		for v in range(chord.size()):
			var base_freq = chord[v] * (1.0 + flutter)
			chord_phases[v] = fmod(chord_phases[v] + base_freq / float(sample_rate), 1.0)
			# Subtle chorused second oscillator
			var detune_freq = (chord[v] + 0.55) * (1.0 + flutter)
			chord_sub_phases[v] = fmod(chord_sub_phases[v] + detune_freq / float(sample_rate), 1.0)
			
			# Pure warm sine + soft bell overtone (3x fundamental at lower volume)
			var tone1 = sin(chord_phases[v] * TAU)
			var tone2 = sin(chord_sub_phases[v] * TAU) * 0.4
			var tone3 = sin(fmod(chord_phases[v] * 3.0, 1.0) * TAU) * 0.12 * exp(-1.5 * local_t)
			var voice_val = (tone1 * 0.6 + tone2 * 0.3 + tone3 * 0.1) * (0.24 if v == 0 else 0.15)
			sample_sum += voice_val
		
		sample_sum *= chord_env
		
		# 2. Sub Bass drone (warm foundation on root note)
		var root_freq = (chord[0] * 0.5) * (1.0 + flutter) # 1 octave below
		var bass_phase = fmod(global_t * root_freq, 1.0)
		var bass_val = sin(bass_phase * TAU) * 0.22 * att
		sample_sum += bass_val
		
		# 3. Melodic ambient sparkle drops
		for m in melody_notes:
			var m_start: float = m["time"]
			var m_dur: float = m["dur"]
			if global_t >= m_start and global_t < (m_start + m_dur):
				var m_t = global_t - m_start
				var m_env = exp(-3.2 * m_t) * 0.14
				var m_phase = fmod(m_t * m["freq"] * (1.0 + flutter), 1.0)
				var m_bell = sin(m_phase * TAU) + sin(fmod(m_phase * 2.0, 1.0) * TAU) * 0.25
				sample_sum += m_bell * m_env
		
		# 4. Lo-fi Vinyl / Tape Warmth Ambient Texture
		var noise = (randf() * 2.0 - 1.0) * 0.008
		# Occasional vinyl crackle tick
		if randf() < 0.0004:
			noise += (randf() * 2.0 - 1.0) * 0.04
		sample_sum += noise
		
		# 5. Low-Pass Filter (Lo-Fi Warmth)
		lp_state = lp_state + filter_coeff * (sample_sum - lp_state)
		
		# 6. Soft Lo-Fi Saturation (Tube/Tape compression)
		var saturated = tanh(lp_state * 1.3) * 0.75
		
		var final_val: int = int(clamp(saturated * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, final_val)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	wav.data = data
	return wav

