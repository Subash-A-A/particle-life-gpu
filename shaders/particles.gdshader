shader_type particles;

uniform sampler2D particles_data;
uniform float scale = .5;
uniform vec3 colors[16];

void process() {
	ivec2 pos_image_size = textureSize(particles_data, 0);
	
	ivec2 texel_pos = ivec2(
		int(mod(float(INDEX), float(pos_image_size.x))),
		int(float(INDEX) / float (pos_image_size.x))
	);
	
	vec4 particle_data = texelFetch(particles_data, texel_pos, 0);
	
	mat2 scale_rot_mat = mat2(
		vec2(cos(particle_data.b), sin(particle_data.b)),
		vec2(-sin(particle_data.b), cos(particle_data.b))
	);
	
	scale_rot_mat *= scale;
	
	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(particle_data.r, particle_data.g);
	COLOR.rgb = colors[int(particle_data.a)];
	COLOR.a = 1.0;
}
