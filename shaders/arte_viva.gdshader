// ARTE DA ABERTURA VIVA (Dragon Bowling 2) — sobre sprites/dragon_bow.png.
//  • um reflexo diagonal passa pelas letras do título de tempos em tempos;
//  • o brilho da bola azul gira na borda dela (parece que ela rola);
//  • as esferas do dragão pulsam;
//  • estrelas e pontos claros cintilam, cada um no seu ritmo.
// As posições estão em pixels da imagem (1024 x 1536).
shader_type canvas_item;

uniform float periodo_reflexo = 3.8;
const vec2 TAM = vec2(1024.0, 1536.0);
const vec2 BOLA = vec2(430.0, 610.0);
const float RAIO_BOLA = 205.0;

float esfera(vec2 px, vec2 c, float r, float fase) {
	float d = length(px - c);
	float dentro = smoothstep(r, r * 0.55, d);
	return dentro * (0.5 + 0.5 * sin(TIME * 2.2 + fase));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = UV * TAM;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 luz = vec3(0.0);

	// 1. Reflexo no título (y 740..1240), só nas letras (claras e vivas).
	float fase = fract(TIME / periodo_reflexo);
	float pos = mix(-300.0, 1350.0, fase);
	float diag = px.x + (px.y - 740.0) * 0.55;
	float banda = smoothstep(70.0, 0.0, abs(diag - pos));
	float no_titulo = smoothstep(730.0, 760.0, px.y) * (1.0 - smoothstep(1225.0, 1255.0, px.y));
	float letra = smoothstep(0.40, 0.70, lum) * smoothstep(0.20, 0.55, sat + (lum - 0.85) * 2.0);
	luz += vec3(1.0, 0.97, 0.86) * banda * no_titulo * letra * 0.60;

	// 2. Bola azul: um brilho que gira pela borda.
	vec2 rel = px - BOLA;
	float d = length(rel);
	float ang = atan(rel.y, rel.x);
	float alvo = TIME * 0.9;
	float dif = abs(mod(ang - alvo + 3.14159, 6.28318) - 3.14159);
	float arco = smoothstep(0.55, 0.0, dif) * smoothstep(RAIO_BOLA * 0.98, RAIO_BOLA * 0.80, d) * smoothstep(RAIO_BOLA * 0.45, RAIO_BOLA * 0.75, d);
	float azul = smoothstep(0.05, 0.25, c.b - c.r);
	luz += vec3(0.75, 0.90, 1.0) * arco * azul * 0.45;

	// 3. Esferas do dragão (laranja) pulsando.
	float laranja = smoothstep(0.10, 0.35, c.r - c.b) * smoothstep(0.35, 0.7, c.g);
	float esferas = esfera(px, vec2(190.0, 170.0), 125.0, 0.0)
		+ esfera(px, vec2(120.0, 1310.0), 95.0, 2.1)
		+ esfera(px, vec2(900.0, 1310.0), 95.0, 4.2);
	luz += vec3(1.0, 0.65, 0.2) * esferas * laranja * 0.22;

	// 4. Cintilar: pontos claros piscam, cada célula num ritmo.
	vec2 cel = floor(px / 14.0);
	float h = fract(sin(dot(cel, vec2(12.9898, 78.233))) * 43758.5453);
	float pisca = pow(max(0.0, sin(TIME * (1.2 + h * 2.4) + h * 6.2831)), 10.0);
	float claro = smoothstep(0.84, 0.97, lum);
	luz += vec3(1.0, 0.95, 0.80) * pisca * claro * 0.40;

	COLOR = vec4(c.rgb + luz, c.a);
}
