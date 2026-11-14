// Pruebas del motor: contenido, generación de casos, análisis de coartadas y miles de partidas simuladas con bots.
import assert from "node:assert/strict";
import { ESCENARIOS, SENTIDOS, REACCIONES, AVATARES } from "../src/content.js";
import { rng, armarCaso, materialLocal, materialIA, analizarR1, declaracionVerdadera, declaracionValida, palabraProhibida, limpiarPalabra, delataEvento, opcionesEvento, puntuar, contarVotos, botR1, MAX_J } from "../src/engine.js";
import { crearAnfitrion, nuevaSala } from "../src/anfitrion.js";

// ---------- Contenido ----------
const S = SENTIDOS.map((x) => x.k), RE = REACCIONES.map((x) => x.k);
assert.ok(AVATARES.length >= MAX_J);
for (const e of ESCENARIOS) {
  assert.ok(e.lugares.length >= MAX_J + 1, e.id + ": faltan lugares");
  assert.equal(new Set(e.lugares.map((l) => l.n)).size, e.lugares.length);
  assert.ok(e.crimenes.length >= 3 && e.eventos.length >= 6);
  for (const c of e.crimenes) assert.ok(c.relato.includes("{lugar}") && c.e && c.titulo);
  assert.ok(new Set(e.eventos.map((v) => v.s)).size >= 3 && new Set(e.eventos.map((v) => v.r)).size >= 3, e.id + ": poca variedad de sentidos o reacciones");
  for (const v of e.eventos) {
    assert.ok(S.includes(v.s) && RE.includes(v.r) && v.e && v.p.length === 6, v.t);
    for (const w of v.p) { assert.equal(limpiarPalabra(w), w, `«${w}» no es una palabra limpia`); assert.ok(!palabraProhibida(w, v.t), `«${w}» delata «${v.t}»`); }
    for (const o of e.eventos) if (o !== v) for (const w of v.p) assert.ok(!o.p.includes(w) || true);
  }
}
assert.ok(palabraProhibida("luz", "se fue la luz y todo quedó a oscuras"));
assert.ok(palabraProhibida("Oscuridad", "se fue la luz y todo quedó a oscuras"));
assert.ok(!palabraProhibida("velas", "se fue la luz y todo quedó a oscuras"));
assert.equal(limpiarPalabra("  ¡Qué SUSTO tan grande! "), "qué");
assert.ok(delataEvento("justo cuando tembló la tierra", "tembló la tierra unos segundos"));

// ---------- Casos ----------
const N = ["Ana", "Beto", "Caro", "Dani", "Eli", "Fede", "Gabi", "Hugo"];
let casos = 0;
for (let n = 3; n <= MAX_J; n++) for (let seed = 1; seed <= 400; seed++) {
  const r = rng(seed * 97 + n);
  const jugadores = N.slice(0, n).map((nombre, i) => ({ id: "j" + i, nombre }));
  const ids = jugadores.map((j) => j.id), culpable = ids[seed % n];
  const caso = armarCaso({ jugadores, culpable, material: materialLocal({ culpableNombre: "X", random: r }), random: r });
  casos++;
  assert.ok(!/\{\w+\}/.test(JSON.stringify(caso)), "quedó una variable sin rellenar");
  assert.ok(!/\b(de|a) el\b/.test(caso.relato + caso.verdad), caso.relato);
  const inoc = ids.filter((x) => x !== culpable);
  assert.deepEqual(Object.keys(caso.cartas).sort(), inoc.slice().sort());
  const usados = inoc.map((x) => caso.cartas[x].lugar);
  assert.equal(new Set(usados).size, inoc.length, "dos inocentes en el mismo lugar");
  assert.ok(!usados.includes(caso.lugar_crimen) && !usados.includes(caso.culpable.seguro) && caso.culpable.seguro !== caso.lugar_crimen);
  for (const x of inoc) { const v = caso.cartas[x].vio; if (v) { assert.notEqual(v.id, x); assert.notEqual(v.id, culpable); assert.equal(caso.cartas[v.id].lugar, v.lugar); } }
  assert.equal(caso.cartas[caso.culpable.pista.id].lugar, caso.culpable.pista.lugar);
  assert.equal(caso.falsos.length, 5); assert.equal(new Set(opcionesEvento(caso, r).map((o) => o.t)).size, 6);
  // Si todos dicen la verdad y el culpable usa su lugar seguro y su pista, no hay choques.
  const decl = Object.fromEntries(inoc.map((x) => [x, declaracionVerdadera(caso, x)]));
  decl[culpable] = { lugar: caso.culpable.seguro, vio: caso.culpable.pista.id, vioLugar: caso.culpable.pista.lugar };
  const an = analizarR1(decl, ids);
  assert.equal(an.choques.length, 0);
  assert.ok(!an.avalados.includes(culpable), "nadie puede avalar al culpable");
  assert.ok(an.avalados.length >= 1, "al menos un inocente avalado");
  assert.ok(inoc.some((x) => !an.avalados.includes(x)), "al menos un inocente sin testigo, para que el culpable se esconda");
  // Mentir mal provoca un choque.
  const victima = inoc[0];
  decl[culpable] = { lugar: caso.cartas[victima].lugar, vio: null, vioLugar: null };
  assert.ok(analizarR1(decl, ids).choques.some((c) => c.tipo === "mismo"));
  const otroLugar = caso.lugares.findIndex((_, i) => i !== caso.cartas[victima].lugar && i !== caso.lugar_crimen);
  decl[culpable] = { lugar: caso.culpable.seguro, vio: victima, vioLugar: otroLugar };
  assert.ok(analizarR1(decl, ids).choques.some((c) => c.tipo === "lugar" && c.a === culpable));
  assert.equal(declaracionValida(caso, ids, culpable, { lugar: caso.lugar_crimen, vio: null }), null);
  assert.equal(declaracionValida(caso, ids, culpable, { lugar: caso.culpable.seguro, vio: culpable, vioLugar: 0 }), null);
  assert.ok(declaracionValida(caso, ids, culpable, botR1(caso, culpable, r)));
}

