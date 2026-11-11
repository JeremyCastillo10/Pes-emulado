// Juega partidas completas en un navegador sin cabeza: modo Clásico y Detective IA (con la API simulada).
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright"); // usa el Playwright global si no está en el proyecto
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
const here = path.dirname(fileURLToPath(import.meta.url));
const url = "file://" + path.join(here, "../www/index.html");
const shots = process.env.SHOTS || "";
if (shots) fs.mkdirSync(shots, { recursive: true });
const browser = await chromium.launch();
const errores = [];
async function nueva() {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 800 }, deviceScaleFactor: 1, hasTouch: true });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => errores.push(String(e)));
  page.on("console", (m) => { if (m.type() === "error") errores.push(m.text()); });
  return { ctx, page };
}
let n = 0;
const foto = async (page, nombre) => { if (shots) await page.screenshot({ path: path.join(shots, String(++n).padStart(2, "0") + "-" + nombre + ".png") }); };
const fijo = (page) => page.locator(".btn-fijo");
const pantalla = (page) => page.locator("#app").getAttribute("data-p");
const estado = (page) => page.evaluate(() => JSON.parse(localStorage.getItem("coartada.v1")));

async function configurar(page, nombres) {
  await page.click('[data-a="config"]');
  for (let i = 3; i < nombres.length; i++) await page.click('[data-a="agregar"]');
  for (let i = 0; i < nombres.length; i++) await page.locator("input.nombre").nth(i).fill(nombres[i]);
}
async function repartir(page, nombres, tag) {
  await fijo(page).click(); // repartir
  for (let i = 0; i < nombres.length; i++) {
    if (i === 0) await foto(page, tag + "-pase");
    await fijo(page).click(); // soy yo
    if (!(await fijo(page).isDisabled())) throw new Error("se puede saltar la carta sin verla");
    const box = await page.locator("#carta").boundingBox();
    await page.mouse.move(box.x + 50, box.y + 50); await page.mouse.down();
    await page.waitForTimeout(160);
    const s = await estado(page);
    const culp = s.partida.ronda.culpable === nombres[i];
    if (culp || (i < 2 && tag)) await foto(page, tag + (culp ? "-carta-culpable" : "-carta-inocente"));
    const txt = await page.locator(".carta-frente .sello").textContent();
    if (culp !== /CULPABLE/.test(txt)) throw new Error("carta equivocada para " + nombres[i] + " txt=" + txt + " culpable=" + s.partida.ronda.culpable + " reparto=" + s.partida.ronda.reparto + " caso=" + s.partida.numCaso + " modo=" + s.partida.modo + " dorso=" + (await page.locator(".carta-dorso small").textContent()) + " jugadores=" + s.partida.jugadores + " :: " + (await page.locator(".carta-frente").innerText()).slice(0, 160));
    await page.mouse.up();
    await fijo(page).click();
  }
}
async function votar(page, nombres, culpable, todosAlCulpable) {
  await fijo(page).click(); // a votar
  for (const j of nombres) {
    await fijo(page).click();
    const objetivo = todosAlCulpable ? (j === culpable ? nombres.find((x) => x !== j) : culpable) : nombres.find((x) => x !== j && x !== culpable) || nombres.find((x) => x !== j);
    await page.click(`.sospechoso[data-v="${objetivo}"]`);
    await fijo(page).click();
  }
}

