// «Las encuestadoras»: una ficha por empresa. Lee datos/casas.json (lo genera R/07b_exportar_extra.R); no calcula nada.
import { colorCss, f1, fecha } from './comun.js';

const cont = document.getElementById('contenido');
const P4 = ['PP', 'PSOE', 'VOX', 'FA'];
const A_QUIEN = { PP: 'al PP', PSOE: 'al PSOE', VOX: 'a Vox', FA: 'a Frente Amplio' };
const CORTO = { PP: 'PP', PSOE: 'PSOE', VOX: 'Vox', FA: 'FA' };
const MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const NOTA_APARTE = {
  CIS_M3: 'No se usa la estimación que publica el CIS, sino una reestimación propia sobre sus microdatos: votantes probables más reparto de indecisos (modelo M3). Por eso estas cifras no son las del CIS.',
  SW: 'Entra con una muestra efectiva de 1000 entrevistas, menor que las 5500 declaradas, por dos razones: acumula entrevistas día a día y hay dudas publicadas sobre su modo de entrevista (llamadas automáticas).'
};

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const miles = n => (+n).toLocaleString('es-ES');
const dia = s => { const [, m, d] = s.split('-'); return `${+d} ${MES[+m - 1]}`; };
const campo = (a, b) => {
  if (a === b) return dia(a);
  const [, ma, da] = a.split('-'), [, mb, db] = b.split('-');
  return ma === mb ? `${+da}–${+db} ${MES[+mb - 1]}` : `${dia(a)}–${dia(b)}`;
};
const r1 = x => Math.round(x * 10) / 10;
const signo = x => { const v = r1(x); return (v > 0 ? '+' : v < 0 ? '−' : '') + f1(Math.abs(v)); };
const cuanto = x => { const v = r1(x); return v === 0 ? 'lo mismo que la media' : `${f1(Math.abs(v))} puntos ${v > 0 ? 'más' : 'menos'}`; };
const cruzaCero = ([, lo, hi]) => lo <= 0 && hi >= 0;
const ancla = c => 'casa-' + c.id.replace(/[^A-Za-z0-9_-]/g, '');

try {
  const r = await fetch('datos/casas.json', { cache: 'no-store' });
  if (!r.ok) throw new Error(`No se han podido cargar los datos (${r.status}).`);
  pintar(await r.json());
} catch (err) {
  cont.innerHTML = `<p class="error">${esc(err.message)} Recarga la página. Si el problema sigue, los datos están en <a href="datos/casas.json">datos/casas.json</a>.</p>`;
}

function pintar(D) {
  const orden = (a, b) => a.nombre.localeCompare(b.nombre, 'es', { sensitivity: 'base', numeric: true });
  const privadas = D.casas.filter(c => !c.libre).sort(orden), aparte = D.casas.filter(c => c.libre).sort(orden);
  // Escala común a todas las fichas: de −L a +L puntos, L entero (las marcas van de punto en punto)
  const L = Math.max(3, Math.ceil(Math.max(...D.casas.flatMap(c => P4.flatMap(p => c.efecto[p].slice(1).map(Math.abs))))));
  const casos = privadas.flatMap(c => P4.map(p => c.efecto[p]));
  const nCruza = casos.filter(cruzaCero).length;
  const ent = privadas.map(c => c.entregas.length);

  document.getElementById('corte').textContent = `Las encuestadoras, a ${fecha(D.meta.corte)}`;
  document.getElementById('pie-texto').textContent = `Efectos casa estimados por el agregador con las encuestas con trabajo de campo hasta el ${fecha(D.meta.corte)}. ` +
    'El efecto casa solo mide la distancia de cada empresa a la media de las demás; no es una nota ni una clasificación. ' +
    'Las cifras de cada encuesta son de sus autores y medios.';

  cont.innerHTML = `
    <h2 class="titulo-pag">Las encuestadoras</h2>
    <p class="entradilla">Cada empresa pregunta y reparte a los indecisos a su manera, y eso la lleva a dar algo más o algo menos a ciertos partidos: es su <strong>efecto casa</strong>.
    El modelo lo mide frente a la media del día con un supuesto clave: <strong>la media de las empresas privadas no tiene sesgo</strong>.
    Por eso dice cuánto se separa cada empresa de las demás, no quién acierta: si todas fallan hacia el mismo lado, como en 2023, no se nota.</p>
    <p class="nota">En cada ficha, el punto marca el efecto casa estimado y la barra, dónde cae en 9 de cada 10 estimaciones del modelo.
    Si la barra cruza la línea del cero, la empresa <em>no se distingue de la media</em>: pasa en ${nCruza} de los ${casos.length} casos:
    con entre ${Math.min(...ent)} y ${Math.max(...ent)} entregas por empresa, el margen es amplio.</p>
    <div class="leyenda-regla" aria-hidden="true"><span>Ejemplo de lectura:</span>${regla([0.6, -0.4, 1.8], 'PP', L)}<span class="marcas"><span>−${L}</span><span class="m0">0</span><span>+${L} puntos</span></span></div>
    <ul class="indice-casas" aria-label="Ir a la ficha de">${privadas.map(c => `<li><a href="#${ancla(c)}">${esc(c.nombre)}</a></li>`).join('')}${aparte.map(c => `<li class="aparte"><a href="#${ancla(c)}">${esc(c.nombre)}</a></li>`).join('')}</ul>

    <h2>Las ${privadas.length} empresas privadas</h2>
    <p class="nota">Fijan el punto de partida: en cada partido, sus efectos casa suman cero. En orden alfabético.</p>
    ${privadas.map(c => ficha(c, L)).join('')}

    <h2>Aparte: ${aparte.map(c => esc(c.nombre)).join(' y ')}</h2>
    <p class="nota">Entran en la media, pero no cuentan para fijar el cero: su efecto casa se estima libre, sin obligarlo a compensarse con el de las demás. Se mide igual, respecto a la media de las privadas.</p>
    ${aparte.map(c => ficha(c, L)).join('')}`;
}

