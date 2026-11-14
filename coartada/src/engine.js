// Motor del juego: genera casos, analiza las declaraciones, decide por los bots y puntúa.
// Son funciones puras (el azar se inyecta) para poder simular miles de partidas en las pruebas.
import { ESCENARIOS, HORAS, VERDADES, VAGAS, SENTIDOS, REACCIONES, CHARLA } from "./content.js";

export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
export const pick = (r, arr) => arr[Math.floor(r() * arr.length)];
export function shuffle(r, arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}
const contraer = (s) => s.replace(/\b([Dd])e el\b/g, "$1el").replace(/\b([Aa]) el\b/g, "$1l");
const fill = (s, vars) => contraer(s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m)));
export const sinAcentos = (s) => String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

export const MIN_J = 3, MAX_J = 8;
const CLAVES_S = SENTIDOS.map((x) => x.k), CLAVES_R = REACCIONES.map((x) => x.k);

// ---------- Palabras ----------
/** Deja la palabra clave de un jugador en una sola palabra corta. */
export function limpiarPalabra(s) {
  return String(s || "").trim().split(/\s+/)[0].replace(/[^\p{L}\p{N}]/gu, "").slice(0, 16).toLowerCase();
}
/** ¿La palabra dice el secreto demasiado claro? (comparte raíz con alguna palabra del secreto) */
export function palabraProhibida(palabra, evento) {
  const p = sinAcentos(limpiarPalabra(palabra));
  if (p.length < 3) return false;
  return sinAcentos(evento).split(/[^a-z0-9ñ]+/).some((w) => {
    if (w.length < 3) return false;
    const n = Math.min(5, w.length, p.length);
    return w.slice(0, n) === p.slice(0, n) && Math.abs(w.length - p.length) <= 4;
  });
}
/** ¿Un texto largo delata el secreto? (para filtrar lo que escribe la IA) */
export function delataEvento(texto, evento) {
  const claves = [...new Set(sinAcentos(evento).split(/[^a-z0-9ñ]+/).filter((w) => w.length >= 5).map((w) => w.slice(0, 6)))];
  if (!claves.length) return false;
  const t = sinAcentos(texto);
  return claves.filter((w) => t.includes(w)).length >= Math.min(2, claves.length);
}

// ---------- Casos ----------
/**
 * material: { emoji, titulo, relato, lugar_crimen:{n,e}, lugares:[{n,e}] (sin el del crimen), evento:{t,e,s,r,p}, falsos:[5], verdad }
 * Devuelve el caso completo. Los lugares se guardan por índice dentro de caso.lugares.
 *   cartas[id]   = { lugar, vio: {id, lugar} | null }            (inocentes)
 *   culpable     = { id, seguro, pista: {id, lugar}, rumor: clave | null }
 */
export function armarCaso({ jugadores, culpable, material, tipoR2, random = Math.random }) {
  const r = random;
  const ids = jugadores.map((j) => j.id);
  const inocentes = ids.filter((id) => id !== culpable);
  if (material.lugares.length < inocentes.length + 1) throw new Error("Faltan lugares");
  const libres = shuffle(r, material.lugares).slice(0, Math.min(material.lugares.length, 8));
  const lugares = shuffle(r, [material.lugar_crimen, ...libres]);
  const idxCrimen = lugares.indexOf(material.lugar_crimen);
  const disponibles = shuffle(r, lugares.map((_, i) => i).filter((i) => i !== idxCrimen));
  const lugarDe = {};
  inocentes.forEach((id, i) => { lugarDe[id] = disponibles[i]; });
  const seguro = disponibles[inocentes.length];

  // Testigos: unos inocentes quedan avalados por otros y el resto no, para que el culpable tenga dónde esconderse.
  const orden = shuffle(r, inocentes);
  const nSin = inocentes.length >= 3 ? Math.floor(inocentes.length / 2) : inocentes.length === 2 ? 1 : 0;
  const sinTestigo = orden.slice(0, nSin), avalados = orden.slice(nSin);
  const objetivo = {};
  const fuentes = shuffle(r, [...sinTestigo, ...avalados]);
  for (const v of avalados) { // cada avalado tiene al menos un testigo
    const f = fuentes.find((x) => x !== v && !(x in objetivo));
    if (f) objetivo[f] = v;
  }
  for (const id of inocentes) {
    if (id in objetivo) continue;
    const cand = avalados.filter((x) => x !== id);
    objetivo[id] = cand.length ? pick(r, cand) : null;
  }
  const cartas = {};
  for (const id of inocentes) cartas[id] = { lugar: lugarDe[id], vio: objetivo[id] ? { id: objetivo[id], lugar: lugarDe[objetivo[id]] } : null };
  const pistaId = avalados.length ? pick(r, avalados) : pick(r, inocentes);
  const tipo = tipoR2 || (r() < 0.5 ? "sentido" : "reaccion");
  const ev = material.evento;
  return {
    emoji: material.emoji, titulo: material.titulo, relato: material.relato, lugares, lugar_crimen: idxCrimen,
    evento: ev, falsos: material.falsos.slice(0, 5), tipoR2: tipo, cartas,
    culpable: { id: culpable, seguro, pista: { id: pistaId, lugar: lugarDe[pistaId] }, rumor: r() < 0.6 ? (tipo === "sentido" ? ev.s : ev.r) : null },
    verdad: material.verdad,
  };
}

