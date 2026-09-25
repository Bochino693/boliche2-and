extends Node2D


@export var deslocamento_empurrao_max_x: float = 28.0
@export var deslocamento_empurrao_max_y: float = 22.0
@export var duracao_empurrao: float = 0.080
@export var duracao_tombo: float = 0.17
@export var arrasto_no_chao: float = 0.90

@export var rotacao_max_queda: float = 138.0
@export var distancia_voo_max: float = 70.0

@export var atrito_plano: float = 0.94
@export var atrito_rotacional: float = 0.91
@export var limiar_deslocamento: float = 0.08
@export var limiar_colisao_em_cadeia: float = 0.12
@export var ganho_rotacao_impacto: float = 108.0
@export var ganho_deslocamento_impacto: float = 68.0
@export var deslocamento_maximo_sem_cair: float = 12.0


@export var largura_visual_alvo: float = 76.0
@export var altura_visual_alvo: float = 144.0
@export var largura_visual_down: float = 148.0
@export var altura_visual_down: float = 116.0
@export var largura_visual_strike: float = 144.0
@export var altura_visual_strike: float = 114.0

@export var largura_colisao_base: float = 48.0
@export var altura_colisao_base: float = 88.0

@export var escala_idle: float = 1.00
@export var escala_down_left: float = 1.03
@export var escala_down_rt: float = 1.03
@export var escala_strike: float = 1.02

@export var limiar_queda: float = 0.15
@export var limiar_quase_queda: float = 0.07


@export var numero: int = 1

@export var fator_profundidade: float = 1.0
@export var mistura_profundidade_down: float = 0.46
@export var mistura_profundidade_strike: float = 0.50

@export var animacao_base: String = "idle"

@export var offset_idle: Vector2 = Vector2(0, 0)
@export var offset_down_left: Vector2 = Vector2(6, 3)
@export var offset_down_rt: Vector2 = Vector2(6, 3)
@export var offset_strike: Vector2 = Vector2(1, 2)

@export var linha_base_local: float = 26.0

@export var amortecimento_idle: float = 0.72
@export var duracao_queda: float = 0.22
@export var duracao_voo: float = 0.10

@export var duracao_quique: float = 0.20
@export var intensidade_quique: float = 1.32
@export var deslocamento_quique_y: float = 20.0
@export var deslocamento_quique_x: float = 8.0
@export var rotacao_quique: float = 11.0
@export var usar_quique_no_tatame: bool = true


@export var tempo_espera_apos_queda: float = 0.85
@export var tempo_fade_apos_queda: float = 0.28

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var numero_label: Label = $Label


var derrubado: bool = false
var hover: bool = false
var game_ref: Node = null

var empurrando: bool = false
var velocidade_plano: Vector2 = Vector2.ZERO
var velocidade_rotacional: float = 0.0
var origem_ultimo_impacto: Vector2 = Vector2.ZERO
var posicao_base_local: Vector2 = Vector2.ZERO
var animacao_atual_nome: String = "idle"
var escala_fx: float = 1.0
var escala_travada_queda: Vector2 = Vector2.ZERO
var travar_escala_na_queda: bool = false

var sumindo_apos_queda: bool = false
var finalizando_queda: bool = false
var em_quase_queda: bool = false
var forca_acumulada: Vector2 = Vector2.ZERO

var ref_idle: Vector2 = Vector2(64, 128)
var ref_down_left: Vector2 = Vector2(96, 96)
var ref_down_rt: Vector2 = Vector2(96, 96)
var ref_strike: Vector2 = Vector2(96, 96)


var _fx: FxPino = null
## Distância (px) até onde um pino que cai alcança o vizinho.
const DISTANCIA_VIZINHO := 110.0
var _caiu_em_ms: int = 0
var _escala_caido: Vector2 = Vector2.ZERO
var _pos_sprite_caido: Vector2 = Vector2.ZERO
var _tw_balanco: Tween = null


func _ready() -> void:
	if numero_label != null:
		numero_label.text = str(numero)
		numero_label.add_theme_font_size_override("font_size", 24)
		numero_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.35))
		numero_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.10))
		numero_label.add_theme_constant_override("outline_size", 5)
		numero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		numero_label.size = Vector2(56, 32)
		numero_label.z_index = 1000
		numero_label.visible = true

	if sprite != null and sprite.sprite_frames != null:
		for nome in sprite.sprite_frames.get_animation_names():
			sprite.sprite_frames.set_animation_loop(nome, nome == "idle")

	if sprite != null and not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)

	if sprite != null and not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)

	aplicar_shader_borda_suave()
	cachear_referencias_animacoes()
	atualizar_posicao_base()
	resetar()

	# Dragon Bowling 2: faíscas, rastro e poeira da queda (criados já).
	_fx = FxPino.new()
	add_child(_fx)


