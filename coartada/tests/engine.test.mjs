// Pruebas del motor: genera miles de casos y comprueba que sean coherentes.
import assert from "node:assert/strict";
import { generarCasoLocal, validarCaso, preguntasLocales, puntuar, contarVotos, opcionesEvento, rng } from "../src/engine.js";

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
        if (c.visto.includes("contigo") && c.visto.split(" estaba")[0].split(" y ").includes(o.jugador)) assert.equal(o.lugar, c.lugar);
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
console.log(`OK: ${casos} casos generados y verificados, puntuación correcta.`);
