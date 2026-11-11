// Pruebas del motor: genera miles de casos y comprueba que sean coherentes.
import assert from "node:assert/strict";
import { generarCasoLocal, validarCaso, preguntasLocales, puntuar, contarVotos, opcionesEvento, rng, armarCasoIA, delataEvento, limpiarEvento, limpiarActividad } from "../src/engine.js";

const NOMBRES = ["Ana", "Beto", "Caro", "Dani", "Eli", "Fede", "Gabi", "Hugo", "Iris", "Juan"];
let casos = 0;
for (let n = 3; n <= 10; n++) {
  for (let seed = 1; seed <= 400; seed++) {
    const r = rng(seed * 31 + n);
    const jugadores = NOMBRES.slice(0, n);
    const culpable = jugadores[seed % n];
    const caso = validarCaso(generarCasoLocal({ jugadores, culpable, random: r }), jugadores, culpable);
    casos++;
    assert.equal(caso.cartas.length, n - 1);
    assert.ok(!caso.cartas.some((c) => c.jugador === culpable), "el culpable no tiene carta de inocente");
    assert.ok(!/\{\w+\}/.test(JSON.stringify(caso)), "quedó una variable sin rellenar");
    assert.ok(!/\b(de|a) el\b/i.test(caso.relato + caso.verdad), "falta una contracción: " + caso.relato);
    const lugares = new Set(caso.cartas.map((c) => c.lugar));
    assert.ok(!lugares.has(caso.lugar_crimen), "un inocente en el lugar del crimen");
    assert.ok(!lugares.has(caso.coartada_falsa.lugar), "un inocente en el lugar de la coartada falsa");
    assert.equal(caso.eventos_falsos.length, 5);
    assert.ok(!caso.eventos_falsos.includes(caso.evento_secreto));
    // Lo que cada uno vio tiene que ser verdad en las cartas de los demás.
    for (const c of caso.cartas) {
      for (const o of caso.cartas) {
        if (o === c) continue;
        if (c.visto.includes(o.jugador + " caminando hacia")) assert.ok(c.visto.includes(o.lugar), `${c.jugador} vio mal a ${o.jugador}`);
        if (c.visto.includes("contigo") && c.visto.split(" estaba")[0].split(" y ").includes(o.jugador)) { assert.equal(o.lugar, c.lugar); assert.notEqual(o.actividad, c.actividad, "misma actividad en pareja"); }
      }
      assert.ok(!c.visto.includes(culpable), "nadie ve al culpable en su carta");
    }
    assert.equal(caso.cartas.filter((c) => c.extra).length, n - 1 >= 4 ? 1 : 0);
    const ops = opcionesEvento(caso, r);
    assert.equal(new Set(ops).size, 6);
    for (let ronda = 1; ronda <= 3; ronda++) {
      const q = preguntasLocales({ ronda, jugadores, caso, random: r });
      for (const j of jugadores) { assert.ok(q[j] && !/\{\w+\}/.test(q[j])); assert.ok(!q[j].includes(caso.evento_secreto)); }
    }
  }
}
// Puntuación
const J = ["A", "B", "C", "D"];
let p = puntuar({ jugadores: J, culpable: "A", votos: { A: "B", B: "A", C: "A", D: "B" } });
assert.equal(p.atrapado, false); assert.equal(p.empate, true); assert.deepEqual(p.puntos, { A: 4, B: 1, C: 1, D: 0 });
p = puntuar({ jugadores: J, culpable: "A", votos: { A: "B", B: "A", C: "A", D: "A" }, adivinoEvento: true, acusadoIA: "C" });
assert.equal(p.atrapado, true); assert.deepEqual(p.puntos, { A: 3, B: 2, C: 2, D: 2 });
p = puntuar({ jugadores: J, culpable: "A", votos: { A: "B", B: "C", C: "B", D: "B" }, acusadoIA: "A" });
assert.equal(p.acusado, "B"); assert.deepEqual(p.puntos, { A: 4, B: 0, C: 0, D: 0 });
assert.equal(contarVotos({}, J).acusado, null);
assert.throws(() => validarCaso({ titulo: "x" }, J, "A"));
// Filtro del dato secreto
assert.ok(delataEvento("¿Dónde estabas cuando la parrilla se apagó un segundo?", "se apagó la parrilla por un segundo"));
assert.ok(delataEvento("Nadie sintió que la tierra tembló", "tembló la tierra un segundo"));
assert.ok(!delataEvento("¿Qué hiciste cuando pasó «eso» que todos recuerdan?", "se apagó la parrilla por un segundo"));
assert.ok(!delataEvento("¿Quién puede confirmar que estabas en el garaje?", "el ventilador se apagó y se escuchó un ladrido de perro"));
assert.equal(limpiarEvento("Esa noche, Se fue la luz."), "se fue la luz");
assert.equal(limpiarActividad("Estabas en el garaje, Reparando tu coche."), "reparando tu coche");
assert.equal(limpiarActividad("bailando solo"), "bailando solo");
// Casos de la IA: el motor reparte y rechaza material defectuoso
const mat = () => ({ titulo: "T", relato: "Pasó algo en la cocina.", lugar_crimen: "La cocina.", hora: "10", pistas: ["p"], evento_secreto: "Esa noche ladró un perro enorme.",
  eventos_falsos: ["a1 cosa", "b2 cosa", "c3 cosa", "d4 cosa", "e5 cosa", "ladró un perro enorme"], coartada_falsa: { lugar: "El garaje. ", actividad: "durmiendo." },
  lugares: ["la cocina", "el garaje", "el patio", "El Patio", "la sala", "el baño", "la azotea", "el pasillo"].map((n) => ({ nombre: n, actividades: ["x"] })), verdad: "V" });
for (let n = 3; n <= 10; n++) {
  for (let sd = 1; sd <= 50; sd++) {
  const jug = NOMBRES.slice(0, n), c = armarCasoIA({ jugadores: jug, culpable: jug[0], material: mat(), random: rng(n * 100 + sd) });
  validarCaso(c, jug, jug[0]);
  assert.ok(!c.cartas.some((k) => ["la cocina", "el garaje"].includes(k.lugar)));
  assert.equal(c.evento_secreto, "ladró un perro enorme"); assert.equal(c.eventos_falsos.length, 5); assert.equal(c.lugar_crimen, "la cocina");
  }
}
assert.throws(() => armarCasoIA({ jugadores: J, culpable: "A", material: { ...mat(), lugares: [] } }));
assert.throws(() => armarCasoIA({ jugadores: J, culpable: "A", material: { ...mat(), eventos_falsos: ["x"] } }));
assert.throws(() => armarCasoIA({ jugadores: J, culpable: "A", material: { ...mat(), relato: "De pronto ladró un perro enorme." } }));
assert.throws(() => armarCasoIA({ jugadores: J, culpable: "A", material: null }));
console.log(`OK: ${casos} casos generados y verificados, puntuación correcta.`);
