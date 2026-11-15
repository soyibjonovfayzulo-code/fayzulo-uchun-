// Shared wall/prop cutaway: fragments between the camera and the player are dithered away
// inside a screen-space circle, so walls never hide the character (Project Zomboid style).
global uniform vec3 cut_player_pos;
global uniform float cut_floor_y;
global uniform float cut_radius;
global uniform vec3 cut_cam_dir;
global uniform float cut_enabled;
// While inside a building: world XZ box (min x, min z, max x, max z) of it, so neighbours stay whole.
global uniform vec4 cut_box;
global uniform float cut_box_on;

float rz_bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

bool rz_cut(vec3 world_pos, vec3 view_vertex, mat4 view_matrix, vec3 cam_dir_world, vec2 fragcoord) {
	if (cut_enabled < 0.5) return false;
	// Only the main camera cuts; shadow passes keep full geometry.
	if (abs(dot(normalize(cam_dir_world), normalize(cut_cam_dir))) < 0.995) return false;
	if (world_pos.y < cut_floor_y + 0.3) return false;
	if (cut_box_on > 0.5 && (world_pos.x < cut_box.x - 1.6 || world_pos.x > cut_box.z + 1.6
			|| world_pos.z < cut_box.y - 1.6 || world_pos.z > cut_box.w + 1.6)) return false;
	vec3 pv = (view_matrix * vec4(cut_player_pos, 1.0)).xyz;
	if (view_vertex.z - pv.z < 0.12) return false;
	float d = length(view_vertex.xy - pv.xy);
	float edge = (d - cut_radius) / 0.9;
	return edge < rz_bayer4(fragcoord);
}
