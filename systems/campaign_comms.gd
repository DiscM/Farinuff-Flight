extends Node
## Binds production flight events to authored, optional transmissions.
const StoryCopy := preload("res://campaign/story_copy.gd")
const NoticeChannel := preload("res://ui/combat_notice.gd")
var _ticker: NoticeChannel
var _first_chain := false

func configure(gameplay: Node, ticker: NoticeChannel) -> void:
	_ticker = ticker
	_ticker.transmission_completed.connect(_on_transmission_completed)
	gameplay.player.boost_chained.connect(_on_chain)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_phase_changed.connect(_on_boss_phase_changed)
	SignalBus.evolution_transition_finished.connect(_on_evolution_finished)

func route_arrived() -> void:
	var node := ExpeditionManager.get_current_node()
	if node != null:
		_request(StringName(str(node.id) + "_arrival"))

func _on_chain() -> void:
	if _first_chain:
		return
	_first_chain = true
	_request(&"first_return")

func _on_wave_started(wave: int) -> void:
	if wave == 21:
		_request(&"endless_departure", 1)

func _on_evolution_finished(_generation: int) -> void:
	var wave := GameManager.current_wave
	if wave >= 6 and wave <= 20:
		_request(StringName("generation_%d" % (2 if wave <= 10 else 3 if wave <= 15 else 4)))

func _on_boss_spawned(_health: int, _maximum: int, _title: String) -> void:
	# The existing boss title/pod hints are always visible, even with Story Off.
	if GameManager.current_wave == 25:
		_request(&"harbinger_discovery", 1)

func _on_boss_phase_changed(variant: int, phase: int) -> void:
	if variant == 4 and phase == 2 and GameManager.current_wave == 20:
		_request(&"core_last_rewrite", 1)

func _request(beat_id: StringName, priority: int = 0) -> void:
	var frequency := int(SaveManager.get_setting("story_frequency", 0))
	if frequency == 2 or GameManager.practice_mode:
		return
	var beat := ExpeditionManager.get_story_beat(beat_id)
	if beat == null or (frequency == 1 and priority == 0):
		return
	if beat.once_policy != &"always" and ExpeditionManager.get_snapshot().seen_story_beat_ids.has(beat_id):
		return
	_ticker.post(StoryCopy.for_beat(beat), beat_id, priority, beat.auto_dismiss_seconds, true)

func _on_transmission_completed(beat_id: StringName) -> void:
	ExpeditionManager.record_story_viewed(beat_id)