export function materialLocal({ escenarioId, usados = [], culpableNombre, random = Math.random }) {
  const r = random;
  const libre = !escenarioId || escenarioId === "azar";
  let esc = libre ? pick(r, ESCENARIOS) : ESCENARIOS.find((e) => e.id === escenarioId) || pick(r, ESCENARIOS);
  let crimen = null;
  for (let i = 0; i < 16 && !crimen; i++) {
    const c = pick(r, esc.crimenes);
    if (!usados.includes(c.titulo)) crimen = c; else if (libre) esc = pick(r, ESCENARIOS);
  }
  if (!crimen) crimen = pick(r, esc.crimenes);
  const lugares = shuffle(r, esc.lugares);
  const eventos = shuffle(r, esc.eventos);
  const vars = { lugar: lugares[0].n, lugar_crimen: lugares[0].n, culpable: culpableNombre };
  return {
    emoji: crimen.e, titulo: crimen.titulo, relato: fill(crimen.relato, vars) + ` Pasó cerca de ${pick(r, HORAS)}, en ${esc.ambiente}.`,
    lugar_crimen: lugares[0], lugares: lugares.slice(1), evento: eventos[0], falsos: eventos.slice(1, 6),
    verdad: fill(pick(r, VERDADES), vars),
  };
}

const texto = (x, max = 200) => (typeof x === "string" ? x.trim().replace(/\s+/g, " ").slice(0, max) : "");
const emojiDe = (x, def) => { const t = texto(x, 8); return t && !/[a-z0-9]/i.test(t) ? t : def; };
function eventoIA(x) {
  if (!x || typeof x !== "object") return null;
  let t = texto(x.texto || x.t, 90).replace(/^esa noche[,:]?\s*/i, "").replace(/[.!\s]+$/, "");
  if (!t) return null;
  t = t.charAt(0).toLowerCase() + t.slice(1);
  const s = CLAVES_S.includes(x.sentido) ? x.sentido : null, rr = CLAVES_R.includes(x.reaccion) ? x.reaccion : null;
  if (!s || !rr) return null;
  const p = [...new Set((Array.isArray(x.palabras) ? x.palabras : []).map(limpiarPalabra).filter((w) => w.length >= 3 && !palabraProhibida(w, t)))].slice(0, 6);
  if (p.length < 3) return null;
  return { t, e: emojiDe(x.emoji, "❗"), s, r: rr, p };
}
/** Valida y normaliza el material inventado por la IA. Lanza Error si no sirve para jugar. */
export function materialIA(m, { nJugadores }) {
  if (!m || typeof m !== "object") throw new Error("Caso vacío");
  const titulo = texto(m.titulo, 70), relato = texto(m.relato, 320).replace(/\{culpable\}/g, "alguien"), verdad = texto(m.verdad, 320);
  if (!titulo || !relato || !verdad) throw new Error("Caso incompleto");
  const lug = (x) => { const n = texto(x && (x.nombre || x.n), 28).replace(/[.\s]+$/, ""); return n ? { n: n.charAt(0).toLowerCase() + n.slice(1), e: emojiDe(x.emoji || x.e, "📍") } : null; };
  const crimen = lug(m.lugar_crimen);
  if (!crimen) throw new Error("Falta el lugar del crimen");
  const vistos = new Set([sinAcentos(crimen.n)]);
  const lugares = (Array.isArray(m.lugares) ? m.lugares : []).map(lug).filter((l) => l && !vistos.has(sinAcentos(l.n)) && vistos.add(sinAcentos(l.n)));
  if (lugares.length < nJugadores) throw new Error("Faltan lugares");
  const evento = eventoIA(m.evento_secreto);
  if (!evento) throw new Error("El secreto no sirve");
  const falsos = (Array.isArray(m.eventos_falsos) ? m.eventos_falsos : []).map(eventoIA).filter((e) => e && sinAcentos(e.t) !== sinAcentos(evento.t));
  if (falsos.length < 5) throw new Error("Faltan secretos falsos");
  if (delataEvento(relato + " " + titulo, evento.t)) throw new Error("El relato delata el secreto");
  return { emoji: emojiDe(m.emoji, "🕵️"), titulo, relato, lugar_crimen: crimen, lugares, evento, falsos: falsos.slice(0, 5), verdad };
}

