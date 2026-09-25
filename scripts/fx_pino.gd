class_name FxPino
extends Node2D

## EFEITOS DA QUEDA DE UM PINO (Dragon Bowling 2).
##
##  • no contato (bola ou outro pino): clarão, anel de choque, faíscas em
##    estrela de 4 pontas e lascas de madeira (brancas e vermelhas);
##  • rastro: duas cópias do pino, translúcidas, que ficam para trás;
##  • no pouso: uma fumacinha rasteira, bem leve.
##
## As texturas são de alta resolução com forma de verdade
## (tools/gerar_particulas.py) — nada de pontinho quadrado ampliado.
## Tudo é criado UMA vez, quando o pino nasce (criar nós na hora do strike
## engasgava a TV Box); na jogada só se reinicia o que já existe.

const TEX_ESTRELA := preload("res://sprites/fx/estrela.png")
const TEX_BRILHO := preload("res://sprites/fx/brilho.png")
const TEX_LASCA := preload("res://sprites/fx/lasca.png")
const TEX_FUMACA := preload("res://sprites/fx/fumaca.png")
const TEX_ANEL := preload("res://sprites/fx/anel.png")

const COR_FAISCA_1 := Color(1.0, 0.98, 0.85, 1.0)
const COR_FAISCA_2 := Color(1.0, 0.72, 0.22, 0.9)
const COR_FAISCA_3 := Color(1.0, 0.42, 0.10, 0.0)
const COR_FUMACA := Color(0.93, 0.88, 0.80, 0.30)
const BRANCO_PINO := Color(1.0, 0.98, 0.95)
const VERMELHO_PINO := Color(0.86, 0.10, 0.12)

static var _somar: CanvasItemMaterial

var _faiscas: CPUParticles2D
var _lascas: CPUParticles2D
var _fumaca: CPUParticles2D
var _clarao: Sprite2D
var _anel: Sprite2D
var _fantasmas: Array[Sprite2D] = []
var _tw_clarao: Tween


static func material_somar() -> CanvasItemMaterial:
	if _somar == null:
		_somar = CanvasItemMaterial.new()
		_somar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _somar


func _ready() -> void:
	z_index = 60

	_faiscas = _emissor(TEX_ESTRELA, 14, 0.42)
	_faiscas.material = material_somar()
	_faiscas.spread = 70.0
	_faiscas.gravity = Vector2(0, 620)
	_faiscas.initial_velocity_min = 180.0
	_faiscas.initial_velocity_max = 520.0
	_faiscas.damping_min = 120.0
	_faiscas.damping_max = 260.0
	_faiscas.scale_amount_min = 0.16
	_faiscas.scale_amount_max = 0.42
	_faiscas.angle_min = 0.0
	_faiscas.angle_max = 90.0
	_faiscas.angular_velocity_min = -240.0
	_faiscas.angular_velocity_max = 240.0
	_faiscas.scale_amount_curve = _curva([Vector2(0, 1.0), Vector2(0.6, 0.8), Vector2(1, 0.0)])
	_faiscas.color_ramp = _gradiente([0.0, 0.35, 1.0], [COR_FAISCA_1, COR_FAISCA_2, COR_FAISCA_3])

	_lascas = _emissor(TEX_LASCA, 9, 0.62)
	_lascas.spread = 55.0
	_lascas.gravity = Vector2(0, 1100)
	_lascas.initial_velocity_min = 170.0
	_lascas.initial_velocity_max = 380.0
	_lascas.scale_amount_min = 0.20
	_lascas.scale_amount_max = 0.40
	_lascas.angle_min = -180.0
	_lascas.angle_max = 180.0
	_lascas.angular_velocity_min = -720.0
	_lascas.angular_velocity_max = 720.0
	# 70 % brancas, 30 % vermelhas (as faixas do pino)
	_lascas.color_initial_ramp = _gradiente([0.0, 0.69, 0.70, 1.0],
		[BRANCO_PINO, BRANCO_PINO, VERMELHO_PINO, VERMELHO_PINO])
	_lascas.color_ramp = _gradiente([0.0, 0.75, 1.0],
		[Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])

	_fumaca = _emissor(TEX_FUMACA, 5, 0.75)
	_fumaca.direction = Vector2(0, -1)
	_fumaca.spread = 75.0
	_fumaca.gravity = Vector2(0, -20)
	_fumaca.initial_velocity_min = 25.0
	_fumaca.initial_velocity_max = 70.0
	_fumaca.damping_min = 40.0
	_fumaca.damping_max = 60.0
	_fumaca.scale_amount_min = 0.28
	_fumaca.scale_amount_max = 0.48
	_fumaca.angle_min = -180.0
	_fumaca.angle_max = 180.0
	_fumaca.scale_amount_curve = _curva([Vector2(0, 0.55), Vector2(1, 1.25)])
	_fumaca.color_ramp = _gradiente([0.0, 0.2, 1.0],
		[Color(COR_FUMACA, 0.0), COR_FUMACA, Color(COR_FUMACA, 0.0)])

	_clarao = _sprite_somado(TEX_BRILHO)
	_anel = _sprite_somado(TEX_ANEL)

	for i in 2:
		var f := Sprite2D.new()
		f.top_level = true
		f.visible = false
		f.z_index = 40
		add_child(f)
		_fantasmas.append(f)


