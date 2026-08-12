shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Gen III — denser fractures, junction network, and hot diagonal veins.
#define VOID_STAGE 3
#include "res://effects/shaders/models/corrupted_void_enemy_evolution_common.gdshaderinc"