export function opcionesEvento(caso, random = Math.random) {
  return shuffle(random, [caso.evento, ...caso.falsos]).map((e) => ({ t: e.t, e: e.e }));
}

// ---------- Ronda 1: coartadas ----------
/** Lo que un inocente declara si dice la verdad. */
export function declaracionVerdadera(caso, id) {
  const c = caso.cartas[id];
  return { lugar: c.lugar, vio: c.vio ? c.vio.id : null, vioLugar: c.vio ? c.vio.lugar : null };
}
export function declaracionValida(caso, ids, id, d) {
  if (!d || !Number.isInteger(d.lugar) || d.lugar < 0 || d.lugar >= caso.lugares.length || d.lugar === caso.lugar_crimen) return null;
  if (d.vio == null) return { lugar: d.lugar, vio: null, vioLugar: null };
  if (d.vio === id || !ids.includes(d.vio) || !Number.isInteger(d.vioLugar) || d.vioLugar < 0 || d.vioLugar >= caso.lugares.length) return null;
  return { lugar: d.lugar, vio: d.vio, vioLugar: d.vioLugar };
}
/**
 * Cruza las declaraciones. avalados: alguien más confirma dónde estaban.
 * choques: {tipo:"lugar", a, b} (a dice que vio a b en otro sitio) o {tipo:"mismo", a, b, lugar} (mismo lugar y no se vieron).
 */
export function analizarR1(decl, ids) {
  const avalados = new Set(), choques = [];
  for (const a of ids) {
    const d = decl[a];
    if (!d || d.vio == null || !decl[d.vio]) continue;
    if (decl[d.vio].lugar === d.vioLugar) avalados.add(d.vio); else choques.push({ tipo: "lugar", a, b: d.vio, lugar: d.vioLugar });
  }
  for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
    const a = ids[i], b = ids[j], da = decl[a], db = decl[b];
    if (!da || !db || da.lugar !== db.lugar) continue;
    const seVieron = (da.vio === b && da.vioLugar === da.lugar) || (db.vio === a && db.vioLugar === db.lugar);
    if (!seVieron) choques.push({ tipo: "mismo", a, b, lugar: da.lugar });
  }
  return { avalados: ids.filter((x) => avalados.has(x)), choques };
}

// ---------- Sospechas ----------
function mayoria(resp) {
  const n = {};
  for (const v of Object.values(resp || {})) n[v] = (n[v] || 0) + 1;
  const orden = Object.entries(n).sort((a, b) => b[1] - a[1]);
  return orden.length && (orden.length === 1 || orden[0][1] > orden[1][1]) ? orden[0][0] : null;
}
function clasePalabra(caso, palabra) {
  const p = sinAcentos(palabra || "");
  if (!p) return "nada";
  const en = (ev) => ev.p.some((w) => sinAcentos(w) === p);
  if (en(caso.evento)) return "buena";
  if (VAGAS.some((w) => sinAcentos(w) === p)) return "vaga";
  if (caso.falsos.some(en)) return "ajena";
  return "desconocida";
}
/**
 * Cuánto sospecha un observador de cada jugador con las pruebas públicas.
 * conVerdad: el observador conoce el secreto (inocentes y detective); si no, se guía por la mayoría.
 */
export function sospechas(caso, pub, ids, { conVerdad = true, yo = null, ruido = 0, random = Math.random } = {}) {
  const s = Object.fromEntries(ids.map((id) => [id, 0]));
  if (pub.r1) {
    const an = pub.analisis || analizarR1(pub.r1, ids);
    for (const id of ids) s[id] += an.avalados.includes(id) ? -2.5 : 1.2;
    for (const c of an.choques) { s[c.a] += 2; s[c.b] += an.avalados.includes(c.b) ? 0.5 : 2; }
  }
  if (pub.r2) {
    const bien = conVerdad ? (caso.tipoR2 === "sentido" ? caso.evento.s : caso.evento.r) : mayoria(pub.r2);
    if (bien) for (const id of ids) if (pub.r2[id]) s[id] += pub.r2[id] === bien ? -1 : 2.2;
  }
  if (pub.r3) for (const id of ids) {
    const c = clasePalabra(caso, pub.r3[id]);
    if (conVerdad) s[id] += { buena: -2.2, vaga: 1.6, ajena: 3, desconocida: 0.4, nada: 1 }[c];
    else s[id] += { buena: 0, vaga: 1.2, ajena: 0, desconocida: 0, nada: 1 }[c];
  }
  if (ruido) for (const id of ids) s[id] += (random() - 0.5) * 2 * ruido;
  if (yo) delete s[yo];
  return s;
}
const masSospechoso = (s) => Object.entries(s).sort((a, b) => b[1] - a[1])[0][0];