func cachear_referencias_animacoes() -> void:
	ref_idle = obter_maior_tamanho_animacao("idle")
	ref_down_left = obter_maior_tamanho_animacao("down_left")
	ref_down_rt = obter_maior_tamanho_animacao("down_rt")
	ref_strike = obter_maior_tamanho_animacao("strike")

	var ref_down_unificada := Vector2(
		max(ref_down_left.x, ref_down_rt.x),
		max(ref_down_left.y, ref_down_rt.y)
	)
	ref_down_left = ref_down_unificada
	ref_down_rt = ref_down_unificada


func obter_maior_tamanho_animacao(nome: String) -> Vector2:
	var max_sz := Vector2(64, 128)
	if sprite == null or sprite.sprite_frames == null:
		return max_sz
	if not sprite.sprite_frames.has_animation(nome):
		return max_sz

	var total := sprite.sprite_frames.get_frame_count(nome)
	max_sz = Vector2.ZERO
	var achou := false

	for i in range(total):
		var tex = sprite.sprite_frames.get_frame_texture(nome, i)
		if tex != null:
			var sz = tex.get_size()
			max_sz.x = max(max_sz.x, sz.x)
			max_sz.y = max(max_sz.y, sz.y)
			achou = true

	return max_sz if achou else Vector2(64, 128)


func _process(delta: float) -> void:
	if sprite == null or not empurrando:
		return

	simular_empurrao(delta)


func _draw() -> void:
	if hover and not derrubado:
		draw_line(Vector2(-14, linha_base_local), Vector2(14, linha_base_local), Color(1, 0.9, 0.2, 0.65), 3.0)


func obter_referencia_animacao() -> Vector2:
	match animacao_atual_nome:
		"idle":
			return ref_idle
		"down_left":
			return ref_down_left
		"down_rt":
			return ref_down_rt
		"strike":
			return ref_strike
	return ref_idle


func obter_fator_animacao() -> float:
	match animacao_atual_nome:
		"idle":
			return fator_profundidade
		"down_left", "down_rt":
			return lerp(1.0, fator_profundidade, mistura_profundidade_down)
		"strike":
			return lerp(1.0, fator_profundidade, mistura_profundidade_strike)
	return fator_profundidade


func obter_box_animacao() -> Vector2:
	var f := obter_fator_animacao()
	match animacao_atual_nome:
		"idle":
			return Vector2(largura_visual_alvo, altura_visual_alvo) * f
		"down_left", "down_rt":
			return Vector2(largura_visual_down, altura_visual_down) * f
		"strike":
			return Vector2(largura_visual_strike, altura_visual_strike) * f
	return Vector2(largura_visual_alvo, altura_visual_alvo) * f


func obter_multiplicador_animacao() -> float:
	match animacao_atual_nome:
		"idle":
			return escala_idle
		"down_left":
			return escala_down_left
		"down_rt":
			return escala_down_rt
		"strike":
			return escala_strike
	return 1.0


func obter_offset_animacao() -> Vector2:
	match animacao_atual_nome:
		"idle":
			return offset_idle
		"down_left":
			return offset_down_left
		"down_rt":
			return offset_down_rt
		"strike":
			return offset_strike
	return Vector2.ZERO


func atualizar_posicao_base() -> void:
	posicao_base_local = position


func recalcular_visual() -> void:
	atualizar_tamanho_base()

func atualizar_tamanho_base(mult_hover: float = 1.0) -> void:
	if sprite == null:
		return

	if derrubado:
		fixar_tamanho_visual_derrubado()
		return

	var ref: Vector2 = obter_referencia_animacao()
	if ref.x <= 0.0 or ref.y <= 0.0:
		return

	var alvo: Vector2 = obter_box_animacao()
	var ex: float = alvo.x / ref.x
	var ey: float = alvo.y / ref.y
	var eb: float = min(ex, ey)
	var ef: float = eb * obter_multiplicador_animacao() * mult_hover * escala_fx

	sprite.scale = Vector2(ef, ef)
	ajustar_ancora_visual(ref, ef)
	atualizar_posicao_numero(ref, ef)


