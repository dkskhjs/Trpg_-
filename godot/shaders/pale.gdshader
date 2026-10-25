// 창백: 화면 전체에 덮는 후처리.
//   intensity — 누적된 창백 노출 (0~1)
//   edge      — 강가·경계처럼 창백 바로 앞에 있을 때의 추가 강도
//   pulse     — 창백이 덮쳐오는 순간의 번쩍임 (트윈으로 0으로 줄어든다)
// 색이 빠지고, 북쪽(화면 위)에서 하얀 안개가 내려오고, 필름 입자가 낀다.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 pale_color : source_color = vec3(0.87, 0.89, 0.89);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float k = clamp(intensity + edge * 0.4 + pulse * 0.5, 0.0, 1.0);
	vec2 uv = SCREEN_UV;

	// 아지랑이처럼 느리게 일렁이는 화면
	float t = TIME * 0.12;
	uv += (vec2(fbm(uv * 3.0 + t), fbm(uv * 3.0 - t + 7.0)) - 0.5) * 0.007 * k;
	vec3 col = texture(screen_texture, uv).rgb;

	// 색이 빠진다
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(k * 1.1, 0.0, 0.9));

	// 북쪽에서 내려오는 안개. 글자를 읽을 수 있게 위쪽에만 짙다.
	float n = fbm(vec2(uv.x * 3.5, uv.y * 2.0 - TIME * 0.025));
	float reach = 0.06 + 0.4 * k;
	float fog = 1.0 - smoothstep(0.0, reach, uv.y + (n - 0.5) * 0.25 * (0.3 + k));
	col = mix(col, pale_color, fog * (0.2 + 0.35 * k));

	// 검은색이 회백색으로 떠오른다
	col = mix(col, pale_color, k * 0.1 + pulse * 0.45);

	// 필름 입자와 가장자리 어둠
	float g = hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + fract(TIME) * 61.0) - 0.5;
	col += g * (0.025 + 0.06 * k);
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - dot(d, d) * (0.35 - 0.25 * k);

	COLOR = vec4(col, 1.0);
}
