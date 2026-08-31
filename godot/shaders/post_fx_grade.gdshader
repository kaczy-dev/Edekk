shader_type canvas_item;
// Vignette + sepia + hue-rotate — the three pieces of LevelScene.ts's
// setupPostFX()/AtmosphereFX.ts that Environment.adjustment_* (brightness/
// contrast/saturation, already wired in AtmosphereFX.gd) has no equivalent
// for in Godot 4's 2D pipeline. See PostFXOverlay.gd, "Vignette/hue/sepia".
//
// Vignette applies unconditionally on every level (Phaser source: a fixed
// default of 0.35 unless a level's mood overrides it — no ported level
// does). Sepia/hue are per-level `mood` values, off by default.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_radius : hint_range(0.1, 2.0) = 0.82;
uniform bool apply_sepia = false;
uniform float hue_degrees = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(screen_texture, SCREEN_UV);
	vec3 color = tex.rgb;

	if (apply_sepia) {
		// 1:1 with Phaser ColorMatrixFilter.sepia()'s standard luma-weighted
		// sepia matrix, simplified to the common gray * tint approximation.
		float gray = dot(color, vec3(0.299, 0.587, 0.114));
		color = vec3(gray * 1.2, gray * 1.0, gray * 0.8);
	}

	if (abs(hue_degrees) > 0.001) {
		vec3 hsv = rgb2hsv(color);
		hsv.x = fract(hsv.x + hue_degrees / 360.0);
		color = hsv2rgb(hsv);
	}

	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	// Correct for non-square viewports so the vignette reads as a circle,
	// not an oval stretched to the aspect ratio.
	centered_uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(centered_uv) / vignette_radius;
	float vignette = smoothstep(1.0, 0.4, dist);
	color *= mix(1.0 - vignette_strength, 1.0, vignette);

	COLOR = vec4(color, tex.a);
}
