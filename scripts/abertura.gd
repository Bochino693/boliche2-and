extends Node2D

## ABERTURA LAZER & SPORT GAMES — o que aparece quando o app abre, no
## lugar da tela preta.
##
## Começa exatamente como a imagem de inicialização do Android (só o fundo
## escuro com o halo, sprites/marca/splash_giro_*.png), então não há pulo.
## O emblema só aparece na montagem: a placa "Lazer & Sport" sobe, o alvo
## sai de trás dela com um impacto, "GAMES" entra letra por letra e um
## brilho passa pela placa. Enquanto isso o menu
## carrega em segundo plano; no fim, a abertura se desfaz por cima do menu.
##
## As imagens vêm em várias larguras (tools/gerar_marca.py) e a abertura
## usa a menor que ainda é maior que o tamanho real na tela: nada de logo
## serrilhado.

const MENU := "res://scene/Main Menu.tscn"
const PASTA := "res://sprites/marca/"
## Versões das imagens, em % do logo original (tools/gerar_marca.py).
const PERCENTUAIS := [25, 50, 100]
const FONTE := "res://fonts/arcade_impact.ttf"
const SOM_IMPACTO := "res://songs/coin.mp3"

const DURACAO := 3.3
const INICIO_DA_CARGA_S := 1.3
## Escala do logo na tela (placa com 820 px) e posições tiradas do logo
## original: o alvo fica 20 px à esquerda e 272 px acima do centro da placa.
const ESCALA_FINAL := 820.0 / 1280.0
const CENTRO_ALVO := Vector2(492, 640)
const CENTRO_PLACA := Vector2(512, 912)

var _t := 0.0
var _impacto_t := -1.0
var _alvo: Sprite2D
var _placa: Sprite2D
var _brilho: Polygon2D
var _letras: Array[Label] = []
var _faiscas: CPUParticles2D
var _som: AudioStreamPlayer
var _saindo := false
var _menu_pedido := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# O menu começa a carregar depois do impacto do alvo: a parte mais
	# animada da abertura roda sem ninguém disputando a TV Box.
	get_tree().create_timer(INICIO_DA_CARGA_S).timeout.connect(func() -> void:
		_menu_pedido = ResourceLoader.load_threaded_request(MENU) == OK)

	# O alvo nasce ESCONDIDO atrás da placa (z menor) e sobe de trás dela:
	# a base dele, cortada reta no desenho, nunca aparece.
	_alvo = _peca("alvo")
	_alvo.z_index = 1
	_alvo.position = CENTRO_PLACA
	_alvo.scale = _escala(_alvo, ESCALA_FINAL * 0.45)
	_alvo.visible = false

	_placa = _peca("placa")
	_placa.scale = _escala(_placa, ESCALA_FINAL)
	_placa.position = CENTRO_PLACA + Vector2(0, 260)
	_placa.modulate.a = 0.0

	# Brilho que passa pela placa: só aparece dentro dela (recorte).
	_placa.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_brilho = Polygon2D.new()
	var alto := _placa.texture.get_height() * 1.2
	_brilho.polygon = PackedVector2Array([Vector2(-60, -alto), Vector2(20, -alto), Vector2(-20, alto), Vector2(-100, alto)])
	_brilho.color = Color(1, 1, 1, 0.55)
	_brilho.position.x = -_placa.texture.get_width()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brilho.material = mat
	_placa.add_child(_brilho)

	_criar_letras()
	_criar_faiscas()

	_som = AudioStreamPlayer.new()
	if ResourceLoader.exists(SOM_IMPACTO):
		_som.stream = load(SOM_IMPACTO)
	_som.volume_db = -6.0
	add_child(_som)

	_animar()


## A menor versão da imagem que ainda cobre o tamanho REAL na tela
## (a tela do jogo é ampliada para o HDMI: numa saída 4K, o dobro).
func _peca(nome: String) -> Sprite2D:
	var janela := get_tree().root
	var fator := 1.0
	if janela.content_scale_size.x > 0:
		fator = maxf(float(janela.size.x) / float(janela.content_scale_size.x),
				float(janela.size.y) / float(janela.content_scale_size.y))
	var precisa := ESCALA_FINAL * fator * 100.0
	var escolhido: int = PERCENTUAIS[-1]
	for p: int in PERCENTUAIS:
		if p >= precisa:
			escolhido = p
			break
	var s := Sprite2D.new()
	s.texture = load("%s%s_%d.png" % [PASTA, nome, escolhido])
	s.set_meta("percentual", escolhido)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = 2
	add_child(s)
	return s


## Escala do sprite para o logo aparecer na escala pedida (em relação ao
## logo original), qualquer que seja a versão carregada.
func _escala(s: Sprite2D, escala_do_logo: float) -> Vector2:
	return Vector2.ONE * escala_do_logo * 100.0 / float(s.get_meta("percentual"))


