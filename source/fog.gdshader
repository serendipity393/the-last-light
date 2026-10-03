shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 float n = noise(UV * vec2(10.0,3.0) + vec2(TIME * 0.035, TIME * 0.015));
 float edge = smoothstep(0.0,0.20,UV.x)*smoothstep(1.0,0.80,UV.x)*smoothstep(0.0,0.30,UV.y)*smoothstep(1.0,0.70,UV.y);
 ALBEDO = vec3(0.35,0.53,0.58);
 ALPHA = edge * n * 0.12;
}
