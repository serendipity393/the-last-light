shader_type spatial;
render_mode cull_disabled;
uniform vec4 sea_color : source_color = vec4(0.027, 0.16, 0.21, 1.0);
varying vec3 world;
void vertex() {
 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 VERTEX.y += sin(world.x * 0.7 + TIME * 0.65) * 0.08 + cos(world.z * 0.5 - TIME * 0.5) * 0.08;
}
void fragment() {
 float wave = sin(world.x * 2.2 + world.z * 0.4 + TIME) * cos(world.z * 2.0 - TIME * 0.65);
 float stripe = pow(max(0.0, wave), 12.0);
 ALBEDO = sea_color.rgb + stripe * vec3(0.06, 0.12, 0.14);
 METALLIC = 0.55;
 ROUGHNESS = 0.23;
 EMISSION = stripe * vec3(0.015, 0.04, 0.055);
}
