@tool
extends Resource
class_name StoryBeatDefinition
## Immutable authored story metadata. Text is resolved by the future presenter.

@export var id: StringName = &""
@export var trigger_type: StringName = &"pre_sector"
@export var speaker_id: StringName = &"moth"
@export var text_key: StringName = &""
@export var once_policy: StringName = &"first_discovery"
@export var blocking: bool = false
@export var skippable: bool = true
@export_range(0.0, 10.0, 0.1) var auto_dismiss_seconds: float = 0.0
@export var required_route_tags: PackedStringArray = PackedStringArray()
@export var forbidden_route_tags: PackedStringArray = PackedStringArray()
