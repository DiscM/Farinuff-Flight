shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Gen I — base corrupted void. Later wrappers reuse the exact interface and
// build detail on top of this silhouette treatment.
#define VOID_STAGE 1
#include "res://effects/shaders/models/corrupted_void_enemy_evolution_common.gdshaderinc"