// ---------- Partida clásica: 5 jugadores, 2 casos ----------
{
  const { ctx, page } = await nueva();
  await page.goto(url);
  await foto(page, "inicio");
  await page.click('[data-a="reglas"]'); await foto(page, "reglas"); await page.click(".atras");
  const N = ["Jere", "Caro", "Luis", "Mafe", "Tito"];
  await configurar(page, N);
  await page.click('[data-a="menos"][data-k="casos"]'); // 2 casos
  await foto(page, "config");
  await fijo(page).click();
  for (let caso = 1; caso <= 2; caso++) {
    if ((await pantalla(page)) !== "caso") throw new Error("no llegó al caso");
    await foto(page, "caso" + caso);
    await repartir(page, N, caso === 1 ? "c1" : "");
    for (let q = 0; q < N.length * 2; q++) {
      if ((await pantalla(page)) !== "interrogatorio") throw new Error("no está en interrogatorio");
      if (q === 0 || q === N.length) await foto(page, "pregunta");
      await fijo(page).click();
    }
    if ((await pantalla(page)) !== "careo") throw new Error("no llegó al careo");
    await page.click("#cronoBtn"); await page.waitForTimeout(1200);
    if ((await page.locator("#crono").innerText()) === "2:00") throw new Error("el cronómetro no corre");
    await foto(page, "careo");
    const culpable = (await estado(page)).partida.ronda.culpable;
    await votar(page, N, culpable, caso === 1);
    await foto(page, "votos");
    await fijo(page).click(); await page.waitForTimeout(500); await foto(page, "revelado");
    if (caso === 1) {
      await fijo(page).click(); // última jugada
      await foto(page, "ultima");
      const s = await estado(page);
      const i = s.partida.ronda.opciones.indexOf(s.partida.ronda.caso.evento_secreto);
      await page.click(`[data-a="adivinar"][data-i="${i}"]`);
      await fijo(page).click();
      const s2 = await estado(page);
      if (s2.partida.puntos[culpable] !== 2) throw new Error("puntos del culpable atrapado que adivina: " + s2.partida.puntos[culpable]);
      if (N.filter((j) => j !== culpable).some((j) => s2.partida.puntos[j] !== 2)) throw new Error("puntos de inocentes incorrectos");
      await foto(page, "resultado");
      // Cerrar y reabrir: la partida debe poder continuarse.
      await page.reload(); await page.click('[data-a="continuar"]');
      if ((await pantalla(page)) !== "resultado") throw new Error("no reanudó en resultado");
    } else {
      await fijo(page).click();
      const s2 = await estado(page);
      if (s2.partida.ronda.resultado.atrapado) throw new Error("no debía ser atrapado");
    }
    await fijo(page).click();
  }
  if ((await pantalla(page)) !== "final") throw new Error("no llegó al final");
  await page.waitForTimeout(500); await foto(page, "final");
  await page.click('[data-a="terminar"]');
  await ctx.close();
}

