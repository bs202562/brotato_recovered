shader_type canvas_item;
render_mode unshaded;

uniform vec4 color_A : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 color_B : source_color = vec4(1.000000, 1.000000, 1.000000, 1.000000);

void fragment() {
// Input:2

// Texture:9
	vec3 color_text;
	float n_out9p1;
	{
		vec4 TEXTURE_tex_read = texture(TEXTURE, UV.xy);
		color_text = TEXTURE_tex_read.rgb;
		n_out9p1 = TEXTURE_tex_read.a;
	}

	vec3 color_text_A = color_A.rgb * (vec3(1.0, 1.0, 1.0) - color_text);
	vec3 color_text_B = color_B.rgb * color_text;

// Output:0
	COLOR.rgb = color_text_A + color_text_B;
	COLOR.a = n_out9p1;

}
