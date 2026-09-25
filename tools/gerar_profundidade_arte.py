"""Gera o mapa de camadas da arte do menu (sprites/dragon_bow_camadas.png).

A arte (sprites/dragon_bow.png, 1024 x 1536) é uma imagem só. Para ela
ganhar movimento de "foto 3D" o shader shaders/arte_viva.gdshader precisa
saber o que está na frente e o que está atrás:

    R = profundidade (0 = fundo, 1 = mais perto: o título)
    G = dragão (cabeça, corpo e garra) — ele "respira"
    B = título DRAGON BOWLING (+ faixa) — ele pulsa
    A = nuvens e pinos brancos (camada do meio) — balançam de leve

Tudo em 1/4 da resolução e desfocado (as bordas macias evitam costura
quando as camadas se deslocam).

    python tools/gerar_profundidade_arte.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
ARTE = RAIZ / "sprites" / "dragon_bow.png"
SAIDA = RAIZ / "sprites" / "dragon_bow_camadas.png"
RED = 4
W, H = 1024 // RED, 1536 // RED

DRAGAO = [(420, 110), (520, 40), (640, 0), (780, 20), (870, 110), (905, 250), (850, 330),
          (800, 430), (790, 560), (730, 650), (660, 740), (590, 740), (570, 600), (565, 480),
          (470, 460), (410, 380), (395, 250)]
GARRA = [(165, 480), (225, 420), (330, 405), (385, 470), (330, 520), (240, 590), (170, 590)]
RABO = [(880, 700), (960, 680), (1010, 760), (1000, 900), (950, 940), (900, 860)]
TITULO = [(60, 790), (400, 760), (960, 770), (975, 960), (930, 1120), (840, 1170), (830, 1270),
          (520, 1300), (240, 1270), (230, 1170), (150, 1140), (120, 960)]
BOLA = (390, 645, 205)
ESFERAS = [(190, 170, 125), (135, 1310, 80), (905, 1310, 80)]


def _poligono(pontos, valor=255):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).polygon([(x / RED, y / RED) for x, y in pontos], fill=valor)
    return im


def _circulo(cx, cy, r, valor=255):
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).ellipse([(cx - r) / RED, (cy - r) / RED, (cx + r) / RED, (cy + r) / RED], fill=valor)
    return im


def _arr(im, desfoque):
    return np.asarray(im.filter(ImageFilter.GaussianBlur(desfoque))).astype(np.float32) / 255


def main():
    arte = Image.open(ARTE).convert("RGB").resize((W, H), Image.LANCZOS)
    rgb = np.asarray(arte).astype(np.float32) / 255
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    sat = rgb.max(-1) - rgb.min(-1)

    # nuvens e pinos: claros e pouco saturados
    branco = np.clip((lum - 0.72) / 0.15, 0, 1) * np.clip((0.30 - sat) / 0.15, 0, 1)
    branco = np.asarray(Image.fromarray((branco * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.0))).astype(np.float32) / 255

    dragao = np.maximum.reduce([_arr(_poligono(DRAGAO), 2.0), _arr(_poligono(GARRA), 2.0), _arr(_poligono(RABO), 2.0)])
    titulo = _arr(_poligono(TITULO), 3.0)
    bola = _arr(_circulo(*BOLA), 2.0)
    esferas = np.maximum.reduce([_arr(_circulo(*e), 2.0) for e in ESFERAS])

    # piso de madeira embaixo vem um pouco para a frente
    y = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    piso = np.clip((y - 0.86) / 0.14, 0, 1) * 0.45

    prof = np.zeros((H, W), np.float32)
    prof = np.maximum(prof, piso)
    prof = np.maximum(prof, branco * 0.38)
    prof = np.maximum(prof, esferas * 0.55)
    prof = np.maximum(prof, dragao * 0.62)
    prof = np.maximum(prof, bola * 0.74)
    prof = np.maximum(prof, titulo * 1.0)
    prof = np.asarray(Image.fromarray((prof * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.0))).astype(np.float32) / 255

    saida = np.dstack([prof, dragao, titulo, branco * (1 - titulo) * (1 - dragao) * (1 - bola)])
    Image.fromarray((np.clip(saida, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(SAIDA, optimize=True)
    print("gerado", SAIDA)


if __name__ == "__main__":
    main()
