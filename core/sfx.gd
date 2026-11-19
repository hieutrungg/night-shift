class_name Sfx
extends RefCounted
## Sound effects synthesised in code, so the MVP needs no audio files or
## licences. Each sound is built once (on first use) and cached.
## Swap any of these for a real recording later by returning a loaded stream.

const MIX_RATE: int = 22050
const MAX_AMPLITUDE: float = 32767.0
## Fixed seed: the same noise on every machine and every run.
const NOISE_SEED: int = 1337

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


static func footstep() -> AudioStreamWAV:
	return _cached(&"footstep", _make_footstep)


static func door_creak() -> AudioStreamWAV:
	return _cached(&"door_creak", _make_door_creak)


static func pickup() -> AudioStreamWAV:
	return _cached(&"pickup", _make_pickup)


static func thud() -> AudioStreamWAV:
	return _cached(&"thud", _make_thud)


static func deposit() -> AudioStreamWAV:
	return _cached(&"deposit", _make_deposit)


static func horn() -> AudioStreamWAV:
	return _cached(&"horn", _make_horn)


static func beep() -> AudioStreamWAV:
	return _cached(&"beep", _make_beep)


static func death_sting() -> AudioStreamWAV:
	return _cached(&"death_sting", _make_death_sting)


## Looping.
static func mannequin_scrape() -> AudioStreamWAV:
	return _cached(&"mannequin_scrape", _make_mannequin_scrape)


## Looping.
static func ambience() -> AudioStreamWAV:
	return _cached(&"ambience", _make_ambience)


## Drops the cached streams (the level calls this when it unloads), so nothing
## is left alive at exit.
static func clear_cache() -> void:
	_cache.clear()


## Plays a one-shot sound at a world position; the player frees itself.
static func play_at(parent: Node, stream: AudioStream, at: Vector3, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _cached(key: StringName, maker: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		var stream: AudioStreamWAV = maker.call()
		_cache[key] = stream
	return _cache[key]


static func _make_footstep() -> AudioStreamWAV:
	var rng := _rng()
	var samples := PackedFloat32Array()
	samples.resize(int(0.09 * MIX_RATE))
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.18
		samples[i] = (low * 2.2 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 45.0)
	return _to_wav(samples, false)


static func _make_door_creak() -> AudioStreamWAV:
	var rng := _rng()
	var samples := PackedFloat32Array()
	samples.resize(int(0.7 * MIX_RATE))
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		# A wobbling sawtooth reads as wood/hinge friction.
		var pitch := 110.0 + 35.0 * sin(TAU * 3.0 * t) + rng.randf_range(-6.0, 6.0)
		phase = fmod(phase + pitch / MIX_RATE, 1.0)
		low += ((phase * 2.0 - 1.0) - low) * 0.25
		var envelope := minf(t * 12.0, 1.0) * exp(-t * 2.5)
		samples[i] = low * envelope * 0.8
	return _to_wav(samples, false)


static func _make_pickup() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(0.08 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		samples[i] = sin(TAU * 1250.0 * t) * exp(-t * 60.0) * 0.6
	return _to_wav(samples, false)


static func _make_thud() -> AudioStreamWAV:
	var rng := _rng()
	var samples := PackedFloat32Array()
	samples.resize(int(0.3 * MIX_RATE))
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.1
		samples[i] = (sin(TAU * 70.0 * t) * 0.9 + low * 1.5) * exp(-t * 18.0)
	return _to_wav(samples, false)


static func _make_deposit() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(0.7 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var second := sin(TAU * 1318.5 * t) if t > 0.12 else 0.0
		samples[i] = (sin(TAU * 880.0 * t) + second) * exp(-t * 5.0) * 0.35
	return _to_wav(samples, false)


static func _make_horn() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(1.3 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var tone := signf(sin(TAU * 196.0 * t)) * 0.5 + signf(sin(TAU * 247.0 * t)) * 0.5
		var envelope := minf(t * 20.0, 1.0) * minf((1.3 - t) * 8.0, 1.0)
		samples[i] = tone * envelope * 0.3
	return _to_wav(samples, false)


static func _make_beep() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(0.12 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		samples[i] = sin(TAU * 1000.0 * t) * minf((0.12 - t) * 40.0, 1.0) * 0.4
	return _to_wav(samples, false)


static func _make_death_sting() -> AudioStreamWAV:
	var rng := _rng()
	var samples := PackedFloat32Array()
	samples.resize(int(1.6 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		# Clashing tones plus a noise hit: harsh on purpose.
		var cluster := sin(TAU * 220.0 * t) + sin(TAU * 233.1 * t) + sin(TAU * 311.1 * t) + sin(TAU * 466.2 * t)
		var hit := rng.randf_range(-1.0, 1.0) * exp(-t * 25.0)
		samples[i] = (cluster * 0.2 * exp(-t * 1.8) + hit * 0.7)
	return _to_wav(samples, false)


static func _make_mannequin_scrape() -> AudioStreamWAV:
	var rng := _rng()
	var samples := PackedFloat32Array()
	# 1 s loop; the 4 Hz judder repeats a whole number of times.
	samples.resize(MIX_RATE)
	var low := 0.0
	var band := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.35
		band += (low - band) * 0.05
		var judder := 0.55 + 0.45 * absf(sin(TAU * 2.0 * t))
		samples[i] = (low - band) * judder * 1.6
	return _to_wav(samples, true)


static func _make_ambience() -> AudioStreamWAV:
	var rng := _rng()
	var seconds := 8
	var samples := PackedFloat32Array()
	samples.resize(seconds * MIX_RATE)
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		# Whole cycles per loop (45, 55, 0.25 Hz over 8 s) so the loop is seamless.
		var drone := sin(TAU * 45.0 * t) * 0.5 + sin(TAU * 55.0 * t) * 0.35
		var swell := 0.6 + 0.4 * sin(TAU * 0.25 * t)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.02
		samples[i] = (drone * swell + low * 2.0) * 0.35
	return _to_wav(samples, true)


static func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	return rng


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * MAX_AMPLITUDE))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
