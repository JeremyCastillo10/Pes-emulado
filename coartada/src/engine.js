// Motor del juego: generación de casos sin internet, validación y puntuación.
import { ESCENARIOS, HORAS, PREGUNTAS, VERDADES } from "./content.js";

export function rng(seed) {
  // mulberry32: determinista para poder probar
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
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
// Rellena {variables} y aplica las contracciones del español: «de el» -> «del», «a el» -> «al».
const contraer = (s) => s.replace(/\b([Dd])e el\b/g, "$1el").replace(/\b([Aa]) el\b/g, "$1l");
const fill = (s, vars) => contraer(s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m)));

/**
 * Reparte las cartas de un caso a partir de su «material» (del archivo o inventado por la IA).
 * El reparto lo hace siempre este código, así las cartas nunca se contradicen entre sí.
 * material: { titulo, relato, lugar_crimen, hora, pistas[], lugares[{n, acts[]}], coartada_falsa{lugar, actividad},
 *             evento_secreto, eventos_falsos[], verdad }
 * Devuelve: { titulo, relato, lugar_crimen, hora, pistas[], evento_secreto, eventos_falsos[5],
 *             cartas[{jugador, lugar, actividad, visto, extra}], coartada_falsa{lugar, actividad}, verdad }
 */
export function armarCaso({ jugadores, culpable, material, random = Math.random }) {
  const r = random;
  const libres = shuffle(r, material.lugares);
  const inocentes = jugadores.filter((j) => j !== culpable);
  const orden = shuffle(r, inocentes);
  // Con 4+ inocentes se forman parejas en el mismo lugar para que se confirmen entre sí.
  const asign = {};
  let li = 0;
  for (let i = 0; i < orden.length; i++) {
    const enPareja = orden.length >= 4 && i % 3 === 1; // comparte lugar con el anterior
    if (!enPareja && i > 0) li++;
    asign[orden[i]] = libres[li % libres.length];
  }
  const cartas = inocentes.map((j) => {
    const lugar = asign[j];
    const companeros = inocentes.filter((o) => o !== j && asign[o].n === lugar.n);
    const idx = orden.indexOf(j);
    const otro = orden[(idx + 1) % orden.length];
    let visto;
    if (companeros.length) {
      visto = `${companeros.join(" y ")} estaba${companeros.length > 1 ? "n" : ""} contigo en ${lugar.n}.`;
    } else if (otro && otro !== j) {
      visto = `Un rato antes viste a ${otro} caminando hacia ${asign[otro].n}.`;
    } else {
      visto = "No te cruzaste con nadie.";
    }
    const acts = lugar.acts;
    // Quienes comparten lugar reciben actividades distintas.
    const grupo = inocentes.filter((o) => asign[o].n === lugar.n);
    const actividad = companeros.length ? acts[grupo.indexOf(j) % acts.length] : pick(r, acts);
    return { jugador: j, lugar: lugar.n, actividad, visto: contraer(visto), extra: null };
  });
  // Testigo: con mesas grandes, un inocente sabe que el lugar de la coartada falsa estaba vacío.
  if (inocentes.length >= 4) {
    pick(r, cartas).extra = `Pasaste por ${material.coartada_falsa.lugar} y no había nadie.`;
  }
  return {
    titulo: material.titulo,
    relato: material.relato,
    lugar_crimen: material.lugar_crimen,
    hora: material.hora,
    pistas: (material.pistas || []).slice(0, 3),
    evento_secreto: material.evento_secreto,
    eventos_falsos: material.eventos_falsos.slice(0, 5),
    cartas,
    coartada_falsa: { lugar: material.coartada_falsa.lugar, actividad: material.coartada_falsa.actividad },
    verdad: material.verdad,
  };
}

/** Genera un caso completo sin internet a partir del archivo de escenarios. */
export function generarCasoLocal({ jugadores, culpable, escenarioId, usados = [], random = Math.random }) {
  const r = random;
  const candidatos = ESCENARIOS.filter((e) => !escenarioId || escenarioId === "azar" || e.id === escenarioId);
  let esc = pick(r, candidatos.length ? candidatos : ESCENARIOS);
  // evita repetir el mismo crimen en la misma partida
  let crimen = null;
  for (let i = 0; i < 12 && !crimen; i++) {
    const c = pick(r, esc.crimenes);
    if (!usados.includes(c.titulo)) crimen = c;
    else if (!escenarioId || escenarioId === "azar") esc = pick(r, ESCENARIOS);
  }
  if (!crimen) crimen = pick(r, esc.crimenes);
  const lugares = shuffle(r, esc.lugares);
  const lugarCrimen = lugares[0], lugarFalso = lugares[1];
  const hora = pick(r, HORAS);
  const eventos = shuffle(r, esc.eventos);
  const vars = { lugar: lugarCrimen.n, lugar_crimen: lugarCrimen.n, lugar_falso: lugarFalso.n, culpable, hora };
  return armarCaso({
    jugadores, culpable, random: r,
    material: {
      titulo: crimen.titulo,
      relato: `Estaban en ${esc.ambiente}. ${fill(crimen.relato, vars)} Ocurrió cerca de las ${hora}.`,
      lugar_crimen: lugarCrimen.n,
      hora,
      pistas: crimen.pistas,
      lugares: lugares.slice(2),
      coartada_falsa: { lugar: lugarFalso.n, actividad: pick(r, lugarFalso.acts) },
      evento_secreto: eventos[0],
      eventos_falsos: eventos.slice(1, 6),
      verdad: fill(pick(r, VERDADES), vars),
    },
  });
}

