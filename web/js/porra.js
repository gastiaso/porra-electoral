// Porra Electoral: rellenar, sellar, compartir y corregir. Todo en el navegador: la porra viaja en el enlace.
import { colorCss, NOMBRES, sinMovimiento, fecha } from './comun.js';

const $ = id => document.getElementById(id);
const SIG = ['1', 'X', '2'], PLENO = ['0', '1', '2', 'M'];
const CLAVE_MIA = 'porra29n.mia', CLAVE_PENA = 'porra29n.pena';

// ---------------------------------------------------------------- almacenamiento local (puede no existir)
const guardar = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* sin almacenamiento: el enlace basta */ } };
const leer = k => { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } };

// ---------------------------------------------------------------- codificación en el enlace
const valido = c => typeof c === 'string' && /^[1X2]{14}[012M]$/.test(c);
const aT = ms => Math.round(ms / 60000).toString(36);          // minutos desde 1970, en base 36
const deT = s => parseInt(s, 36) * 60000;
const validoE = e => typeof e === 'string' && /^\d{1,3}(\.\d{1,3})*$/.test(e) && e.split('.').length === PARTIDOS.length && e.split('.').reduce((a, x) => a + +x, 0) === 350;
const limpiaE = e => validoE(e) ? e : '';                       // escaños: una cifra por partido de la tabla, separadas por puntos, o nada
const enlaceDe = b => `${location.origin}${location.pathname}#p=${b.c}${b.e ? '&e=' + b.e : ''}&t=${b.t}${b.n ? '&n=' + encodeURIComponent(b.n) : ''}`;
function leerHash(h) {
  const crudo = h.replace(/^#/, ''), q = new URLSearchParams(crudo);
  // La peña se lee sin descodificar antes de trocear: un nombre puede llevar comas, punto y coma o «%»
  const mp = crudo.match(/(?:^|&)pena=([^&]*)/);
  if (mp && mp[1]) {
    const texto = x => { try { return decodeURIComponent(x || ''); } catch (e) { return x || ''; } };
    const miembros = mp[1].split(';').map(m => { const [c, t, n, e] = m.split(','); return { c, t, n: texto(n).slice(0, 30), e: limpiaE(e) }; }).filter(m => valido(m.c));
    return { pena: miembros };
  }
  if (valido(q.get('p'))) return { boleto: { c: q.get('p'), t: q.get('t') || '', n: q.get('n') || '', e: limpiaE(q.get('e')) } };
  return {};
}
const enlacePena = ms => `${location.origin}${location.pathname}#pena=${ms.map(m => [m.c, m.t, encodeURIComponent(m.n || ''), m.e || ''].join(',')).join(';')}`;

// ---------------------------------------------------------------- datos
const [reglas, modelo, resultados] = await Promise.all([
  fetch('datos/porra.json').then(r => r.json()),
  fetch('datos/modelo.json', { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null),
  fetch('datos/resultados.json', { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null)
]);
const media = modelo?.porra_media || null;                     // en veda no hay cifras
const cierre = Date.parse(reglas.cierre), cerrada = Date.now() >= cierre;

// signo real de cada fila y opción real del pleno, si hay resultados
function escanos(amb, p) {
  if (!resultados) return null;
  if (amb === 'Congreso') return resultados.congreso?.[p] ?? 0;
  const pr = resultados.provincias?.[amb];
  return pr ? (pr[p] ?? 0) : null;                            // provincia aún sin escrutar
}
const real = reglas.filas.map(f => {
  const a = escanos(f.ambito, f.local), b = escanos(f.ambito, f.visitante);
  return (a === null || b === null) ? null : a > b ? '1' : a === b ? 'X' : '2';
});
const realPleno = (() => {
  if (!resultados?.congreso) return null;
  const s = (resultados.congreso.PP ?? 0) + (resultados.congreso.VOX ?? 0);
  return reglas.pleno.opciones.find(o => s >= o.min && s <= o.max)?.id ?? null;
})();
const aciertos = c => {
  let n = 0, pend = 0;
  reglas.filas.forEach((f, i) => { if (real[i] === null) pend++; else if (c[i] === real[i]) n++; });
  if (realPleno === null) pend++; else if (c[14] === realPleno) n++;
  return { n, pend };
};
// Juego de escaños: el reparto real solo cuenta cuando están asignados los 350
const PARTIDOS = reglas.escanos.partidos;
const realE = (() => {
  if (!resultados?.congreso || !resultados.completo) return null;
  const v = PARTIDOS.map(p => p === 'OTROS' ? Object.entries(resultados.congreso).filter(([k]) => !PARTIDOS.includes(k) || k === 'OTROS').reduce((a, [, x]) => a + x, 0) : (resultados.congreso[p] ?? 0));
  return v.reduce((a, x) => a + x, 0) === 350 ? v : null;
})();
const desvio = e => (e && realE) ? e.split('.').reduce((a, x, i) => a + Math.abs(+x - realE[i]), 0) : null;
const mediaE = media?.escanos ? PARTIDOS.map(p => media.escanos[p] ?? 0).join('.') : '';
const porraMedia = media ? reglas.filas.map((f, i) => { const m = media.filas[i]; return [['1', m.p1], ['X', m.pX], ['2', m.p2]].sort((a, b) => b[1] - a[1])[0][0]; }).join('') +
  Object.entries(media.pleno).sort((a, b) => b[1] - a[1])[0][0] : null;

// ---------------------------------------------------------------- boleto
const filas = $('filas');
const CORTO = { FA: 'FA', AA: 'Adelante', BILDU: 'Bildu', POD: 'Podemos' };
const nombre = (k) => CORTO[k] ? `<span class="largo">${NOMBRES[k]}</span><span class="corto">${CORTO[k]}</span>` : NOMBRES[k];
const cuadro = (k) => `<span class="cuadro" style="background:${colorCss(k)}"></span>`;
// Nombre accesible de cada casilla: qué fila es y qué significa la marca
const etiqueta = (f, s) => `Fila ${f.id} (${f.nombre_ambito}, ${NOMBRES[f.local]} contra ${NOMBRES[f.visitante]}): ${s === '1' ? `1, más escaños ${NOMBRES[f.local]}` : s === 'X' ? 'X, empate' : `2, más escaños ${NOMBRES[f.visitante]}`}`;
const desplazar = nodo => nodo.scrollIntoView({ behavior: sinMovimiento() ? 'auto' : 'smooth', block: 'start' });
reglas.filas.forEach((f, i) => {
  const m = media?.filas[i];
  filas.insertAdjacentHTML('beforeend', `<tr data-i="${i}">
    <td class="n">${f.id}</td>
    <td class="izq amb">${f.nombre_ambito}</td>
    <td class="izq partido"><span class="eq">${cuadro(f.local)}${nombre(f.local)}</span><span class="contra">–</span><span class="eq">${cuadro(f.visitante)}${nombre(f.visitante)}</span>
      ${m ? `<span class="media-fila" hidden>La media: 1 ${Math.round(m.p1 * 100)} %, X ${Math.round(m.pX * 100)} %, 2 ${Math.round(m.p2 * 100)} %</span>` : ''}</td>
    ${SIG.map(s => `<td class="sig"><label class="casilla"><input type="radio" name="f${i}" value="${s}" aria-label="${etiqueta(f, s)}"><span>${s}</span></label></td>`).join('')}
    <td class="res" id="res-${i}"></td></tr>`);
});
$('pleno').innerHTML = `<p class="pleno-titulo" id="pleno-titulo"><span class="n">15</span> Pleno al 15: ${reglas.pleno.pregunta}</p>
  <div class="pleno-ops" role="radiogroup" aria-labelledby="pleno-titulo">${reglas.pleno.opciones.map(o => `<label class="casilla ancha"><input type="radio" name="pleno" value="${o.id}"><span>${o.texto}</span></label>`).join('')}</div>
  ${media ? `<p class="media-fila" hidden>La media: ${reglas.pleno.opciones.map(o => `${o.texto.toLowerCase()} ${Math.round(media.pleno[o.id] * 100)} %`).join('; ')}.</p>` : ''}
  <p class="nota" id="res-pleno"></p>`;

const nom = k => k === 'OTROS' ? 'Otros' : (CORTO[k] ? `<span class="largo">${NOMBRES[k]}</span><span class="corto">${CORTO[k]}</span>` : NOMBRES[k]);
$('escanos').innerHTML = `<p class="pleno-titulo"><span class="n" aria-hidden="true">+</span> ${reglas.escanos.pregunta}</p>
  <p class="nota">Opcional. Gana quien menos se desvíe del reparto real y sirve de desempate en el 1-X-2. Tienen que sumar 350; deja todo en blanco si no quieres jugar.</p>
  <div class="rejilla-esc">${PARTIDOS.map((k, i) => `<label class="esc"><span class="eq">${cuadro(k)}${nom(k)}</span>
    <input type="number" inputmode="numeric" min="0" max="350" step="1" id="e-${i}" aria-label="Escaños de ${k === 'OTROS' ? 'otros partidos' : NOMBRES[k]}" aria-describedby="re-${i}">
    ${media?.escanos ? `<span class="media-fila" hidden>media ${media.escanos[k] ?? 0}</span>` : ''}<span class="res-esc" id="re-${i}"></span></label>`).join('')}</div>
  <div class="botones"><span class="contador" id="contador" aria-live="polite"></span>
    <button class="volver" id="partir-media" type="button"${mediaE ? '' : ' hidden'}>Partir de la media</button>
    <button class="volver" id="vaciar-esc" type="button">Vaciar</button></div>`;
const cajas = PARTIDOS.map((_, i) => $('e-' + i));
const leerE = () => cajas.map(x => x.value.trim());
function contar() {
  const v = leerE(); if (v.every(x => x === '')) { $('contador').textContent = 'Sin rellenar.'; $('contador').className = 'contador'; return; }
  const s = v.reduce((a, x) => a + (parseInt(x, 10) || 0), 0);
  $('contador').textContent = s === 350 ? 'Suman 350.' : s < 350 ? `Llevas ${s}: quedan ${350 - s} por repartir.` : `Llevas ${s}: sobran ${s - 350}.`;
  $('contador').className = 'contador ' + (s === 350 ? 'bien' : 'mal');
}
cajas.forEach(x => x.addEventListener('input', contar));
$('partir-media').addEventListener('click', () => { mediaE.split('.').forEach((x, i) => cajas[i].value = x); contar(); });
$('vaciar-esc').addEventListener('click', () => { cajas.forEach(x => x.value = ''); contar(); });
const ponerE = (e, bloquear) => {
  const v = e ? e.split('.') : [];
  cajas.forEach((x, i) => { x.value = v[i] ?? ''; x.disabled = bloquear; });
  $('partir-media').hidden = bloquear || !mediaE; $('vaciar-esc').hidden = bloquear; contar();
  if (bloquear && !e) $('contador').textContent = 'No ha repartido escaños.';
};

if (!media) $('lbl-media').hidden = true;
else if (modelo?.meta?.corte) $('txt-media').textContent = `Ver lo que dice la media de encuestas (datos del ${fecha(modelo.meta.corte)})`;
$('ver-media').addEventListener('change', e => document.querySelectorAll('.media-fila').forEach(x => x.hidden = !e.target.checked));

const form = $('boleto');
const leerForm = () => reglas.filas.map((_, i) => form.querySelector(`input[name=f${i}]:checked`)?.value || '-').join('') + (form.querySelector('input[name=pleno]:checked')?.value || '-');
const ponerForm = (c, bloquear) => {
  [...c].forEach((s, i) => { const n = i < 14 ? `f${i}` : 'pleno'; form.querySelectorAll(`input[name=${n}]`).forEach(x => { x.checked = x.value === s; x.disabled = bloquear; }); });
};
const desbloquear = () => form.querySelectorAll('input[type=radio]').forEach(x => x.disabled = false);

function corregirE(e) {
  PARTIDOS.forEach((_, i) => {
    const sp = $('re-' + i);
    if (!realE) { sp.textContent = ''; sp.className = 'res-esc'; return; }
    const d = e ? Math.abs(+e.split('.')[i] - realE[i]) : null;
    sp.textContent = `salió ${realE[i]}${d === null ? '' : d === 0 ? ' · clavado' : ` · ${d} de desvío`}`;
    sp.className = 'res-esc ' + (d === 0 ? 'bien' : '');
  });
}
function corregir(c, e) {
  if (!resultados) return;
  reglas.filas.forEach((f, i) => {
    const td = $('res-' + i);
    td.innerHTML = real[i] === null ? 'pendiente' : c[i] === real[i] ? `<span aria-hidden="true">✓</span> ${real[i]}<span class="mudo">: acertada</span>` : `<span aria-hidden="true">✗</span> ${real[i]}<span class="mudo">: fallada</span>`;
    td.className = 'res ' + (real[i] === null ? '' : c[i] === real[i] ? 'bien' : 'mal');
  });
  corregirE(e);
  const o = reglas.pleno.opciones.find(x => x.id === realPleno);
  $('res-pleno').textContent = realPleno === null ? '' : `Resultado: ${o.texto.toLowerCase()}. ${c[14] === realPleno ? 'Acertado.' : 'Fallado.'}`;
}

// ---------------------------------------------------------------- estado y acciones
const estado = $('estado');
// Siempre en hora peninsular, esté donde esté el navegador: el cierre es a las 9.00 de la Península
const HUSO = 'Europe/Madrid';
const fechaHora = ms => { const d = new Date(ms); return `${d.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', timeZone: HUSO })} a las ${d.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit', timeZone: HUSO })}`; };
const textoResultados = (c, e) => {
  if (!resultados) return cerrada ? 'Los resultados se publicarán aquí la noche electoral.' : `La porra se cierra el ${fechaHora(cierre)} (hora peninsular). Los resultados se publicarán aquí la noche electoral.`;
  const a = aciertos(c), prov = resultados.estado !== 'definitivo' ? ' (provisional)' : '';
  const m = porraMedia ? ` La porra de la media de encuestas lleva ${aciertos(porraMedia).n}.` : '';
  const d = desvio(e), dm = desvio(mediaE);
  const te = !e ? '' : d === null ? ' El desvío en escaños se calcula cuando estén repartidos los 350.'
    : ` En escaños te has desviado ${d}${dm !== null ? ` (la media, ${dm})` : ''}.`;
  return `<b>${a.n} aciertos de 15${prov}.</b>${a.pend ? ` Faltan ${a.pend} por resolver.` : ''}${m}${te}`;
};

let vista = 'mia';            // 'mia' (editable o sellada) o 'ajena' (enlace de otra persona)
function mostrarMia() {
  vista = 'mia';
  const mia = leer(CLAVE_MIA);
  $('nueva').hidden = !mia; $('compartir').hidden = !mia;
  if (mia) {
    ponerForm(mia.c, true); ponerE(mia.e, true); $('alias').value = mia.n || ''; $('alias').disabled = true; $('sellar').hidden = true;
    estado.innerHTML = `<p class="modo"><b>${mia.n ? `Porra de ${escapar(mia.n)}` : 'Tu porra'}, sellada el ${fechaHora(deT(mia.t))}.</b> ${textoResultados(mia.c, mia.e)}</p>`;
    prepararCompartir(mia); corregir(mia.c, mia.e);
  } else {
    desbloquear(); ponerE('', false); $('alias').disabled = false; $('sellar').hidden = cerrada;
    estado.innerHTML = cerrada ? '<p class="modo"><b>La porra está cerrada.</b> Ya no se pueden sellar porras nuevas; puedes consultar las de tu peña.</p>'
      : `<p class="modo"><b>Sin sellar.</b> Marca las 15 filas, reparte los escaños si quieres y pulsa «Sellar la porra». Se cierra el ${fechaHora(cierre)} (hora peninsular).</p>`;
  }
}
function mostrarAjena(b) {
  vista = 'ajena';
  ponerForm(b.c, true); ponerE(b.e, true); $('alias').value = b.n || ''; $('alias').disabled = true; $('sellar').hidden = true; $('compartir').hidden = true;
  $('nueva').hidden = false; $('nueva').textContent = leer(CLAVE_MIA) ? 'Ver mi porra' : 'Hacer mi porra';
  const fuera = b.t && deT(b.t) > cierre ? ' Sellada después del cierre: no cuenta.' : '';
  estado.innerHTML = `<p class="modo"><b>${b.n ? `Porra de ${escapar(b.n)}` : 'Porra compartida'}${b.t ? `, sellada el ${fechaHora(deT(b.t))}` : ''}.</b>${fuera} ${textoResultados(b.c, b.e)}</p>
    <div class="botones"><button class="volver" id="a-pena" type="button">Añadir a mi peña</button></div>`;
  $('a-pena').addEventListener('click', () => anadirPena(b));
  corregir(b.c, b.e);
}
const escapar = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

form.addEventListener('submit', ev => {
  ev.preventDefault();
  if (cerrada) return;
  const c = leerForm(), faltan = [...c].filter(x => x === '-').length;
  if (faltan) {
    estado.innerHTML = `<p class="modo"><b>Faltan ${faltan} ${faltan === 1 ? 'fila' : 'filas'} por marcar.</b> Cada una de las 14 filas y el pleno necesitan una marca.</p>`;
    const k = c.indexOf('-'); form.querySelector(`input[name=${k < 14 ? 'f' + k : 'pleno'}]`).focus();
    return;
  }
  const v = leerE(); let e = '';
  if (!v.every(x => x === '')) {
    const nums = v.map(x => x === '' ? 0 : Number(x));
    if (nums.some(x => !Number.isInteger(x) || x < 0 || x > 350)) { estado.innerHTML = '<p class="modo"><b>Revisa los escaños.</b> Solo valen números enteros entre 0 y 350.</p>'; return; }
    const s = nums.reduce((a, x) => a + x, 0);
    if (s !== 350) { estado.innerHTML = `<p class="modo"><b>Los escaños suman ${s}.</b> Tienen que sumar 350, o déjalos todos en blanco para jugar solo al 1-X-2.</p>`; desplazar($('escanos')); cajas[0].focus({ preventScroll: true }); return; }
    e = nums.join('.');
  }
  const mia = { c, e, t: aT(Date.now()), n: $('alias').value.trim().slice(0, 30) };
  guardar(CLAVE_MIA, mia);
  anadirPena(mia, true);
  history.replaceState(null, '', location.pathname);
  mostrarMia();
  desplazar($('compartir')); $('compartir-titulo').focus({ preventScroll: true });   // «Sellar» desaparece: el foco pasa a «Compártela»
});
$('nueva').addEventListener('click', () => {
  if (vista === 'ajena' && leer(CLAVE_MIA)) { history.replaceState(null, '', location.pathname); return mostrarMia(); }
  if (leer(CLAVE_MIA) && !confirmar()) return;
  try { localStorage.removeItem(CLAVE_MIA); } catch (e) { /* nada */ }
  history.replaceState(null, '', location.pathname);
  form.reset(); contar(); corregirE(''); filas.querySelectorAll('.res').forEach(td => { td.textContent = ''; td.className = 'res'; }); $('res-pleno').textContent = '';
  mostrarMia();
  form.querySelector('input[name=f0]').focus();
});
// En lugar de un diálogo del navegador, un segundo clic confirma
let aviso = 0;
function confirmar() {
  if (Date.now() - aviso < 4000) return true;
  aviso = Date.now(); $('nueva').textContent = 'Pulsa otra vez para borrar tu porra sellada'; setTimeout(() => $('nueva').textContent = 'Hacer otra porra', 4000);
  return false;
}

function prepararCompartir(b) {
  const url = enlaceDe(b);
  $('enlace').value = url;
  const texto = `Mi porra de las elecciones del 29N${b.n ? ` (${b.n})` : ''}: ${url}`;
  $('whatsapp').href = `https://wa.me/?text=${encodeURIComponent(texto)}`;
  $('compartir-btn').hidden = !navigator.share;
  $('compartir-btn').onclick = () => navigator.share({ title: 'Porra Electoral', text: 'Mi porra del 29N', url }).catch(() => {});
}
$('copiar').addEventListener('click', () => copiar($('enlace').value, $('copiar')));
async function copiar(t, boton) {
  try { await navigator.clipboard.writeText(t); boton.textContent = 'Copiado'; }
  catch (e) { $('enlace').select(); boton.textContent = 'Selecciona y copia'; }
  setTimeout(() => boton.textContent = boton.id === 'copiar' ? 'Copiar enlace' : 'Copiar enlace de la peña', 2500);
}

// ---------------------------------------------------------------- peña
const pena = () => leer(CLAVE_PENA) || [];
function anadirPena(b, silencio) {
  const ms = pena(); const k = b.c + b.t;
  const ya = ms.find(m => m.c + m.t === k);
  if (!ya) ms.push({ c: b.c, t: b.t, n: b.n || '', e: b.e || '' }); else if (b.e && !ya.e) ya.e = b.e;
  guardar(CLAVE_PENA, ms); pintarPena(ms);
  if (!silencio) $('pena-aviso').textContent = `${b.n || 'La porra'} está en tu peña.`;
}
$('anadir').addEventListener('click', () => {
  const v = $('pegar').value.trim(); const i = v.indexOf('#');
  const h = i >= 0 ? leerHash(v.slice(i)) : {};
  if (h.boleto) { anadirPena(h.boleto); $('pegar').value = ''; }
  else if (h.pena) { h.pena.forEach(m => anadirPena(m, true)); $('pegar').value = ''; $('pena-aviso').textContent = 'Peña añadida.'; }
  else $('pena-aviso').textContent = 'Ese enlace no contiene una porra. Copia el enlace completo que te han enviado.';
});
$('copiar-pena').addEventListener('click', () => copiar(enlacePena(pena()), $('copiar-pena')));
$('vaciar-pena').addEventListener('click', () => { guardar(CLAVE_PENA, []); pintarPena([]); $('pena-aviso').textContent = 'Peña vacía.'; });

function pintarPena(ms) {
  $('pena-botones').hidden = !ms.length;
  pintarPenaE(ms);
  if (!ms.length) { $('pena-cab').innerHTML = ''; $('pena-filas').innerHTML = '<tr><td class="izq vacia">Todavía no hay nadie. Añade tu porra sellándola y pega aquí los enlaces de tus amigos.</td></tr>'; return; }
  const filasP = ms.map(m => ({ ...m, a: aciertos(m.c), d: desvio(m.e), fuera: m.t && deT(m.t) > cierre }));
  if (porraMedia) filasP.push({ c: porraMedia, e: mediaE, n: 'La media de encuestas', a: aciertos(porraMedia), d: desvio(mediaE), media: true });
  // desempate: menos desvío en escaños; quien no los rellenó queda detrás
  if (resultados) filasP.sort((x, y) => (x.fuera - y.fuera) || (y.a.n - x.a.n) || ((x.d ?? 1e9) - (y.d ?? 1e9)));
  $('pena-cab').innerHTML = `<tr><th class="izq">Quién</th>${resultados ? '<th class="num">Aciertos</th>' : ''}${reglas.filas.map(f => `<th class="sig">${f.id}</th>`).join('')}<th class="sig">15</th></tr>`;
  $('pena-filas').innerHTML = (resultados ? `<tr class="real"><td class="izq"><b>Resultado</b></td><td></td>${real.map(s => `<td class="sig">${s ?? '·'}</td>`).join('')}<td class="sig">${realPleno ?? '·'}</td></tr>` : '') +
    filasP.map(m => `<tr class="${m.media ? 'fila-media' : ''}"><td class="izq">${escapar(m.n || 'Sin nombre')}${m.fuera ? ' (fuera de plazo)' : ''}</td>${resultados ? `<td class="num"><b>${m.a.n}</b></td>` : ''}${[...m.c].map((s, i) => {
      const r = i < 14 ? real[i] : realPleno; const cl = resultados && r !== null ? (s === r ? 'bien' : 'mal') : '';
      return `<td class="sig ${cl}">${s}${cl ? `<span class="mudo">${cl === 'bien' ? ', acierto' : ', fallo'}</span>` : ''}</td>`; }).join('')}</tr>`).join('');
}

// ---------------------------------------------------------------- arranque
const h = leerHash(location.hash);
// Abrir otro enlace de porra o de peña en esta misma pestaña solo cambia el final de la dirección: se recarga para leerlo
addEventListener('hashchange', () => { if (location.hash.length > 1) location.reload(); });
if (h.pena) { h.pena.forEach(m => anadirPena(m, true)); $('pena-aviso').textContent = 'Has abierto una peña: ya está guardada en este navegador.'; mostrarMia(); $('pena').scrollIntoView(); }
else if (h.boleto) mostrarAjena(h.boleto);
else mostrarMia();
pintarPena(pena());

function pintarPenaE(ms) {
  const filasP = ms.filter(m => m.e).map(m => ({ ...m, d: desvio(m.e), fuera: m.t && deT(m.t) > cierre }));
  $('pena-esc').hidden = !filasP.length;
  if (!filasP.length) return;
  if (mediaE) filasP.push({ e: mediaE, n: 'La media', d: desvio(mediaE), media: true });
  if (realE) filasP.sort((x, y) => (x.fuera - y.fuera) || (x.d - y.d));
  const corto = k => ({ OTROS: 'Otros', POD: 'Pod.' })[k] || CORTO[k] || NOMBRES[k];
  $('esc-cab').innerHTML = `<tr><th class="izq">Quién</th>${realE ? '<th class="num">Desvío</th>' : ''}${PARTIDOS.map(k => `<th class="num">${corto(k)}</th>`).join('')}</tr>`;
  $('esc-filas').innerHTML = (realE ? `<tr class="real"><td class="izq"><b>Resultado</b></td><td></td>${realE.map(x => `<td class="num">${x}</td>`).join('')}</tr>` : '') +
    filasP.map(m => `<tr class="${m.media ? 'fila-media' : ''}"><td class="izq">${escapar(m.n || 'Sin nombre')}${m.fuera ? ' (fuera de plazo)' : ''}</td>${realE ? `<td class="num"><b>${m.d}</b></td>` : ''}${m.e.split('.').map((x, i) =>
      `<td class="num ${realE && +x === realE[i] ? 'bien' : ''}">${x}${realE && +x === realE[i] ? '<span class="mudo">, clavado</span>' : ''}</td>`).join('')}</tr>`).join('');
}
