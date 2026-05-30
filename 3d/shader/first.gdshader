shader_type spatial;

void vertex () {
	//VERTEX.x = sin(TIME) + VERTEX.x;
	//VERTEX.y = cos(TIME) + VERTEX.y;
}

void fragment() {
	if (dot(NORMAL, vec3(0, 1, 0)) >= 0.9) {
		ALBEDO = vec3(0, 0, 0);
	} else {
	
		ALBEDO = vec3(UV.x, UV.y, 0);
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
