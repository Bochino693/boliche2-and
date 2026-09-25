"""Gera as texturas das partículas do Dragon Bowling 2 (sprites/fx/).

As partículas antigas eram um ponto de 32 px ampliado — na TV 4K
viravam quadradinhos borrados. Aqui cada uma tem forma de verdade e é
desenhada com supersample 4x (bordas lisas), em tamanho grande, e o
Godot gera mipmaps para reduzir sem serrilhar.

    brilho.png   128  — luz redonda suave (núcleo quente + halo)
    estrela.png  128  — estrela de 4 pontas com halo (faísca)
    lasca.png     64  — lasca/farpa de madeira do pino (branca; a cor vem do jogo)
    fumaca.png   128  — nuvem macia, irregular
    anel.png     128  — onda de choque (anel fino e suave)

    python tools/gerar_particulas.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
PASTA = RAIZ / "sprites" / "fx"
SS = 4

rng = np.random.default_rng(7)


def _grade(lado_x, lado_y=None):
    lado_y = lado_y or lado_x
    nx, ny = lado_x * SS, lado_y * SS
    x = (np.arange(nx) + 0.5) / nx * 2 - 1
    y = (np.arange(ny) + 0.5) / ny * 2 - 1
    return np.meshgrid(x, y)


def _salvar(nome, rgb, alfa, lado_x, lado_y=None):
    lado_y = lado_y or lado_x
    alfa = np.clip(alfa, 0, 1)
    rgb = np.clip(rgb, 0, 1)
    pre = np.dstack([rgb * alfa[..., None], alfa])
    im = Image.fromarray((pre * 255 + 0.5).astype(np.uint8), "RGBA").resize((lado_x, lado_y), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255
    cor = np.where(a[..., 3:4] > 0.002, a[..., :3] / np.maximum(a[..., 3:4], 1e-4), 1.0)
    final = np.dstack([np.clip(cor, 0, 1), a[..., 3]])
    Image.fromarray((final * 255 + 0.5).astype(np.uint8), "RGBA").save(PASTA / nome, optimize=True)
    print("gerado", PASTA / nome)


def _suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def brilho():
    x, y = _grade(128)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-(r / 0.36) ** 2) * 0.75 + np.exp(-(r / 0.12) ** 2) * 0.6
    a *= _suave(1.0, 0.85, r)  # chega a zero antes da borda (sem corte)
    _salvar("brilho.png", np.ones(r.shape + (3,)), a, 128)


def estrela():
    x, y = _grade(128)
    r = np.sqrt(x * x + y * y)
    ax, ay = np.abs(x), np.abs(y)
    # raios principais: finos, afinando até a ponta
    raio_h = np.exp(-(ay / (0.035 * (1 - np.clip(ax, 0, 1)) + 0.004)) ** 2) * (1 - ax) ** 1.5
    raio_v = np.exp(-(ax / (0.035 * (1 - np.clip(ay, 0, 1)) + 0.004)) ** 2) * (1 - ay) ** 1.5
    # raios diagonais, curtos e fracos
    u, v = (x + y) / np.sqrt(2), (x - y) / np.sqrt(2)
    au, av = np.abs(u), np.abs(v)
    diag = (np.exp(-(av / 0.02) ** 2) * np.clip(1 - au / 0.55, 0, 1) ** 2
            + np.exp(-(au / 0.02) ** 2) * np.clip(1 - av / 0.55, 0, 1) ** 2) * 0.45
    nucleo = np.exp(-(r / 0.10) ** 2)
    halo = np.exp(-(r / 0.30) ** 2) * 0.35
    a = np.clip(raio_h + raio_v + diag + nucleo + halo, 0, 1)
    a *= _suave(1.0, 0.9, r)
    _salvar("estrela.png", np.ones(r.shape + (3,)), a, 128)


def lasca():
    # farpa: losango alongado e pontudo, um lado mais comprido, sombreado
    x, y = _grade(64, 32)
    xs = x - 0.12 * y  # leve inclinação
    forma = np.abs(xs) / 0.94 + np.abs(y + 0.05 * xs) / (0.55 * (1.0 - 0.35 * xs))
    dentro = _suave(1.0, 0.88, forma)
    luz = 0.70 + 0.30 * np.clip(-y * 1.4 + 0.25, -1, 1)  # face de cima mais clara
    aresta = _suave(0.10, 0.0, np.abs(y + 0.08)) * 0.18  # quina iluminada
    tom = np.clip(luz + aresta, 0, 1)
    rgb = np.dstack([tom, tom * 0.97, tom * 0.92])
    _salvar("lasca.png", rgb, dentro, 64, 32)


def fumaca():
    # nuvem: ruído aleatório em baixa resolução ampliado (bolhas macias)
    x, y = _grade(128)
    r = np.sqrt(x * x + y * y)
    lado = 128 * SS
    ruido = np.zeros_like(r)
    for escala, peso in ((6, 1.0), (12, 0.5), (24, 0.25)):
        base = Image.fromarray((rng.random((escala, escala)) * 255).astype(np.uint8), "L")
        ruido += (np.asarray(base.resize((lado, lado), Image.BICUBIC)).astype(np.float32) / 255 - 0.5) * peso
    a = np.exp(-(r / (0.52 + 0.22 * ruido)) ** 2) * np.clip(0.8 + 0.6 * ruido, 0, 1)
    a *= _suave(1.0, 0.8, r)
    tom = np.clip(0.92 + 0.25 * ruido, 0, 1)
    rgb = np.dstack([tom, tom, tom])
    _salvar("fumaca.png", rgb, a * 0.9, 128)


def anel():
    x, y = _grade(128)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-((r - 0.78) / 0.07) ** 2) + np.exp(-((r - 0.70) / 0.18) ** 2) * 0.25
    a *= _suave(1.0, 0.94, r)
    _salvar("anel.png", np.ones(r.shape + (3,)), a, 128)


def main():
    PASTA.mkdir(parents=True, exist_ok=True)
    brilho()
    estrela()
    lasca()
    fumaca()
    anel()


if __name__ == "__main__":
    main()
