uniform mat4 perspective;
uniform mat4 view;
uniform mat4 model_matrix;
uniform float rotation;
uniform float playerSide;

varying float zpos;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
	zpos = vertex_position.z;
	vec4 pos = perspective * view * model_matrix * vertex_position;
	return vec4(pos.x + 3.5*playerSide, pos.yzw);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	float xpos = texture_coords.x + rotation + 4.3/18.0;
	vec4 texturecolor = Texel(texture, vec2(xpos, texture_coords.y));
	// vec4 texturecolor = Texel(texture, vec2((1.0f-texture_coords.x), texture_coords.y));
	return vec4(max((zpos + 1) / 2.0f, .25) * texturecolor.rgb, texturecolor.a);
	// return vec4(texture_coords, 0, 1);
	// return vec4(vec2(xpos, texture_coords.y), 0, 1);
}
#endif
