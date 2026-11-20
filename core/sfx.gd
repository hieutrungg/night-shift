class_name Sfx
extends RefCounted
## All game sounds in one place. Recorded sounds come from Kenney RPG Audio
## (CC0, assets/audio/kenney_rpg_audio); the rest are synthesised in code.
## Each sound is built once (on first use) and cached.

const MIX_RATE: int = 22050
const MAX_AMPLITUDE: float = 32767.0
## Fixed seed: the same noise on every machine and every run.
const NOISE_SEED: int = 1337
const KENNEY_DIR: String = "res://assets/audio/kenney_rpg_audio/"
const FOOTSTEP_FILES: Array[String] = [
	"footstep00", "footstep01", "footstep02", "footstep03", "footstep04",
	"footstep05", "footstep06", "footstep07", "footstep08", "footstep09",
]
const DOOR_OPEN_FILES: Array[String] = ["doorOpen_1", "doorOpen_2"]
const DOOR_CLOSE_FILES: Array[String] = ["doorClose_1", "doorClose_2", "doorClose_3", "doorClose_4"]
const PICKUP_FILES: Array[String] = ["cloth1", "cloth2", "handleSmallLeather"]
const DROP_FILES: Array[String] = ["dropLeather"]
const CREAK_FILES: Array[String] = ["creak1", "creak2", "creak3"]
## Pitch spread for recorded variants (1.0 = none), so repeats sound different.
const FOOTSTEP_PITCH_SPREAD: float = 1.08
const DEFAULT_PITCH_SPREAD: float = 1.05
const MANNEQUIN_MUSIC_SECONDS: float = 8.0
const MANNEQUIN_NOTE_SECONDS: float = 0.5
const MANNEQUIN_NOTES: Array[float] = [220.0, 233.0, 165.0, 208.0, 220.0, 311.0, 233.0, 165.0]
const TRUCK_ENGINE_SECONDS: float = 2.0
const TRUCK_ENGINE_RUMBLE_HZ: float = 42.0
const TRUCK_ENGINE_PULSE_HZ: float = 13.0
const TRUCK_ENGINE_RATTLE_HZ: float = 126.0

static var _cache: Dictionary[StringName, AudioStream] = {}


static func footstep() -> AudioStream:
	return _cached(&"footstep", _recorded.bind(FOOTSTEP_FILES, FOOTSTEP_PITCH_SPREAD))


static func door_open() -> AudioStream:
	return _cached(&"door_open", _recorded.bind(DOOR_OPEN_FILES, DEFAULT_PITCH_SPREAD))


static func door_close() -> AudioStream:
	return _cached(&"door_close", _recorded.bind(DOOR_CLOSE_FILES, DEFAULT_PITCH_SPREAD))


static func pickup() -> AudioStream:
	return _cached(&"pickup", _recorded.bind(PICKUP_FILES, DEFAULT_PITCH_SPREAD))


static func item_drop() -> AudioStream:
	return _cached(&"item_drop", _recorded.bind(DROP_FILES, DEFAULT_PITCH_SPREAD))


## Joints creaking when the mannequin starts to move.
static func mannequin_creak() -> AudioStream:
	return _cached(&"mannequin_creak", _recorded.bind(CREAK_FILES, DEFAULT_PITCH_SPREAD))


static func thud() -> AudioStream:
	return _cached(&"thud", _make_thud)


static func deposit() -> AudioStream:
	return _cached(&"deposit", _make_deposit)


static func horn() -> AudioStream:
	return _cached(&"horn", _make_horn)


## Looping diesel-like rumble, created locally without a downloaded asset.
static func truck_engine() -> AudioStream:
	return _cached(&"truck_engine", _make_truck_engine)


static func beep() -> AudioStream:
	return _cached(&"beep", _make_beep)


static func quota_reached() -> AudioStream:
	return _cached(&"quota_reached", _make_quota_reached)


static func death_sting() -> AudioStream:
	return _cached(&"death_sting", _make_death_sting)


## Looping.
static func mannequin_music() -> AudioStream:
	return _cached(&"mannequin_music", _make_mannequin_music)


## Looping.
static func ambience() -> AudioStream:
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


static func _cached(key: StringName, maker: Callable) -> AudioStream:
	if not _cache.has(key):
		var stream: AudioStream = maker.call()
		_cache[key] = stream
	return _cache[key]


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


static func _make_quota_reached() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(0.6 * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var frequency := 660.0 if t < 0.2 else (880.0 if t < 0.4 else 1320.0)
		var envelope := minf(t * 30.0, 1.0) * minf((0.6 - t) * 10.0, 1.0)
		samples[i] = sin(TAU * frequency * t) * envelope * 0.3
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


static func _make_truck_engine() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(TRUCK_ENGINE_SECONDS * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var rumble := sin(TAU * TRUCK_ENGINE_RUMBLE_HZ * t)
		var harmonic := sin(TAU * TRUCK_ENGINE_RUMBLE_HZ * 2.0 * t)
		var rattle := sin(TAU * TRUCK_ENGINE_RATTLE_HZ * t)
		var pulse := 0.7 + 0.3 * sin(TAU * TRUCK_ENGINE_PULSE_HZ * t)
		samples[i] = (rumble * 0.55 + harmonic * 0.22 + rattle * 0.12) * pulse * 0.55
	return _to_wav(samples, true)


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


static func _make_mannequin_music() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(MANNEQUIN_MUSIC_SECONDS * MIX_RATE))
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var note_index := int(t / MANNEQUIN_NOTE_SECONDS) % MANNEQUIN_NOTES.size()
		var note_time := fmod(t, MANNEQUIN_NOTE_SECONDS)
		var envelope := pow(sin(PI * note_time / MANNEQUIN_NOTE_SECONDS), 2.0)
		var frequency := MANNEQUIN_NOTES[note_index]
		var strings := sin(TAU * frequency * note_time) + 0.3 * sin(TAU * frequency * 2.0 * note_time)
		# Whole drone cycles and silent note boundaries keep the loop seamless.
		var drone := sin(TAU * 55.0 * t) + 0.6 * sin(TAU * 58.0 * t)
		var swell := 0.65 + 0.35 * sin(TAU * 0.25 * t)
		samples[i] = strings * envelope * 0.3 + drone * swell * 0.18
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


## Random variant on each play, with a little pitch variation.
static func _recorded(files: Array[String], pitch_spread: float) -> AudioStream:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = pitch_spread
	for file in files:
		var stream := load(KENNEY_DIR + file + ".ogg") as AudioStream
		if stream != null:
			randomizer.add_stream(-1, stream)
	return randomizer


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
