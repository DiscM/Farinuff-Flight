shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Gen IV — apex interference and the companion reactor-centered radial aura.
#define VOID_STAGE 4
#include "res://effects/shaders/models/corrupted_void_enemy_evolution_common.gdshaderinc"
