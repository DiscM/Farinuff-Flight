extends RefCounted
class_name FrontierPalette
## Shared roles for world, craft, and event feedback.

const SPACE := Color("080b1b")
const CYAN := Color("35dcf2")
const ICE := Color("d4f7ff")
const VIOLET := Color("ad63ef")
const HOSTILE := Color("ee69c0")
const GOLD := Color("ffc875")
const SPARK := Color("ff9d50")

const CRT_PROFILE := {
	"scanline_intensity": 0.045,
	"scanline_count": 720.0,
	"aberration_strength": 0.00035,
	"vignette_strength": 0.22,
	"contrast": 1.0,
	"brightness": 1.0,
	"barrel_distortion": 0.012,
}


static func apply_galaxy(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"space_color", SPACE)
	material.set_shader_parameter(&"nebula_blue", Color("294462"))
	material.set_shader_parameter(&"nebula_violet", Color("48365b"))
	material.set_shader_parameter(&"nebula_pink", Color("745074"))
	material.set_shader_parameter(&"nebula_strength", 0.72)
	material.set_shader_parameter(&"star_brightness", 0.66)
	material.set_shader_parameter(&"drift_speed", 0.009)


static func apply_crt(material: ShaderMaterial) -> void:
	for parameter in CRT_PROFILE:
		material.set_shader_parameter(parameter, CRT_PROFILE[parameter])