func _emissor(tex: Texture2D, quantos: int, vida: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.emitting = false
	e.one_shot = true
	e.explosiveness = 1.0
	e.randomness = 0.4
	e.amount = quantos
	e.lifetime = vida
	e.local_coords = false
	e.texture = tex
	add_child(e)
	return e


func _sprite_somado(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.top_level = true
	s.visible = false
	s.z_index = 130
	s.material = material_somar()
	add_child(s)
	return s


static func _gradiente(ofs: Array, cores: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(ofs)
	g.colors = PackedColorArray(cores)
	return g


static func _curva(pontos: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in pontos:
		c.add_point(p)
	return c


## Contato: faíscas saindo para longe de quem bateu, lascas, clarão e anel.
## forte = 1 para a bola; ~0.6 para pino batendo em pino.
func faiscas(onde: Vector2, direcao: Vector2, forte: float = 1.0) -> void:
	var dir := direcao if direcao.length() > 0.01 else Vector2.UP
	_faiscas.global_position = onde
	_faiscas.direction = dir
	_faiscas.initial_velocity_max = lerpf(300.0, 540.0, forte)
	_faiscas.restart()
	_lascas.global_position = onde
	_lascas.direction = Vector2(dir.x, dir.y - 0.5).normalized()
	var qtd_lascas: int = 9 if forte > 0.8 else 5
	if _lascas.amount != qtd_lascas:
		_lascas.amount = qtd_lascas
	_lascas.restart()
	_piscar(onde, forte)


func _piscar(onde: Vector2, forte: float) -> void:
	if _tw_clarao != null and _tw_clarao.is_valid():
		_tw_clarao.kill()
	_clarao.global_position = onde
	_clarao.scale = Vector2.ONE * 0.35 * forte
	_clarao.modulate = Color(1.0, 0.93, 0.72, 0.95)
	_clarao.visible = true
	_anel.global_position = onde
	_anel.scale = Vector2(0.14, 0.09) * forte
	_anel.modulate = Color(1.0, 0.88, 0.55, 0.75 * forte)
	_anel.visible = true
	_tw_clarao = create_tween().set_parallel(true)
	_tw_clarao.tween_property(_clarao, "scale", Vector2.ONE * 1.25 * forte, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw_clarao.tween_property(_clarao, "modulate:a", 0.0, 0.16)
	# o anel é achatado: deitado na pista, em perspectiva
	_tw_clarao.tween_property(_anel, "scale", Vector2(0.80, 0.46) * forte * forte, 0.26)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_clarao.tween_property(_anel, "modulate:a", 0.0, 0.26)
	_tw_clarao.chain().tween_callback(func() -> void:
		_clarao.visible = false
		_anel.visible = false)


## Pouso na pista: fumacinha rasteira e macia.
func poeira(onde: Vector2) -> void:
	_fumaca.global_position = onde
	_fumaca.restart()


## Duas cópias do pino que ficam para trás e somem.
func rastro(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	for i in _fantasmas.size():
		await get_tree().create_timer(0.035 * (i + 1)).timeout
		if not is_instance_valid(sprite):
			return
		var f := _fantasmas[i]
		f.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		f.centered = sprite.centered
		f.offset = sprite.offset
		f.flip_h = sprite.flip_h
		f.global_transform = sprite.global_transform
		f.modulate = Color(1.0, 0.95, 0.85, 0.38 - 0.12 * i)
		f.visible = true
		var tw := create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.18)
		tw.tween_callback(func() -> void: f.visible = false)
