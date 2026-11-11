// Utilidades comunes a todas las páginas. La web no calcula nada: solo lee datos/modelo.json.
export const COLOR = { PP: '#1D5FA8', PSOE: '#D7263D', VOX: '#5A9E2F', FA: '#C2407D', POD: '#6B3FA0', SALF: '#A0522D',
  ERC: '#E0A030', JUNTS: '#2BA6A3', BILDU: '#9AA53B', PNV: '#4F7A5A', BNG: '#78AEDB', CC: '#E6C84A', UPN: '#6C88AE' };
// Color de partido para usar en style="": la variable de estilo.css (que cambia en el boleto de noche) con el hexadecimal de reserva.
export const colorCss = k => COLOR[k] ? `var(--${k.toLowerCase()}, ${COLOR[k]})` : '#9a948a';
export const NOMBRES = { PP: 'PP', PSOE: 'PSOE', VOX: 'Vox', FA: 'Frente Amplio', POD: 'Podemos', SALF: 'SALF', ERC: 'ERC',
  JUNTS: 'Junts', BILDU: 'EH Bildu', PNV: 'PNV', BNG: 'BNG', CC: 'CC', UPN: 'UPN' };
export const ORDEN = ['PP', 'PSOE', 'VOX', 'FA', 'ERC', 'BILDU', 'PNV', 'JUNTS', 'BNG', 'CC', 'UPN', 'POD', 'SALF'];
export const ESCENARIOS = [
  { id: 'A_media_privadas', corto: 'Si aciertan de media', largo: 'Si las encuestas aciertan de media' },
  { id: 'B_correccion_23J', corto: 'Si fallan como en 2023', largo: 'Si la media falla como en 2023 (1 punto de más al PP, 3 de menos al PSOE)' },
  { id: 'F_ancla_microdatos', corto: 'Si aciertan las de microdatos abiertos', largo: 'Si aciertan el CIS y More in Common, recalculados con sus microdatos' },
  { id: 'E_ancla_SW', corto: 'Si acierta SW Demoscopia', largo: 'Si acierta SW Demoscopia, la única que pone primero al PSOE' }
];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
export const fecha = s => { const [, m, d] = s.split('-'); return `${+d} de ${MESES[+m - 1]}`; };
export const f1 = x => x.toLocaleString('es-ES', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
export const r0 = x => Math.round(x);
export const cada100 = p => p > 0.99 ? 'más de 99 de cada 100' : p < 0.01 ? 'menos de 1 de cada 100' : `${Math.round(p * 100)} de cada 100`;
export const sinMovimiento = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

// ---------------------------------------------------------------- boleto de noche
// Sin elección guardada se sigue al sistema (prefers-color-scheme, en estilo.css). El botón guarda la elección solo si
// es distinta de la del sistema; si coincide, la borra y la página vuelve a seguir al sistema. Un guion en el <head>
// de cada página aplica la elección guardada antes de pintar, para que no haya parpadeo.
const CLAVE_TEMA = 'porra29n.tema', raiz = document.documentElement;
const sistemaOscuro = matchMedia('(prefers-color-scheme: dark)');
const esOscuro = () => raiz.dataset.tema ? raiz.dataset.tema === 'oscuro' : sistemaOscuro.matches;
(function botonTema() {
  const cab = document.querySelector('.cabecera');
  if (!raiz.classList.contains('con-noche') || !cab || cab.querySelector('.tema')) return;
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'tema';
  b.innerHTML = '<span class="casilla-tema" aria-hidden="true"></span>Boleto de noche';
  const marcar = () => b.setAttribute('aria-pressed', String(esOscuro()));
  b.addEventListener('click', () => {
    const oscuro = !esOscuro();
    try {
      if (oscuro === sistemaOscuro.matches) localStorage.removeItem(CLAVE_TEMA);
      else localStorage.setItem(CLAVE_TEMA, oscuro ? 'oscuro' : 'claro');
    } catch (e) { /* sin almacenamiento: vale para esta visita */ }
    if (oscuro === sistemaOscuro.matches) delete raiz.dataset.tema; else raiz.dataset.tema = oscuro ? 'oscuro' : 'claro';
    marcar();
  });
  sistemaOscuro.addEventListener('change', marcar);
  marcar();
  const fila = document.createElement('div'); fila.className = 'tema-fila'; fila.append(b);
  cab.prepend(fila);
})();

// ---------------------------------------------------------------- menú superior
// Las mismas secciones que el pie, arriba de cada página, con los enlaces de datos de la página. En el móvil es una
// tira que se desplaza en horizontal. Incluye un enlace oculto «Saltar al contenido» para teclado y lectores de pantalla.
export const SECCIONES = [['index.html', 'La media de encuestas'], ['porra.html', 'Rellena tu porra'], ['supuestos.html', 'Elige tus supuestos'],
  ['encuestas.html', 'Las encuestas'], ['casas.html', 'Las encuestadoras'], ['metodologia.html', 'Cómo se calcula'], ['preguntas.html', 'Preguntas frecuentes']];
(function menuArriba() {
  const main = document.querySelector('main.boleto');
  if (!main || main.querySelector('.menu-arriba')) return;
  const pagina = location.pathname.split('/').pop() || 'index.html';
  const nav = document.createElement('nav');
  nav.className = 'menu-arriba'; nav.setAttribute('aria-label', 'Menú principal');
  const datos = [...document.querySelectorAll('.pie .datos-pie a')]
    .map(a => `<a class="dato" href="${a.getAttribute('href')}">${a.textContent}</a>`).join('');
  // todos los enlaces en una misma fila flexible: las secciones a la izquierda, los datos de la página a la derecha
  nav.innerHTML = `<span class="secciones">${SECCIONES.map(([h, t]) =>
      `<a href="${h}"${h === pagina ? ' aria-current="page"' : ''}>${t}</a>`).join('')}</span>${datos}`;
  main.prepend(nav);
  const destino = document.getElementById('contenido') || main.querySelector('article, .contenido') || main.querySelector('.cabecera');
  if (destino) {
    if (!destino.id) destino.id = 'contenido-principal';
    const salto = document.createElement('a');
    salto.className = 'saltar'; salto.href = '#' + destino.id; salto.textContent = 'Saltar al contenido';
    main.prepend(salto);
  }
  // en el móvil, que la sección actual quede a la vista dentro de la tira
  const actual = nav.querySelector('[aria-current]');
  if (actual && nav.scrollWidth > nav.clientWidth) nav.scrollLeft = Math.max(0, actual.offsetLeft - 16);
})();

// ---------------------------------------------------------------- menú del pie
// El mismo en todas las páginas. Marca la página actual y añade «¿En qué acertamos?» solo si ya existe la evaluación
// (datos/evaluacion.json, que se genera con los resultados): se pregunta en silencio y, si no está, no se enseña nada.
(function menuPie() {
  const nav = document.querySelector('.pie nav');
  if (!nav) return;
  const pagina = location.pathname.split('/').pop() || 'index.html';
  const marcar = () => nav.querySelectorAll('a').forEach(a => { if (a.getAttribute('href') === pagina) a.setAttribute('aria-current', 'page'); });
  marcar();
  if (nav.querySelector('a[href="evaluacion.html"]')) return;
  (async () => {
    try {
      const url = 'datos/evaluacion.json';
      let r = await fetch(url, { method: 'HEAD', cache: 'no-store' });
      if (r.status === 405 || r.status === 501) r = await fetch(url, { cache: 'no-store' });   // servidores sin HEAD
      if (!r.ok) return;
      const a = document.createElement('a');
      a.href = 'evaluacion.html'; a.textContent = '¿En qué acertamos?';
      nav.append(a); marcar();
      const arriba = document.querySelector('.menu-arriba .secciones');
      if (arriba && !arriba.querySelector('a[href="evaluacion.html"]')) {
        const b = a.cloneNode(true); if (pagina === 'evaluacion.html') b.setAttribute('aria-current', 'page'); arriba.append(b);
      }
    } catch (e) { /* sin red o sin fichero: el menú se queda como está */ }
  })();
})();

export async function cargar() {
  const r = await fetch('datos/modelo.json', { cache: 'no-store' });
  if (!r.ok) throw new Error(`No se han podido cargar los datos (${r.status}).`);
  const D = await r.json();
  if (D.meta?.veda) return D;                      // en veda el JSON solo trae el aviso
  D.escenario = id => D.escenarios.find(e => e.escenario === id && e.swing === 'mixto');
  // voto a la fecha de corte: la clave que no es la del 29-nov (R/02 la etiqueta «8-nov» aunque cambie el corte)
  const hoy = Object.keys(D.media || {}).find(m => m !== '29-nov');
  D.voto = k => D.media?.[hoy]?.[k];
  D.pie = `Media de ${D.meta.encuestas} encuestas de ${D.meta.casas} empresas con trabajo de campo hasta el ${fecha(D.meta.corte)}, ` +
    `corregida por el sesgo de cada empresa y simulada ${D.meta.simulaciones.toLocaleString('es-ES')} veces en las 52 circunscripciones. ` +
    'No es una encuesta propia ni una casa de apuestas: no hay cuotas ni premios.';
  return D;
}

// Del 24 al 28 de noviembre el JSON no trae cifras: la página solo enseña el aviso.
export function avisoVeda(cont) {
  cont.innerHTML = `<section class="veda"><h1>Volvemos el 29 de noviembre</h1>
    <p>La ley electoral (artículo 69.7 de la LOREG) prohíbe publicar, difundir o reproducir sondeos durante los cinco días anteriores a la votación.
    Las cifras vuelven tras el cierre de los colegios electorales.</p></section>`;
}
