# Genera web/img/og-portada.png y web/img/og-porra.png (1200x630) a partir de og.html. Requiere playwright (pip).
# Uso: python3 herramientas/og.py   (desde la raíz del proyecto)
import pathlib
from playwright.sync_api import sync_playwright
raiz = pathlib.Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 1200, 'height': 630})
    for v in ('portada', 'porra'):
        pg.goto((raiz / 'herramientas' / 'og.html').as_uri() + f'?v={v}'); pg.wait_for_timeout(500)
        pg.screenshot(path=str(raiz / 'web' / 'img' / f'og-{v}.png'))
    b.close()
print('hecho')
