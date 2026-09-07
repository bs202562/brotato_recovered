shader_type spatial;
render_mode diffuse_burley;
uniform vec2 floor_size = vec2(18.0, 40.0);
void fragment() {
	vec2 p = UV * floor_size;
	vec2 cell = floor(p);
	vec2 edge = min(fract(p), 1.0 - fract(p));
	float grout = 1.0 - smoothstep(0.008, 0.024, min(edge.x, edge.y));
	float tile = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(vec3(0.052, 0.09, 0.105), vec3(0.062, 0.103, 0.115), tile);
	base = mix(base, vec3(0.02, 0.042, 0.053), grout * 0.65);
	float rail = 1.0 - smoothstep(0.025, 0.065, abs(abs(p.x - floor_size.x * 0.5) - 5.0));
	float dash = step(0.45, fract(p.y * 0.5));
	base = mix(base, vec3(0.55, 0.46, 0.24), rail * dash * 0.6);
	ALBEDO = base;
	ROUGHNESS = 0.85;
}