const sinAcentos = (s) => String(s).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
const VACIAS = new Set(["noche", "todos", "todas", "segundo", "segundos", "minuto", "minutos", "durante", "cuando", "donde", "estaba", "estaban", "alguien", "entero", "entera", "misma", "mismo", "veces", "hasta", "desde", "sobre", "entre", "apenas", "justo", "fuerte", "nadie", "repente"]);
const claves = (s) => [...new Set(sinAcentos(s).split(/[^a-z0-9ñ]+/).filter((w) => w.length >= 5 && !VACIAS.has(w)).map((w) => w.slice(0, 6)))];
/** ¿El texto delata el dato secreto? Compara las palabras distintivas (por su raíz). */
export function delataEvento(texto, evento) {
  const k = claves(evento);
  if (!k.length) return false;
  const t = sinAcentos(texto);
  const aciertos = k.filter((w) => t.includes(w)).length;
  return aciertos >= Math.min(2, k.length);
}

/** Deja un evento listo para completar la frase «Esa noche …». */
export function limpiarEvento(s) {
  let t = String(s).trim().replace(/^esa noche[,:]?\s*/i, "").replace(/[.!\s]+$/, "");
  return t.charAt(0).toLowerCase() + t.slice(1);
}
/** Deja una actividad lista para completar «Estabas en X, …» («Estabas en el patio, Bailando.» -> «bailando»). */
export function limpiarActividad(s) {
  const t = String(s).trim().replace(/^estabas(\s+en\s+[^,]+)?\s*,?\s*/i, "").replace(/[.\s]+$/, "");
  return t.charAt(0).toLowerCase() + t.slice(1);
}
/** Normaliza el nombre de un lugar («La cocina.» -> «la cocina») para usarlo dentro de una frase. */
export function conArticulo(s) {
  const t = String(s).trim().replace(/[.\s]+$/, "");
  return t.charAt(0).toLowerCase() + t.slice(1);
}

/**
 * Convierte el material inventado por la IA en un caso jugable. Lanza Error si no sirve.
 */
export function armarCasoIA({ jugadores, culpable, material, random = Math.random }) {
  const m = material || {};
  for (const k of ["titulo", "relato", "lugar_crimen", "hora", "evento_secreto", "verdad"]) if (typeof m[k] !== "string" || !m[k].trim()) throw new Error("Caso incompleto: " + k);
  if (!m.coartada_falsa || !m.coartada_falsa.lugar || !m.coartada_falsa.actividad) throw new Error("Falta la coartada falsa");
  const prohibidos = [sinAcentos(conArticulo(m.lugar_crimen)), sinAcentos(conArticulo(m.coartada_falsa.lugar))];
  const vistos = new Set();
  const lugares = (Array.isArray(m.lugares) ? m.lugares : [])
    .map((l) => ({ n: conArticulo(l && l.nombre || ""), acts: (l && Array.isArray(l.actividades) ? l.actividades : []).filter((a) => typeof a === "string" && a.trim()).map(limpiarActividad).filter(Boolean) }))
    .filter((l) => l.n && l.acts.length && !prohibidos.includes(sinAcentos(l.n)) && !vistos.has(sinAcentos(l.n)) && vistos.add(sinAcentos(l.n)));
  if (lugares.length < 4) throw new Error("Faltan lugares");
  for (const l of lugares) if (l.acts.length < 2) l.acts.push(l.acts[0]);
  const evento = limpiarEvento(m.evento_secreto);
  const falsos = [...new Set((Array.isArray(m.eventos_falsos) ? m.eventos_falsos : []).filter((e) => typeof e === "string" && e.trim()).map(limpiarEvento))].filter((e) => sinAcentos(e) !== sinAcentos(evento));
  if (falsos.length < 5) throw new Error("Faltan eventos falsos");
  if (delataEvento(m.relato + " " + (m.pistas || []).join(" "), evento)) throw new Error("El relato delata el dato secreto");
  return armarCaso({
    jugadores, culpable, random,
    material: {
      titulo: m.titulo.trim(), relato: m.relato.trim(), lugar_crimen: conArticulo(m.lugar_crimen), hora: m.hora.trim(),
      pistas: (Array.isArray(m.pistas) ? m.pistas : []).filter((x) => typeof x === "string" && x.trim()),
      lugares, coartada_falsa: { lugar: conArticulo(m.coartada_falsa.lugar), actividad: limpiarActividad(m.coartada_falsa.actividad) || "sin hacer nada" },
      evento_secreto: evento, eventos_falsos: falsos, verdad: m.verdad.trim(),
    },
  });
}

