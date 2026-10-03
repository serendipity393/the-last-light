shader_type canvas_item;
uniform sampler2D scene : hint_screen_texture, filter_linear_mipmap;
void fragment() {
 vec3 original = textureLod(scene, SCREEN_UV, 0.0).rgb;
 vec3 bloom = max(textureLod(scene, SCREEN_UV, 2.8).rgb - vec3(0.50), vec3(0.0));
 vec2 p = SCREEN_UV * 2.0 - 1.0;
 float vignette = 1.0 - 0.20 * smoothstep(0.30, 1.50, dot(p, p));
 vec3 grade = original * vec3(0.96, 1.01, 1.035) + bloom * vec3(0.50, 0.39, 0.20);
 COLOR = vec4(grade * vignette, 1.0);
}
