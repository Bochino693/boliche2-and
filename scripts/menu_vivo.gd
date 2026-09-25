class_name MenuVivo
extends Node2D

## A ARTE DO MENU EM MOVIMENTO (Dragon Bowling 2).
##
##  • shaders/arte_viva.gdshader na arte: "foto 3D" (paralaxe por camadas,
##    sprites/dragon_bow_camadas.png), dragão respirando, bola balançando,
##    título pulsando, reflexos, esferas do dragão e estrelas cintilando;
##  • a arte "respira": zoom lento de ida e volta;
##  • estrelas de 4 pontas douradas e azuis sobem girando, e luzes macias
##    (bokeh) flutuam na frente — texturas em alta (sprites/fx);
##  • o selo "2" entra com um tranco, gira os raios e pulsa.
##
## Tudo leve: um shader na imagem que já era desenhada, poucos emissores
## e um desenho simples.

const SHADER_ARTE := preload("res://shaders/arte_viva.gdshader")
const CAMADAS := preload("res://sprites/dragon_bow_camadas.png")
const FONTE := "res://fonts/arcade_impact.ttf"
const CENTRO_DO_SELO := Vector2(900, 1178)
const RAIO_DO_SELO := 84.0

var _arte: Sprite2D
var _selo: Node2D
var _t := 0.0


func _init(arte: Sprite2D) -> void:
	_arte = arte


func _ready() -> void:
	z_index = 200
	if _arte != null:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_ARTE
		mat.set_shader_parameter("camadas", CAMADAS)
		_arte.material = mat
		_respirar.call_deferred()
	_criar_faiscas()
	_criar_selo()


## Zoom lento em volta do centro da tela, ida e volta, para sempre.
func _respirar() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_arte):
		return
	var escala_base := _arte.scale
	var pos_base := _arte.position
	var centro := Tela.TAMANHO * 0.5
	var zoom := 1.035
	var tw := create_tween().set_loops()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(_arte):
			return
		var s := lerpf(1.0, zoom, k)
		_arte.scale = escala_base * s
		_arte.position = centro + (pos_base - centro) * s, 0.0, 1.0, 6.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(_arte):
			return
		var s := lerpf(1.0, zoom, k)
		_arte.scale = escala_base * s
		_arte.position = centro + (pos_base - centro) * s, 1.0, 0.0, 6.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _criar_faiscas() -> void:
	# estrelas subindo e girando
	for cor: Color in [Color(1.0, 0.86, 0.38, 1.0), Color(0.50, 0.88, 1.0, 0.95)]:
		var e := _emissor(FxPino.TEX_ESTRELA, 16, 5.0)
		e.emission_rect_extents = Vector2(Tela.TAMANHO.x * 0.5, 20)
		e.position = Vector2(Tela.TAMANHO.x * 0.5, Tela.TAMANHO.y + 20)
		e.initial_velocity_min = 200.0
		e.initial_velocity_max = 360.0
		e.scale_amount_min = 0.12
		e.scale_amount_max = 0.34
		e.angle_min = 0.0
		e.angle_max = 90.0
		e.angular_velocity_min = -90.0
		e.angular_velocity_max = 90.0
		# acende, pisca no meio do caminho e apaga
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.45, 0.55, 0.85, 1.0])
		ramp.colors = PackedColorArray([Color(cor, 0.0), cor, Color(cor, 0.35), cor, Color(cor, 0.5), cor, Color(cor, 0.0)])
		e.color_ramp = ramp
		add_child(e)
	# luzes macias (bokeh), grandes e lentas
	var bokeh := _emissor(FxPino.TEX_BRILHO, 9, 7.0)
	bokeh.emission_rect_extents = Vector2(Tela.TAMANHO.x * 0.5, Tela.TAMANHO.y * 0.5)
	bokeh.position = Tela.TAMANHO * 0.5
	bokeh.spread = 180.0
	bokeh.initial_velocity_min = 8.0
	bokeh.initial_velocity_max = 30.0
	bokeh.scale_amount_min = 0.5
	bokeh.scale_amount_max = 1.2
	bokeh.color_initial_ramp = FxPino._gradiente([0.0, 0.5, 0.51, 1.0],
		[Color(1.0, 0.8, 0.4), Color(1.0, 0.8, 0.4), Color(0.4, 0.75, 1.0), Color(0.4, 0.75, 1.0)])
	bokeh.color_ramp = FxPino._gradiente([0.0, 0.3, 0.7, 1.0],
		[Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	add_child(bokeh)


func _emissor(tex: Texture2D, quantos: int, vida: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = tex
	e.amount = quantos
	e.lifetime = vida
	e.preprocess = vida
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.direction = Vector2(0, -1)
	e.spread = 12.0
	e.gravity = Vector2.ZERO
	e.material = FxPino.material_somar()
	return e


func _criar_selo() -> void:
	_selo = Node2D.new()
	_selo.position = CENTRO_DO_SELO
	_selo.scale = Vector2.ZERO
	_selo.rotation = -0.5
	_selo.draw.connect(_desenhar_selo)
	add_child(_selo)
	var dois := Label.new()
	dois.text = "2"
	dois.size = Vector2(200, 200)
	dois.position = Vector2(-100, -108)
	dois.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dois.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(FONTE):
		dois.add_theme_font_override("font", load(FONTE))
	dois.add_theme_font_size_override("font_size", 150)
	dois.add_theme_color_override("font_color", Color(1.0, 0.93, 0.35))
	dois.add_theme_color_override("font_outline_color", Color(0.45, 0.04, 0.06))
	dois.add_theme_constant_override("outline_size", 20)
	dois.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	dois.add_theme_constant_override("shadow_offset_x", 5)
	dois.add_theme_constant_override("shadow_offset_y", 7)
	_selo.add_child(dois)
	# Entrada: um tranco girando, depois fica pulsando.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_selo, "scale", Vector2.ONE, 0.55).set_delay(0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_selo, "rotation", 0.12, 0.55).set_delay(0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _selo != null and _t > 1.1:
		_selo.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.045)
	if _selo != null:
		_selo.queue_redraw()


## Estrela de pontas (raios girando) + disco vermelho com borda dourada.
func _desenhar_selo() -> void:
	var pontas := 14
	var giro := _t * 0.6
	var estrela := PackedVector2Array()
	for i in pontas * 2:
		var r := RAIO_DO_SELO * (1.32 if i % 2 == 0 else 1.02)
		var a := giro + TAU * float(i) / float(pontas * 2)
		estrela.append(Vector2.from_angle(a) * r)
	_selo.draw_colored_polygon(estrela, Color(1.0, 0.78, 0.15))
	_selo.draw_circle(Vector2.ZERO, RAIO_DO_SELO * 1.0, Color(0.55, 0.05, 0.08))
	_selo.draw_circle(Vector2.ZERO, RAIO_DO_SELO * 0.88, Color(0.86, 0.12, 0.12))
	_selo.draw_arc(Vector2.ZERO, RAIO_DO_SELO * 0.94, 0.0, TAU, 64, Color(1.0, 0.86, 0.3), 6.0, true)
	# brilho que passa pelo disco
	var brilho := fmod(_t * 0.7, 1.0)
	_selo.draw_arc(Vector2.ZERO, RAIO_DO_SELO * 0.72, TAU * brilho, TAU * brilho + 0.9, 24, Color(1, 1, 1, 0.35), 8.0, true)