func ajustar_ancora_visual(ref_size: Vector2, escala_final: float) -> void:
	if sprite == null:
		return
	var ofs := offset_idle if travar_escala_na_queda else obter_offset_animacao()
	sprite.position = Vector2(ofs.x, linha_base_local - ref_size.y * escala_final + ofs.y)
	sprite.offset = Vector2.ZERO


func atualizar_posicao_numero(ref_size: Vector2, escala_final: float) -> void:
	if numero_label == null:
		return

	var topo_y := sprite.position.y
	var centro_x := sprite.position.x
	numero_label.position = Vector2(
		centro_x - numero_label.size.x * 0.5,
		topo_y + ref_size.y * escala_final * 0.12
	)

	if derrubado:
		numero_label.position.x += clamp(sprite.rotation_degrees * 0.10, -7.0, 7.0)


func obter_area_colisao() -> Vector2:
	var box: Vector2 = Vector2(largura_colisao_base, altura_colisao_base)

	match animacao_atual_nome:
		"idle":
			box *= 1.0
		"down_left", "down_rt":
			box = Vector2(box.x * 1.24, box.y * 0.72)
		"strike":
			box = Vector2(box.x * 1.18, box.y * 0.76)

	box *= fator_profundidade

	match numero:
		1:
			box *= Vector2(1.06, 1.08)
		2, 3:
			box *= Vector2(1.03, 1.04)
		7, 10:
			box *= Vector2(0.98, 1.00)

	return box

func foi_clicado(mouse_global: Vector2) -> bool:
	var area := obter_area_colisao()
	var rect := Rect2(global_position + Vector2(-area.x * 0.5, -area.y * 0.5), area)
	return rect.has_point(mouse_global)


func atualizar_hover(mouse_global: Vector2) -> void:
	var novo_hover: bool = not derrubado and foi_clicado(mouse_global)
	if hover != novo_hover:
		hover = novo_hover
		if sprite != null:
			sprite.modulate = Color(1.06, 1.06, 1.0, sprite.modulate.a) if hover else Color(1, 1, 1, sprite.modulate.a)
		atualizar_tamanho_base(1.015 if hover else 1.0)
		queue_redraw()


func receber_forca(forca_vec: Vector2, magnitude: float, origem: Vector2) -> void:
	if derrubado:
		return

	# ── Proteção: ignora força se este pino está na lista de sobreviventes ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			return

	var dir := forca_vec.normalized()
	if dir.length() <= 0.001:
		dir = (global_position - origem).normalized()

	origem_ultimo_impacto = origem

	var peso_local: float = 1.0
	match numero:
		1:
			peso_local = 0.92
		2, 3:
			peso_local = 0.95
		4, 5, 6:
			peso_local = 1.00
		7, 10:
			peso_local = 1.03

	var ganho: float = magnitude / peso_local

	forca_acumulada += dir * ganho
	velocidade_plano += Vector2(dir.x * 1.05, -abs(dir.y) * 0.62) * ganho * ganho_deslocamento_impacto
	velocidade_rotacional += dir.x * ganho * ganho_rotacao_impacto
	empurrando = true

	var magnitude_total: float = forca_acumulada.length()

	var limiar_efetivo: float = limiar_queda
	if numero in [7, 8, 9, 10]:
		limiar_efetivo = limiar_queda * 0.70
	elif numero in [4, 5, 6]:
		limiar_efetivo = limiar_queda * 0.82

	if magnitude_total >= limiar_efetivo:
		var lado: String = "down_rt" if forca_acumulada.x >= 0.0 else "down_left"
		if abs(forca_acumulada.x) < 0.05:
			lado = "strike"

		cair_voando(lado, clamp(magnitude_total, 0.98, 1.72), origem)
		forca_acumulada = Vector2.ZERO
	elif magnitude_total >= limiar_quase_queda * 0.85:
		if not em_quase_queda and not finalizando_queda:
			_oscilar(dir, magnitude_total)