function regla([m, lo, hi], p, L) {
  const pos = x => Math.max(0, Math.min(100, 50 + x / L * 50)).toFixed(2);
  return `<span class="regla" aria-hidden="true"><span class="cero"></span>
    <span class="tramo" style="left:${pos(lo)}%;width:${(pos(hi) - pos(lo)).toFixed(2)}%;background:${colorCss(p)}"></span>
    <span class="punto" style="left:${pos(m)}%;background:${colorCss(p)}"></span></span>`;
}

function ficha(c, L) {
  const u = c.ultima, esCIS = c.id === 'CIS_M3';
  const fuente = esCIS ? 'Cálculo propio: <a href="metodologia.html">metodología</a>' : u.fuente ? `Fuente: ${u.url ? `<a href="${esc(u.url)}"${/^https?:/.test(u.url) ? ' rel="noopener"' : ''}>${esc(u.fuente)}</a>` : esc(u.fuente)}` : '';
  const sesgos = P4.map(p => {
    const e = c.efecto[p];
    return `<li><span class="quien"><span class="cuadro" style="background:${colorCss(p)}"></span>${A_QUIEN[p]}</span> ${cuanto(e[0])}
      ${regla(e, p, L)}
      <span class="margen">entre ${signo(e[1])} y ${signo(e[2])}</span>${cruzaCero(e) ? '<span class="igual">no se distingue de la media</span>' : ''}</li>`;
  }).join('');
  return `<article class="ficha${c.libre ? ' libre' : ''}" id="${ancla(c)}" aria-labelledby="t-${ancla(c)}">
    <h3 id="t-${ancla(c)}">${esc(c.nombre)}</h3>
    <p class="ficha-meta"><b>${esCIS ? 'Origen' : c.clientes.length > 1 ? 'Medios' : 'Medio'}:</b> ${c.clientes.map(esc).join(', ')} · <b>Entrevista:</b> ${c.modo ? esc(c.modo) : 'no consta'}</p>
    <div class="ficha-cuerpo">
      <div>
        <p class="rotulo">${c.entregas.length === 1 ? '1 entrega usada' : `${c.entregas.length} entregas usadas`} <span class="margen">(fechas de campo y entrevistas)</span></p>
        <ul class="entregas">${c.entregas.map(([a, b, n]) => `<li>${campo(a, b)} <span class="n-ent">(${miles(n)})</span></li>`).join('')}</ul>
        <p class="ver-encuestas"><a href="encuestas.html#empresa=${encodeURIComponent(c.id)}">Ver sus encuestas con todas las cifras</a></p>
        <p class="rotulo">${esCIS ? 'Reestimación propia' : 'Última estimación publicada'} <span class="margen">(campo ${campo(u.inicio, u.fin)}, % de voto)</span></p>
        <table class="mini"><caption class="mudo">${esCIS ? 'Reestimación propia' : 'Última estimación publicada'} de ${esc(c.nombre)}</caption>
          <thead><tr>${P4.map(p => `<th scope="col"><span class="cuadro" style="background:${colorCss(p)}"></span>${CORTO[p]}</th>`).join('')}</tr></thead>
          <tbody><tr>${P4.map(p => `<td>${u[p] === null || u[p] === undefined ? '–' : f1(u[p])}</td>`).join('')}</tr></tbody></table>
        <p class="fuente">${fuente}</p>
      </div>
      <div>
        <p class="rotulo">Respecto a la media de las privadas, ${esCIS ? 'esta reestimación' : 'esta casa'} da…</p>
        <ul class="sesgos">${sesgos}</ul>
      </div>
    </div>
    ${NOTA_APARTE[c.id] ? `<p class="aparte-nota">${NOTA_APARTE[c.id]}</p>` : ''}
  </article>`;
}
