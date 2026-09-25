// BRILHO DA PISTA: canaletas azuis subindo e dourado pulsando.
// As máscaras vêm prontas em sprites/pista_mascara.png.
shader_type canvas_item;
uniform sampler2D mascara : filter_linear;
uniform float intensidade : hint_range(0.0, 2.0) = 0.55;
uniform float velocidade : hint_range(0.0, 5.0) = 1.2;
uniform float erro_forca : hint_range(0.0, 1.0) = 0.0;
uniform float frenesi = 0.0;
uniform vec3 cor_canaleta = vec3(0.0, 0.95, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 m = texture(mascara, UV).rg;
	COLOR = tex;
	// Longe das canaletas e do dourado (a maior parte da tela) não há luz
	// para animar: o pixel sai direto, sem a conta do brilho.
	if (m.r + m.g >= 0.004) {
		float mascara_c = m.r;
		float t = TIME * velocidade;
		float luz_subindo = fract(UV.y * 1.5 - t * 0.28);
		float pulso_canaleta = smoothstep(0.0, 0.18, luz_subindo) * (1.0 - smoothstep(0.18, 0.55, luz_subindo));
		float pulso_global = 0.70 + 0.30 * sin(t * 1.8 + UV.y * 12.0 + UV.x * 5.0);
		float pulso_gold = pulso_global * (0.55 + 0.45 * sin(t * 2.6 + UV.x * 18.0));
		float brilho_canaleta = mascara_c * pulso_canaleta * intensidade * (1.0 + frenesi);
		float brilho_gold = m.g * pulso_gold * intensidade * 0.45 * (1.0 - erro_forca);
		vec3 cor_base = tex.rgb;
		cor_base.g *= 1.0 - (mascara_c * erro_forca * 0.65);
		cor_base.b *= 1.0 - (mascara_c * erro_forca * 0.85);
		// Dragon Bowling 2: um reflexo passa pelo dourado (emblema e espiral)
		// a cada 4,5 s, na diagonal.
		float fase_reflexo = fract(TIME / 4.5);
		float diag = UV.x + UV.y * 0.6;
		float reflexo = smoothstep(0.07, 0.0, abs(diag - mix(-0.3, 1.9, fase_reflexo))) * m.g;
		vec3 luz_normal = cor_canaleta * brilho_canaleta + vec3(1.0, 0.88, 0.30) * brilho_gold + vec3(1.0, 0.96, 0.82) * reflexo * 0.55;
		vec3 luz_erro = vec3(1.0, 0.0, 0.0) * (brilho_canaleta * 2.2 + mascara_c * 0.10);
		COLOR = vec4(cor_base + mix(luz_normal, luz_erro, erro_forca), tex.a);
	}
}
