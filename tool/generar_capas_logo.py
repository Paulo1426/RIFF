"""Separa el logo en capas para la animación de apertura (lib/animations/logo_animado.dart).

Parte de lib/assets/icon/icono_primer_plano.png (logo 1024 con fondo transparente)
y deja en lib/assets/images/logo/animado/: base.png (logo sin barras ni nota),
barra_N.png, nota.png y triangulo.png, además de imprimir las posiciones.
Ejecutar: python tool/generar_capas_logo.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SALIDA = 'lib/assets/images/logo/animado/'
logo = Image.open('lib/assets/icon/icono_primer_plano.png').convert('RGBA').crop((184, 246, 839, 778))
a = np.array(logo).astype(float)
alto, ancho = a.shape[:2]
mx = a[..., :3].max(2)
sat = (mx - a[..., :3].min(2)) / np.maximum(mx, 1)

# Barras: cada barra se lleva el contorno de la más alta de sus vecinas; base en y=168.
CORTES = [222, 259, 300, 337, 394, 430, 468, 499]
BASE_Y = 168
base = a.copy()
barras = []
for i in range(7):
    x0, x1 = CORTES[i], CORTES[i + 1]
    capa = np.zeros((BASE_Y, x1 - x0, 4))
    capa[:] = a[:BASE_Y, x0:x1]
    ys = np.where(capa[..., 3].max(1) > 8)[0]
    top = int(ys.min())
    Image.fromarray(capa[top:].astype(np.uint8)).save(f'{SALIDA}barra_{i + 1}.png')
    barras.append((x0, top, x1 - x0, BASE_Y - top))
base[:BASE_Y, CORTES[0]:CORTES[-1]] = 0

# Nota: el componente oscuro dentro de la R.
x0, x1, y0, y1 = 120, 300, 195, 360
caja = a[y0:y1, x0:x1]
oscuro = (caja[..., :3].max(2) < 95) & (caja[..., 3] > 200)
lab, _ = ndi.label(oscuro)
nota = lab == lab[(207 + 344) // 2 - y0, 205 - x0] if lab[(207 + 344) // 2 - y0, 205 - x0] else None
if nota is None:
    tam = np.bincount(lab.ravel())
    tam[0] = 0
    nota = lab == tam.argmax()
nota = ndi.binary_dilation(nota, iterations=3)
mascara = np.zeros((alto, ancho), bool)
mascara[y0:y1, x0:x1] = nota
lum = a[..., :3].mean(2)
cob = np.clip((235 - lum) / (235 - 25), 0, 1) * mascara
capa = np.zeros((alto, ancho, 4))
capa[..., :3] = (12, 24, 38)
capa[..., 3] = cob * 255
ys, xs = np.where(mascara)
nx0, nx1, ny0, ny1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
Image.fromarray(capa[ny0:ny1, nx0:nx1].astype(np.uint8)).save(SALIDA + 'nota.png')
# Relleno del hueco de la nota: difusión desde los bordes.
relleno = base[..., :3].copy()
relleno[mascara] = 240
for _ in range(400):
    suave = ndi.uniform_filter(relleno, size=(3, 3, 1))
    relleno[mascara] = suave[mascara]
base[mascara, :3] = relleno[mascara]
Image.fromarray(base.astype(np.uint8)).save(SALIDA + 'base.png')

# Triángulo: píxeles saturados fuera de las barras.
tri = np.clip((sat - 0.4) / 0.3, 0, 1) * (mx > 110) * (a[..., 3] / 255)
tri[:BASE_Y, CORTES[0]:CORTES[-1]] = 0
capa = a.copy()
capa[..., 3] = tri * 255
Image.fromarray(capa.astype(np.uint8)).save(SALIDA + 'triangulo.png')

print('ancho, alto =', ancho, alto)
print('barras (x, y, w, h) =', barras, 'base_y =', BASE_Y)
print('nota (x, y, w, h) =', (nx0, ny0, nx1 - nx0, ny1 - ny0))
