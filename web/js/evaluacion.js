// Evaluación tras el 29N. Lee datos/evaluacion.json, que genera R/10_evaluacion.R con los resultados; la página no
// calcula nada. Mientras el fichero no existe, solo avisa de que la evaluación se publicará con los resultados.
import * as C from './comun.js';

const { NOMBRES, f1, cada100, fecha } = C;
const color = k => (C.colorCss ? C.colorCss(k) : C.COLOR[k]) || '#9a948a';
const $ = id => document.getElementById(id);
const cont = $('contenido');
const CUATRO = ['PP', 'PSOE', 'VOX', 'FA'];
const MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const NBSP = ' ';

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const dec = (x, d = 1) => (+x).toLocaleString('es-ES', { minimumFractionDigits: d, maximumFractionDigits: d });
const pct = x => `${f1(x)}${NBSP}%`;
const signo = (x, d = 1) => { const r = +(+x).toFixed(d); return (r > 0 ? '+' : r < 0 ? '−' : '') + dec(Math.abs(r), d); };
const prob = p => p == null ? '–' : p > 0.99 ? `>99${NBSP}%` : p < 0.01 ? `<1${NBSP}%` : `${Math.round(p * 100)}${NBSP}%`;
const nombre = k => k === 'OTROS' ? 'Otros' : NOMBRES[k] || k;
const corto = k => ({ FA: 'FA', BILDU: 'Bildu', AA: 'Adelante', OTROS: 'Otros' })[k] || NOMBRES[k] || k;
const partido = k => `<span class="cuadro" style="background:${color(k)}"></span>${nombre(k) === corto(k) ? nombre(k) : `<span class="n-largo">${nombre(k)}</span><span class="n-corto">${corto(k)}</span>`}`;
const reparto = r => Object.entries(r || {}).map(([k, v]) => `${corto(k)}${NBSP}${v}`).join(' · ');
const fCorta = s => { const [, m, d] = s.split('-'); return `${+d}${NBSP}${MES[+m - 1]}`; };
const fechaHora = s => s ? `${fecha(s.slice(0, 10))} a las ${s.slice(11, 16)}` : '';
const enLista = xs => xs.length < 2 ? xs.join('') : `${xs.slice(0, -1).join(', ')} y ${xs.at(-1)}`;
const intervalo = (a, b, d = 1) => `${dec(a, d)}–${dec(b, d)}`;
const marcaDentro = b => b ? '<span class="dentro">dentro</span>' : '<span class="fuera">fuera</span>';
const nomEsc = x => C.ESCENARIOS?.find(s => s.id === x.escenario)?.corto || x.nombre;