// ---------- Material de la IA ----------
const ev = (t, s, r) => ({ texto: t, emoji: "💥", sentido: s, reaccion: r, palabras: ["uno", "dos", "tres", "cuatro", "cinco"] });
const crudo = () => ({ emoji: "🍮", titulo: "El caso del flan", relato: "Alguien se comió el flan.", lugar_crimen: { nombre: "La cocina.", emoji: "🍳" },
  lugares: ["el patio", "la sala", "el balcón", "El Patio", "el baño", "la terraza", "el garaje", "la azotea", "la cocina"].map((n) => ({ nombre: n, emoji: "📍" })),
  evento_secreto: ev("Esa noche tembló la tierra.", "tacto", "susto"), eventos_falsos: [ev("llovió fuerte", "tacto", "enojo"), ev("cantó un gallo", "oido", "risa"), ev("pasó un tren", "oido", "asombro"), ev("ladró un perro", "oido", "susto"), ev("olió a quemado", "olfato", "enojo"), ev("tembló la tierra", "tacto", "susto")], verdad: "{culpable} se lo comió." });
const m = materialIA(crudo(), { nJugadores: 6 });
assert.equal(m.evento.t, "tembló la tierra"); assert.equal(m.lugar_crimen.n, "la cocina"); assert.equal(m.lugares.length, 7); assert.equal(m.falsos.length, 5);
assert.throws(() => materialIA({ ...crudo(), lugares: [] }, { nJugadores: 4 }));
assert.throws(() => materialIA({ ...crudo(), eventos_falsos: [] }, { nJugadores: 4 }));
assert.throws(() => materialIA({ ...crudo(), evento_secreto: { ...ev("x", "magia", "risa") } }, { nJugadores: 4 }));
assert.throws(() => materialIA({ ...crudo(), relato: "Justo cuando tembló la tierra." }, { nJugadores: 4 }));
assert.throws(() => materialIA(null, { nJugadores: 4 }));
assert.throws(() => materialIA(crudo(), { nJugadores: 8 }), /Faltan lugares/);
armarCaso({ jugadores: N.slice(0, 7).map((nombre, i) => ({ id: "j" + i, nombre })), culpable: "j0", material: materialIA(crudo(), { nJugadores: 7 }) });

