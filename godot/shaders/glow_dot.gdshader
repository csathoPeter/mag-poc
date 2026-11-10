shader_type spatial;
// Fénylő pont a világban (mélységteszttel: a bolygó eltakarja). Lásd glow_dot.gdshaderinc.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/glow_dot.gdshaderinc"
