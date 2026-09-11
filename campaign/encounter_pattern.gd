extends Resource
class_name EncounterPattern
## A bounded formation consumes ordinary spawn slots and threat admission.
@export var title := ""
@export var archetypes: Array[StringName] = []
@export var lanes := PackedFloat32Array()
@export var warning_seconds := 1.2
@export var maximum_seconds := 8.0
@export var interval_seconds := 0.8

## Opposite edges create crossfire while keeping the unoccupied half clear.
@export var opposite_edges := PackedByteArray()
@export var entry_edges := PackedInt32Array([0, 1, 2, 3])
@export var minimum_wave := 3
