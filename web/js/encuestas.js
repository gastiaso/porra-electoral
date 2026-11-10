// «Las encuestas»: todas las encuestas de la media con su ficha, para filtrar y ordenar.
// Lee datos/encuestas.json (lo genera R/07b_exportar_extra.R); no calcula nada.
// El filtro y el orden viajan en el enlace (#empresa=…&medio=…&desde=…&hasta=…&orden=…), para poder compartirlos.
import { colorCss, f1, fecha } from './comun.js';

const cont = document.getElementById('contenido');
const PARTIDOS = [['PP', 'PP'], ['PSOE', 'PSOE'], ['VOX', 'Vox'], ['FA', 'FA'], ['POD', 'Pod.'], ['SALF', 'SALF']];
const DEMOCRATA = 'https://www.democrata.es/elecciones-generales-espana/herramientas/encuestas';
const MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const COLUMNAS = [   // id, título, tipo de orden
  ['fin', 'Campo', 'fecha'], ['empresa', 'Empresa y medio', 'texto'], ['n', 'Muestra', 'num'],
  ...PARTIDOS.map(([k, t]) => [k, t, 'num'])];

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const dia = s => { const [, m, d] = s.split('-'); return `${+d} ${MES[+m - 1]}`; };
const campo = (a, b) => {
  if (a === b) return dia(a);
  const [, ma, da] = a.split('-'), [, mb, db] = b.split('-');
  return ma === mb ? `${+da}–${+db} ${MES[+mb - 1]}` : `${dia(a)}–${dia(b)}`;
};
const MODO_CORTO = { 'telefónica': 'Teléfono', 'por internet': 'Internet', 'mixta (combina varios modos)': 'Mixto', 'llamadas automáticas (IVR)': 'IVR' };
const pct = x => x == null ? '<span class="sin-dato" title="No publicado">–</span>' : f1(x);

let D, estado;

try {
  const r = await fetch('datos/encuestas.json', { cache: 'no-store' });
  if (!r.ok) throw new Error(`No se han podido cargar los datos (${r.status}).`);
  D = await r.json();
  estado = leerHash();
  montar();
  pintar();
  addEventListener('hashchange', () => { estado = leerHash(); ponerControles(); pintar(); });
} catch (err) {
  cont.innerHTML = `<p class="error">${esc(err.message)} Recarga la página. Si el problema sigue, los datos están en <a href="datos/encuestas.csv">datos/encuestas.csv</a>.</p>`;
}

function leerHash() {
  const q = new URLSearchParams(location.hash.slice(1));
  const [col, dir] = (q.get('orden') || 'fin-desc').split('-');
  const valida = COLUMNAS.some(c => c[0] === col);
  return { empresa: q.get('empresa') || '', medio: q.get('medio') || '', desde: q.get('desde') || '', hasta: q.get('hasta') || '',
           col: valida ? col : 'fin', dir: dir === 'asc' ? 'asc' : 'desc' };
}
function escribirHash() {
  const q = new URLSearchParams();
  for (const k of ['empresa', 'medio', 'desde', 'hasta']) if (estado[k]) q.set(k, estado[k]);
  if (!(estado.col === 'fin' && estado.dir === 'desc')) q.set('orden', `${estado.col}-${estado.dir}`);
  const h = q.toString();
  history.replaceState(null, '', h ? `#${h}` : location.pathname + location.search);
}

