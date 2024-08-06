shader_type spatial;
render_mode unshaded;
uniform sampler2D image: source_color;
uniform sampler2D mask;
uniform vec4 bg_color: source_color;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec3 c = texture(image, UV).rgb;
	ALBEDO = mix(c, bg_color.rgb, bg_color.a);
	//if (mask) {
		//
	//}
	ALPHA = texture(mask, UV).a;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
