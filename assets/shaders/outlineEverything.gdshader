shader_type spatial;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D normal_texture : hint_normal_roughness_texture;

// Outline color, exposed as a uniform for easy tweaking
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float outline_thickness : hint_range(0.0, 0.01, 0.0000001) = 0.002;
uniform float outline_start : hint_range(0.0, 0.1, 0.001) = 0.005;
uniform float outline_end : hint_range(0.0, 1, 0.001) = 0.01;


void fragment() {
	vec2 uv = SCREEN_UV;
    float offset = outline_thickness;

    // --- Sobel Filter for Depth ---
    float d0 = texture(depth_texture, uv + vec2(-offset, -offset)).r;
    float d1 = texture(depth_texture, uv + vec2(0.0, -offset)).r;
    float d2 = texture(depth_texture, uv + vec2(offset, -offset)).r;
    float d3 = texture(depth_texture, uv + vec2(-offset, 0.0)).r;
    float d5 = texture(depth_texture, uv + vec2(offset, 0.0)).r;
    float d6 = texture(depth_texture, uv + vec2(-offset, offset)).r;
    float d7 = texture(depth_texture, uv + vec2(0.0, offset)).r;
    float d8 = texture(depth_texture, uv + vec2(offset, offset)).r;

    float depth_Gx = d0 * -1.0 + d2 * 1.0 + d3 * -2.0 + d5 * 2.0 + d6 * -1.0 + d8 * 1.0;
    float depth_Gy = d0 * -1.0 + d1 * -2.0 + d2 * -1.0 + d6 * 1.0 + d7 * 2.0 + d8 * 1.0;
    float depth_magnitude = sqrt(depth_Gx * depth_Gx + depth_Gy * depth_Gy);

    // --- Sobel Filter for Normals ---
    vec3 n0 = texture(normal_texture, uv + vec2(-offset, -offset)).rgb;
    vec3 n1 = texture(normal_texture, uv + vec2(0.0, -offset)).rgb;
    vec3 n2 = texture(normal_texture, uv + vec2(offset, -offset)).rgb;
    vec3 n3 = texture(normal_texture, uv + vec2(-offset, 0.0)).rgb;
    vec3 n5 = texture(normal_texture, uv + vec2(offset, 0.0)).rgb;
    vec3 n6 = texture(normal_texture, uv + vec2(-offset, offset)).rgb;
    vec3 n7 = texture(normal_texture, uv + vec2(0.0, offset)).rgb;
    vec3 n8 = texture(normal_texture, uv + vec2(offset, offset)).rgb;

    vec3 normal_Gx = n0 * -1.0 + n2 * 1.0 + n3 * -2.0 + n5 * 2.0 + n6 * -1.0 + n8 * 1.0;
    vec3 normal_Gy = n0 * -1.0 + n1 * -2.0 + n2 * -1.0 + n6 * 1.0 + n7 * 2.0 + n8 * 1.0;
    float normal_magnitude = sqrt(dot(normal_Gx, normal_Gx) + dot(normal_Gy, normal_Gy));

    // --- Combine the results with priority ---
    float final_edge_magnitude;
    if (depth_magnitude > 0.001) { // Check if there's any significant depth change
        final_edge_magnitude = depth_magnitude;
    } else {
        final_edge_magnitude = normal_magnitude;
    }

    // Smoothly interpolate the alpha value
    float alpha_outline = smoothstep(outline_start, outline_end, final_edge_magnitude);

    // Get the original scene color
    vec4 scene_color = texture(screen_texture, uv);

	ALBEDO = mix(vec3(scene_color.r,scene_color.g,scene_color.b), vec3(outline_color.r,outline_color.g,outline_color.b), alpha_outline);
	ALPHA = outline_color.a;
}