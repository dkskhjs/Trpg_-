// 인물 초상화: 전체를 흑백으로 바꾸고, spots에 적은 자리(손·소품·얼굴 근처)에만
// 물감을 떨어뜨린 것처럼 원래 색이 돌아온다. 가장자리는 울퉁불퉁하고, 아래로 살짝 흘러내리며,
// 주변에 작은 방울이 튄다. 창백 노출(pale)이 쌓이면 방울이 줄어든다.
// 미리보기용 같은 공식: tools/tone_preview.py
shader_type canvas_item;

uniform vec3 spots[4];          // (x, y, r) — 그림 기준 0~1, r은 너비 대비 반지름
uniform int spot_count = 0;
uniform float pale : hint_range(0.0, 1.0) = 0.0;
const vec3 INK = vec3(0.10, 0.09, 0.08);
const vec3 PAPER = vec3(0.93, 0.91, 0.86);

float hash1(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }

float angle_noise(float a, float seed) {
	return 0.5 * sin(a * 3.0 + hash1(seed + 3.0) * 6.283)
		+ 0.3 * sin(a * 7.0 + hash1(seed + 7.0) * 6.283)
		+ 0.2 * sin(a * 13.0 + hash1(seed + 13.0) * 6.283);
}

float spot_mask(vec2 uv, float aspect, vec3 s, float seed) {
	float r = s.z * aspect * (1.0 - 0.7 * pale);
	float dx = (uv.x - s.x) * aspect;
	float dy = uv.y - s.y;
	dy = dy > 0.0 ? dy * 0.8 : dy;                 // 아래로 살짝 흘러내림
	float d = length(vec2(dx, dy)) / max(r, 1e-4);
	float edge = 1.0 + 0.18 * angle_noise(atan(dy, dx), seed);
	float m = clamp((edge - d) / 0.06, 0.0, 1.0);
	for (int i = 0; i < 6; i++) {                  // 주변에 튄 작은 방울
		float fi = float(i);
		float ang = hash1(seed * 7.0 + fi) * 6.283;
		float dist = r * (1.2 + 0.5 * hash1(seed * 3.0 + fi));
		float rad = r * (0.05 + 0.08 * hash1(seed * 5.0 + fi));
		float dd = length(vec2(dx, dy) - vec2(cos(ang), sin(ang)) * dist);
		m = max(m, clamp((rad - dd) / (rad * 0.3), 0.0, 1.0));
	}
	return m;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * 1.15 + 0.5, 0.0, 1.0);
	vec3 gray = mix(INK, PAPER, l);
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;   // 너비 / 높이
	float m = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i < spot_count) {
			m = max(m, spot_mask(UV, aspect, spots[i], float(i + 1)));
		}
	}
	COLOR = vec4(mix(gray, src.rgb, m), src.a);
}
