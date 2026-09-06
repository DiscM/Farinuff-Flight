@tool
extends Resource
class_name Native3DPresentationSettings
## Scene-owned budgets for the native 3D presentation slice.
##
## These values deliberately live outside project settings: the native combat
## scene can tune its visual pressure without changing the shared renderer or
## the 2D menu/HUD presentation.

@export_range(16, 128, 1) var effect_pool_size: int = 64
@export_range(1, 16, 1) var effect_warm_batch_size: int = 16
@export_range(0, 16, 1) var max_local_effect_lights: int = 4
@export var metrics_enabled: bool = true
@export_range(0.05, 1.0, 0.05) var metrics_interval: float = 0.25
