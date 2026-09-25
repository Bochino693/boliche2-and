class_name FxPino
extends Node2D

## EFEITOS DA QUEDA DE UM PINO (Dragon Bowling 2).
##
##  • faíscas douradas no instante em que a bola toca o pino;
##  • rastro: duas cópias do pino, translúcidas, que ficam para trás e
##    somem — o pino "voa" em vez de só girar;
##  • poeira quando ele bate no chão da pista.
##
## Tudo é criado UMA vez, quando o pino nasce (nada é criado no meio da
## jogada — na TV Box criar nós na hora do strike engasgava).

const COR_FAISCA_1 := Color(1.0, 0.97, 0.75, 1.0)
const COR_FAISCA_2 := Color(1.0, 0.62, 0.15, 0.0)
const COR_POEIRA := Color(0.96, 0.86, 0.66, 0.42)

static var _ponto: Texture2D

var _faiscas: CPUParticles2D
var _poeira: CPUParticles2D
var _fantasmas: Array[Sprite2D] = []


static func _textura_ponto() -> Texture2D:
	if _ponto == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_ponto = t
	return _ponto


func _ready() -> void:
	z_index = 60
	_faiscas = _emissor(16, 0.45)
	_faiscas.spread = 65.0
	_faiscas.gravity = Vector2(0, 700)
	_faiscas.initial_velocity_min = 220.0
	_faiscas.initial_velocity_max = 520.0
	_faiscas.scale_amount_min = 0.30
	_faiscas.scale_amount_max = 0.62
	var cores := Gradient.new()
	cores.set_color(0, COR_FAISCA_1)
	cores.set_color(1, COR_FAISCA_2)
	_faiscas.color_ramp = cores
	var brilho := CanvasItemMaterial.new()
	brilho.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_faiscas.material = brilho

	_poeira = _emissor(10, 0.65)
	_poeira.direction = Vector2(0, -1)
	_poeira.spread = 80.0
	_poeira.gravity = Vector2(0, -25)
	_poeira.initial_velocity_min = 30.0
	_poeira.initial_velocity_max = 95.0
	_poeira.scale_amount_min = 0.9
	_poeira.scale_amount_max = 1.7
	var cresce := Curve.new()
	cresce.add_point(Vector2(0, 0.5))
	cresce.add_point(Vector2(1, 1.3))
	_poeira.scale_amount_curve = cresce
	var some := Gradient.new()
	some.set_color(0, COR_POEIRA)
	some.set_color(1, Color(COR_POEIRA.r, COR_POEIRA.g, COR_POEIRA.b, 0.0))
	_poeira.color_ramp = some

	for i in 2:
		var f := Sprite2D.new()
		f.top_level = true
		f.visible = false
		f.z_index = 40
		add_child(f)
		_fantasmas.append(f)


func _emissor(quantos: int, vida: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.emitting = false
	e.one_shot = true
	e.explosiveness = 1.0
	e.amount = quantos
	e.lifetime = vida
	e.local_coords = false
	e.texture = _textura_ponto()
	add_child(e)
	return e


## Faíscas saindo do ponto de contato, para longe da bola.
func faiscas(onde: Vector2, direcao: Vector2) -> void:
	_faiscas.global_position = onde
	_faiscas.direction = direcao if direcao.length() > 0.01 else Vector2.UP
	_faiscas.restart()


## Poeira no chão, onde o pino caiu.
func poeira(onde: Vector2) -> void:
	_poeira.global_position = onde
	_poeira.restart()


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