func _criar_letras() -> void:
	var fonte: Font = load(FONTE) if ResourceLoader.exists(FONTE) else null
	var texto := "GAMES"
	var passo := 118.0
	var x0 := 512.0 - passo * (texto.length() - 1) * 0.5
	var y := CENTRO_PLACA.y + 215.0
	for i in texto.length():
		var l := Label.new()
		l.text = texto[i]
		l.size = Vector2(140, 150)
		l.pivot_offset = l.size * 0.5
		l.position = Vector2(x0 + passo * i, y) - l.size * 0.5
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if fonte != null:
			l.add_theme_font_override("font", fonte)
		l.add_theme_font_size_override("font_size", 120)
		l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18))
		l.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.08))
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_x", 6)
		l.add_theme_constant_override("shadow_offset_y", 8)
		l.modulate.a = 0.0
		l.scale = Vector2(0.2, 0.2)
		l.z_index = 3
		add_child(l)
		_letras.append(l)


func _criar_faiscas() -> void:
	_faiscas = CPUParticles2D.new()
	_faiscas.position = CENTRO_ALVO
	_faiscas.emitting = false
	_faiscas.one_shot = true
	_faiscas.amount = 70
	_faiscas.lifetime = 1.1
	_faiscas.explosiveness = 1.0
	_faiscas.spread = 180.0
	_faiscas.gravity = Vector2(0, 520)
	_faiscas.initial_velocity_min = 380.0
	_faiscas.initial_velocity_max = 900.0
	_faiscas.scale_amount_min = 5.0
	_faiscas.scale_amount_max = 11.0
	_faiscas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_faiscas.emission_sphere_radius = 120.0
	var cores := Gradient.new()
	cores.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	cores.set_color(1, Color(1.0, 0.35, 0.3, 0.0))
	_faiscas.color_ramp = cores
	_faiscas.z_index = 1
	add_child(_faiscas)


func _animar() -> void:
	var tw := create_tween().set_parallel(true)
	# 1. A placa sobe primeiro.
	tw.tween_property(_placa, "position:y", CENTRO_PLACA.y, 0.5)\
		.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_placa, "modulate:a", 1.0, 0.3).set_delay(0.2)
	# 2. O alvo sai de trás da placa. A posição não passa do ponto (senão a
	#    base cortada apareceria); só o tamanho dá o tranco.
	tw.tween_callback(func() -> void: _alvo.visible = true).set_delay(0.7)
	tw.tween_property(_alvo, "position", CENTRO_ALVO, 0.45)\
		.set_delay(0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_alvo, "scale", _escala(_alvo, ESCALA_FINAL), 0.45)\
		.set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_impacto).set_delay(1.15)
	# 3. GAMES, letra por letra.
	for i in _letras.size():
		var l := _letras[i]
		var atraso := 1.35 + i * 0.09
		tw.tween_property(l, "modulate:a", 1.0, 0.12).set_delay(atraso)
		tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_delay(atraso)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 4. Brilho passando pela placa.
	tw.tween_property(_brilho, "position:x", _placa.texture.get_width() * 0.6, 0.7)\
		.set_delay(1.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _impacto() -> void:
	_impacto_t = _t
	_faiscas.emitting = true
	if _som.stream != null:
		_som.play()
	var tw := create_tween()
	var base := _alvo.scale
	tw.tween_property(_alvo, "scale", base * 1.08, 0.06)
	tw.tween_property(_alvo, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# "GAMES" respira depois de entrar.
	if _t > 1.8:
		for i in _letras.size():
			_letras[i].position.y += sin(_t * 4.0 + i * 0.7) * 0.35
	if _t >= DURACAO and not _saindo:
		_ir_para_o_menu()


## O fundo: escuro com um halo roxo, raios de luz girando devagar e, no
## impacto, anéis que se espalham.
func _draw() -> void:
	var tela := Tela.TAMANHO
	draw_rect(Rect2(Vector2.ZERO, tela), Color(0.024, 0.031, 0.086))
	var aparece := clampf(_t / 0.6, 0.0, 1.0)
	for r: float in [900.0, 700.0, 520.0, 380.0]:
		var a := 0.07 * aparece * (1.0 - r / 1000.0)
		draw_circle(CENTRO_ALVO, r, Color(0.36, 0.18, 0.78, a))
	var giro := _t * 0.25
	for i in 12:
		var ang := giro + TAU * i / 12.0
		var d1 := Vector2.from_angle(ang - 0.07) * 1600.0
		var d2 := Vector2.from_angle(ang + 0.07) * 1600.0
		draw_colored_polygon(PackedVector2Array([CENTRO_ALVO, CENTRO_ALVO + d1, CENTRO_ALVO + d2]),
				Color(1.0, 0.85, 0.4, 0.035 * aparece))
	if _impacto_t >= 0.0:
		var dt := _t - _impacto_t
		for k in 3:
			var u := dt * 1.3 - k * 0.18
			if u > 0.0 and u < 1.0:
				draw_arc(CENTRO_ALVO, 150.0 + u * 700.0, 0.0, TAU, 96,
						Color(1.0, 0.8, 0.3, (1.0 - u) * 0.55), 10.0 * (1.0 - u) + 2.0, true)


func _ir_para_o_menu() -> void:
	var recurso: PackedScene = null
	if _menu_pedido:
		var estado := ResourceLoader.load_threaded_get_status(MENU)
		if estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return   # o menu ainda carrega: a abertura continua viva
		if estado == ResourceLoader.THREAD_LOAD_LOADED:
			recurso = ResourceLoader.load_threaded_get(MENU)
	if recurso == null:
		recurso = load(MENU)
	_saindo = true
	Cortina.trocar_para(get_tree(), recurso)
