shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_albedo : hint_albedo;
uniform vec4 coat_color : hint_color = vec4(0.8,0.4,0.1,1.0);
uniform vec4 skin_color : hint_color = vec4(0.7,0.45,0.3,1.0);
uniform bool zombie_palette = false;
void fragment() {
	vec3 source = texture(source_albedo, UV).rgb;
	float warm = smoothstep(1.12,1.4,source.r/max(source.g,0.001)) * smoothstep(1.1,1.5,source.g/max(source.b,0.001));
	float skin = smoothstep(1.3,1.7,source.g/max(source.r,0.001)) * smoothstep(0.65,0.85,source.g/max(source.b,0.001)) * smoothstep(0.10,0.22,source.g);
	if (zombie_palette) {
		warm = smoothstep(1.25,1.65,source.r/max(source.g,0.001)) * smoothstep(1.1,1.5,source.r/max(source.b,0.001));
		skin = smoothstep(1.03,1.2,source.g/max(source.r,0.001)) * smoothstep(1.1,1.4,source.g/max(source.b,0.001));
	}
	float value = max(source.r,max(source.g,source.b));
	vec3 recolored = mix(source,coat_color.rgb*(0.35+value*0.8),warm);
	ALBEDO = mix(recolored,skin_color.rgb*(0.38+value*0.75),skin);
	ROUGHNESS = 0.88;
}
