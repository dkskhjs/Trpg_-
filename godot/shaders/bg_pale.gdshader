// 창백이 그려진 풍경 배경용(압록강 너머). 그림 속 하얀 공백을 찾아 살아 움직이게 한다.
//   - 공백의 가장자리가 천천히 일렁이고
//   - 흰 점들이 제각각 깜빡이고
//   - 공백 둘레가 은은하게 빛나며
//   - 공백 근처에서 새 점들이 생겨나 위로 떠오르다 사라진다.
// strength: 효과 세기(설정의 창백 효과 세기), pale: 누적 창백 노출(공백이 커지고 밝아진다)
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.5) = 1.0;
uniform float pale : hint_range(0.0, 1.0) = 0.0;
const vec3 WHITE = vec3(0.97, 0.97, 0.95);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 하얗고 채도가 낮은 곳 = 창백
float pale_mask(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	return smoothstep(0.82 - pale * 0.08, 0.95, lum) * (1.0 - smoothstep(0.06, 0.18, sat));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// 일렁임: 공백 근처에서만 눈에 띄게
	vec2 wob = (vec2(noise(uv * 9.0 + t * 0.25), noise(uv * 9.0 - t * 0.25 + 4.0)) - 0.5) * 0.012 * strength;
	vec4 base = texture(TEXTURE, uv);
	float m = pale_mask(texture(TEXTURE, uv + wob).rgb);

	// 둘레의 빛: 주변 여덟 곳의 공백 정도
	float glow = 0.0;
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.5708 + 0.785;
		glow += pale_mask(texture(TEXTURE, uv + vec2(cos(a), sin(a)) * vec2(0.03, 0.05)).rgb);
	}
	glow /= 4.0;

	// 깜빡임: 작은 칸마다 다른 박자
	vec2 cell = floor(uv * vec2(160.0, 90.0));
	float twinkle = 0.55 + 0.45 * sin(t * (1.5 + hash(cell) * 2.0) + hash(cell + 7.0) * 6.283);

	vec3 col = base.rgb;
	col = mix(col, WHITE, m * mix(1.0, twinkle, 0.6) * strength);
	col += vec3(0.22, 0.22, 0.24) * glow * (0.65 + 0.35 * sin(t * 0.6)) * strength;

	// 떠오르는 점: 공백 근처의 칸에서 생겨 위로 올라가며 사라진다
	vec2 g = uv * vec2(70.0, 40.0);
	g.y += t * 0.35;
	vec2 gc = floor(g);
	float life = fract(t * 0.12 + hash(gc));
	vec2 dot_pos = vec2(hash(gc + 1.3), hash(gc + 2.7));
	float d = length(fract(g) - dot_pos);
	float spawn = step(0.86, hash(gc + 9.1)) * smoothstep(0.3, 0.6, glow);
	float dot_a = (1.0 - smoothstep(0.06, 0.12, d)) * spawn * sin(life * 3.1416);
	col = mix(col, WHITE, dot_a * 0.9 * strength);

	// 창백 노출이 쌓이면 화면 전체가 조금씩 바랜다
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), pale * 0.4);
	COLOR = vec4(col, base.a);
}
