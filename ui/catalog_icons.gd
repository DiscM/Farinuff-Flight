extends RefCounted
## Bundled symbols for catalog entries; readable labels remain authoritative.
const FALLBACK := preload("res://assets/ui/catalog/module.svg")
const TEXTURES := {
	"ship_swallowtail": preload("res://assets/ui/catalog/swallowtail.svg"),
	"ship_interceptor": preload("res://assets/ui/catalog/interceptor.svg"),
	"ship_bulwark": preload("res://assets/ui/catalog/bulwark.svg"),
	"meta_hull": preload("res://assets/ui/catalog/shield.svg"),
	"meta_thrusters": preload("res://assets/ui/catalog/boost.svg"),
	"meta_cannons": preload("res://assets/ui/catalog/charge.svg"),
	"meta_reserves": preload("res://assets/ui/catalog/retry.svg"),
	"meta_orbitals": preload("res://assets/ui/catalog/orbit.svg"),
	"meta_piercing": preload("res://assets/ui/catalog/pierce.svg"),
	"meta_explosive": preload("res://assets/ui/catalog/burst.svg"),
	"consumable_stock": preload("res://assets/ui/catalog/retry.svg"),
	"consumable_powerup": preload("res://assets/ui/catalog/supply.svg"),
	"mod_fast_spawns": preload("res://assets/ui/catalog/rapid.svg"),
	"mod_tough_enemies": preload("res://assets/ui/catalog/armor.svg"),
	"mod_frail": preload("res://assets/ui/catalog/fracture.svg"),
	"mod_no_powerups": preload("res://assets/ui/catalog/blockade.svg"),
	"mod_orb_drought": preload("res://assets/ui/catalog/drought.svg"),
	"twin_cannons": preload("res://assets/ui/catalog/cannons.svg"),
	"auto_aim": preload("res://assets/ui/catalog/aim.svg"),
	"drone_escort": preload("res://assets/ui/catalog/drone.svg"),
	"hull_plating": preload("res://assets/ui/catalog/shield.svg"),
	"afterburner": preload("res://assets/ui/catalog/boost.svg"),
	"spread_shot_elite": preload("res://assets/ui/catalog/spread.svg"),
	"shield_burst": preload("res://assets/ui/catalog/burst.svg"),
	"magnet_field": preload("res://assets/ui/catalog/magnet.svg"),
	"overclock": preload("res://assets/ui/catalog/charge.svg"),
	"rear_gunner": preload("res://assets/ui/catalog/rear.svg"),
	"orbitals": preload("res://assets/ui/catalog/orbit.svg"),
	"piercing": preload("res://assets/ui/catalog/pierce.svg"),
	"explosive_rounds": preload("res://assets/ui/catalog/burst.svg"),
	"salvage": preload("res://assets/ui/catalog/salvage.svg"),
}

static func make(id: String, extent: float = 32.0, tint: Color = Color.WHITE) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = TEXTURES.get(id, FALLBACK)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * extent
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.self_modulate = tint
	return icon