func simular_empurrao(delta: float) -> void:
	if derrubado:
		return
	if not empurrando:
		return
		
		
	# ── Proteção: cancela empurrão se protegido ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			empurrando = false
			velocidade_plano = Vector2.ZERO
			velocidade_rotacional = 0.0
			forca_acumulada = Vector2.ZERO
			position = posicao_base_local
			return

	position += velocidade_plano * delta
	velocidade_plano *= pow(atrito_plano, delta * 60.0)

	if sprite != null:
		sprite.rotation_degrees += velocidade_rotacional * delta

	velocidade_rotacional *= pow(atrito_rotacional, delta * 60.0)

	var deslocamento: float = position.distance_to(posicao_base_local)

	if deslocamento >= deslocamento_maximo_sem_cair or forca_acumulada.length() >= limiar_colisao_em_cadeia:
		var lado: String = "down_rt" if velocidade_plano.x >= 0.0 else "down_left"
		if abs(velocidade_plano.x) < 1.2:
			lado = "strike"

		cair_voando(lado, clamp(max(forca_acumulada.length(), 0.98), 0.98, 1.60), origem_ultimo_impacto)
		forca_acumulada = Vector2.ZERO
		return

	if velocidade_plano.length() < limiar_deslocamento and abs(velocidade_rotacional) < 1.0:
		empurrando = false
		velocidade_plano = Vector2.ZERO
		velocidade_rotacional = 0.0

		if not derrubado:
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_SINE)
			tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "position", posicao_base_local, 0.08)
			if sprite != null:
				tw.parallel().tween_property(sprite, "rotation_degrees", 0.0, 0.08)


func _oscilar(direcao: Vector2, magnitude: float) -> void:
	if derrubado or sprite == null:
		return

	em_quase_queda = true

	var lado_x: float = direcao.x
	if abs(lado_x) < 0.05:
		lado_x = 1.0 if randf() > 0.5 else -1.0

	var forca_local: float = clamp(magnitude, 0.65, 1.15)

	var amp_rot: float = lerp(8.0, 18.0, inverse_lerp(0.65, 1.15, forca_local)) * sign(lado_x)
	var amp_x: float = lerp(3.0, 7.0, inverse_lerp(0.65, 1.15, forca_local)) * sign(lado_x)

	var base_pos: Vector2 = sprite.position
	var base_rot: float = sprite.rotation_degrees

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)

	tw.tween_property(sprite, "rotation_degrees", base_rot + amp_rot, 0.055)
	tw.parallel().tween_property(sprite, "position", base_pos + Vector2(amp_x, -abs(amp_x) * 0.25), 0.055)

	tw.tween_property(sprite, "rotation_degrees", base_rot - amp_rot * 0.82, 0.095)
	tw.parallel().tween_property(sprite, "position", base_pos + Vector2(-amp_x * 0.72, 0.0), 0.095)

	tw.tween_property(sprite, "rotation_degrees", base_rot + amp_rot * 0.26, 0.055)
	tw.parallel().tween_property(sprite, "position", base_pos + Vector2(amp_x * 0.20, 0.0), 0.055)

	tw.tween_property(sprite, "rotation_degrees", base_rot, 0.070)
	tw.parallel().tween_property(sprite, "position", base_pos, 0.070)

	tw.finished.connect(func() -> void:
		em_quase_queda = false
		forca_acumulada = Vector2.ZERO
	)


