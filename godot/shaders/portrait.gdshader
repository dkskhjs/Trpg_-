// 인물 초상화: 흑백으로 바꾼 뒤 인물별 포인트 색 하나로 물들인다(먹색 → 포인트 색 → 종이색).
// 창백 노출(pale)이 쌓이면 포인트 색이 종이색으로 빠져 초상화가 바래 간다.
// 미리보기용 같은 공식: tools/tone_preview.py
shader_type canvas_item;

uniform vec3 accent : source_color = vec3(0.72, 0.19, 0.17);
uniform float strength : hint_range(0.0, 1.0) = 0.85;   // 0이면 순수 흑백
uniform float pale : hint_range(0.0, 1.0) = 0.0;
const vec3 INK = vec3(0.10, 0.09, 0.08);
const vec3 PAPER = vec3(0.93, 0.91, 0.86);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * 1.15 + 0.5, 0.0, 1.0);
	vec3 gray = mix(INK, PAPER, l);
	vec3 c = mix(accent, PAPER, pale);
	vec3 duo = l < 0.5 ? mix(INK, c, l * 2.0) : mix(c, PAPER, l * 2.0 - 1.0);
	COLOR = vec4(mix(gray, duo, strength), src.a);
}