/** Comprueba y normaliza un caso (local o generado por la IA). Lanza Error si no sirve. */
export function validarCaso(caso, jugadores, culpable) {
  const req = ["titulo", "relato", "lugar_crimen", "hora", "evento_secreto", "verdad"];
  for (const k of req) if (typeof caso[k] !== "string" || !caso[k].trim()) throw new Error("Caso incompleto: " + k);
  if (!Array.isArray(caso.pistas)) caso.pistas = [];
  if (!Array.isArray(caso.eventos_falsos) || caso.eventos_falsos.length < 3) throw new Error("Faltan eventos falsos");
  caso.eventos_falsos = caso.eventos_falsos.filter((e) => e && e !== caso.evento_secreto).slice(0, 5);
  if (!caso.coartada_falsa || !caso.coartada_falsa.lugar) throw new Error("Falta la coartada falsa");
  const inocentes = jugadores.filter((j) => j !== culpable);
  const norm = (s) => String(s).trim().toLowerCase();
  const cartas = [];
  for (const j of inocentes) {
    const c = (caso.cartas || []).find((x) => norm(x.jugador) === norm(j));
    if (!c || !c.lugar || !c.actividad) throw new Error("Falta la carta de " + j);
    cartas.push({ jugador: j, lugar: c.lugar, actividad: c.actividad, visto: c.visto || "No te cruzaste con nadie.", extra: c.extra || null });
  }
  caso.cartas = cartas;
  return caso;
}

/** Preguntas del modo Clásico para una ronda (1, 2 o 3). Devuelve {jugador: pregunta}. */
export function preguntasLocales({ ronda, jugadores, caso, random = Math.random }) {
  const banco = PREGUNTAS["r" + Math.min(3, Math.max(1, ronda))];
  const mazo = shuffle(random, banco);
  const out = {};
  jugadores.forEach((j, i) => {
    const otros = jugadores.filter((o) => o !== j);
    out[j] = fill(mazo[i % mazo.length], { otro: pick(random, otros), hora: caso.hora, lugar_crimen: caso.lugar_crimen });
  });
  return out;
}

/** Cuenta votos. votos = {votante: acusado}. */
export function contarVotos(votos, jugadores) {
  const cuenta = Object.fromEntries(jugadores.map((j) => [j, 0]));
  for (const v of Object.values(votos)) if (v in cuenta) cuenta[v]++;
  const max = Math.max(...Object.values(cuenta));
  const lideres = jugadores.filter((j) => cuenta[j] === max);
  // El acusado es quien tiene más votos; si hay empate, nadie es atrapado.
  return { cuenta, acusado: lideres.length === 1 && max > 0 ? lideres[0] : null, empate: lideres.length > 1 };
}

/**
 * Puntos de la ronda.
 * - Culpable escapa: +4 para el culpable; +1 a cada inocente que sí le votó.
 * - Culpable atrapado: +2 a cada inocente que le votó. Si el culpable adivina el dato secreto: +2 para el culpable.
 * - Si el Detective IA acusó a un inocente: +1 para el culpable.
 */
export function puntuar({ jugadores, culpable, votos, adivinoEvento = false, acusadoIA = null }) {
  const { cuenta, acusado, empate } = contarVotos(votos, jugadores);
  const atrapado = acusado === culpable;
  const puntos = Object.fromEntries(jugadores.map((j) => [j, 0]));
  const motivos = [];
  for (const j of jugadores) {
    if (j === culpable) continue;
    if (votos[j] === culpable) puntos[j] += atrapado ? 2 : 1;
  }
  if (atrapado) {
    motivos.push(`${culpable} fue descubierto: +2 a quienes le votaron.`);
    if (adivinoEvento) { puntos[culpable] += 2; motivos.push(`${culpable} adivinó el dato secreto: +2.`); }
  } else {
    puntos[culpable] += 4;
    motivos.push(`${culpable} escapó: +4.${empate ? " Hubo empate en la votación." : ""}`);
    if (jugadores.some((j) => j !== culpable && votos[j] === culpable)) motivos.push("Quienes sí sospecharon del culpable: +1.");
  }
  if (acusadoIA && acusadoIA !== culpable) { puntos[culpable] += 1; motivos.push(`El detective acusó a ${acusadoIA} por error: +1 para ${culpable}.`); }
  return { puntos, atrapado, acusado, empate, cuenta, motivos };
}

export function opcionesEvento(caso, random = Math.random) {
  return shuffle(random, [caso.evento_secreto, ...caso.eventos_falsos.slice(0, 5)]);
}
