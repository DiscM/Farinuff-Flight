extends RefCounted
class_name VisualStyleSettings
## Shared access to renderer-wide visual-style selection.

const VOXEL_STYLE_SETTING := "rendering/voxel_style_enabled"
const VOXEL_STYLE_ARG := "--voxel-style"


static func voxel_style_enabled() -> bool:
	if OS.get_cmdline_user_args().has(VOXEL_STYLE_ARG):
		return true
	return bool(ProjectSettings.get_setting(VOXEL_STYLE_SETTING, false))