// ---------- Bots ----------
export function botR1(caso, id, random = Math.random) {
  const r = random;
  if (id !== caso.culpable.id) return declaracionVerdadera(caso, id);
  const c = caso.culpable;
  const otros = caso.lugares.map((_, i) => i).filter((i) => i !== caso.lugar_crimen);
  const lugar = r() < 0.8 ? c.seguro : pick(r, otros);
  const x = r();
  if (x < 0.72) return { lugar, vio: c.pista.id, vioLugar: c.pista.lugar };
  if (x < 0.88) return { lugar, vio: null, vioLugar: null };
  const ids = Object.keys(caso.cartas);
  return { lugar, vio: pick(r, ids), vioLugar: pick(r, otros) };
}
export function botR2(caso, id, random = Math.random) {
  const r = random, claves = caso.tipoR2 === "sentido" ? CLAVES_S : CLAVES_R;
  const bien = caso.tipoR2 === "sentido" ? caso.evento.s : caso.evento.r;
  if (id !== caso.culpable.id) return r() < 0.8 ? bien : pick(r, claves.filter((k) => k !== bien));
  return caso.culpable.rumor || pick(r, claves);
}
export function botR3(caso, id, pub, random = Math.random) {
  const r = random;
  const usadas = new Set(Object.values(pub.r3 || {}).map(sinAcentos));
  const libre = (lista) => { const l = lista.filter((w) => !usadas.has(sinAcentos(w))); return l.length ? pick(r, l) : pick(r, lista); };
  if (id !== caso.culpable.id) return libre(caso.evento.p);
  if (r() < 0.3) return libre(VAGAS);
  // El culpable deduce por la mayoría de la ronda 2 y se arriesga con una palabra de un secreto que encaje.
  const pista = mayoria(pub.r2);
  const todos = [caso.evento, ...caso.falsos];
  const encajan = todos.filter((e) => !pista || (caso.tipoR2 === "sentido" ? e.s : e.r) === pista);
  return libre(pick(r, encajan.length ? encajan : todos).p);
}
export function botVoto(caso, id, pub, ids, random = Math.random) {
  const esCulpable = id === caso.culpable.id;
  return masSospechoso(sospechas(caso, pub, ids, { conVerdad: !esCulpable, yo: id, ruido: 3.4, random }));
}
/** El bot culpable intenta adivinar el secreto con lo que oyó. Devuelve un índice de `opciones`. */
export function botAdivina(caso, pub, opciones, random = Math.random) {
  const todos = [caso.evento, ...caso.falsos];
  const pista = mayoria(pub.r2);
  const dichas = Object.entries(pub.r3 || {}).filter(([id]) => id !== caso.culpable.id).map(([, w]) => sinAcentos(w));
  const pesos = opciones.map((o) => {
    const ev = todos.find((e) => e.t === o.t);
    let w = 1;
    if (pista && (caso.tipoR2 === "sentido" ? ev.s : ev.r) === pista) w += 2;
    w += 2.5 * ev.p.filter((p) => dichas.includes(sinAcentos(p))).length;
    return w;
  });
  let x = random() * pesos.reduce((a, b) => a + b, 0);
  for (let i = 0; i < pesos.length; i++) { x -= pesos[i]; if (x <= 0) return i; }
  return pesos.length - 1;
}
/** Comentarios de los bots tras una revelación: [{id, txt}] */
export function charlaBots(caso, pub, jugadores, etapa, random = Math.random) {
  const r = random, bots = jugadores.filter((j) => j.bot), ids = jugadores.map((j) => j.id);
  if (!bots.length) return [];
  const nombre = (id) => (jugadores.find((j) => j.id === id) || {}).nombre || "?";
  const frases = [];
  const an = pub.analisis || { avalados: [], choques: [] };
  if (etapa === "r1") {
    for (const c of an.choques.slice(0, 1)) frases.push(fill(pick(r, CHARLA.choque), { x: nombre(c.a), y: nombre(c.b) }));
    const sin = ids.filter((id) => !an.avalados.includes(id));
    if (sin.length && sin.length < ids.length) frases.push(fill(pick(r, CHARLA.sinTestigo), { x: nombre(pick(r, sin)) }));
  } else if (etapa === "r2") {
    const m = mayoria(pub.r2);
    const raros = ids.filter((id) => m && pub.r2[id] && pub.r2[id] !== m);
    if (raros.length) frases.push(fill(pick(r, CHARLA.raro), { x: nombre(pick(r, raros)) }));
  } else if (etapa === "r3") {
    const raros = ids.filter((id) => ["ajena", "vaga"].includes(clasePalabra(caso, pub.r3[id])));
    if (raros.length) { const x = pick(r, raros); frases.push(fill(pick(r, CHARLA.palabra), { x: nombre(x), p: pub.r3[x] })); }
  }
  if (!frases.length) frases.push(pick(r, CHARLA.calma));
  const hablan = shuffle(r, bots);
  // Un bot no se acusa a sí mismo.
  return frases.slice(0, 2).map((txt, i) => ({ id: hablan[i % hablan.length].id, txt })).filter((f) => !f.txt.includes(nombre(f.id)));
}

