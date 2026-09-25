"""Gera a bola azul do Dragon Bowling 2 (sprites/bola_azul.png).

A bola é renderizada em 3D de verdade (esfera + luz), quadro a quadro,
girando para a frente — como ela rola pista acima. Combina com a bola
azul da arte da abertura: azul profundo marmorizado, veios claros,
pontinhos dourados de "galáxia" e os três furos.

    16 quadros de 256 x 256 numa grade 4 x 4  →  1024 x 1024 (RGBA)

Supersample 2x (renderiza em 512 e reduz) para a borda sair lisa.

    python tools/gerar_bola_azul.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "sprites" / "bola_azul.png"

QUADROS = 16
LADO = 256
SS = 2
N = LADO * SS
RAIO = 0.953  # a bola ocupa ~244 px dos 256 (sobra borda para o brilho)

rng = np.random.default_rng(20260925)


def _ruido3(p, ondas):
    """Ruído 3D suave e sem emenda: soma de senoides com direções/fases fixas."""
    total = np.zeros(p.shape[:-1])
    for k, d, fase, amp in ondas:
        total += amp * np.sin((p @ d) * k + fase)
    return total


def _ondas(qtd, k_min, k_max):
    ondas = []
    for i in range(qtd):
        d = rng.normal(size=3)
        d /= np.linalg.norm(d)
        k = k_min * (k_max / k_min) ** (i / max(1, qtd - 1))
        ondas.append((k, d, rng.uniform(0, 2 * np.pi), 1.0 / (1.0 + i * 0.55)))
    return ondas


ONDAS_BASE = _ondas(9, 1.6, 9.0)
ONDAS_VEIO = _ondas(7, 2.5, 14.0)

# Pontinhos dourados/brancos espalhados na superfície (direções fixas).
ESTRELAS = rng.normal(size=(260, 3))
ESTRELAS /= np.linalg.norm(ESTRELAS, axis=1, keepdims=True)
TAM_ESTRELAS = rng.uniform(0.012, 0.030, size=260)
COR_ESTRELAS = np.where(rng.random(260)[:, None] < 0.7,
                        np.array([1.0, 0.82, 0.30]), np.array([0.85, 0.95, 1.0]))

# Três furos (no referencial da bola). No quadro 0 ficam em cima, de frente.
def _dir(x, y, z):
    v = np.array([x, y, z], float)
    return v / np.linalg.norm(v)


FUROS = [
    (_dir(-0.20, -0.52, 0.83), 0.150),  # polegar (maior, mais abaixo)
    (_dir(-0.27, -0.87, 0.42), 0.118),
    (_dir(0.13, -0.86, 0.49), 0.118),
]


def _rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def _suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def renderizar(angulo):
    # Coordenadas de tela: x → direita, y → para baixo, z → para o espectador.
    u = (np.arange(N) + 0.5) / N * 2 - 1
    x, y = np.meshgrid(u, u)
    x = x / RAIO
    y = y / RAIO
    r2 = x * x + y * y
    dentro = r2 <= 1.0
    z = np.sqrt(np.clip(1 - r2, 0, 1))
    n = np.stack([x, y, z], -1)  # normal em tela

    # Normal no referencial da bola. Rolar pista acima = a face de frente
    # sobe na tela → gira em torno de x.
    R = _rot_x(-angulo)
    p = n @ R.T

    # --- material: azul marmorizado ---
    base = _ruido3(p, ONDAS_BASE)
    turb = _ruido3(p * 1.7 + 3.1, ONDAS_VEIO)
    veio = np.abs(np.sin(base * 1.4 + turb * 1.1))
    veio = (1.0 - _suave(0.0, 0.45, veio)) ** 1.6  # veios suaves, como mármore
    nuvem = _suave(-0.8, 1.6, base)
    nebulosa = _suave(0.3, 1.8, turb) * _suave(-0.5, 1.0, base)

    azul_fundo = np.array([0.02, 0.07, 0.30])
    azul_meio = np.array([0.05, 0.26, 0.78])
    azul_claro = np.array([0.35, 0.72, 1.00])
    cor = azul_fundo + (azul_meio - azul_fundo) * nuvem[..., None]
    cor = cor + (azul_claro - cor) * (veio * 0.40)[..., None]
    cor = cor + np.array([0.10, 0.45, 0.70]) * (nebulosa * 0.45)[..., None]
    # toque roxo nas partes escuras (como na arte)
    roxo = _suave(0.2, -1.2, base)[..., None]
    cor = cor + (np.array([0.20, 0.06, 0.45]) - cor) * roxo * 0.35

    # pontinhos
    brilho_pontos = np.zeros(p.shape[:-1])
    cor_pontos = np.zeros(p.shape)
    for d, tam, c in zip(ESTRELAS, TAM_ESTRELAS, COR_ESTRELAS):
        ang = np.arccos(np.clip(p @ d, -1, 1))
        k = _suave(tam, tam * 0.25, ang)
        brilho_pontos = np.maximum(brilho_pontos, k)
        cor_pontos += c * k[..., None]
    cor_pontos /= np.maximum(brilho_pontos, 1e-4)[..., None] + 1e-4
    cor = cor + (cor_pontos - cor) * (brilho_pontos * 0.85)[..., None]

    # --- furos ---
    furo = np.zeros(p.shape[:-1])
    borda_furo = np.zeros(p.shape[:-1])
    fundo_furo = np.zeros(p.shape[:-1])
    for d, raio in FUROS:
        ang = np.arccos(np.clip(p @ d, -1, 1))
        furo = np.maximum(furo, _suave(raio, raio * 0.88, ang))
        borda_furo = np.maximum(borda_furo, _suave(raio * 1.18, raio, ang) * _suave(raio * 0.85, raio, ang))
        # dentro do furo: parede iluminada de um lado, fundo escuro
        lado = (p - d * (p @ d)[..., None]) @ np.array([0.0, -1.0, 0.0])
        fundo_furo = np.maximum(fundo_furo, _suave(raio, 0.0, ang) * (0.5 + 0.5 * lado / raio))
    parede = np.array([0.03, 0.08, 0.22]) * (0.4 + 1.3 * np.clip(fundo_furo, 0, 1))[..., None]
    cor = cor * (1 - furo[..., None]) + parede * furo[..., None]

    # --- luz (fixa em tela, não gira com a bola) ---
    luz = np.array([-0.45, -0.62, 0.64])
    luz /= np.linalg.norm(luz)
    ndl = np.clip(n @ luz, 0, 1)
    difusa = 0.30 + 0.85 * ndl
    meio = luz + np.array([0, 0, 1.0])
    meio /= np.linalg.norm(meio)
    ndh = np.clip(n @ meio, 0, 1)
    especular = ndh ** 90 * 1.25 + ndh ** 14 * 0.22
    especular *= (1 - furo)
    fresnel = (1 - z) ** 3
    # reflexo de "janela" do salão na parte de baixo
    janela = _suave(0.25, 0.0, np.abs(x + 0.15)) * _suave(0.55, 0.75, y) * _suave(0.98, 0.85, np.sqrt(r2))

    rgb = cor * difusa[..., None]
    rgb += np.array([0.45, 0.80, 1.0]) * (fresnel * 0.55)[..., None]
    rgb += np.array([1.0, 0.98, 0.92]) * especular[..., None]
    rgb += np.array([0.55, 0.80, 1.0]) * (janela * 0.22)[..., None]
    rgb += np.array([0.7, 0.9, 1.0]) * (borda_furo * 0.35 * (0.3 + ndl))[..., None]
    # sombra suave na borda de baixo (assenta a bola)
    rgb *= (1 - 0.35 * _suave(0.2, 1.0, y) * _suave(0.5, 1.0, np.sqrt(r2)))[..., None]

    rgb = np.clip(rgb, 0, 1)
    # borda anti-serrilhada: alfa pela distância ao contorno
    dist = np.sqrt(r2) * RAIO
    alfa = np.clip((RAIO - dist) * N * 0.5 + 0.5, 0, 1)
    img = np.dstack([rgb * alfa[..., None], alfa])  # pré-multiplicado p/ reduzir
    im = Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA")
    im = im.resize((LADO, LADO), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255
    rgb = np.where(a[..., 3:4] > 0, a[..., :3] / np.maximum(a[..., 3:4], 1e-4), 0)
    return Image.fromarray((np.dstack([np.clip(rgb, 0, 1), a[..., 3]]) * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    cols = 4
    folha = Image.new("RGBA", (LADO * cols, LADO * (QUADROS // cols)), (0, 0, 0, 0))
    for i in range(QUADROS):
        q = renderizar(2 * np.pi * i / QUADROS)
        folha.paste(q, ((i % cols) * LADO, (i // cols) * LADO))
        print("quadro", i)
    folha.save(SAIDA, optimize=True)
    print("gerado", SAIDA)


if __name__ == "__main__":
    main()
