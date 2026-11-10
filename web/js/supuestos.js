// «Elige tus supuestos»: comparador de escenarios ya simulados. Lee datos/supuestos.json (lo genera
// R/07b_exportar_extra.R a partir de salidas/escanos_escenarios.csv); no calcula nada.
import { colorCss, f1, fecha, cada100 } from './comun.js';

const cont = document.getElementById('contenido');
const P4 = ['PP', 'PSOE', 'VOX', 'FA'];
const CORTO = { PP: 'PP', PSOE: 'PSOE', VOX: 'Vox', FA: 'FA' };
const BASE = 'A_media_privadas', REGLA_BASE = 'mixto', ESCALA = 150;   // escala fija de las barras de escaños
const MES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const dia = s => { const [, m, d] = s.split('-'); return `${+d} ${MES[+m - 1]}`; };
const campo = ([a, b]) => { const [, ma, da] = a.split('-'), [, mb, db] = b.split('-');
  return a === b ? dia(a) : ma === mb ? `${+da}–${+db} ${MES[+mb - 1]}` : `${dia(a)}–${dia(b)}`; };
const signo = x => { const v = Math.round(x * 10) / 10; return (v > 0 ? '+' : v < 0 ? '−' : '') + f1(Math.abs(v)); };
const demas = x => `${f1(Math.abs(x))} ${x >= 0 ? 'de más' : 'de menos'}`;
const de100 = p => p > 0.99 ? 'más de 99' : p < 0.01 ? 'menos de 1' : String(Math.round(p * 100));
const veredicto = p => p >= 0.95 ? 'Mayoría casi segura' : p >= 0.75 ? 'Mayoría probable' : p >= 0.6 ? 'Mayoría algo más probable que no' : p > 0.4 ? 'A cara o cruz' : p > 0.25 ? 'Mayoría poco probable' : 'Mayoría muy improbable';
const desvio = a => `${P4.map(p => `${CORTO[p]} ${signo(a[p])}`).join(', ').replace(/, ([^,]*)$/, ' y $1')} puntos`;

// Textos de cada supuesto (los de la portada y la metodología); las cifras salen de supuestos.json
const ESC = [
  { id: 'A_media_privadas', nombre: 'La media de las encuestas', corto: 'La media',
    expl: () => 'Las empresas privadas, en conjunto, aciertan: su sesgo medio es cero. Es lo que enseña la portada.' },
  { id: 'B_correccion_23J', nombre: 'Si fallan como en 2023', corto: 'Si fallan como en 2023',
    expl: D => { const e = D.error_23J; return `Se corrige la media con el error que tuvo el 23J, cuando dio ${f1(Math.abs(e.PP))} puntos ${e.PP >= 0 ? 'de más' : 'de menos'} al PP, ${demas(e.PSOE)} al PSOE, ${demas(e.VOX)} a Vox y ${demas(e.SUMAR)} a Sumar (aquí, Frente Amplio y Podemos).`; } },
  { id: 'F_ancla_microdatos', nombre: 'Si aciertan las de microdatos abiertos', corto: 'Microdatos abiertos',
    expl: D => `La media del CIS y de More in Common, recalculados con el mismo modelo sobre sus microdatos: ${desvio(D.anclas.F_ancla_microdatos)}.` },
  { id: 'C_ancla_CIS_M3', nombre: 'Si acierta el CIS recalculado', corto: 'CIS recalculado',
    expl: D => `El barómetro del CIS (campo ${campo(D.anclas.C_ancla_CIS_M3.campo[0])}) recalculado sobre sus microdatos, no su estimación publicada: ${desvio(D.anclas.C_ancla_CIS_M3)}.` },
  { id: 'D_ancla_MiC', nombre: 'Si acierta More in Common, tal como la publicó', corto: 'More in Common publicada',
    expl: D => `Su estimación publicada (campo ${campo(D.anclas.D_ancla_MiC.campo[0])}): ${desvio(D.anclas.D_ancla_MiC)}.` },
  { id: 'D2_ancla_MiC_M3', nombre: 'Si acierta More in Common, recalculada', corto: 'More in Common recalculada',
    expl: D => `Sus microdatos de octubre recalculados con el mismo modelo que el CIS: ${desvio(D.anclas.D2_ancla_MiC_M3)}.` },
  { id: 'E_ancla_SW', nombre: 'Si acierta SW Demoscopia', corto: 'SW Demoscopia',
    expl: D => `Su seguimiento (campo ${campo(D.anclas.E_ancla_SW.campo[0])}), la única encuesta que pone primero al PSOE: ${desvio(D.anclas.E_ancla_SW)}.` }
];
const REGLAS = [
  { id: 'proporcional', nombre: 'Proporcional', expl: 'Cada partido crece o cae en cada provincia en proporción a lo que tenía en 2023: si pierde una décima parte de su voto en España, pierde una décima parte en todas.' },
  { id: 'aditivo', nombre: 'Aditiva', expl: 'Cada partido suma o resta los mismos puntos en todas las provincias: si baja 2 puntos en España, baja 2 en cada una.' },
  { id: 'mixto', nombre: 'Mixta', expl: 'Mitad y mitad: la media de las dos anteriores. Es la que usa la portada.' }
];