function montar() {
  const E = D.encuestas;
  const fechas = E.map(e => e.fin).sort(), primera = E.map(e => e.inicio).sort()[0];
  const empresas = [...new Map(E.map(e => [e.id, e.empresa])).entries()].sort((a, b) => a[1].localeCompare(b[1], 'es', { sensitivity: 'base', numeric: true }));
  const medios = [...new Set(E.map(e => e.medio))].sort((a, b) => a.localeCompare(b, 'es', { sensitivity: 'base' }));
  document.getElementById('corte').textContent = `Las encuestas · campo hasta el ${fecha(D.meta.corte)}`;
  document.getElementById('pie-texto').textContent = 'Son las encuestas publicadas que entran en la media, no una selección: ninguna se descarta por su resultado. No es una encuesta propia ni una casa de apuestas.';
  cont.innerHTML = `
    <p class="entradilla">${D.meta.n} encuestas de ${D.meta.casas} empresas, con trabajo de campo entre el ${fecha(primera)} y el ${fecha(fechas[fechas.length - 1])}. Son todas las que entran en la media, cada una con su ficha: empresa, medio que la encarga, fechas de campo, muestra, modo de entrevista y de dónde salen las cifras.</p>
    <p class="nota">Cifras, fechas y muestras: <a href="${DEMOCRATA}" rel="noopener">base de sondeos de Demócrata</a>, que enlaza cada estudio con su publicación original; las que no figuran allí, de la fuente que indica cada fila. Cuánto se separa cada empresa de las demás: <a href="casas.html">Las encuestadoras</a>. Las marcadas con ◆ entran en la media con su sesgo estimado aparte (<a href="preguntas.html#sw-electomania">por qué</a>).</p>
    <form class="filtros" id="filtros" aria-label="Filtrar encuestas">
      <label>Empresa <select id="f-empresa"><option value="">Todas</option>${empresas.map(([id, n]) => `<option value="${esc(id)}">${esc(n)}</option>`).join('')}</select></label>
      <label>Medio <select id="f-medio"><option value="">Todos</option>${medios.map(m => `<option value="${esc(m)}">${esc(m)}</option>`).join('')}</select></label>
      <label>Campo desde <input type="date" id="f-desde" min="${primera}" max="${fechas[fechas.length - 1]}"></label>
      <label>hasta <input type="date" id="f-hasta" min="${primera}" max="${fechas[fechas.length - 1]}"></label>
      <button type="button" class="volver" id="f-quitar">Quitar filtros</button>
    </form>
    <p class="recuento" id="recuento" role="status" aria-live="polite"></p>
    <div class="desliza" tabindex="0" role="region" aria-label="Tabla de encuestas">
      <table class="tabla-encuestas">
        <caption class="mudo">Encuestas de la media con su ficha técnica y estimación de voto en %. Los encabezados ordenan la tabla.</caption>
        <thead><tr>${COLUMNAS.map(([id, t, tipo]) => `<th scope="col" class="${tipo === 'num' ? '' : 'izq'}" data-col="${id}"><button type="button" class="ordenar" data-col="${id}">${PARTIDOS.some(p => p[0] === id) ? `<span class="cuadro-th" style="background:${colorCss(id)}" aria-hidden="true"></span>` : ''}${t}<span class="flecha" aria-hidden="true"></span></button></th>`).join('')}<th scope="col" class="izq">Modo</th><th scope="col" class="izq">Fuente</th></tr></thead>
        <tbody id="filas"></tbody>
      </table>
    </div>
    <ol class="notas-tabla" id="notas" aria-label="Notas de la tabla"></ol>
    <p class="nota">Estimación de voto en % sobre voto válido, tal como la publica cada empresa. «–»: la empresa no da cifra para ese partido. La muestra es la que usa la media: en los seguimientos acumulados es una muestra efectiva menor que la declarada (lo explica la nota de la fila).</p>`;
  const F = id => document.getElementById(id);
  F('f-empresa').addEventListener('change', e => cambiar({ empresa: e.target.value }));
  F('f-medio').addEventListener('change', e => cambiar({ medio: e.target.value }));
  F('f-desde').addEventListener('change', e => cambiar({ desde: e.target.value }));
  F('f-hasta').addEventListener('change', e => cambiar({ hasta: e.target.value }));
  F('f-quitar').addEventListener('click', () => cambiar({ empresa: '', medio: '', desde: '', hasta: '' }));
  cont.querySelectorAll('button.ordenar').forEach(b => b.addEventListener('click', () => {
    const col = b.dataset.col;
    const tipo = COLUMNAS.find(c => c[0] === col)[2];
    const dir = estado.col === col ? (estado.dir === 'asc' ? 'desc' : 'asc') : (tipo === 'texto' ? 'asc' : 'desc');
    cambiar({ col, dir });
  }));
  ponerControles();
}