func cair(animacao: String, intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if derrubado:
		return
	cair_voando(animacao, intensidade, origem_impacto)


# ─────────────────────────────────────────────────────────────────────────────
# cair_voando
#
# O delay_s simula o tempo que a onda de impacto leva até este pino.
# TODOS os efeitos visuais (flash, squash, rotação, skew) ficam DEPOIS
# do await — o pino só reage quando a "onda" fisicamente chega nele.
# ─────────────────────────────────────────────────────────────────────────────
func cair_voando(animacao: String, intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO, delay_s: float = 0.0) -> void:
	if derrubado:
		return
		
	if delay_s > 0.001:
		await get_tree().create_timer(delay_s).timeout
		if derrubado:
			return

	# ── Proteção pós-delay: se virou sobrevivente durante o delay, aborta ──
	if game_ref != null and "pinos_protegidos_sobreviventes" in game_ref:
		if numero in game_ref.pinos_protegidos_sobreviventes:
			return

	# Pausa silenciosa — o pino fica completamente estático até aqui.
	# Nada pisca, nada se move. A reação só começa após o delay.
	if delay_s > 0.001:
		await get_tree().create_timer(delay_s).timeout
		if derrubado:
			return

	# ── A partir daqui a bola tocou este pino ────────────────
	if _tw_balanco != null and _tw_balanco.is_valid():
		_tw_balanco.kill()
	if sprite != null:
		sprite.rotation_degrees = 0.0
	derrubado = true
	hover = false
	escala_fx = 1.0
	sumindo_apos_queda = false
	finalizando_queda = false
	em_quase_queda = false
	empurrando = false
	forca_acumulada = Vector2.ZERO
	velocidade_plano = Vector2.ZERO
	velocidade_rotacional = 0.0

	if numero_label != null:
		numero_label.modulate = Color(1, 1, 1, 1)
		numero_label.visible = true
		var tw_num: Tween = create_tween()
		tw_num.tween_property(numero_label, "modulate", Color(1, 1, 1, 0.0), 0.05)
		tw_num.finished.connect(func() -> void:
			if numero_label != null:
				numero_label.visible = false
		)

	var tipo_queda: String = animacao
	if tipo_queda not in ["down_left", "down_rt", "strike"]:
		tipo_queda = "strike"

	animacao_atual_nome = tipo_queda
	travar_escala_na_queda = true

	if sprite != null:
		escala_travada_queda = sprite.scale
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
			sprite.stop()
			sprite.frame = 0
		fixar_tamanho_visual_derrubado()

	# ── Flash de contato — dispara AQUI, depois do delay ─────
	# O pino "acende" exatamente quando é tocado, nunca antes.
	if sprite != null:
		var tw_flash: Tween = create_tween()
		tw_flash.set_parallel(true)
		tw_flash.tween_property(sprite, "modulate", Color(1.55, 1.45, 1.30, 1.0), 0.020)
		tw_flash.chain().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.052)

	# ── Quem me acertou: a bola, ou um pino vizinho que caiu antes? ──
	# Na cascata do strike cada pino recebe um atraso; o que caiu logo
	# antes, entre a bola e este, é quem "bate" nele (reação em cadeia).
	var batedor: Vector2 = _pino_que_me_acertou(origem_impacto)
	var por_pino: bool = batedor != Vector2.INF
	if por_pino:
		origem_impacto = batedor
	_caiu_em_ms = Time.get_ticks_msec()

	# ── Direção: para longe de quem bateu, sempre com um pouco "para trás"
	# (pista acima, rumo ao fosso) ──
	var dir: Vector2 = global_position - origem_impacto
	if dir.length() < 0.5:
		dir = Vector2(randf_range(-0.3, 0.3), -1.0)
	dir = dir.normalized()
	if dir.y > -0.22:
		dir = Vector2(dir.x, -0.22).normalized()

	# Faíscas + lascas no ponto de contato, e o rastro do voo.
	if _fx != null and sprite != null:
		var centro_local: Vector2 = sprite.offset
		var quadro: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) if sprite.sprite_frames != null else null
		if quadro != null and not sprite.centered:
			centro_local += quadro.get_size() * 0.5
		var centro: Vector2 = sprite.get_global_transform() * centro_local
		if por_pino:
			# o choque é entre os dois pinos, mais perto de quem bateu
			centro += (origem_impacto - global_position) * 0.35
		_fx.faiscas(centro, Vector2(dir.x, dir.y - 0.6).normalized(), 0.62 if por_pino else 1.0)
		_fx.rastro(sprite)

	if sprite == null:
		return

	var forca: float = clamp(intensidade, 0.90, 1.60)
	var t_forca: float = inverse_lerp(0.90, 1.60, forca)

	var lado_rot: float = signf(dir.x)
	if absf(dir.x) < 0.08:
		lado_rot = 1.0 if randf() > 0.5 else -1.0
	if tipo_queda == "down_left":
		lado_rot = -1.0
	elif tipo_queda == "down_rt":
		lado_rot = 1.0

	# Tipo do tombo:
	#  • PARA TRÁS (bola/pino de frente): o pino deita apontando para o
	#    fundo — em perspectiva ele "encurta", sobe na pista e gira pouco;
	#  • DE LADO (golpe lateral): gira ~90° e escorrega na diagonal.
	var de_lado: bool = (tipo_queda != "strike" and absf(dir.x) > 0.35) or absf(dir.x) > 0.72
	var s0: Vector2 = escala_travada_queda if escala_travada_queda != Vector2.ZERO else sprite.scale
	var altura: float = ref_idle.y * s0.y
	var pos_sprite0: Vector2 = sprite.position

	var recuo: float = lerp(40.0, 96.0, t_forca) * clamp(-dir.y, 0.35, 1.0) * randf_range(0.85, 1.15)
	var desvio: float = dir.x * lerp(24.0, 70.0, t_forca) * randf_range(0.8, 1.2)
	var deitar: float
	var giro: float
	if de_lado:
		deitar = randf_range(0.80, 0.92)
		giro = lado_rot * randf_range(74.0, 106.0)
		recuo *= 0.55
	else:
		deitar = randf_range(0.46, 0.58)
		giro = lado_rot * randf_range(22.0, 52.0)
	if por_pino:
		recuo *= 0.8
		desvio *= 0.8
	var s_final := Vector2(s0.x * randf_range(0.90, 0.96), s0.y * deitar)
	# deitado, o pino fica rente ao chão: o centro desce
	var desce: float = altura * 0.5 * (1.0 - (0.30 if de_lado else deitar)) * 0.85
	var pos_sprite_final: Vector2 = pos_sprite0 + Vector2(0.0, desce)
	var base_pos: Vector2 = position
	var alvo: Vector2 = base_pos + Vector2(desvio, -recuo)
	var sombra := Color(0.86, 0.86, 0.90, 1.0)

	_escala_caido = Vector2.ZERO
	var tw: Tween = create_tween()

	# Fase 1 — tranco (achata no contato e já começa a inclinar)
	tw.tween_property(sprite, "scale", Vector2(s0.x * 1.12, s0.y * 0.88), 0.035)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position", base_pos + dir * 9.0, 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "rotation_degrees", giro * 0.14, 0.06)
	tw.parallel().tween_property(sprite, "modulate", Color(1.25, 1.2, 1.12, 1.0), 0.03)

	# Fase 2 — tombo: o voo desacelera (arrasto) e a queda acelera (gravidade)
	var t_voo: float = lerp(0.30, 0.36, t_forca)
	var t_tombo: float = 0.24
	tw.tween_property(self, "position", alvo, t_voo)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "rotation_degrees", giro, t_tombo)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "scale", s_final, t_tombo)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "position", pos_sprite_final, t_tombo)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "modulate", sombra, t_tombo)

	tw.finished.connect(func() -> void:
		_escala_caido = s_final
		_pos_sprite_caido = pos_sprite_final
		if _fx != null:
			_fx.poeira(to_global(Vector2(0, linha_base_local)))
		_balancar_vizinhos(dir)
		_aplicar_quique_no_tatame(forca)
	)