try {
  const r = await fetch('datos/supuestos.json', { cache: 'no-store' });
  if (!r.ok) throw new Error(`No se han podido cargar los datos (${r.status}).`);
  pintar(await r.json());
} catch (err) {
  cont.innerHTML = `<p class="error">${err.message} Recarga la página. Si el problema sigue, los datos están en <a href="datos/supuestos.json">datos/supuestos.json</a>.</p>`;
}

// Mayoría PP+Vox con la media según la regla: una cifra si coinciden las tres
function conReglas(D) {
  const v = REGLAS.map(r => de100(D.escenarios[BASE][r.id]?.mayoria ?? NaN));
  if (v.every(x => x === v[0])) return `${v[0]} de cada 100 con cualquiera de las tres`;
  return REGLAS.map((r, j) => `${v[j]} (${r.nombre.toLowerCase()})`).join(', ').replace(/, ([^,]*)$/, ' y $1') + ' de cada 100';
}

function pintar(D) {
  const S = D.meta.simulaciones.toLocaleString('es-ES');
  const esc = ESC.filter(e => D.escenarios[e.id]);
  const base = D.escenarios[BASE][REGLA_BASE];
  document.getElementById('corte').textContent = `Elige tus supuestos, a ${fecha(D.meta.corte)}`;
  document.getElementById('pie-texto').textContent = `Cada supuesto se ha simulado ${S} veces en las 52 circunscripciones (D'Hondt, umbral del 3 %), ` +
    `con las encuestas con trabajo de campo hasta el ${fecha(D.meta.corte)}. No es una encuesta propia ni una casa de apuestas: no hay cuotas ni premios.`;

  cont.innerHTML = `
    <h2 class="titulo-pag">Elige tus supuestos</h2>
    <p class="entradilla">La media da por hecho que las empresas de encuestas, en conjunto, aciertan. Aquí puedes cambiar ese supuesto y la forma de repartir el voto por provincias, y ver qué pasa con los escaños.
    Cada combinación está ya simulada ${S} veces: esta página solo enseña esos resultados.</p>
    <form class="comparador" id="comparador" onsubmit="return false">
      <div class="controles">
        <fieldset class="escenarios">
          <legend><span class="n">1</span>¿Qué encuestas aciertan?</legend>
          <p class="ayuda">Cuando el supuesto es una encuesta concreta, se toma cuánto se separaba de la media en sus fechas de campo (las cifras de cada línea) y esa diferencia se traslada al 29 de noviembre.</p>
          ${esc.map((e, j) => `<label class="opcion" data-id="${e.id}"><span class="n">${j + 1}</span><input type="radio" name="esc" value="${e.id}"><span class="caja" aria-hidden="true"></span><span class="txt"><b>${e.nombre}</b><span class="expl">${e.expl(D)}</span></span></label>`).join('')}
        </fieldset>
        <fieldset>
          <legend><span class="n">2</span>¿Cómo se reparte el voto por provincias?</legend>
          <p class="ayuda">La media da el voto en toda España. Para contar escaños hay que llevarlo a las 52 circunscripciones partiendo del 23J, y hay más de una forma de hacerlo.</p>
          <div class="reglas">${REGLAS.map(r => `<label class="opcion" data-id="${r.id}"><input type="radio" name="regla" value="${r.id}"><span class="caja" aria-hidden="true"></span><span class="txt">${r.nombre}</span></label>`).join('')}</div>
          <p class="regla-expl" id="regla-expl"></p>
        </fieldset>
      </div>
      <section class="resultado" id="resultado" aria-label="Resultado del supuesto elegido"></section>
    </form>
    <p class="mudo" aria-live="polite" id="anuncio"></p>

    <h2>Todos los supuestos, de un vistazo</h2>
    <p class="nota">Con la regla mixta. Escaños: el valor central de las ${S} simulaciones de cada supuesto. Las dos últimas columnas cuentan en cuántas de cada 100 simulaciones PP y Vox llegan a 176 y el PSOE saca más escaños que el PP. Pulsa un supuesto para verlo arriba.</p>
    <div class="desliza"><table class="vistazo">
      <thead><tr><th class="izq">Supuesto</th>${P4.map(p => `<th><span class="cuadro" style="background:${colorCss(p)}"></span>${CORTO[p]}</th>`).join('')}<th class="prob">Mayoría PP+Vox</th><th class="prob">PSOE por delante</th></tr></thead>
      <tbody>${esc.map(e => { const x = D.escenarios[e.id][REGLA_BASE]; return `<tr data-id="${e.id}"><td class="izq"><button type="button" data-id="${e.id}">${e.corto}</button></td>${P4.map(p => `<td>${x[p]}</td>`).join('')}<td>${de100(x.mayoria)}</td><td>${de100(x.psoe_primero)}</td></tr>`; }).join('')}</tbody>
    </table></div>
    <p class="nota">Todos los supuestos llevan el mismo error común de las encuestas el día de la votación (sección 4 de la <a href="metodologia.html">metodología</a>).
    La regla de reparto solo se ha simulado con las tres opciones para la media; con ella, la mayoría de PP y Vox sale en ${conReglas(D)}.</p>`;

  // ---------------------------------------------------------------- estado
  const leerHash = () => { const q = new URLSearchParams(location.hash.slice(1));
    return { esc: D.escenarios[q.get('e')] ? q.get('e') : BASE, pedida: REGLAS.some(r => r.id === q.get('r')) ? q.get('r') : REGLA_BASE }; };
  const s = leerHash();
  const form = document.getElementById('comparador');
  const res = document.getElementById('resultado'), expl = document.getElementById('regla-expl'), anuncio = document.getElementById('anuncio');

  const actualizar = (anunciar = true) => {
    const disp = D.escenarios[s.esc];
    const regla = disp[s.pedida] ? s.pedida : REGLA_BASE;
    form.querySelectorAll('input[name=esc]').forEach(i => { i.checked = i.value === s.esc; i.closest('.opcion').classList.toggle('activa', i.checked); });
    form.querySelectorAll('input[name=regla]').forEach(i => {
      i.disabled = !disp[i.value]; i.checked = i.value === regla;
      i.closest('.opcion').classList.toggle('no', i.disabled); i.closest('.opcion').classList.toggle('activa', i.checked);
    });
    const R = REGLAS.find(r => r.id === regla);
    expl.innerHTML = `<b>${R.nombre}.</b> ${R.expl}` + (Object.keys(disp).length < REGLAS.length ? '<span class="aviso">Con este supuesto solo se ha simulado la regla mixta.</span>' : '');
    document.querySelectorAll('.vistazo tbody tr').forEach(tr => tr.classList.toggle('sel', tr.dataset.id === s.esc));

    const E = ESC.find(e => e.id === s.esc), x = disp[regla], esBase = s.esc === BASE && regla === REGLA_BASE;
    const n100 = x.mayoria >= 1 ? 100 : Math.min(99, Math.max(0, Math.round(x.mayoria * 100)));   // nunca 100 si no es seguro
    const dif = p => { const d = x[p] - base[p]; return d === 0 ? '=' : (d > 0 ? '+' : '−') + Math.abs(d); };
    const pos = v => Math.min(100, v / ESCALA * 100).toFixed(1);
    res.innerHTML = `
      <p class="rotulo">Tu supuesto</p>
      <h3>${E.nombre}<span class="sub">Regla de reparto ${R.nombre.toLowerCase()}</span></h3>
      <div class="arriba">
        <div class="cien" role="img" aria-label="${cada100(x.mayoria)} elecciones simuladas con mayoría de PP y Vox">${Array.from({ length: 100 }, (_, i) => `<i class="${i < n100 ? 'si' : ''}"></i>`).join('')}</div>
        <p class="veredicto"><b>${veredicto(x.mayoria)}:</b> PP y Vox llegan a 176 escaños en ${cada100(x.mayoria)} elecciones simuladas. Cada cuadro negro es una de ellas.</p>
      </div>
      <table class="tabla-sup">
        <caption class="mudo">Escaños con este supuesto${esBase ? '' : ', frente a la media'}</caption>
        <thead><tr><th class="izq"></th><th>Escaños</th><th class="dif">${esBase ? '' : 'Frente a la media'}</th><th class="barra"></th></tr></thead>
        <tbody>${P4.map(p => `<tr><td class="izq"><span class="cuadro" style="background:${colorCss(p)}"></span>${CORTO[p]}</td><td class="n-esc">${x[p]}</td>
          <td class="dif">${esBase ? '' : dif(p)}</td>
          <td class="barra" aria-hidden="true"><div class="barra-esc"><span style="width:${pos(x[p])}%;background:${colorCss(p)}"></span>${esBase ? '' : `<i style="left:${pos(base[p])}%"></i>`}</div></td></tr>`).join('')}</tbody>
      </table>
      <p class="pie-res">PP y Vox suman entre <b>${x.p05}</b> y <b>${x.p95}</b> escaños en 9 de cada 10 simulaciones. La mayoría absoluta está en ${D.meta.mayoria}.</p>
      <p class="pie-res">El PSOE queda por delante del PP en escaños en ${cada100(x.psoe_primero)}.</p>
      ${esBase ? '' : '<p class="pie-res margen">La raya negra de cada barra marca los escaños de la media.</p>'}`;
    if (anunciar) anuncio.textContent = `${E.nombre}, regla ${R.nombre.toLowerCase()}: PP y Vox llegan a la mayoría en ${cada100(x.mayoria)} elecciones simuladas. PP ${x.PP}, PSOE ${x.PSOE}, Vox ${x.VOX}, Frente Amplio ${x.FA}.`;
    const h = (s.esc === BASE && regla === REGLA_BASE) ? '' : `#e=${s.esc}${regla !== REGLA_BASE ? `&r=${regla}` : ''}`;
    history.replaceState(null, '', location.pathname + location.search + h);
  };

  form.addEventListener('change', ev => {
    if (ev.target.name === 'esc') s.esc = ev.target.value;
    if (ev.target.name === 'regla') s.pedida = ev.target.value;
    actualizar();
  });
  document.querySelector('.vistazo').addEventListener('click', ev => {
    const b = ev.target.closest('button[data-id]'); if (!b) return;
    s.esc = b.dataset.id; actualizar();
    res.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
  });
  addEventListener('hashchange', () => { Object.assign(s, leerHash()); actualizar(); });
  actualizar(false);
}