function ponerControles() {
  const F = id => document.getElementById(id);
  F('f-empresa').value = estado.empresa; F('f-medio').value = estado.medio;
  F('f-desde').value = estado.desde; F('f-hasta').value = estado.hasta;
  // si el enlace trae una empresa o un medio que ya no existe, se ignora
  if (F('f-empresa').value !== estado.empresa) estado.empresa = '';
  if (F('f-medio').value !== estado.medio) estado.medio = '';
}

function cambiar(c) { Object.assign(estado, c); escribirHash(); pintar(); }

function pintar() {
  const { empresa, medio, desde, hasta, col, dir } = estado;
  const tipo = COLUMNAS.find(c => c[0] === col)[2];
  let E = D.encuestas.filter(e => (!empresa || e.id === empresa) && (!medio || e.medio === medio) &&
    (!desde || e.fin >= desde) && (!hasta || e.inicio <= hasta));
  const valor = e => col === 'fin' ? e.fin + e.inicio : e[col];
  const s = dir === 'asc' ? 1 : -1;
  E = [...E].sort((a, b) => {
    const x = valor(a), y = valor(b);
    if (x == null && y == null) return 0;
    if (x == null) return 1;                       // sin dato, siempre al final
    if (y == null) return -1;
    const r = tipo === 'texto' ? String(x).localeCompare(String(y), 'es', { sensitivity: 'base', numeric: true }) : (x < y ? -1 : x > y ? 1 : 0);
    return r * s || (b.fin > a.fin ? 1 : -1);
  });
  document.querySelectorAll('.tabla-encuestas th[data-col]').forEach(th => {
    const activa = th.dataset.col === col;
    if (activa) th.setAttribute('aria-sort', dir === 'asc' ? 'ascending' : 'descending'); else th.removeAttribute('aria-sort');
    th.querySelector('.flecha').textContent = activa ? (dir === 'asc' ? ' ▲' : ' ▼') : '';
  });
  const filtrado = empresa || medio || desde || hasta;
  const casas = new Set(E.map(e => e.id)).size;
  document.getElementById('recuento').textContent = filtrado
    ? `${E.length} de ${D.meta.n} encuestas (${casas} ${casas === 1 ? 'empresa' : 'empresas'}).`
    : `${D.meta.n} encuestas. Pulsa un encabezado para ordenar.`;
  document.getElementById('f-quitar').hidden = !filtrado;
  const notas = [];                                 // notas de las filas visibles, numeradas como llamadas al pie
  document.getElementById('filas').innerHTML = E.length ? E.map(e => fila(e, notas)).join('')
    : `<tr><td colspan="${COLUMNAS.length + 2}" class="izq vacia">Ninguna encuesta cumple esos filtros.</td></tr>`;
  document.getElementById('notas').innerHTML = notas.map(([n, e]) =>
    `<li id="nota-${n}" value="${n}"><b>${esc(e.empresa)}, ${campo(e.inicio, e.fin)}.</b> ${esc(e.nota)}</li>`).join('');
}

function fila(e, notas) {
  const f = e.fuente.replace(/\s*\(base de sondeos\)/, '');
  const fuente = e.url ? `<a href="${esc(e.url)}" rel="noopener">${esc(f)}</a>` : esc(f);
  const libre = e.libre ? ' <span class="marca-libre" title="Entra en la media con su sesgo estimado aparte">◆<span class="mudo"> (sesgo estimado aparte)</span></span>' : '';
  return `<tr>
    <td class="izq">${campo(e.inicio, e.fin)}</td>
    <td class="izq"><a href="casas.html#casa-${esc(e.id.replace(/[^A-Za-z0-9_-]/g, ''))}">${esc(e.empresa)}</a>${libre}<br><span class="medio">${esc(e.medio)}</span></td>
    <td>${e.n.toLocaleString('es-ES')}</td>
    ${PARTIDOS.map(([k]) => `<td>${pct(e[k])}</td>`).join('')}
    <td class="izq">${e.modo ? `<abbr title="${esc(e.modo)}">${esc(MODO_CORTO[e.modo] ?? e.modo)}</abbr>` : '–'}</td>
    <td class="izq">${fuente}${e.nota ? (notas.push([notas.length + 1, e]), ` <sup><a href="#nota-${notas.length}" aria-label="nota ${notas.length}">${notas.length}</a></sup>`) : ''}</td>
  </tr>`;
}