## O pino que caiu há pouco, vizinho, e que está entre quem bateu e este.
## Devolve a base dele (global) ou Vector2.INF se foi a bola.
func _pino_que_me_acertou(origem: Vector2) -> Vector2:
	var pai := get_parent() as Node2D
	if pai == null:
		return Vector2.INF
	var agora: int = Time.get_ticks_msec()
	var origem_local: Vector2 = pai.to_local(origem)
	var minha_dist: float = posicao_base_local.distance_to(origem_local)
	var melhor := Vector2.INF
	var melhor_d: float = DISTANCIA_VIZINHO
	for irmao in pai.get_children():
		if irmao == self or not ("_caiu_em_ms" in irmao) or not irmao.derrubado:
			continue
		var quando: int = irmao._caiu_em_ms
		if quando <= 0 or agora - quando > 700 or agora - quando < 15:
			continue
		var base_irmao: Vector2 = irmao.posicao_base_local
		var d: float = posicao_base_local.distance_to(base_irmao)
		if d >= melhor_d or base_irmao.distance_to(origem_local) >= minha_dist:
			continue
		melhor_d = d
		melhor = pai.to_global(base_irmao)
	return melhor


## Quem ficou em pé do lado balança com o tranco (só visual: não muda o
## resultado da jogada).
func _balancar_vizinhos(dir: Vector2) -> void:
	var pai := get_parent()
	if pai == null:
		return
	for irmao in pai.get_children():
		if irmao == self or not irmao.has_method("balancar") or irmao.derrubado:
			continue
		var d: float = posicao_base_local.distance_to(irmao.posicao_base_local)
		if d < DISTANCIA_VIZINHO * 1.15:
			irmao.balancar(irmao.posicao_base_local - posicao_base_local, 1.0 - d / (DISTANCIA_VIZINHO * 1.3))


func balancar(de_onde: Vector2, forca: float) -> void:
	if derrubado or sprite == null or em_quase_queda or empurrando:
		return
	if _tw_balanco != null and _tw_balanco.is_valid():
		return
	var lado: float = signf(de_onde.x) if absf(de_onde.x) > 1.0 else (1.0 if randf() > 0.5 else -1.0)
	var amp: float = lerp(3.0, 9.0, clamp(forca, 0.0, 1.0)) * lado
	var base_rot: float = sprite.rotation_degrees
	_tw_balanco = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_balanco.tween_property(sprite, "rotation_degrees", base_rot + amp, 0.07)
	_tw_balanco.tween_property(sprite, "rotation_degrees", base_rot - amp * 0.6, 0.12)
	_tw_balanco.tween_property(sprite, "rotation_degrees", base_rot + amp * 0.25, 0.10)
	_tw_balanco.tween_property(sprite, "rotation_degrees", base_rot, 0.10)


