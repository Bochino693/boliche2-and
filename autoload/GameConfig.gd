extends Node

## Somente modo livre. Configuracoes antigas de credito sao ignoradas.
var modo_livre: bool = true

## Cena da pista, sons e fontes carregados em segundo plano pelo menu.
## Ficam guardados aqui para não saírem do cache entre uma partida e outra.
var precarregados: Dictionary = {}

## SOM JUNTO COM A IMAGEM. O som sai na hora; a imagem da bola chega à
## tela um ou dois quadros depois (e a TV ainda processa a imagem). O som
## da jogada espera o quadro com a bola já desenhado e mais esta folga.
var atraso_som_jogada: float = 0.06

## FONTES SEM BUSCA NO SISTEMA. As fontes do jogo não têm 🎳 🏆 ★ ◆ ▼...
## Sem reserva própria, o Godot ia procurar nas fontes do Android na hora
## em que o texto aparecia (abrir a fonte de emoji inteira, vários MB) — a
## tela travava no modal de jogadores e no placar. Estas duas fontinhas
## (tools/gerar_fontes_simbolos.py) têm só o que os textos usam.
const FONTES_DO_JOGO := [
	"res://fonts/arcade_impact.ttf",
	"res://fonts/painel_arcade.ttf",
	"res://fonts/titan.ttf",
]
const FONTES_RESERVA := [
	"res://fonts/simbolos_do_jogo.ttf",
	"res://fonts/emoji_do_jogo.ttf",
]
var _fontes: Array[Font] = []


func _ready() -> void:
	_preparar_fontes()


func _preparar_fontes() -> void:
	var reservas: Array[Font] = []
	for caminho: String in FONTES_RESERVA:
		if ResourceLoader.exists(caminho):
			var f := load(caminho) as FontFile
			if f != null:
				f.allow_system_fallback = false
				reservas.append(f)
	var todas: Array[Font] = [ThemeDB.fallback_font]
	for caminho: String in FONTES_DO_JOGO:
		if ResourceLoader.exists(caminho):
			todas.append(load(caminho) as Font)
	for f in todas:
		if f == null:
			continue
		f.fallbacks = reservas
		if f is FontFile:
			(f as FontFile).allow_system_fallback = false
		# Guardadas aqui: continuam as mesmas (com a reserva) no jogo todo.
		_fontes.append(f)

# ─────────────────────────────────────────────
# CONFIGURAÇÃO GLOBAL DO JOGO
# ─────────────────────────────────────────────

# Quantidade de jogadores (1 ou 2)
var jogadores: int = 1

# Rodadas base por jogador
var rounds_por_jogador: int = 3

# Dados persistentes da sessão
var jogador_atual: int = 1
var partida_ativa: bool = false

# Nome do cenário atual
var cenario_atual: String = ""

# Dificuldade (facil / dificil)
var dificuldade: String = "facil"

# Idioma
var idioma: String = "pt_br"

# Tempo padrão de partida
var tempo_partida: int = 120

# ─────────────────────────────────────────────
# RESET DE PARTIDA
# ─────────────────────────────────────────────
func resetar_partida() -> void:
	jogadores = clamp(jogadores, 1, 2)
	jogador_atual = 1
	partida_ativa = false


# ─────────────────────────────────────────────
# CONFIGURA JOGADORES
# ─────────────────────────────────────────────
func configurar_jogadores(qtd: int) -> void:
	jogadores = clamp(qtd, 1, 2)
	jogador_atual = 1


# ─────────────────────────────────────────────
# TROCA PLAYER
# ─────────────────────────────────────────────
func proximo_jogador() -> int:
	if jogadores <= 1:
		jogador_atual = 1
		return jogador_atual

	jogador_atual += 1

	if jogador_atual > jogadores:
		jogador_atual = 1

	return jogador_atual


# ─────────────────────────────────────────────
# RETORNA TEXTO PLAYER
# ─────────────────────────────────────────────
func texto_player() -> String:
	if jogadores <= 1:
		return "1 PLAYER"

	return "PLAYER %d" % jogador_atual