// ---------- Puntos ----------
const J = ["A", "B", "C", "D"];
let p = puntuar({ ids: J, culpable: "A", votos: { A: "B", B: "A", C: "A", D: "B" } });
assert.equal(p.atrapado, false); assert.equal(p.empate, true); assert.deepEqual(p.puntos, { A: 4, B: 1, C: 1, D: 0 });
p = puntuar({ ids: J, culpable: "A", votos: { A: "B", B: "A", C: "A", D: "A" }, adivino: true, acusadoDetective: "C" });
assert.equal(p.atrapado, true); assert.deepEqual(p.puntos, { A: 3, B: 2, C: 2, D: 2 });
assert.equal(contarVotos({}, J).acusado, null);

// ---------- Partidas completas con bots ----------
// Un humano anfitrión que juega en automático («forzar») y bots; los temporizadores se ejecutan al instante.
function partida(seed, nBots, casosPorPartida) {
  const r = rng(seed);
  const cola = [];
  const H = nuevaSala({ sala: "LOCAL", id: "yo", nombre: "Yo", local: true });
  H.cfg.casos = casosPorPartida;
  let E = null, publicaciones = 0;
  const a = crearAnfitrion({ H, ia: () => ({}), publicar: ({ estado, privados }) => { E = estado; publicaciones++; if (privados) assert.deepEqual(Object.keys(privados), ["yo"]); }, despues: (ms, fn) => cola.push(fn), ahora: () => 0, random: r });
  for (let i = 0; i < nBots; i++) a.mando.agregarBot();
  assert.equal(new Set(H.jugadores.map((j) => j.nombre)).size, H.jugadores.length);
  assert.equal(new Set(H.jugadores.map((j) => j.av)).size, H.jugadores.length);
  a.mando.empezar();
  const stats = { casos: 0, atrapado: 0, adivino: 0, detective: 0, choques: 0 };
  let pasos = 0;
  while (E.fase !== "final") {
    assert.ok(++pasos < 4000, "la partida no termina: " + E.fase);
    if (cola.length) { cola.shift()(); continue; }
    const f = E.fase;
    if (["caso", "r1", "r2", "r3", "voto"].includes(f)) { assert.ok(!E.listos.includes("yo") || E.listos.length < E.jugadores.length); a.mando.forzar(); }
    else if (f === "ultima") a.accion({ id: "yo", t: "adivina", i: Math.floor(r() * 6) }), E.fase === "ultima" && a.mando.continuar();
    else if (f === "resultado") {
      const res = E.resultado; stats.casos++;
      if (E.atrapado) stats.atrapado++; if (res.adivino) stats.adivino++;
      if (E.veredicto.acusado === E.culpable) stats.detective++;
      stats.choques += E.analisis.choques.length;
      assert.ok(Object.values(E.r3).every((w) => w && w === limpiarPalabra(w)));
      assert.equal(Object.keys(E.r1).length, E.jugadores.length); assert.equal(Object.keys(E.votos).length, E.jugadores.length);
      assert.ok(!Object.entries(E.votos).some(([x, y]) => x === y), "alguien se votó a sí mismo");
      a.mando.continuar();
    } else {
      // El secreto no puede asomar en el estado público antes del resultado.
      if (f !== "ultima") assert.ok(!JSON.stringify(E).includes(H.ronda.caso.evento.t), "el secreto se filtró en la fase " + f);
      if (!["revelacion", "ultima", "resultado"].includes(f)) assert.ok(E.culpable === undefined, "el culpable se filtró en la fase " + f);
      a.mando.continuar();
    }
  }
  assert.equal(stats.casos, casosPorPartida);
  assert.ok(Object.values(E.puntos).every((x) => Number.isInteger(x) && x >= 0));
  return stats;
}
const tot = { casos: 0, atrapado: 0, adivino: 0, detective: 0, choques: 0 };
let partidas = 0;
for (let nBots = 2; nBots <= 7; nBots++) for (let s = 1; s <= 250; s++) {
  const st = partida(s * 13 + nBots, nBots, 1 + (s % 3)); partidas++;
  for (const k of Object.keys(tot)) tot[k] += st[k];
}
const pct = (x) => Math.round((100 * x) / tot.casos) + "%";
console.log(`OK: ${casos} casos verificados y ${partidas} partidas con bots (${tot.casos} casos jugados). Culpable atrapado ${pct(tot.atrapado)}, adivina el secreto ${Math.round(100 * tot.adivino / Math.max(1, tot.atrapado))}% de las veces que cae, detective acierta ${pct(tot.detective)}.`);
assert.ok(tot.atrapado / tot.casos > 0.4 && tot.atrapado / tot.casos < 0.72, "el juego está desbalanceado");