// ---------- Detective IA con la API simulada ----------
{
  const { ctx, page } = await nueva();
  const N = ["Ana", "Beto", "Caro"];
  const llamadas = [];
  const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "*" };
  await page.route("https://api.groq.com/**", async (route) => {
    const req = route.request();
    if (req.method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    if (req.url().endsWith("/models")) return route.fulfill({ status: 200, contentType: "application/json", headers: cors, body: JSON.stringify({ data: [{ id: "openai/gpt-oss-120b", active: true, context_window: 131072 }, { id: "whisper-large-v3", active: true, context_window: 448 }] }) });
    const body = JSON.parse(req.postData());
    llamadas.push({ url: req.url(), body, headers: req.headers() });
    const sys = body.messages[0].content, usr = body.messages[1].content;
    let out;
    if (sys.includes('"saludo"')) out = { saludo: "Buenas noches" };
    else if (sys.includes('"lugares"')) {
      const culp = /Culpable de este caso: (\w+)/.exec(usr)[1];
      out = { titulo: "El caso del flan robado", relato: "Alguien se comió el flan en la cocina.", lugar_crimen: "La cocina.", hora: "10 de la noche", pistas: ["Una cuchara tibia."],
        lugares: ["el patio", "la sala", "el balcón", "el baño", "la terraza", "el garaje", "la cocina"].map((n) => ({ nombre: n, actividades: ["regando matas", "bailando solo"] })),
        coartada_falsa: { lugar: "el garaje", actividad: "buscando una llave" }, evento_secreto: "Esa noche tembló la tierra un segundo.", eventos_falsos: ["llovió", "cantó un gallo", "se fue la luz", "pasó un tren", "ladró un perro"], verdad: culp + " se comió el flan." };
    } else if (sys.includes('"preguntas"')) out = { preguntas: N.map((j, i) => ({ jugador: j, pregunta: i === 0 ? "¿Dónde estabas cuando tembló la tierra?" : "PREGUNTA-IA para " + j })) };
    else out = { informe: "Algo no me cuadra.", contradicciones: ["Beto dudó.", "Nadie sintió que la tierra tembló."], acusado: "Beto", frase_final: "Fuiste tú, Beto." };
    await route.fulfill({ status: 200, contentType: "application/json", headers: cors,
      body: JSON.stringify({ id: "c1", object: "chat.completion", model: body.model, choices: [{ index: 0, finish_reason: "stop", message: { role: "assistant", content: JSON.stringify(out) } }] }) });
  });
  await page.goto(url);
  await page.click('[data-a="ajustes"]');
  await page.fill("#apiKey", "gsk_prueba");
  await page.click('[data-a="probar"]');
  await page.waitForFunction(() => document.querySelector("#pruebaRes").textContent.includes("Conectado"));
  await foto(page, "ajustes");
  await page.click(".atras");
  await configurar(page, N);
  await page.click('[data-a="modo"][data-v="ia"]');
  await page.fill("#ambientacion", "asado en casa de Jere");
  await page.click('[data-a="menos"][data-k="casos"]'); await page.click('[data-a="menos"][data-k="casos"]');
  await foto(page, "config-ia");
  await fijo(page).click();
  await page.waitForFunction(() => document.querySelector("#app").dataset.p === "caso");
  if (!(await page.locator(".titular").innerText()).includes("flan")) throw new Error("no usó el caso de la IA");
  await repartir(page, N, "");
  const caso = (await estado(page)).partida.ronda.caso;
  if (caso.evento_secreto !== "tembló la tierra un segundo") throw new Error("evento sin limpiar: " + caso.evento_secreto);
  if (caso.lugar_crimen !== "la cocina" || caso.cartas.some((c) => ["la cocina", "el garaje"].includes(c.lugar))) throw new Error("lugares mal repartidos");
  let iaVistas = 0, filtradas = 0;
  for (let q = 0; q < 6; q++) {
    await page.waitForFunction(() => document.querySelector("#app").dataset.p === "interrogatorio");
    const txt = await page.locator(".pregunta").innerText();
    if (txt.includes("tembló")) throw new Error("una pregunta delató el dato secreto");
    if (q >= 3) { if (txt.includes("PREGUNTA-IA")) iaVistas++; else filtradas++; }
    await page.fill("#respuesta", "respuesta " + q);
    if (q === 4) await foto(page, "pregunta-ia");
    await fijo(page).click();
  }
  if (iaVistas !== 2 || filtradas !== 1) throw new Error("ronda 2: se esperaban 2 preguntas de la IA y 1 sustituida, hubo " + iaVistas + " y " + filtradas);
  await page.waitForFunction(() => document.querySelector("#app").dataset.p === "careo");
  const culpable = (await estado(page)).partida.ronda.culpable;
  await votar(page, N, culpable, false);
  await page.waitForSelector('[data-a="acusar"]');
  await fijo(page).click(); await page.waitForTimeout(500); await foto(page, "veredicto-ia");
  await fijo(page).click(); await fijo(page).click(); await fijo(page).click();
  const s = await estado(page);
  const esperado = 4 + (culpable !== "Beto" ? 1 : 0);
  if (s.partida.puntos[culpable] !== esperado) throw new Error("puntos IA: " + s.partida.puntos[culpable] + " != " + esperado);
  if (s.partida.ronda.veredicto.contradicciones.length !== 1) throw new Error("no se filtró la contradicción que delataba el secreto");
  // Forma de las peticiones
  if (llamadas.length !== 4) throw new Error("se esperaban 4 llamadas, hubo " + llamadas.length);
  for (const l of llamadas) {
    if (!l.url.endsWith("/openai/v1/chat/completions")) throw new Error("ruta inesperada " + l.url);
    if (l.body.model !== "openai/gpt-oss-120b") throw new Error("modelo inesperado");
    if (l.headers["authorization"] !== "Bearer gsk_prueba") throw new Error("falta la clave");
    if (l.body.response_format.type !== "json_object") throw new Error("falta el modo JSON");
  }
  const det = llamadas[2].body.messages[1].content;
  if (!det.includes("respuesta 0")) throw new Error("el detective no recibió las respuestas");
  if (/Culpable de este caso/.test(det) || /coartada falsa/i.test(det)) throw new Error("se le filtró el culpable al detective");
  await ctx.close();
}
await browser.close();
if (errores.length) { console.error("Errores en consola:\n" + errores.join("\n")); process.exit(1); }
console.log("OK: partida clásica (5 jugadores, 2 casos) y partida con Detective IA simulada, sin errores.");
