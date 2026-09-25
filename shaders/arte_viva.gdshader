// ARTE DA ABERTURA VIVA (Dragon Bowling 2) — sobre sprites/dragon_bow.png.
//
// A imagem vira uma "foto 3D": o mapa sprites/dragon_bow_camadas.png
// (tools/gerar_profundidade_arte.py) diz o que está na frente e o que
// está atrás, e a câmera balança devagar — o título vem para a frente,
// o dragão e a bola ficam no meio e o fundo fica para trás.
//  • o dragão respira (sobe e desce, peito enchendo);
//  • a bola azul balança, girando para lá e para cá;
//  • o título pulsa e um reflexo passa pelas letras;
//  • nuvens e pinos ondulam de leve;
//  • esferas do dragão pulsam; estrelas e pontos claros cintilam.
// Posições em pixels da imagem (1024 x 1536).
shader_type canvas_item;

uniform sampler2D camadas : filter_linear, repeat_disable;
uniform float forca_paralaxe = 22.0;
uniform float periodo_reflexo = 3.8;
const vec2 TAM = vec2(1024.0, 1536.0);
const vec2 BOLA = vec2(390.0, 645.0);
const float RAIO_BOLA = 205.0;
const vec2 PEITO = vec2(660.0, 470.0);
const vec2 CENTRO_TITULO = vec2(520.0, 1010.0);

float esfera(vec2 px, vec2 c, float r, float fase) {
	float d = length(px - c);
	float dentro = smoothstep(r, r * 0.55, d);
	return dentro * (0.5 + 0.5 * sin(TIME * 2.2 + fase));
}

vec2 girar(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void fragment() {
	// 1. Paralaxe: a câmera passeia numa curva lenta.
	vec2 cam = vec2(sin(TIME * 0.55), sin(TIME * 0.43 + 1.3) * 0.75);
	vec4 m = texture(camadas, UV);
	vec2 desloc = cam * (m.r - 0.3) * forca_paralaxe / TAM;
	m = texture(camadas, UV - desloc);
	desloc = cam * (m.r - 0.3) * forca_paralaxe / TAM;
	vec2 px = (UV - desloc) * TAM;

	// 2. Dragão respirando: o corpo cresce um pouco a partir do peito e a
	//    cabeça sobe e desce.
	float folego = sin(TIME * 1.7);
	px = PEITO + (px - PEITO) * (1.0 - 0.014 * folego * m.g);
	px.y += 4.0 * folego * m.g;

	// 3. Título pulsando (bate como um coração, a cada 1,6 s).
	float batida = pow(max(0.0, sin(TIME * 3.93)), 6.0);
	px = CENTRO_TITULO + (px - CENTRO_TITULO) * (1.0 - 0.018 * batida * m.b);

	// 4. Nuvens e pinos ondulando.
	px.x += m.a * sin(TIME * 1.1 + px.y * 0.012) * 3.5;
	px.y += m.a * cos(TIME * 0.9 + px.x * 0.010) * 2.0;

	// 5. Bola balançando (gira ±9° em volta do centro), sem mexer nas
	//    garras do dragão nem no título que ficam por cima dela.
	vec2 rel_bola = px - BOLA;
	float peso_bola = smoothstep(RAIO_BOLA * 0.80, RAIO_BOLA * 0.55, length(rel_bola)) * (1.0 - m.g) * (1.0 - m.b);
	px = BOLA + girar(rel_bola, 0.16 * sin(TIME * 1.15) * peso_bola);

	vec2 uv = clamp(px / TAM, vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, uv);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 luz = vec3(0.0);

	// 6. Reflexo no título (y 740..1240), só nas letras (claras e vivas).
	float fase = fract(TIME / periodo_reflexo);
	float pos = mix(-300.0, 1350.0, fase);
	float diag = px.x + (px.y - 740.0) * 0.55;
	float banda = smoothstep(70.0, 0.0, abs(diag - pos));
	float no_titulo = smoothstep(730.0, 760.0, px.y) * (1.0 - smoothstep(1225.0, 1255.0, px.y));
	float letra = smoothstep(0.40, 0.70, lum) * smoothstep(0.20, 0.55, sat + (lum - 0.85) * 2.0);
	luz += vec3(1.0, 0.97, 0.86) * banda * no_titulo * letra * 0.60;
	// o título acende um pouco a cada batida
	luz += c.rgb * batida * m.b * 0.12;

	// 7. Bola azul: um brilho que gira pela borda.
	vec2 rel = px - BOLA;
	float d = length(rel);
	float ang = atan(rel.y, rel.x);
	float alvo = TIME * 0.9;
	float dif = abs(mod(ang - alvo + 3.14159, 6.28318) - 3.14159);
	float arco = smoothstep(0.55, 0.0, dif) * smoothstep(RAIO_BOLA * 0.98, RAIO_BOLA * 0.80, d) * smoothstep(RAIO_BOLA * 0.45, RAIO_BOLA * 0.75, d);
	float azul = smoothstep(0.05, 0.25, c.b - c.r);
	luz += vec3(0.75, 0.90, 1.0) * arco * azul * 0.45;

	// 8. Esferas do dragão (laranja) pulsando.
	float laranja = smoothstep(0.10, 0.35, c.r - c.b) * smoothstep(0.35, 0.7, c.g);
	float esferas = esfera(px, vec2(190.0, 170.0), 125.0, 0.0)
		+ esfera(px, vec2(135.0, 1310.0), 85.0, 2.1)
		+ esfera(px, vec2(905.0, 1310.0), 85.0, 4.2);
	luz += vec3(1.0, 0.65, 0.2) * esferas * laranja * 0.24;

	// 9. Cintilar: pontos claros piscam, cada célula num ritmo.
	vec2 cel = floor(px / 14.0);
	float h = fract(sin(dot(cel, vec2(12.9898, 78.233))) * 43758.5453);
	float pisca = pow(max(0.0, sin(TIME * (1.2 + h * 2.4) + h * 6.2831)), 10.0);
	float claro = smoothstep(0.84, 0.97, lum);
	luz += vec3(1.0, 0.95, 0.80) * pisca * claro * 0.40;

	COLOR = vec4(c.rgb + luz, c.a);
}