## Pouso: o pino deitado dá um quique curto na pista.
func _aplicar_quique_no_tatame(forca: float = 1.0) -> void:
	if sprite == null:
		return
	if finalizando_queda:
		return

	finalizando_queda = true
	if not usar_quique_no_tatame or _escala_caido == Vector2.ZERO:
		finalizando_queda = false
		_sumir_apos_queda()
		return

	var intensidade: float = clamp(forca * intensidade_quique, 0.90, 1.55)
	var base_rot: float = sprite.rotation_degrees
	var base_pos_no: Vector2 = position
	var lado: float = signf(base_rot) if absf(base_rot) > 1.0 else 1.0
	var pulo: float = deslocamento_quique_y * 0.42 * intensidade
	var qr: float = rotacao_quique * 0.6 * intensidade * lado

	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	# achata no chão, pula um pouco e assenta
	tw.tween_property(sprite, "scale", Vector2(_escala_caido.x * 1.06, _escala_caido.y * 0.86), 0.035)
	tw.tween_property(self, "position", base_pos_no + Vector2(0, -pulo), 0.07).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "scale", _escala_caido, 0.07)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot + qr, 0.07)
	tw.tween_property(self, "position", base_pos_no, 0.08).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot - qr * 0.3, 0.08)
	tw.tween_property(self, "position", base_pos_no + Vector2(0, -pulo * 0.22), 0.05).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot, 0.05)
	tw.tween_property(self, "position", base_pos_no, 0.05).set_ease(Tween.EASE_IN)

	tw.finished.connect(func() -> void:
		finalizando_queda = false
		_sumir_apos_queda()
	)


## Depois de deitado um pouco, escorrega para o fosso e some.
func _sumir_apos_queda() -> void:
	if sumindo_apos_queda:
		return

	sumindo_apos_queda = true

	var tw := create_tween()
	tw.tween_interval(tempo_espera_apos_queda)

	if sprite != null:
		tw.tween_property(sprite, "modulate", Color(0.8, 0.8, 0.85, 0.0), tempo_fade_apos_queda)
		tw.parallel().tween_property(self, "position", position + Vector2(0, -26), tempo_fade_apos_queda)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if numero_label != null:
		tw.parallel().tween_property(numero_label, "modulate", Color(1, 1, 1, 0.0), tempo_fade_apos_queda)


func sumir_apos_queda() -> void:
	_sumir_apos_queda()


func impacto_visual(intensidade: float = 1.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if sprite == null:
		return

	var ganho: float = clamp(intensidade, 0.92, 1.50)
	var base_mod: Color = sprite.modulate
	var base_rot: float = sprite.rotation_degrees
	var base_pos: Vector2 = sprite.position

	var lado: float = sign(global_position.x - origem_impacto.x)
	if lado == 0.0:
		lado = 1.0

	var dx: float = lado * lerp(1.2, 2.8, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))
	var dy: float = -lerp(2.4, 4.6, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))
	var rot: float = lado * lerp(2.0, 4.4, clamp((ganho - 0.9) / 0.6, 0.0, 1.0))

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", base_pos + Vector2(dx, dy), 0.040)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot + rot, 0.045)
	tw.parallel().tween_property(sprite, "modulate", Color(1.14, 1.14, 1.14, 1.0), 0.040)

	var tw2: Tween = create_tween()
	tw2.tween_property(self, "escala_fx", 1.04, 0.035)
	tw2.tween_property(self, "escala_fx", 1.0, 0.070)

	tw.tween_property(sprite, "position", base_pos, 0.065)
	tw.parallel().tween_property(sprite, "modulate", base_mod, 0.065)


func abalo_lateral(intensidade: float = 1.0) -> void:
	if derrubado or sprite == null:
		return

	var dir_x: float = 1.0 if randf() > 0.5 else -1.0
	var mag: float = clamp(intensidade * 0.35, 0.0, limiar_queda - 0.05)
	receber_forca(Vector2(dir_x, -0.2), mag, global_position + Vector2(-dir_x * 60.0, 0.0))

	var base_pos: Vector2 = sprite.position
	var base_rot: float = sprite.rotation_degrees
	var f: float = clamp(intensidade, 0.7, 1.25)

	var tw: Tween = create_tween()
	tw.tween_property(sprite, "position", base_pos + Vector2(randf_range(-1.6, 1.6) * f, 0), 0.018)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot + randf_range(-2.8, 2.8) * f, 0.018)
	tw.tween_property(sprite, "position", base_pos + Vector2(randf_range(-0.8, 0.8) * f, 0), 0.018)
	tw.parallel().tween_property(sprite, "rotation_degrees", base_rot, 0.018)
	tw.tween_property(sprite, "position", base_pos, 0.024)

	var brilho: Color = sprite.modulate
	var tw2: Tween = create_tween()
	tw2.tween_property(sprite, "modulate", Color(1.08, 1.08, 1.08, sprite.modulate.a), 0.02)
	tw2.tween_property(sprite, "modulate", brilho, 0.05)


