extends Node
## A small dedicated voice pool keeps menu feedback independent of combat SFX.
const RATE := 22050
const NOTES := {
	&"UI.NAV.MOVE": [74],
	&"UI.NAV.CONFIRM": [62, 69],
	&"UI.NAV.CANCEL": [69, 62],
	&"MAP.NODE.DISCOVER": [62, 69, 70, 69, 65, 62],
	&"MAP.ROUTE.SELECT": [69, 70, 69],
	&"MAP.SECTOR.DEPART": [62, 69, 70, 69, 65, 62],
	&"STORY.FRAGMENT.OPEN": [69, 70, 69, 62],
}
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _last: Dictionary = {}
var _departure_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("UI") < 0:
		AudioServer.add_bus()
		var index := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, "UI")
		AudioServer.set_bus_send(index, "Master")
	for cue: StringName in NOTES:
		var note_seconds := 0.04 if cue == &"UI.NAV.MOVE" else 0.12
		if cue == &"MAP.SECTOR.DEPART":
			note_seconds = AudioManager.MUSIC_BAR_SECONDS / NOTES[cue].size()
		_streams[cue] = _make_cell(NOTES[cue], note_seconds)
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = "UI"
		add_child(voice)
		_voices.append(voice)
	SaveManager._apply_audio_settings()

func play(cue: StringName) -> void:
	if cue == &"MAP.SECTOR.DEPART":
		if _departure_pending:
			return
		_departure_pending = true
		var delay := AudioManager.seconds_to_next_music_bar()
		if delay > 0.0:
			await get_tree().create_timer(delay, true, false, true).timeout
		_departure_pending = false
	_play_now(cue)


func _play_now(cue: StringName) -> void:
	if not _streams.has(cue):
		return
	var now := Time.get_ticks_msec() * 0.001
	var cooldown := 0.09 if cue == &"UI.NAV.MOVE" else 0.2
	if now - float(_last.get(cue, -100.0)) < cooldown:
		return
	_last[cue] = now
	var selected: AudioStreamPlayer = null
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			selected = voice
			break
	if selected == null:
		# Navigation never interrupts a discovery or confirmation already sounding.
		return
	selected.stream = _streams[cue]
	selected.volume_db = -27.0 if cue == &"UI.NAV.MOVE" else -17.0
	selected.play()

func _make_cell(notes: Array, note_seconds: float) -> AudioStreamWAV:
	var samples_per_note := int(RATE * note_seconds)
	var data := PackedByteArray()
	data.resize(samples_per_note * notes.size() * 2)
	for note_index in notes.size():
		var frequency := 440.0 * pow(2.0, (float(notes[note_index]) - 69.0) / 12.0)
		for sample in samples_per_note:
			var time := float(sample) / RATE
			var envelope := minf(time / 0.006, 1.0) * pow(1.0 - float(sample) / samples_per_note, 2.0)
			var tone := sin(TAU * frequency * time) + 0.16 * sin(TAU * frequency * 2.0 * time)
			data.encode_s16((note_index * samples_per_note + sample) * 2, roundi(tone * envelope * 20000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
