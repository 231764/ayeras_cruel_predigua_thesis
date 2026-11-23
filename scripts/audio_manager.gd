extends Node

# Self-contained procedural Audio & Settings Manager for Paldo.
# Synthesizes warm, noise-free acoustic UI & feedback SFX (marimba, kalimba,
# silky Rhodes, crisp bells, droplet pops) normalized across 4 balanced
# dynamic loudness tiers, plus a cozy 64-step Rhodes/Kalimba lo-fi BGM loop.

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 0.85
var music_volume: float = 0.55
var sfx_volume: float = 0.85
var music_muted: bool = false
var sfx_muted: bool = false
var autoplay_speed_index: int = 1 # 0 = Normal (0.35s), 1 = Fast (0.20s), 2 = Turbo (0.09s)

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
var _sfx_cache: Dictionary = {}
var _sfx_last_played_ms: Dictionary = {}
var _day_tick_toggle: bool = false

const SAMPLE_RATE := 22050
const AUTOPLAY_SPEEDS := [0.35, 0.20, 0.09]
const AUTOPLAY_LABELS := ["Normal (0.35s/day)", "Fast (0.20s/day)", "Turbo (0.09s/day)"]
const PITCH_VARIANCE_SFX := ["click", "toggle", "paper", "hover", "chat_pop", "coin"]
const SFX_COOLDOWNS_MS := {
	"hover": 110,
	"day_tick": 125,
	"click": 45,
	"toggle": 45,
	"paper": 65,
	"tool_open": 90,
	"tool_close": 90,
	"coin": 55,
	"toast_slide": 180
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_setup_players()
	_prebake_sfx()
	_start_bgm()
	_apply_volumes()

func get_autoplay_wait_time() -> float:
	return AUTOPLAY_SPEEDS[clamp(autoplay_speed_index, 0, AUTOPLAY_SPEEDS.size() - 1)]

func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	add_child(_bgm_player)
	
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		add_child(p)
		_sfx_players.append(p)

func _apply_volumes() -> void:
	if _bgm_player:
		var eff_bgm: float = 0.0 if music_muted else (master_volume * music_volume * 0.38)
		_bgm_player.volume_db = linear_to_db(max(0.0001, eff_bgm)) if eff_bgm > 0.001 else -80.0
		_bgm_player.stream_paused = (eff_bgm <= 0.001)
	var eff_sfx: float = 0.0 if sfx_muted else (master_volume * sfx_volume)
	var sfx_db: float = linear_to_db(max(0.0001, eff_sfx)) if eff_sfx > 0.001 else -80.0
	for p in _sfx_players:
		p.volume_db = sfx_db

func set_master_volume(val: float) -> void:
	master_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_music_volume(val: float) -> void:
	music_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_sfx_volume(val: float) -> void:
	sfx_volume = clamp(val, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_volumes()
	save_settings()

func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_apply_volumes()
	save_settings()

func set_autoplay_speed(idx: int) -> void:
	autoplay_speed_index = clamp(idx, 0, AUTOPLAY_SPEEDS.size() - 1)
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("audio", "sfx_muted", sfx_muted)
	cfg.set_value("gameplay", "autoplay_speed_index", autoplay_speed_index)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master_volume", 0.85))
		music_volume = float(cfg.get_value("audio", "music_volume", 0.55))
		sfx_volume = float(cfg.get_value("audio", "sfx_volume", 0.85))
		music_muted = bool(cfg.get_value("audio", "music_muted", false))
		sfx_muted = bool(cfg.get_value("audio", "sfx_muted", false))
		autoplay_speed_index = int(cfg.get_value("gameplay", "autoplay_speed_index", 1))

func play_sfx(sfx_name: String) -> void:
	if sfx_name == "":
		return
	var p_scale: float = 1.0
	if sfx_name == "day_tick":
		# Gentle alternating tick/tock desk-clock rhythm across consecutive days
		_day_tick_toggle = not _day_tick_toggle
		p_scale = 1.045 if _day_tick_toggle else 0.945
	elif sfx_name in PITCH_VARIANCE_SFX:
		p_scale = randf_range(0.97, 1.03)
	play_sfx_pitched(sfx_name, p_scale)

func play_sfx_pitched(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if sfx_name == "":
		return
	if sfx_muted or master_volume <= 0.001 or sfx_volume <= 0.001:
		return
	if not _sfx_cache.has(sfx_name):
		return
	var now_ms: int = Time.get_ticks_msec()
	var cooldown: int = int(SFX_COOLDOWNS_MS.get(sfx_name, 0))
	if cooldown > 0:
		var last_ms: int = int(_sfx_last_played_ms.get(sfx_name, -99999))
		if (now_ms - last_ms) < cooldown:
			return
	_sfx_last_played_ms[sfx_name] = now_ms
	if DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = _acquire_sfx_player()
	player.pitch_scale = clamp(pitch_scale, 0.5, 2.0)
	player.stream = _sfx_cache[sfx_name]
	player.play()

func _acquire_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	var chosen: AudioStreamPlayer = _sfx_players[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_players.size()
	return chosen

# ==========================================
# PURE NOISE-FREE ACOUSTIC SYNTHESIS & NORMALIZER
# ==========================================

func _encode_wav(buf: PackedFloat32Array, target_peak: float) -> AudioStreamWAV:
	var n: int = buf.size()
	var max_abs: float = 0.0
	for i in range(n):
		var a: float = absf(buf[i])
		if a > max_abs:
			max_abs = a
	var gain: float = (target_peak / max_abs) if max_abs > 0.0001 else 0.0
	var fade_in: int = min(n, int(0.0025 * float(SAMPLE_RATE)))
	var fade_out: int = min(n, int(0.006 * float(SAMPLE_RATE)))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var v: float = buf[i] * gain
		if i < fade_in and fade_in > 0:
			v *= float(i) / float(fade_in)
		if i >= (n - fade_out) and fade_out > 0:
			v *= float(n - 1 - i) / float(fade_out)
		var pcm: int = int(clamp(v * 32767.0, -32767.0, 32767.0))
		data.encode_s16(i * 2, pcm)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _mix_acoustic_note(buf: PackedFloat32Array, start_sec: float, freq: float, dur_sec: float, decay: float, timbre: String, amp: float, attack_sec: float = 0.005) -> void:
	var s0: int = int(start_sec * float(SAMPLE_RATE))
	var count: int = max(1, int(dur_sec * float(SAMPLE_RATE)))
	var tail_samples: int = max(1, int(0.012 * float(SAMPLE_RATE)))
	for i in range(count):
		var idx: int = s0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = TAU * freq * t
		var attack: float = minf(1.0, t / maxf(0.001, attack_sec))
		var tail_fade: float = minf(1.0, float(count - i) / float(tail_samples))
		var env: float = exp(-decay * t) * attack * tail_fade
		var val: float = 0.0
		match timbre:
			"kalimba":
				val = sin(p) * 0.86 + sin(p * 2.0) * 0.19 * exp(-decay * 2.2 * t) + sin(p * 3.0) * 0.06 * exp(-28.0 * t)
			"rhodes":
				var tine: float = sin(p * 2.0) * 0.20 * exp(-16.0 * t) + sin(p * 3.0) * 0.07 * exp(-24.0 * t)
				var trem: float = 0.94 + 0.06 * sin(TAU * 4.2 * t)
				val = (sin(p) * 0.88 + tine) * trem
			"marimba":
				val = sin(p) * 0.90 + sin(p * 4.0) * 0.20 * exp(-26.0 * t)
			"bell":
				val = sin(p) * 0.80 + sin(p * 2.0) * 0.24 * exp(-12.0 * t) + sin(p * 3.0) * 0.10 * exp(-20.0 * t)
			_:
				val = sin(p)
		buf[idx] += val * env * amp

func _synth_glide_pop(start_hz: float, end_hz: float, dur_sec: float, target_peak: float, harmonic_mix: float = 0.10) -> AudioStreamWAV:
	var count: int = max(1, int(dur_sec * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var norm: float = float(i) / float(count)
		var freq: float = lerpf(start_hz, end_hz, pow(norm, 0.72))
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = sin(PI * norm) * exp(-2.2 * norm)
		buf[i] = (sin(phase) + harmonic_mix * sin(phase * 2.0)) * env
	return _encode_wav(buf, target_peak)

func _synth_layered_chord_sfx(events: Array, total_dur: float, timbre: String, target_peak: float, attack_sec: float = 0.005) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(max(1, int(total_dur * float(SAMPLE_RATE))))
	for ev in events:
		var st: float = float(ev[0])
		var hz: float = float(ev[1])
		var ndur: float = float(ev[2])
		var dec: float = float(ev[3])
		var g: float = float(ev[4]) if ev.size() > 4 else 1.0
		var note_timbre: String = str(ev[5]) if ev.size() > 5 else timbre
		_mix_acoustic_note(buf, st, hz, ndur, dec, note_timbre, g, attack_sec)
	return _encode_wav(buf, target_peak)

func _prebake_sfx() -> void:
	# ==========================================
	# TIER 1: SUBTLE AMBIENT / MICRO-TACTILE (0.15 - 0.20)
	# ==========================================
	# hover: soft muted kalimba murmur (ONLY on physical desk props that visually highlight)
	_sfx_cache["hover"] = _synth_layered_chord_sfx([
		[0.00, 392.00, 0.055, 38.0, 1.0]
	], 0.06, "sine", 0.15, 0.004)
	# day_tick: warm damped marimba desk-clock step (alternates tick/tock pitch on each day)
	_sfx_cache["day_tick"] = _synth_layered_chord_sfx([
		[0.00, 493.88, 0.075, 29.0, 0.90],
		[0.00, 246.94, 0.055, 38.0, 0.34, "sine"]
	], 0.085, "marimba", 0.18, 0.002)
	# paper: brisk light double-flutter marimba tap for switching budget envelopes
	_sfx_cache["paper"] = _synth_layered_chord_sfx([
		[0.00, 622.25, 0.045, 36.0, 0.55],
		[0.024, 739.99, 0.070, 26.0, 1.00]
	], 0.10, "marimba", 0.20, 0.002)

	# ==========================================
	# TIER 2: PRIMARY UI NAVIGATION (0.23 - 0.25)
	# ==========================================
	# click: crisp warm tactile wooden-marimba key-press (distinct from bubbly chat_pop)
	_sfx_cache["click"] = _synth_layered_chord_sfx([
		[0.00, 587.33, 0.065, 32.0, 0.92],
		[0.00, 293.66, 0.045, 42.0, 0.42, "sine"]
	], 0.075, "marimba", 0.25, 0.0018)
	# toggle: snappy tight dual wooden switch (tabs, filters, routine dropdowns, phone apps)
	_sfx_cache["toggle"] = _synth_layered_chord_sfx([
		[0.00, 523.25, 0.045, 38.0, 0.78],
		[0.024, 783.99, 0.060, 30.0, 1.00]
	], 0.09, "marimba", 0.23, 0.002)
	# tool_open: warm grounded upward marimba bloom (ALL desk tools + Goal Tracker)
	_sfx_cache["tool_open"] = _synth_layered_chord_sfx([
		[0.00, 440.00, 0.12, 18.0, 0.85],
		[0.042, 587.33, 0.14, 15.0, 1.00]
	], 0.19, "marimba", 0.25, 0.004)
	# tool_close: calm settling downward mirror of tool_open (ALL desk tools + Goal Tracker)
	_sfx_cache["tool_close"] = _synth_layered_chord_sfx([
		[0.00, 587.33, 0.10, 19.0, 0.85],
		[0.040, 440.00, 0.13, 16.0, 1.00]
	], 0.18, "marimba", 0.23, 0.004)
	# chat_pop: clean buoyant messenger water-droplet bubble pop
	_sfx_cache["chat_pop"] = _synth_glide_pop(360.0, 940.0, 0.056, 0.25, 0.07)
	# toast_slide: polite airy two-note ascending shimmer for top banners
	_sfx_cache["toast_slide"] = _synth_layered_chord_sfx([
		[0.00, 783.99, 0.15, 14.0, 0.80, "rhodes"],
		[0.058, 1174.66, 0.22, 11.5, 0.95, "bell"]
	], 0.29, "bell", 0.23, 0.005)
	# soft_chime: genuinely soothing warm Rhodes major-7th swell (Rest / Self-Care)
	_sfx_cache["soft_chime"] = _synth_layered_chord_sfx([
		[0.00, 523.25, 0.42, 5.5, 0.74],
		[0.045, 659.25, 0.42, 5.5, 0.78],
		[0.090, 783.99, 0.44, 5.2, 0.80],
		[0.135, 987.77, 0.46, 5.0, 0.72]
	], 0.62, "rhodes", 0.24, 0.010)

	# ==========================================
	# TIER 3: GAMEPLAY FEEDBACK & EVENTS (0.27 - 0.31)
	# ==========================================
	# spend: warm grounded descending marimba two-step (normal bills/spending/withdrawal)
	_sfx_cache["spend"] = _synth_layered_chord_sfx([
		[0.00, 392.00, 0.13, 16.0, 0.92],
		[0.062, 293.66, 0.17, 13.5, 0.96]
	], 0.24, "marimba", 0.27, 0.003)
	# stat_down: soft sympathetic descending 3-note Rhodes sigh (stress/happy/social loss)
	_sfx_cache["stat_down"] = _synth_layered_chord_sfx([
		[0.00, 329.63, 0.16, 13.0, 0.88],
		[0.065, 293.66, 0.17, 12.5, 0.90],
		[0.130, 261.63, 0.22, 10.5, 0.96]
	], 0.36, "rhodes", 0.27, 0.006)
	# stat_up: cheerful ascending 3-note kalimba sparkle (positive free stat gains)
	_sfx_cache["stat_up"] = _synth_layered_chord_sfx([
		[0.00, 659.25, 0.14, 14.0, 0.82],
		[0.048, 783.99, 0.16, 13.0, 0.90],
		[0.096, 1046.50, 0.22, 10.5, 1.00]
	], 0.33, "kalimba", 0.29, 0.004)
	# event_pop: curious desk-card marimba prompt (everyday routine/family events)
	_sfx_cache["event_pop"] = _synth_layered_chord_sfx([
		[0.00, 587.33, 0.16, 14.0, 0.88],
		[0.060, 783.99, 0.20, 12.0, 0.96]
	], 0.27, "marimba", 0.27, 0.003)
	# weekly_open: cozy end-of-week warm chord cadence (ALL 4 weeks consistently)
	_sfx_cache["weekly_open"] = _synth_layered_chord_sfx([
		[0.00, 261.63, 0.42, 6.2, 0.55, "rhodes"],
		[0.00, 392.00, 0.32, 7.5, 0.82, "kalimba"],
		[0.068, 493.88, 0.32, 7.2, 0.88, "kalimba"],
		[0.136, 587.33, 0.38, 6.4, 0.96, "kalimba"]
	], 0.54, "kalimba", 0.28, 0.005)
	# error_bump: friendly low rounded double-boop (unread notifications / blocked action)
	_sfx_cache["error_bump"] = _synth_layered_chord_sfx([
		[0.00, 220.00, 0.080, 22.0, 0.95],
		[0.065, 174.61, 0.115, 18.0, 1.00]
	], 0.19, "sine", 0.28, 0.003)
	# phone_ding: classic friendly two-tone smartphone chime
	_sfx_cache["phone_ding"] = _synth_layered_chord_sfx([
		[0.00, 880.00, 0.22, 11.5, 0.88],
		[0.080, 1318.51, 0.30, 9.2, 1.00]
	], 0.40, "bell", 0.29, 0.004)
	# bill_due: grounded low Rhodes bill reminder (Monthly Bill Settlement / taking a loan)
	_sfx_cache["bill_due"] = _synth_layered_chord_sfx([
		[0.00, 293.66, 0.20, 10.5, 0.90],
		[0.085, 261.63, 0.20, 10.0, 0.92],
		[0.170, 220.00, 0.28, 8.2, 1.00]
	], 0.46, "rhodes", 0.29, 0.005)
	# opportunity: inspiring ascending 4-note kalimba roll (jobs, side hustle, starting run)
	_sfx_cache["opportunity"] = _synth_layered_chord_sfx([
		[0.00, 587.33, 0.24, 9.5, 0.80],
		[0.056, 739.99, 0.26, 9.0, 0.86],
		[0.112, 880.00, 0.28, 8.5, 0.92],
		[0.168, 1318.51, 0.36, 7.2, 1.00]
	], 0.54, "kalimba", 0.30, 0.004)
	# coin: iconic joyful bright peso coin ring (B5 -> E6 + octave sparkle)
	_sfx_cache["coin"] = _synth_layered_chord_sfx([
		[0.00, 987.77, 0.13, 16.0, 0.88],
		[0.065, 1318.51, 0.28, 9.5, 1.00],
		[0.065, 2637.02, 0.14, 18.0, 0.22, "sine"]
	], 0.36, "bell", 0.30, 0.003)
	# alert: calm but unmistakable warm low Rhodes warning (emergencies / crisis / game over)
	_sfx_cache["alert"] = _synth_layered_chord_sfx([
		[0.00, 164.81, 0.26, 8.5, 0.50, "sine"],
		[0.00, 329.63, 0.24, 9.2, 0.90, "rhodes"],
		[0.110, 233.08, 0.34, 7.5, 1.00, "rhodes"]
	], 0.46, "rhodes", 0.31, 0.005)

	# ==========================================
	# TIER 4: HERO REWARDS & CELEBRATIONS (0.34 - 0.37)
	# ==========================================
	# cash_register: crisp two-stage wooden latch + sparkling major bell ka-ching!
	_sfx_cache["cash_register"] = _synth_layered_chord_sfx([
		[0.00, 246.94, 0.042, 42.0, 0.72, "marimba"],
		[0.00, 659.25, 0.032, 50.0, 0.42, "marimba"],
		[0.052, 1046.50, 0.30, 9.0, 0.80, "bell"],
		[0.074, 1318.51, 0.32, 8.6, 0.86, "bell"],
		[0.096, 1567.98, 0.34, 8.2, 0.90, "bell"],
		[0.118, 2093.00, 0.36, 8.0, 0.85, "bell"]
	], 0.50, "bell", 0.34, 0.002)
	# achievement: radiant overlapping 4-note bell chime
	_sfx_cache["achievement"] = _synth_layered_chord_sfx([
		[0.00, 587.33, 0.34, 7.0, 0.84],
		[0.070, 739.99, 0.36, 6.6, 0.90],
		[0.140, 880.00, 0.38, 6.2, 0.94],
		[0.210, 1174.66, 0.46, 5.2, 1.00]
	], 0.70, "bell", 0.34, 0.005)
	# payday: joyful warm overlapping Rhodes salary fanfare (exclusive to Sahod Day)
	_sfx_cache["payday"] = _synth_layered_chord_sfx([
		[0.00, 523.25, 0.34, 6.4, 0.84],
		[0.066, 659.25, 0.34, 6.2, 0.88],
		[0.132, 783.99, 0.36, 6.0, 0.92],
		[0.198, 987.77, 0.38, 5.8, 0.88],
		[0.264, 1046.50, 0.46, 5.2, 1.00]
	], 0.74, "rhodes", 0.35, 0.005)
	# milestone: warm triumphant 5-note kalimba arpeggio
	_sfx_cache["milestone"] = _synth_layered_chord_sfx([
		[0.00, 523.25, 0.34, 6.8, 0.84],
		[0.066, 659.25, 0.36, 6.5, 0.88],
		[0.132, 783.99, 0.38, 6.2, 0.92],
		[0.198, 880.00, 0.38, 6.0, 0.92],
		[0.264, 1046.50, 0.46, 5.2, 1.00]
	], 0.74, "kalimba", 0.35, 0.005)
	# grade_s: grand warm celebratory Rhodes chord flourish (Grade S / Full Paldo)
	_sfx_cache["grade_s"] = _synth_layered_chord_sfx([
		[0.00, 523.25, 0.44, 5.6, 0.80],
		[0.062, 659.25, 0.44, 5.5, 0.84],
		[0.124, 783.99, 0.46, 5.3, 0.88],
		[0.186, 987.77, 0.48, 5.1, 0.88],
		[0.248, 1174.66, 0.50, 4.9, 0.92],
		[0.310, 1318.51, 0.56, 4.5, 1.00]
	], 0.88, "rhodes", 0.37, 0.006)

func _start_bgm() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Cozy 64-step (~20.5s) 2-section Rhodes/Kalimba lo-fi loop:
	# Section A: Cmaj7 -> Am7 -> Fmaj7 -> G6
	# Section B: Em7 -> Am7 -> Dm7 -> G7sus4
	var melody := [
		# Section A (32 steps)
		523.25, 0.0, 659.25, 783.99, 659.25, 0.0, 587.33, 523.25,
		440.00, 0.0, 523.25, 659.25, 587.33, 0.0, 392.00, 0.0,
		523.25, 0.0, 659.25, 880.00, 783.99, 0.0, 659.25, 587.33,
		440.00, 523.25, 587.33, 659.25, 523.25, 0.0, 0.0, 0.0,
		# Section B (32 steps)
		783.99, 0.0, 659.25, 587.33, 523.25, 0.0, 659.25, 0.0,
		659.25, 0.0, 523.25, 440.00, 523.25, 0.0, 587.33, 0.0,
		587.33, 0.0, 659.25, 783.99, 880.00, 0.0, 783.99, 659.25,
		587.33, 523.25, 587.33, 659.25, 587.33, 0.0, 392.00, 0.0
	]
	var bass := [
		# Cmaj7 / G - Am7 / G - Fmaj7 / C - Dm7 / G -> Section A
		130.81, 0.0, 0.0, 0.0, 196.00, 0.0, 0.0, 0.0,
		110.00, 0.0, 0.0, 0.0, 164.81, 0.0, 0.0, 0.0,
		174.61, 0.0, 0.0, 0.0, 130.81, 0.0, 0.0, 0.0,
		146.83, 0.0, 0.0, 0.0, 196.00, 0.0, 0.0, 0.0,
		# Em7 - Am7 - Dm7 - G7sus4 -> Section B
		164.81, 0.0, 0.0, 0.0, 123.47, 0.0, 0.0, 0.0,
		110.00, 0.0, 0.0, 0.0, 164.81, 0.0, 0.0, 0.0,
		146.83, 0.0, 0.0, 0.0, 174.61, 0.0, 0.0, 0.0,
		196.00, 0.0, 0.0, 0.0, 146.83, 0.0, 196.00, 0.0
	]
	# Soft warm rhodes dyad pad chords on bar starts (8 bars total)
	var bar_chords := [
		[261.63, 329.63, 392.00], # Cmaj
		[220.00, 261.63, 329.63], # Am
		[174.61, 220.00, 261.63], # Fmaj
		[196.00, 246.94, 293.66], # Gmaj
		[164.81, 196.00, 246.94], # Em
		[220.00, 261.63, 329.63], # Am
		[174.61, 220.00, 293.66], # Dm7
		[196.00, 261.63, 293.66]  # G7sus4
	]
	var step_dur := 0.32
	var samples_per_step := int(step_dur * float(SAMPLE_RATE))
	var bar_samples := samples_per_step * 8
	var total_samples := melody.size() * samples_per_step
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(melody.size()):
		var mf: float = float(melody[i])
		var bf: float = float(bass[i])
		var bar_idx: int = int(i / 8)
		var bar_step_offset: int = (i % 8) * samples_per_step
		var chord: Array = bar_chords[bar_idx]
		for s in range(samples_per_step):
			var idx := i * samples_per_step + s
			var t := float(s) / float(SAMPLE_RATE)
			var bar_t := float(bar_step_offset + s) / float(SAMPLE_RATE)
			var bar_dur := float(bar_samples) / float(SAMPLE_RATE)
			var val := 0.0
			# Gentle kalimba lead
			if mf > 0.0:
				var m_env: float = exp(-7.2 * t) * minf(1.0, t / 0.008)
				val += (sin(TAU * mf * t) + 0.14 * sin(TAU * mf * 2.0 * t)) * m_env * 0.15
			# Warm pluck bass
			if bf > 0.0:
				var b_env: float = exp(-3.2 * t) * minf(1.0, t / 0.015)
				val += sin(TAU * bf * t) * b_env * 0.13
			# Soft Rhodes chord pad (smooth swell + tail across each 8-step bar)
			var pad_fade_out := clampf((bar_dur - bar_t) / 0.18, 0.0, 1.0)
			var pad_env := minf(1.0, bar_t / 0.12) * exp(-0.85 * bar_t) * pad_fade_out
			for cf in chord:
				val += sin(TAU * float(cf) * bar_t) * pad_env * 0.032
			var pcm := int(clamp(val * 32767.0, -32767.0, 32767.0))
			data.encode_s16(idx * 2, pcm)
			
	var bgm := AudioStreamWAV.new()
	bgm.format = AudioStreamWAV.FORMAT_16_BITS
	bgm.mix_rate = SAMPLE_RATE
	bgm.stereo = false
	bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm.loop_begin = 0
	bgm.loop_end = total_samples
	bgm.data = data
	_bgm_player.stream = bgm
	_bgm_player.play()