func fixar_tamanho_visual_derrubado() -> void:
	if sprite == null:
		return

	if _escala_caido != Vector2.ZERO:
		sprite.scale = _escala_caido
		sprite.position = _pos_sprite_caido
		return

	var escala_base_queda: Vector2 = escala_travada_queda
	if escala_base_queda == Vector2.ZERO:
		escala_base_queda = sprite.scale

	sprite.scale = escala_base_queda
	ajustar_ancora_visual(ref_idle, escala_base_queda.y)
	atualizar_posicao_numero(ref_idle, escala_base_queda.y)


func destacar_acerto() -> void:
	if numero_label == null:
		return

	var brilho := numero_label.modulate
	var escala := numero_label.scale

	var tw := create_tween()
	tw.tween_property(numero_label, "scale", escala * 1.12, 0.05)
	tw.parallel().tween_property(numero_label, "modulate", Color(1.18, 1.18, 0.70, 1.0), 0.04)
	tw.tween_property(numero_label, "scale", escala, 0.10)
	tw.parallel().tween_property(numero_label, "modulate", brilho, 0.10)


func resetar() -> void:
	derrubado = false
	_caiu_em_ms = 0
	_escala_caido = Vector2.ZERO
	if _tw_balanco != null and _tw_balanco.is_valid():
		_tw_balanco.kill()
	hover = false
	animacao_atual_nome = "idle"
	escala_fx = 1.0
	sumindo_apos_queda = false
	finalizando_queda = false
	em_quase_queda = false
	forca_acumulada = Vector2.ZERO
	position = posicao_base_local
	rotation_degrees = 0.0
	modulate = Color(1, 1, 1, 1)
	travar_escala_na_queda = false
	escala_travada_queda = Vector2.ZERO

	if sprite != null:
		sprite.visible = true
		sprite.material = null
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.rotation_degrees = 0.0
		sprite.skew = 0.0
		sprite.position = Vector2.ZERO
		sprite.offset = Vector2.ZERO
		sprite.scale = Vector2.ONE

	if numero_label != null:
		numero_label.modulate = Color(1, 1, 1, 1)
		numero_label.scale = Vector2.ONE
		numero_label.visible = true

	if sprite != null and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
			sprite.frame = 0
		else:
			var nomes := sprite.sprite_frames.get_animation_names()
			if nomes.size() > 0:
				sprite.play(nomes[0])
				sprite.frame = 0

	atualizar_tamanho_base()


func _on_frame_changed() -> void:
	if derrubado:
		return

	atualizar_tamanho_base(1.015 if hover and not derrubado else 1.0)


func aplicar_shader_borda_suave() -> void:
	if sprite == null:
		return

	sprite.material = null
	# Os frames de 200 a 1024 px sao reduzidos na pista; mipmaps
	# evitam serrilhado e cintilacao nas bordas dos pinos.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func forcar_queda_imediata(animacao: String, intensidade: float = 3.0, origem_impacto: Vector2 = Vector2.ZERO) -> void:
	if derrubado:
		return

	em_quase_queda = false
	finalizando_queda = false
	empurrando = false
	forca_acumulada = Vector2.ZERO
	velocidade_plano = Vector2.ZERO
	velocidade_rotacional = 0.0

	if sprite != null:
		sprite.rotation_degrees = 0.0
		sprite.skew = 0.0
		sprite.modulate = Color(1, 1, 1, 1)

	cair_voando(animacao, intensidade, origem_impacto, 0.0)


func _on_anim_finished() -> void:
	if derrubado and sprite != null and sprite.animation != "idle":
		var total := sprite.sprite_frames.get_frame_count(sprite.animation)
		if total > 0:
			sprite.stop()
			sprite.frame = total - 1
			escala_fx = 1.0
			fixar_tamanho_visual_derrubado()
			if not finalizando_queda:
				_aplicar_quique_no_tatame(1.0)
