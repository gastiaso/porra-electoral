import { cargar, avisoVeda, colorCss, ORDEN, ESCENARIOS, f1, r0, cada100, fecha, sinMovimiento } from './comun.js';

const cont = document.getElementById('contenido');
const miles = n => (+n).toLocaleString('es-ES');
const esc = t => String(t ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const DEMOCRATA = 'https://www.democrata.es/elecciones-generales-espana/herramientas/encuestas';
const CIERRE = '2026-11-23';
// fechas de campo cortas, como en «Las encuestadoras»: «2–4 nov», «26 oct–8 nov»
const MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const dia = f => { const [, m, d] = f.split('-'); return `${+d} ${MES[+m - 1]}`; };
const campo = (a, b) => { if (a === b) return dia(a); const [, ma, da] = a.split('-'), [, mb, db] = b.split('-');
  return ma === mb ? `${+da}–${+db} ${MES[+mb - 1]}` : `${dia(a)}–${dia(b)}`; };   // última actualización antes de la veda (LOREG, art. 69.7)

try {
  const D = await cargar();
  if (D.meta.veda) {
    avisoVeda(cont);
    document.getElementById('enlace-csv').hidden = true;
  } else {
    pintar(D);
  }
} catch (err) {
  cont.innerHTML = `<p class="error" role="alert">${err.message} Recarga la página. Si el problema sigue, los datos están en <a href="datos/modelo.json">datos/modelo.json</a>.</p>`;
}

function pintar(D) {
  const B = D.bloque_pp_vox, N = D.nombres, S = D.meta.simulaciones;
  document.getElementById('corte').textContent = `Media de encuestas a ${fecha(D.meta.corte)}`;
  // Desde la última actualización, un sello deja claro que las cifras ya no cambian hasta que cierren los colegios
  if (D.meta.corte >= CIERRE) {
    const c = document.getElementById('corte');
    c.insertAdjacentHTML('afterend', '<span class="sello-cierre">Datos cerrados el 23 de noviembre a las 23:59. No se actualizan hasta el cierre de los colegios.</span>');
    c.parentElement.classList.add('con-sello');
  }
  document.getElementById('pie-texto').textContent = D.pie;

  cont.innerHTML = `
    <p class="entradilla">Si las encuestas aciertan de media, <strong>PP y Vox suman ${B.mediana} escaños</strong>: entre ${B.p05} y ${B.p95} en 9 de cada 10 simulaciones. La mayoría absoluta está en 176 y la superan en ${cada100(B.p_mayoria)}. Si fallan como en 2023, el margen se estrecha: está más abajo.</p>

    <div class="maquina">
      <p class="modo" id="modo"><b>La media.</b> Lo que sale más a menudo en las ${miles(S)} elecciones simuladas.</p>
      <div class="botones">
        <button class="palanca" id="palanca" type="button"><svg viewBox="0 0 22 30" aria-hidden="true"><rect x="3" y="24" width="16" height="5" fill="currentColor"/><g class="brazo"><rect x="9.5" y="5" width="3" height="21" fill="currentColor"/><circle cx="11" cy="5" r="4.5" fill="#d9480f"/></g></svg>Tirar de la palanca</button>
        <button class="volver" id="volver" type="button" hidden>Volver a la media</button>
      </div>
      <p class="mudo" id="anuncio" role="status"></p>
    </div>
    <table class="boleto-tabla">
      <caption class="mudo">Voto y escaños por candidatura</caption>
      <thead><tr><th scope="col"><span class="mudo">Fila</span></th><th scope="col" class="izq">Candidatura</th><th scope="col">% voto</th><th scope="col">Escaños</th><th scope="col">9 de cada 10</th></tr></thead>
      <tbody id="filas"></tbody>
    </table>

    <div class="llamada"><p><b>¿Tú qué crees?</b>Rellena tu porra del 29N, compártela con tus amigos y compárala con los resultados la noche electoral. Sin dinero.</p><a class="palanca" href="porra.html">Rellenar mi porra</a></div>

    <h2>Cómo se ha movido la media</h2>
    <p class="nota">Línea: media corregida por el sesgo de cada empresa. Banda: donde cae en 9 de cada 10 casos. Puntos: cada encuesta. El tramo final, sin encuestas, es la proyección al 29 de noviembre.</p>
    <div class="grafico" id="grafico"></div>
    <details class="datos-grafico"><summary>Ver los datos del gráfico</summary>
      <p class="nota">Media corregida de cada partido, en % de voto, una fecha por semana. Desde el ${fecha(D.meta.corte)}, proyección.</p>
      <div class="desliza" tabindex="0" role="region" aria-label="Datos del gráfico">${tablaSerie(D)}</div>
    </details>

    <h2>Quién se lleva el último escaño</h2>
    <p class="nota">Las circunscripciones donde el último escaño está más disputado. 1 es el favorito; X, empate técnico (menos de 5 puntos de diferencia); 2, el siguiente.</p>
    <div class="desliza"><table class="x12"><caption class="mudo">Quién se lleva el último escaño en cada circunscripción: 1, favorito; X, empate técnico; 2, el siguiente</caption><thead><tr><th scope="col"><span class="mudo">Fila</span></th><th scope="col" class="izq">Circunscripción (escaños)</th><th scope="col" style="text-align:center">1</th><th scope="col" class="colx" style="text-align:center">X</th><th scope="col" style="text-align:center">2</th></tr></thead><tbody id="x12"></tbody></table></div>

    <h2>¿Y si las encuestas se equivocan?</h2>
    <p class="nota">La media da por hecho que las empresas, en conjunto, aciertan. No siempre pasa: en 2023 se pasaron con el PP y se quedaron cortas con el PSOE. Por eso repetimos la elección ${miles(S)} veces con cada uno de estos supuestos. Cada tarjeta resume 100 de esas elecciones: un cuadro negro es una elección en la que PP y Vox suman 176 escaños o más, y uno blanco, una en la que no llegan. <a href="preguntas.html#escenarios">¿Por qué no hay una única cifra?</a></p>
    <div class="falla" id="falla"></div>
    <p class="seguir"><a class="volver" href="supuestos.html">Prueba otros supuestos</a></p>

    <details><summary>Las ${D.meta.encuestas} encuestas de la media</summary>
      <p class="fuente-encuestas">Cifras, fechas de campo y muestras: <a href="${DEMOCRATA}" rel="noopener">base de sondeos de Demócrata</a>, que enlaza cada estudio con su publicación original; la última columna dice de dónde sale cada fila. Qué hace cada empresa y cuánto se separa de las demás: <a href="casas.html">Las encuestadoras</a>. Para filtrarlas y ordenarlas: <a href="encuestas.html">Las encuestas</a>.</p>
      <div class="desliza" tabindex="0" role="region" aria-label="Encuestas de la media"><table class="encuestas"><caption class="mudo">Encuestas de la media, de la más reciente a la más antigua: empresa, medio, fechas de campo, muestra, % de voto y fuente</caption><thead><tr><th scope="col" class="izq">Empresa</th><th scope="col" class="izq">Medio</th><th scope="col" class="izq">Campo</th><th scope="col">Muestra</th><th scope="col">PP</th><th scope="col">PSOE</th><th scope="col">Vox</th><th scope="col">FA</th><th scope="col">Podemos</th><th scope="col">SALF</th><th scope="col" class="izq">Fuente</th></tr></thead><tbody id="encuestas"></tbody></table></div>
    </details>`;

  // ---------------------------------------------------------------- boleto y palanca
  const filas = document.getElementById('filas');
  const celdas = {};
  ORDEN.forEach((k, j) => {
    const e = D.escanos[k], v = D.voto(k);
    filas.insertAdjacentHTML('beforeend', `<tr><td class="n">${j + 1}</td><td class="izq"><span class="cuadro" style="background:${colorCss(k)}"></span>${N[k]}</td>
      <td>${v ? f1(v.mediana) : '–'}</td><td class="esc" id="e-${k}">${r0(e.mediana)}</td><td>${r0(e.p05)}–${r0(e.p95)}</td></tr>`);
    celdas[k] = document.getElementById('e-' + k);
  });
  filas.insertAdjacentHTML('beforeend', `<tr class="pleno"><td class="n">15</td><td class="izq">PP + Vox</td><td></td><td><span class="sello" id="pleno">${B.mediana}</span></td><td>${B.p05}–${B.p95}</td></tr>`);
  const pleno = document.getElementById('pleno'), modo = document.getElementById('modo');
  const palanca = document.getElementById('palanca'), volver = document.getElementById('volver');
  const tabla = document.querySelector('.boleto-tabla');
  let i = 0, rodando = false;

  // Para lectores de pantalla: un resumen al terminar cada tirada (la animación no se anuncia)
  const anuncio = document.getElementById('anuncio');
  const resumen = (e, s) => `PP ${e.PP}, PSOE ${e.PSOE}, Vox ${e.VOX}, Frente Amplio ${e.FA}. PP y Vox suman ${s}${s >= 176 ? ': mayoría absoluta' : ': no llegan a 176'}.`;
  const ponerMedia = () => {
    ORDEN.forEach(k => celdas[k].textContent = r0(D.escanos[k].mediana));
    pleno.textContent = B.mediana; pleno.classList.remove('no');
    modo.innerHTML = `<b>La media.</b> Lo que sale más a menudo en las ${miles(S)} elecciones simuladas.`;
    volver.hidden = true;
    anuncio.textContent = 'La media. ' + resumen(Object.fromEntries(ORDEN.map(k => [k, r0(D.escanos[k].mediana)])), B.mediana);
  };
  const ponerTirada = t => {
    ORDEN.forEach(k => celdas[k].textContent = t[k]);
    const s = t.PP + t.VOX; pleno.textContent = s; pleno.classList.toggle('no', s < 176);
    modo.innerHTML = `<b>Tirada ${miles(t.n)} de ${miles(S)}.</b> ${s >= 176 ? 'PP y Vox suman mayoría' : 'PP y Vox no llegan a 176'} en esta elección simulada. Ninguna tirada es una predicción: la media es lo que se repite.`;
    volver.hidden = false;
    anuncio.textContent = `Tirada ${miles(t.n)} de ${miles(S)}. ` + resumen(t, s);
  };
  palanca.addEventListener('click', () => {
    if (rodando) return;
    const t = D.tiradas[i++ % D.tiradas.length];
    palanca.classList.add('tirando'); setTimeout(() => palanca.classList.remove('tirando'), 350);
    if (sinMovimiento()) return ponerTirada(t);
    rodando = true; tabla.classList.add('rodando');
    const t0 = performance.now(), dur = k => 450 + ORDEN.indexOf(k) * 45;
    const paso = now => {
      let vivo = false;
      ORDEN.forEach(k => {
        if (now - t0 < dur(k)) { vivo = true; const e = D.escanos[k]; celdas[k].textContent = Math.round(e.p05 + Math.random() * (e.p95 - e.p05)); }
        else celdas[k].textContent = t[k];
      });
      if (vivo) { pleno.textContent = Math.round(B.p05 + Math.random() * (B.p95 - B.p05)); requestAnimationFrame(paso); }
      else { rodando = false; tabla.classList.remove('rodando'); ponerTirada(t); }
    };
    requestAnimationFrame(paso);
  });
  volver.addEventListener('click', () => { ponerMedia(); palanca.focus(); });   // el botón se oculta: el foco vuelve a la palanca

  // ---------------------------------------------------------------- gráfico
  const g = document.getElementById('grafico'); grafico(D, g);
  let ancho = g.clientWidth, espera;
  addEventListener('resize', () => { clearTimeout(espera); espera = setTimeout(() => { if (Math.abs(g.clientWidth - ancho) > 20) { ancho = g.clientWidth; grafico(D, g); } }, 200); });

  // ---------------------------------------------------------------- 1-X-2
  const x12 = document.getElementById('x12');
  const nc = k => ({ FA: 'F. Amplio', BILDU: 'Bildu', AA: 'Adelante' })[k] || N[k];
  D.en_juego.slice(0, 8).forEach((x, j) => {
    const empate = (x.q1 - x.q2) < 0.05;
    x12.insertAdjacentHTML('beforeend', `<tr><td class="n">${j + 1}</td><td class="izq">${x.provincia} (${x.escanos})</td>
      <td class="c"><span class="marca ${empate ? '' : 'fav'}">${nc(x.p1)} ${Math.round(x.q1 * 100)} %</span>${empate ? '<span class="marca fav x-movil">X</span>' : ''}</td>
      <td class="c colx">${empate ? '<span class="marca fav">X</span>' : ''}</td>
      <td class="c"><span class="marca">${nc(x.p2)} ${Math.round(x.q2 * 100)} %</span></td></tr>`);
  });

  // ---------------------------------------------------------------- escenarios
  const cuantos = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;
  const veredicto = p => p >= 0.95 ? 'Mayoría casi segura' : p >= 0.75 ? 'Mayoría probable' : p >= 0.6 ? 'Mayoría algo más probable que no' : p > 0.4 ? 'A cara o cruz' : p > 0.25 ? 'Mayoría poco probable' : 'Mayoría muy improbable';
  document.getElementById('falla').innerHTML = ESCENARIOS.map((s, j) => {
    const x = D.escenario(s.id), n = Math.round(x.p_mayoria * 100);
    const n100 = x.p_mayoria >= 1 ? 100 : Math.min(99, Math.max(0, n));   // nunca 100 si no es seguro
    const cuadros = Array.from({ length: 100 }, (_, i) => `<i class="${i < n100 ? 'si' : ''}"></i>`).join('');
    return `<div class="${j === 0 ? 'media' : ''}"><span class="cifra">${s.corto}</span>
      <div class="cien" role="img" aria-label="${cuantos(n100, 'cuadro negro', 'cuadros negros')} y ${cuantos(100 - n100, 'blanco', 'blancos')}: PP y Vox llegan a 176 en ${cada100(x.p_mayoria)} elecciones simuladas">${cuadros}</div>
      <b>${veredicto(x.p_mayoria)}:</b> PP y Vox llegan a 176 en ${cada100(x.p_mayoria)} elecciones simuladas.
      El reparto más habitual: PP ${r0(x.PP)}, PSOE ${r0(x.PSOE)}, Vox ${r0(x.VOX)}.
      El PSOE queda por delante del PP en escaños en ${cada100(x.p_psoe_primero)}.</div>`;
  }).join('');

  // ---------------------------------------------------------------- encuestas
  const nf = v => (v === null || v === undefined || v === '') ? '–' : f1(+v);
  document.getElementById('encuestas').innerHTML = [...D.encuestas].sort((a, b) => b.fin.localeCompare(a.fin)).map(e =>
    `<tr><td class="izq">${esc(e.casa)}</td><td class="izq">${esc(e.cliente)}</td><td class="izq">${campo(e.inicio, e.fin)}</td><td>${miles(+e.n)}</td>
     <td>${nf(e.PP)}</td><td>${nf(e.PSOE)}</td><td>${nf(e.VOX)}</td><td>${nf(e.FA)}</td><td>${nf(e.POD)}</td><td>${nf(e.SALF)}</td><td class="izq fuente">${esc(e.fuente) || '–'}</td></tr>`).join('');
}

// Alternativa textual al gráfico: una fecha por semana, el día de corte y la proyección al 29 de noviembre
function tablaSerie(D) {
  const P = ['PP', 'PSOE', 'VOX', 'FA', 'POD', 'SALF'], corte = Date.parse(D.meta.corte);
  const serie = P.map(k => D.serie.filter(x => x.partido === k)), fechas = serie[0].map(x => x.fecha);
  const filas = fechas.map((f, j) => ({ f, j })).filter(({ f, j }) => j % 7 === 0 || f === D.meta.corte || j === fechas.length - 1);
  const ult = fechas.length - 1, rango = p => `${f1(Math.max(0, p.lo))}–${f1(p.hi)}`;
  return `<table><caption class="mudo">Media corregida de cada partido, en % de voto</caption>
    <thead><tr><th scope="col" class="izq">Fecha</th>${P.map(k => `<th scope="col">${D.nombres[k]}</th>`).join('')}</tr></thead><tbody>` +
    filas.map(({ f, j }) => { const pr = Date.parse(f) > corte;
      return `<tr${pr ? ' class="proyeccion"' : ''}><th scope="row" class="izq">${fecha(f)}${pr ? ' (proyección)' : ''}</th>${serie.map(x => `<td>${f1(x[j].med)}</td>`).join('')}</tr>`; }).join('') +
    `<tr class="proyeccion"><th scope="row" class="izq">${fecha(fechas[ult])}, 9 de cada 10</th>${serie.map(x => `<td>${rango(x[ult])}</td>`).join('')}</tr></tbody></table>`;
}

function grafico(D, nodo) {
  const P = ['PP', 'PSOE', 'VOX', 'FA', 'POD', 'SALF'], W = Math.max(320, nodo.clientWidth || 820), estrecho = W < 600;
  const H = estrecho ? 300 : 380, m = { t: 14, r: estrecho ? 82 : 170, b: 30, l: 30 };
  const corto = { PP: 'PP', PSOE: 'PSOE', VOX: 'Vox', FA: 'FA', POD: 'Podemos', SALF: 'SALF' };
  const serie = P.map(k => D.serie.filter(x => x.partido === k));
  const fechas = serie[0].map(x => x.fecha), t0 = Date.parse(fechas[0]), t1 = Date.parse(fechas.at(-1));
  const corte = Date.parse(D.meta.corte);
  const X = f => m.l + (Date.parse(f) - t0) / (t1 - t0) * (W - m.l - m.r), Y = v => m.t + (1 - v / 36) * (H - m.t - m.b);
  const linea = (pts, acc) => pts.map((p, j) => `${j ? 'L' : 'M'}${X(p.fecha).toFixed(1)},${Y(acc(p)).toFixed(1)}`).join('');
  // Colores: los de partido con var() (cambian de noche); rejilla, ejes y etiquetas, por clase desde estilo.css
  let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" tabindex="0" aria-label="Evolución de la media de encuestas por partido desde finales de septiembre, con proyección al 29 de noviembre. Con las flechas se recorren las fechas; los datos están en la tabla que sigue al gráfico.">`;
  for (let v = 0; v <= 35; v += 5) svg += `<line class="rej" x1="${m.l}" x2="${W - m.r}" y1="${Y(v)}" y2="${Y(v)}" stroke-opacity="${v ? .1 : .5}"/><text class="eje" x="${m.l - 6}" y="${Y(v) + 4}" text-anchor="end" font-size="12">${v}</text>`;
  (estrecho ? [['2026-10-01', '1 oct'], ['2026-11-08', '8 nov'], ['2026-11-29', '29 nov']] : [['2026-10-01', '1 oct'], ['2026-10-28', '28 oct'], ['2026-11-08', '8 nov'], ['2026-11-29', '29 nov']]).forEach(([f, et]) =>
    svg += `<line class="rej" x1="${X(f)}" x2="${X(f)}" y1="${m.t}" y2="${H - m.b}" stroke-opacity=".15" stroke-dasharray="2 3"/><text class="eje" x="${X(f)}" y="${H - 10}" text-anchor="middle" font-size="12">${et}</text>`);
  svg += `<rect class="proy" x="${X(D.meta.corte)}" y="${m.t}" width="${W - m.r - X(D.meta.corte)}" height="${H - m.t - m.b}"/>`;
  P.forEach((k, j) => {
    const s = serie[j];
    svg += `<path d="${linea(s, p => p.hi)}L${[...s].reverse().map(p => `${X(p.fecha).toFixed(1)},${Y(Math.max(0, p.lo)).toFixed(1)}`).join('L')}Z" style="fill:${colorCss(k)}" fill-opacity=".14"/>`;
  });
  D.encuestas.forEach(e => {
    const f = new Date((Date.parse(e.inicio) + Date.parse(e.fin)) / 2).toISOString().slice(0, 10);
    P.forEach(k => { const v = e[k]; if (v !== null && v !== '' && v !== undefined) svg += `<circle cx="${X(f)}" cy="${Y(+v)}" r="2.6" style="fill:${colorCss(k)}" fill-opacity=".55"/>`; });
  });
  P.forEach((k, j) => {
    const s = serie[j], antes = s.filter(p => Date.parse(p.fecha) <= corte), despues = s.filter(p => Date.parse(p.fecha) >= corte);
    svg += `<path d="${linea(antes, p => p.med)}" fill="none" style="stroke:${colorCss(k)}" stroke-width="2.4"/>`;
    svg += `<path d="${linea(despues, p => p.med)}" fill="none" style="stroke:${colorCss(k)}" stroke-width="2" stroke-dasharray="5 4"/>`;
  });
  // etiquetas directas al final, sin solaparse
  const fin = P.map((k, j) => ({ k, v: serie[j].at(-1).med, y: Y(serie[j].at(-1).med) })).sort((a, b) => a.y - b.y);
  for (let j = 1; j < fin.length; j++) if (fin[j].y - fin[j - 1].y < 15) fin[j].y = fin[j - 1].y + 15;
  fin.forEach(e => svg += `<text class="etq" x="${W - m.r + 6}" y="${e.y + 4}" font-size="${estrecho ? 11.5 : 13}"><tspan font-weight="700">${estrecho ? corto[e.k] : D.nombres[e.k]}</tspan> ${f1(e.v)}</text>`);
  svg += `<line class="cursor" x1="0" x2="0" y1="${m.t}" y2="${H - m.b}" stroke-width="1.5" visibility="hidden"/>`;
  svg += `<rect x="${m.l}" y="${m.t}" width="${W - m.l - m.r}" height="${H - m.t - m.b}" fill="transparent"/></svg>`;
  nodo.innerHTML = svg + '<div class="lectura" hidden></div>';

  const el = nodo.querySelector('svg'), cur = el.querySelector('.cursor'), lec = nodo.querySelector('.lectura');
  let actual = fechas.findIndex(f => Date.parse(f) >= corte);           // con el teclado se empieza en el día de corte
  const mostrar = j => {
    actual = j;
    const f = fechas[j], xx = X(f), r = el.getBoundingClientRect();
    cur.setAttribute('x1', xx); cur.setAttribute('x2', xx); cur.setAttribute('visibility', 'visible');
    lec.hidden = false;
    lec.innerHTML = `<b>${fecha(f)}${Date.parse(f) > corte ? ' (proyección)' : ''}</b><br>` +
      P.map((k, i) => `<span class="cuadro" style="background:${colorCss(k)}"></span>${D.nombres[k]} ${f1(serie[i][j].med)}`).join('<br>');
    const px = xx / W * r.width; lec.style.left = (px > r.width / 2 ? px - lec.offsetWidth - 12 : px + 12) + 'px';
  };
  const ocultar = () => { cur.setAttribute('visibility', 'hidden'); lec.hidden = true; };
  el.addEventListener('pointermove', ev => {
    const r = el.getBoundingClientRect(), x = (ev.clientX - r.left) / r.width * W;
    mostrar(Math.max(0, Math.min(fechas.length - 1, Math.round((x - m.l) / (W - m.l - m.r) * (fechas.length - 1)))));
  });
  el.addEventListener('pointerleave', () => { if (document.activeElement !== el) ocultar(); });
  el.addEventListener('focus', () => mostrar(actual));
  el.addEventListener('blur', ocultar);
  el.addEventListener('keydown', ev => {
    if (ev.key === 'Escape') return ocultar();
    const paso = { ArrowLeft: -1, ArrowRight: 1 }[ev.key];
    const j = paso ? actual + paso : ev.key === 'Home' ? 0 : ev.key === 'End' ? fechas.length - 1 : null;
    if (j === null) return;
    ev.preventDefault(); mostrar(Math.max(0, Math.min(fechas.length - 1, j)));
  });
}
