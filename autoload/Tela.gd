extends Node

## A TELA DO JOGO: sempre em pé, 1024 x 1536.
##
## Na Pro Ultra 4K com Android 10, o HDMI permanece em paisagem.
## O jogo desenha tudo girado 90° pela transformação
## GLOBAL do canvas da janela, que vale para TODAS as camadas (HUD,
## telas por cima, cortinas), não só para o fundo.
##
## Os scripts sempre enxergam a tela em pé: use `Tela.retangulo()` e
## `Tela.cobrir()`, nunca o tamanho da janela.
##
## Sentido do giro: `dragon/tela/giro` em project.godot
##   1  = topo do jogo na ESQUERDA do HDMI
##  -1  = topo do jogo na DIREITA do HDMI (se ficar de cabeça para baixo)
##   0  = sem giro (PC ou monitor já em retrato)

const TAMANHO := Vector2(1024, 1536)

var giro := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	giro = _giro_configurado()
	_aplicar()
	get_tree().root.size_changed.connect(_aplicar)
	get_tree().node_added.connect(_no_adicionado)


## Cena cuja raiz é um Control (ex.: tela de teste) ocupa a tela em pé,
## e não o retângulo deitado da janela.
func _no_adicionado(no: Node) -> void:
	if no is Control and no.get_parent() == get_tree().root:
		cobrir.call_deferred(no)


func _giro_configurado() -> int:
	if OS.has_environment("DRAGON_GIRO"):
		return int(OS.get_environment("DRAGON_GIRO"))
	if OS.get_name() != "Android":
		return 0
	return int(ProjectSettings.get_setting("dragon/tela/giro", 1))


func tamanho() -> Vector2:
	return TAMANHO


func retangulo() -> Rect2:
	return Rect2(Vector2.ZERO, TAMANHO)


## Faz um Control cobrir a tela do jogo inteira.
func cobrir(no: Control) -> void:
	no.set_anchors_preset(Control.PRESET_TOP_LEFT)
	no.position = Vector2.ZERO
	no.size = TAMANHO


## PRESET_FULL_RECT que funciona com a tela girada: dentro de outro
## Control ancora no pai; direto numa CanvasLayer cobre a tela em pé.
func cobrir_auto(no: Control) -> void:
	no.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cobrir_se_raiz.call_deferred(no)


func _cobrir_se_raiz(no: Control) -> void:
	if is_instance_valid(no) and not (no.get_parent() is Control):
		cobrir(no)


func _aplicar() -> void:
	var janela := get_tree().root
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	if giro == 0:
		janela.content_scale_size = Vector2i(TAMANHO)
		janela.global_canvas_transform = Transform2D.IDENTITY
		return
	janela.content_scale_size = Vector2i(int(TAMANHO.y), int(TAMANHO.x))
	if giro > 0:
		# (x, y) do jogo -> (y, 1024 - x) na tela
		janela.global_canvas_transform = Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, TAMANHO.x))
	else:
		# (x, y) do jogo -> (1536 - y, x) na tela
		janela.global_canvas_transform = Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(TAMANHO.y, 0))
