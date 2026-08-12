shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Gen II — augmented conduit lattice and first junction nodes.
#define VOID_STAGE 2
#include "res://effects/shaders/models/corrupted_void_enemy_evolution_common.gdshaderinc"