// ---------- Detective ----------
/** El detective del archivo: acusa según las pruebas, con algo de error humano. */
export function detectiveLocal(caso, pub, jugadores, random = Math.random) {
  const ids = jugadores.map((j) => j.id), nombre = (id) => jugadores.find((j) => j.id === id).nombre;
  const s = sospechas(caso, pub, ids, { conVerdad: true, ruido: 4.6, random });
  const acusado = masSospechoso(s);
  const an = pub.analisis || { avalados: [], choques: [] }, razones = [];
  const ch = an.choques.find((c) => c.a === acusado || c.b === acusado);
  if (ch) razones.push(`Su coartada chocó con la de ${nombre(ch.a === acusado ? ch.b : ch.a)}.`);
  if (!an.avalados.includes(acusado)) razones.push("Nadie pudo confirmar dónde estaba.");
  const m = mayoria(pub.r2);
  if (m && pub.r2[acusado] && pub.r2[acusado] !== m) razones.push("Respondió distinto a casi todos sobre «eso».");
  if (pub.r3 && pub.r3[acusado]) razones.push(`Su palabra clave fue «${pub.r3[acusado]}». Me dejó pensando.`);
  if (!razones.length) razones.push("No tengo pruebas firmes, pero mi olfato no falla… casi nunca.");
  return { acusado, razones: razones.slice(0, 3), frase: pick(random, [`${nombre(acusado)}, tu historia hace agua por todos lados.`, `Lo siento, ${nombre(acusado)}: todas las pistas llevan a ti.`, `${nombre(acusado)}, no mires para otro lado. Fuiste tú.`]) };
}

// ---------- Votos y puntos ----------
export function contarVotos(votos, ids) {
  const cuenta = Object.fromEntries(ids.map((j) => [j, 0]));
  for (const v of Object.values(votos)) if (v in cuenta) cuenta[v]++;
  const max = Math.max(...Object.values(cuenta));
  const lideres = ids.filter((j) => cuenta[j] === max);
  return { cuenta, acusado: lideres.length === 1 && max > 0 ? lideres[0] : null, empate: lideres.length > 1 };
}
/**
 * - Culpable escapa: +4; +1 a cada inocente que sí le votó.
 * - Culpable atrapado: +2 a cada inocente que le votó; si adivina el secreto, +2 para el culpable.
 * - Si el detective acusó a un inocente: +1 para el culpable.
 */
export function puntuar({ ids, culpable, votos, adivino = false, acusadoDetective = null }) {
  const { cuenta, acusado, empate } = contarVotos(votos, ids);
  const atrapado = acusado === culpable;
  const puntos = Object.fromEntries(ids.map((j) => [j, 0])), motivos = [];
  for (const j of ids) if (j !== culpable && votos[j] === culpable) puntos[j] += atrapado ? 2 : 1;
  if (atrapado) {
    motivos.push({ k: "atrapado" });
    if (adivino) { puntos[culpable] += 2; motivos.push({ k: "adivino" }); }
  } else {
    puntos[culpable] += 4; motivos.push({ k: empate ? "empate" : "escapo" });
    if (ids.some((j) => j !== culpable && votos[j] === culpable)) motivos.push({ k: "olfato" });
  }
  if (acusadoDetective && acusadoDetective !== culpable) { puntos[culpable] += 1; motivos.push({ k: "detective", id: acusadoDetective }); }
  return { puntos, atrapado, acusado, empate, cuenta, motivos };
}