const [E, casasPub] = await Promise.all([
  fetch('datos/evaluacion.json', { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null),
  fetch('datos/casas.json', { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null)
]);
if (!E?.meta) pendiente(); else pintar(E);

function pendiente() {
  cont.innerHTML = `<section class="veda"><h2>La evaluación se publicará cuando haya resultados</h2>
    <p>Con el escrutinio, esta página comparará la media de encuestas y la simulación de escaños con el resultado: el voto de cada partido,
    los escaños, las 52 circunscripciones y la última encuesta de cada empresa. Se publica salga como salga.</p></section>`;
}

function pintar(E) {
  const M = E.meta, V = E.voto, S = E.escanos, P = E.provincias, provisional = M.estado !== 'definitivo';
  $('enlace-json').hidden = false;
  $('pie-texto').textContent = (provisional ? 'Resultados del escrutinio provisional del Ministerio del Interior: pueden cambiar hasta el escrutinio general. '
    : 'Resultados del escrutinio general. ') + 'La media de encuestas y las simulaciones son las de la última versión publicada antes de la veda' +
    (M.corte ? `, con encuestas hasta el ${fecha(M.corte)}` : '') + ` (${M.simulaciones.toLocaleString('es-ES')} simulaciones de escaños).`;

  const partes = [];
  partes.push(`<div class="maquina estado-eval"><p class="modo"><span class="sello${provisional ? ' no' : ''}">${provisional ? 'Provisional' : 'Definitivo'}</span>` +
    (M.escrutado != null ? `Escrutado: ${dec(M.escrutado, 2)}${NBSP}%. ` : '') +
    (provisional ? 'Las cifras pueden cambiar hasta el escrutinio general. ' : '') + `Actualizado el ${fechaHora(M.generado)}.</p>` +
    (M.avisos?.length ? `<ul class="avisos">${M.avisos.map(a => `<li>${esc(a)}</li>`).join('')}</ul>` : '') + '</div>');
  partes.push(`<p class="entradilla">${resumen(V, S, M.completo)}</p>`);
  partes.push(V ? seccionVoto(V, M) : '<h2>El voto</h2><p class="nota">Falta el voto estatal.</p>');
  partes.push(S ? seccionEscanos(S, M.completo) : '<h2>Los escaños</h2><p class="nota">Faltan los escaños.</p>');
  partes.push(P ? seccionProvincias(P) : '');
  partes.push(E.casas ? seccionCasas(E.casas, V) : '');
  cont.innerHTML = partes.join('');

  const graficos = [];
  if (V) graficos.push([$('g-voto'), filasVoto(V), { cero: 'media', titulo: 'Diferencia entre el voto de cada partido y la media de encuestas, con los intervalos del 90 %' }]);
  if (S) graficos.push([$('g-escanos'), filasEscanos(S), { cero: 'mediana', decimales: 0, titulo: 'Diferencia entre los escaños de cada partido y la mediana de las simulaciones, con el intervalo del 90 %' }]);
  const dibujar = () => graficos.forEach(([n, f, o]) => grafico(n, f, o));
  dibujar();
  let ancho = cont.clientWidth, espera;
  addEventListener('resize', () => { clearTimeout(espera); espera = setTimeout(() => { if (Math.abs(cont.clientWidth - ancho) > 20) { ancho = cont.clientWidth; dibujar(); } }, 200); });
}

// ---------------------------------------------------------------- resumen
function resumen(V, S, completo) {
  const fr = [];
  if (V) {
    const v = k => V.partidos.find(x => x.partido === k);
    fr.push(`La media de encuestas daba al PP un ${pct(v('PP').media)} y al PSOE un ${pct(v('PSOE').media)}; han obtenido un ${pct(v('PP').resultado)} y un ${pct(v('PSOE').resultado)}.`);
    fr.push(`De los ${V.resumen.n} partidos de la media, ${V.resumen.dentro} quedaron dentro de su intervalo del 90${NBSP}%, y ${V.resumen.dentro_comun} al sumar el error común de todas las encuestas.`);
  }
  if (S && !completo) fr.push(`Con los escaños asignados hasta ahora, PP y Vox suman <strong>${S.pp_vox.resultado}</strong>; faltan circunscripciones por completar.`);
  else if (S) {
    const b = S.pp_vox;
    fr.push(b.mayoria ? `PP y Vox suman <strong>${b.resultado} escaños</strong>, mayoría absoluta: la media la daba en ${cada100(b.p_mayoria)} simulaciones.`
      : `PP y Vox suman <strong>${b.resultado} escaños</strong>, sin mayoría absoluta: la media daba ese desenlace en ${cada100(b.p_resultado)} simulaciones.`);
    const c = S.escenarios.filter(x => x.mas_cercano);
    fr.push(`${c.length > 1 ? 'Los supuestos que más se acercaron' : 'El supuesto que más se acercó'} en PP, PSOE, Vox y Frente Amplio ${c.length > 1 ? 'fueron' : 'fue'} ${enLista(c.map(x => `«${esc(nomEsc(x))}»`))}, con ${c[0].desvio} escaños de desvío sumado.`);
  }
  return fr.join(' ');
}

// ---------------------------------------------------------------- voto
function textoErrorComun(ec) {
  const orden = ['PP', 'PSOE', 'VOX', 'FA', 'POD', 'SALF'].filter(k => ec?.[k] != null), grupos = [];
  orden.forEach(k => { const g = grupos.at(-1); if (g && g.v === ec[k]) g.k.push(nombre(k)); else grupos.push({ v: ec[k], k: [nombre(k)] }); });
  return enLista(grupos.map((g, i) => `${g.v.toLocaleString('es-ES')}${i ? '' : ' puntos'} en ${enLista(g.k)}`));
}
function filasVoto(V) {
  return V.partidos.map(x => ({
    k: x.partido, etiqueta: nombre(x.partido), corto: corto(x.partido),
    lo: x.p05 - x.media, hi: x.p95 - x.media, lo2: x.p05_comun - x.media, hi2: x.p95_comun - x.media,
    punto: x.error, raya: x.promedio_simple - x.media, texto: `${f1(x.resultado)} (${signo(x.error)})`,
    detalle: `<b>${nombre(x.partido)}</b><br>Resultado: ${pct(x.resultado)}<br>Media: ${pct(x.media)}<br>9 de cada 10: ${intervalo(x.p05, x.p95)}<br>Con el error común: ${intervalo(x.p05_comun, x.p95_comun)}<br>Promedio simple: ${pct(x.promedio_simple)}`
  }));
}
function seccionVoto(V, M) {
  const R = V.resumen;
  const filas = V.partidos.map(x => `<tr><td class="izq">${partido(x.partido)}</td>
    <td><b>${f1(x.resultado)}</b></td><td>${f1(x.media)}</td><td><b>${signo(x.error)}</b></td>
    <td>${intervalo(x.p05, x.p95)} ${marcaDentro(x.dentro)}</td><td>${intervalo(x.p05_comun, x.p95_comun)} ${marcaDentro(x.dentro_comun)}</td>
    <td>${f1(x.promedio_simple)}</td><td>${signo(x.error_simple)}</td></tr>`).join('');
  const otros = V.otros?.length ? `<h3>Partidos fuera de la media</h3>
    <p class="nota">No entran en la media de encuestas: el modelo les asignaba un voto fijo, tomado de las encuestas que los publican, con un margen del 20${NBSP}% hacia arriba o hacia abajo (30${NBSP}% en Adelante Andalucía).</p>
    <div class="desliza"><table class="tabla-eval"><thead><tr><th class="izq">Partido</th><th>Resultado</th><th>Supuesto</th><th>Diferencia</th><th>9 de cada 10</th></tr></thead><tbody>
    ${V.otros.map(x => `<tr><td class="izq">${partido(x.partido)}</td><td><b>${dec(x.resultado, 2)}</b></td>
      <td>${dec(x.supuesto, 2)}</td><td><b>${signo(x.error, 2)}</b></td><td>${intervalo(x.p05, x.p95, 2)} ${marcaDentro(x.dentro)}</td></tr>`).join('')}</tbody></table></div>` : '';
  return `<h2>El voto</h2>
    <p class="nota">Diferencia entre el resultado y la media de encuestas proyectada al 29 de noviembre, en puntos sobre el voto válido. La barra oscura es el intervalo del 90${NBSP}% de la media;
    la clara, el mismo intervalo al sumar un error común de todas las encuestas (desviación típica de ${textoErrorComun(M.error_comun)}), que es el que usaba la simulación de escaños.
    La raya es el promedio simple de la última encuesta de cada empresa, sin corregir.</p>
    ${leyenda([['int1', '9 de cada 10 (media)'], ['int2', 'con el error común'], ['punto', 'resultado'], ['raya', 'promedio simple']])}
    <div class="grafico grafico-eval" id="g-voto"></div>
    <div class="desliza"><table class="tabla-eval"><caption class="mudo">Voto: resultado, media de encuestas e intervalos</caption>
      <thead><tr><th class="izq">Partido</th><th>Resultado</th><th>Media</th><th>Diferencia</th><th>9 de cada 10</th><th>Con error común</th><th>Promedio simple</th><th>Diferencia</th></tr></thead>
      <tbody>${filas}</tbody></table></div>
    <p class="nota">Diferencia media, sin signo: ${dec(R.error_medio, 2)} puntos con la media de encuestas y ${dec(R.error_medio_simple, 2)} con el promedio simple de las últimas encuestas de cada empresa
    (${dec(R.error_medio_cuatro, 2)} y ${dec(R.error_medio_simple_cuatro, 2)} en PP, PSOE, Vox y Frente Amplio).</p>
    ${otros}`;
}

// ---------------------------------------------------------------- escaños
function filasEscanos(S) {
  return S.partidos.map(x => ({
    k: x.partido, etiqueta: nombre(x.partido), corto: corto(x.partido),
    lo: x.p05 - x.mediana, hi: x.p95 - x.mediana, punto: x.error, texto: `${x.resultado} (${signo(x.error, 0)})`,
    detalle: `<b>${nombre(x.partido)}</b><br>Escaños: ${x.resultado}<br>Mediana: ${x.mediana}<br>9 de cada 10: ${x.p05}–${x.p95}<br>Menos escaños en ${cada100(x.p_menos)} simulaciones; más, en ${cada100(x.p_mas)}`
  }));
}
function seccionEscanos(S, completo) {
  const b = S.pp_vox;
  const n100 = b.p_mayoria >= 1 ? 100 : Math.min(99, Math.max(0, Math.round(b.p_mayoria * 100)));
  const cuadros = Array.from({ length: 100 }, (_, i) => `<i class="${i < n100 ? 'si' : ''}"></i>`).join('');
  const filas = S.partidos.map(x => `<tr><td class="izq">${partido(x.partido)}</td>
    <td><b>${x.resultado}</b></td><td>${x.mediana}</td><td><b>${signo(x.error, 0)}</b></td><td>${x.p05}–${x.p95} ${marcaDentro(x.dentro)}</td><td>${prob(x.p_exacto)}</td></tr>`).join('');
  const r = S.partidos.reduce((a, x) => (a[x.partido] = x.resultado, a), {});
  const sc = S.escenarios.map(x => `<tr><td class="izq">${esc(nomEsc(x))}${x.en_portada ? '' : '*'}${x.mas_cercano ? ' <span class="marca fav">más cerca</span>' : ''}</td>
    <td>${x.PP}</td><td>${x.PSOE}</td><td>${x.VOX}</td><td>${x.FA}</td><td><b>${x.desvio}</b></td><td>${prob(x.p_mayoria)}</td><td>${x.p05}–${x.p95} ${marcaDentro(x.dentro_pp_vox)}</td></tr>`).join('');
  return `<h2>Los escaños</h2>
    ${completo ? '' : '<p class="aviso-parcial">Escaños parciales: hay circunscripciones sin todos sus escaños asignados, así que estas cifras todavía no son el resultado.</p>'}
    <p class="nota">Diferencia entre los escaños obtenidos y la mediana de las simulaciones con la media de encuestas. La barra va del 5 al 95${NBSP}% de las simulaciones: ahí cayeron
    ${S.resumen.dentro} de las ${S.resumen.n} candidaturas. «Prob. exacta» es la parte de las simulaciones que daba exactamente esos escaños.</p>
    ${leyenda([['int1', '9 de cada 10 simulaciones'], ['punto', 'resultado']])}
    <div class="grafico grafico-eval" id="g-escanos"></div>
    <div class="desliza"><table class="tabla-eval"><caption class="mudo">Escaños: resultado y simulaciones con la media de encuestas</caption>
      <thead><tr><th class="izq">Candidatura</th><th>Escaños</th><th>Mediana</th><th>Diferencia</th><th>9 de cada 10</th><th>Prob. exacta</th></tr></thead>
      <tbody>${filas}</tbody></table></div>

    <div class="pleno-eval">
      <span class="sello${b.mayoria ? '' : ' no'}" aria-hidden="true">${b.resultado}</span>
      <p><b>PP + Vox: ${b.resultado} escaños${!completo ? ' con el escrutinio incompleto' : b.mayoria ? ', mayoría absoluta' : ', sin mayoría absoluta'}.</b> La media daba una mediana de ${b.mediana}, entre ${b.p05} y ${b.p95} en 9 de cada 10 simulaciones,
      y mayoría (176 o más) en ${cada100(b.p_mayoria)}. Sumaban menos de ${b.resultado} en ${cada100(b.p_menos)} simulaciones y más, en ${cada100(b.p_mas)}.</p>
      <div class="cien" role="img" aria-label="${cada100(b.p_mayoria)} simulaciones con mayoría de PP y Vox">${cuadros}</div>
    </div>
    <p class="nota">Cada cuadro es una de cada 100 simulaciones con la media de encuestas: negro si PP y Vox sumaban 176 escaños o más.</p>

    <h3>¿Qué supuesto se acercó más?</h3>
    <p class="nota">Mediana de escaños con cada supuesto. Desvío: suma de las diferencias, sin signo, en PP, PSOE, Vox y Frente Amplio; de menor a mayor.
    ${S.escenarios.some(x => !x.en_portada) ? 'Con asterisco, supuestos que se calcularon pero no se mostraban en portada.' : ''}</p>
    <div class="desliza"><table class="tabla-eval tabla-sup"><caption class="mudo">Escaños de cada supuesto frente al resultado</caption>
      <thead><tr><th class="izq">Supuesto</th><th>PP</th><th>PSOE</th><th>Vox</th><th>FA</th><th>Desvío</th><th>Prob. de mayoría PP+Vox</th><th>PP+Vox, 9 de cada 10</th></tr></thead>
      <tbody><tr class="real"><td class="izq">Resultado</td><td>${r.PP}</td><td>${r.PSOE}</td><td>${r.VOX}</td><td>${r.FA}</td><td></td><td>${b.mayoria ? 'mayoría' : 'sin mayoría'}</td><td>${b.resultado}</td></tr>${sc}</tbody></table></div>`;
}

// ---------------------------------------------------------------- circunscripciones
function celdaUltimo(x) {
  const fav = x.ultimo_favorito ? `${corto(x.ultimo_favorito)} ${prob(x.p_favorito)}` : '–';
  if (!x.ultimo_real) return `<span class="nota-celda">favorito: ${fav}</span>`;
  return `${corto(x.ultimo_real)}<span class="nota-celda">${x.acierto_ultimo ? `era el favorito (${prob(x.p_favorito)})` : `${prob(x.p_ultimo_real)}; favorito: ${fav}`}</span>`;
}
function filaProv(x, ultimo) {
  if (!x.completa) return `<tr><td class="izq">${esc(x.provincia)} (${x.escanos})</td><td class="izq reparto" colspan="${ultimo ? 4 : 3}">Escrutinio incompleto: ${reparto(x.reparto_real) || 'sin datos'}</td>${ultimo ? '' : '<td></td>'}</tr>`;
  return `<tr><td class="izq">${esc(x.provincia)} (${x.escanos})</td><td class="izq reparto">${reparto(x.reparto_real)}</td><td class="izq reparto">${reparto(x.reparto_mas_repetido)}</td>
    <td>${x.cambiados}</td>${ultimo ? `<td class="izq">${celdaUltimo(x)}</td>` : `<td>${prob(x.p_dos_primeros)}</td>`}</tr>`;
}
function seccionProvincias(P) {
  const R = P.resumen, U = R.ultimo;
  const peores = P.lista.filter(x => x.completa && x.cambiados > 0).slice(0, 10);
  const todas = [...P.lista].sort((a, b) => a.provincia.localeCompare(b.provincia, 'es'));
  const ult = U.con_datos ? `El último escaño fue para el partido que más veces lo ganaba en las simulaciones en ${U.aciertos} de ${U.con_datos} circunscripciones con voto provincial
    (con las probabilidades que daba el modelo, lo esperable eran unas ${dec(U.esperados, 0)}).` : 'Sin el voto por circunscripción no se puede saber aún quién se llevó el último escaño de cada una.';
  return `<h2>Las circunscripciones</h2>
    <p class="nota">En ${R.aciertos_reparto} de las ${R.evaluadas} circunscripciones con el escrutinio completo, el reparto que más se repetía en las simulaciones fue el real;
    con las probabilidades que daba el modelo, lo esperable eran unas ${dec(R.esperados_reparto, 0)}. En total, ${R.cambiados} escaños fueron a un partido distinto del de ese reparto. ${ult}</p>
    <h3>Donde más se falló</h3>
    ${peores.length ? `<p class="nota">Circunscripciones con más escaños en un partido distinto del reparto más repetido. La última columna es la probabilidad que daban las simulaciones
      a que los dos primeros partidos sacaran exactamente esos escaños.</p>
    <div class="desliza"><table class="tabla-eval tabla-prov"><caption class="mudo">Circunscripciones con más escaños fallados</caption>
      <thead><tr><th class="izq">Circunscripción</th><th class="izq">Resultado</th><th class="izq">Lo que más se repetía</th><th>Escaños en otro partido</th><th>Prob. de los dos primeros</th></tr></thead>
      <tbody>${peores.map(x => filaProv(x, false)).join('')}</tbody></table></div>`
      : '<p class="nota">En todas las circunscripciones con el escrutinio completo, el reparto más repetido fue el real.</p>'}
    <details class="todas"><summary>Las ${P.lista.length} circunscripciones</summary>
      <div class="desliza"><table class="tabla-eval tabla-prov"><caption class="mudo">Todas las circunscripciones</caption>
        <thead><tr><th class="izq">Circunscripción</th><th class="izq">Resultado</th><th class="izq">Lo que más se repetía</th><th>Escaños en otro partido</th><th class="izq">Último escaño</th></tr></thead>
        <tbody>${todas.map(x => filaProv(x, true)).join('')}</tbody></table></div>
    </details>`;
}

// ---------------------------------------------------------------- empresas
function seccionCasas(casas, V) {
  const pub = {};
  (casasPub?.casas || []).forEach(c => pub[c.id] = { nombre: c.nombre, medio: (c.clientes || []).join(', ') });
  const PROPIAS = { CIS_M3: 'CIS (reestimación propia)', MiC_M3: 'More in Common (reestimación propia)' };
  const fila = (x, propia) => {
    const nom = propia ? PROPIAS[x.casa] || x.medio : pub[x.casa]?.nombre || x.casa;
    const medio = pub[x.casa]?.medio || (propia ? 'microdatos' : x.medio);
    return { nom, html: `<tr><td class="izq">${esc(nom)}</td><td class="izq medio">${esc(medio)}</td><td>${fCorta(x.fin)}</td>` +
      CUATRO.map(k => x[k] == null ? '<td>–</td>' : `<td title="Estimación: ${pct(x[k])}">${signo(x[`error_${k}`])}</td>`).join('') +
      `<td><b>${dec(x.error_medio, 2)}</b></td></tr>` };
  };
  const ordenar = xs => xs.sort((a, b) => a.nom.localeCompare(b.nom, 'es', { sensitivity: 'base' })).map(x => x.html).join('');
  const encuestas = ordenar(casas.filter(x => x.tipo === 'encuesta').map(x => fila(x, false)));
  const propias = ordenar(casas.filter(x => x.tipo !== 'encuesta').map(x => fila(x, true)));
  const ref = (titulo, campo) => {
    const e = CUATRO.map(k => V.partidos.find(x => x.partido === k)[campo]);
    return `<tr><td class="izq">${titulo}</td><td class="medio"></td><td></td>${e.map(v => `<td>${signo(v)}</td>`).join('')}<td>${dec(e.reduce((a, v) => a + Math.abs(v), 0) / e.length, 2)}</td></tr>`;
  };
  return `<h2>Las encuestas, una a una</h2>
    <p class="nota">Diferencia entre el resultado y la última estimación que publicó cada empresa antes de la veda, en puntos: positiva si el partido sacó más de lo que daba la encuesta.
    Por orden alfabético. La última columna es la media de las cuatro diferencias, sin signo. Una encuesta con el trabajo de campo lejos del 29 de noviembre no medía lo mismo que una de la última semana.</p>
    <div class="desliza"><table class="tabla-eval tabla-casas"><caption class="mudo">Error de la última encuesta de cada empresa</caption>
      <thead><tr><th class="izq">Empresa</th><th class="izq medio">Medio</th><th>Campo hasta</th><th>PP</th><th>PSOE</th><th>Vox</th><th>FA</th><th>Dif. media</th></tr></thead>
      <tbody>${encuestas}</tbody>
      ${propias ? `<tbody><tr class="sep"><td colspan="8">Reestimaciones propias con microdatos</td></tr>${propias}</tbody>` : ''}
      <tfoot>${ref('Media de encuestas (este modelo)', 'error')}${ref('Promedio simple de las últimas encuestas', 'error_simple')}</tfoot>
    </table></div>`;
}

// ---------------------------------------------------------------- gráfico de diferencias (SVG)
function leyenda(items) {
  const muestra = {
    int1: '<svg viewBox="0 0 26 12"><rect class="int1" x="0" y="1" width="26" height="10" rx="2"/></svg>',
    int2: '<svg viewBox="0 0 26 12"><rect class="int2" x="0" y="1" width="26" height="10" rx="2"/></svg>',
    punto: '<svg viewBox="0 0 14 14"><circle class="punto muestra" cx="7" cy="7" r="5.5"/></svg>',
    raya: '<svg viewBox="0 0 6 16"><line class="raya" x1="3" x2="3" y1="0" y2="16"/></svg>'
  };
  return `<div class="leyenda" aria-hidden="true">${items.map(([k, t]) => `<span>${muestra[k]}${t}</span>`).join('')}</div>`;
}
function grafico(nodo, filas, o) {
  if (!nodo) return;
  const W = Math.max(300, nodo.clientWidth || 800), estrecho = W < 560, d = o.decimales ?? 1;
  const iz = estrecho ? 70 : 132, de = estrecho ? 88 : 120, alto = estrecho ? 28 : 30, arr = 30, aba = 6;
  const H = arr + filas.length * alto + aba;
  const ext = Math.max(d ? 1 : 2, ...filas.flatMap(f => [f.lo, f.hi, f.lo2, f.hi2, f.punto, f.raya]).filter(v => v != null && isFinite(v)).map(Math.abs));
  // escala: el límite más corto que cubre los datos con 1-3 marcas por lado en móvil y 2-4 en pantalla ancha
  const todas = [0.5, 1, 2, 5, 10, 20, 25, 50, 100].filter(p => d || p >= 1).map(p => ({ p, n: Math.max(1, Math.ceil(ext / p)) }))
    .filter(o => o.n <= (estrecho ? 3 : 4));
  const validas = todas.filter(o => o.n >= (estrecho ? 1 : 2)), opciones = validas.length ? validas : todas;
  opciones.sort((a, b) => a.p * a.n - b.p * b.n || (estrecho ? a.n - b.n : b.n - a.n));
  const { p: paso, n } = opciones[0] || { p: 100, n: Math.ceil(ext / 100) }, lim = n * paso;
  const X = v => iz + (v + lim) / (2 * lim) * (W - iz - de);
  let s = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(o.titulo)}">`;
  for (let i = -n; i <= n; i++) {
    const v = i * paso, x = X(v).toFixed(1);
    s += `<line class="rej${i ? '' : ' cero'}" x1="${x}" x2="${x}" y1="${arr - 6}" y2="${H - aba}"/>`;
    s += `<text class="eje" x="${x}" y="${arr - 12}" text-anchor="middle">${i ? signo(v, paso < 1 ? 1 : 0) : o.cero}</text>`;
  }
  filas.forEach((f, i) => {
    const y = arr + i * alto + alto / 2, ancho = (a, b) => Math.max(2, X(b) - X(a)).toFixed(1);
    s += `<text class="etq" x="${iz - 8}" y="${y + 4}" text-anchor="end">${esc(estrecho ? f.corto : f.etiqueta)}</text>`;
    if (f.lo2 != null) s += `<rect class="int2" x="${X(f.lo2).toFixed(1)}" y="${y - 5}" width="${ancho(f.lo2, f.hi2)}" height="10" rx="2"/>`;
    s += `<rect class="int1" x="${X(f.lo).toFixed(1)}" y="${y - 5}" width="${ancho(f.lo, f.hi)}" height="10" rx="2"/>`;
    if (f.raya != null) s += `<line class="raya" x1="${X(f.raya).toFixed(1)}" x2="${X(f.raya).toFixed(1)}" y1="${y - 9}" y2="${y + 9}"/>`;
    s += `<circle class="punto" cx="${X(f.punto).toFixed(1)}" cy="${y}" r="6" style="fill:${color(f.k)}"/>`;
    s += `<text class="val" x="${W - de + 10}" y="${y + 4}">${f.texto}</text>`;
  });
  nodo.innerHTML = s + '</svg><div class="lectura" hidden></div>';
  const svg = nodo.querySelector('svg'), lec = nodo.querySelector('.lectura');
  const leer = ev => {
    const r = svg.getBoundingClientRect(), k = r.width / W, i = Math.floor(((ev.clientY - r.top) / k - arr) / alto);
    if (i < 0 || i >= filas.length) { lec.hidden = true; return; }
    lec.innerHTML = filas[i].detalle; lec.hidden = false;
    const px = ev.clientX - r.left, izq = px > r.width / 2 ? px - lec.offsetWidth - 14 : px + 14;
    lec.style.left = `${Math.max(0, Math.min(r.width - lec.offsetWidth, izq))}px`;
    lec.style.top = `${(arr + (i + 1) * alto) * k + 2}px`;
  };
  svg.addEventListener('pointermove', leer); svg.addEventListener('pointerdown', leer);
  svg.addEventListener('pointerleave', () => { lec.hidden = true; });
}
