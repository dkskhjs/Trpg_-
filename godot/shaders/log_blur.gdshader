// 지난 대사 위에 덮는 블러. 구분선 위쪽만 덮는다(main.gd가 높이를 맞춘다).
// 아래쪽 끝 몇 픽셀은 원래 화면과 섞어 경계가 부드럽게.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 3.0;      // 샘플 간격(픽셀)
uniform float dim = 0.35;        // 어둡게 하는 정도
uniform float edge_px = 18.0;    // 아래 경계에서 서서히 선명해지는 길이
uniform float rect_h = 100.0;    // 막의 높이(픽셀, main.gd가 넣어 준다)

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 c = vec3(0.0);
	float w = 0.0;
	// 3×3 샘플을 넓게 벌려 찍는다(웹·저사양에서 가볍게)
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			float k = 1.0 / (1.0 + float(x * x + y * y));
			c += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * k;
			w += k;
		}
	}
	c /= w;
	c = mix(c, vec3(0.07, 0.07, 0.065), dim);
	vec3 sharp = texture(screen_tex, SCREEN_UV).rgb;
	float from_bottom = (1.0 - UV.y) * rect_h;
	float t = smoothstep(0.0, edge_px, from_bottom);
	COLOR = vec4(mix(sharp, c, t), 1.0);
}
