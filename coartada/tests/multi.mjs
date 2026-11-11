// Partidas en sala con varios «teléfonos» (pestañas aisladas) contra un servidor MQTT local.
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const { Aedes } = require("aedes");
const { WebSocketServer, createWebSocketStream } = require("ws");

const here = path.dirname(fileURLToPath(import.meta.url));
const url = "file://" + path.join(here, "../www/index.html");
const shots = process.env.SHOTS || "";
if (shots) fs.mkdirSync(shots, { recursive: true });

// Servidor MQTT local sobre WebSocket
const aedes = await Aedes.createBroker();
const http = createServer();
new WebSocketServer({ server: http }).on("connection", (ws) => aedes.handle(createWebSocketStream(ws)));
await new Promise((r) => http.listen(0, r));
const servidor = "ws://localhost:" + http.address().port;

const browser = await chromium.launch();
const errores = [];
async function telefono(nombre) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 800 }, hasTouch: true });
  // Ojo: un script de inicio que escriba en localStorage hace que Chromium pierda datos al recargar.
  await ctx.addInitScript((s) => { window.__coartadaServidores = [s]; }, servidor);
  const page = await ctx.newPage();
  page.on("pageerror", (e) => errores.push(nombre + ": " + e));
  page.on("console", (m) => { if (m.type() === "error" && !/ERR_CONNECTION|WebSocket/.test(m.text())) errores.push(nombre + ": " + m.text()); });
  return { ctx, page, nombre };
}
let nf = 0;
const foto = async (t, n) => { if (shots) await t.page.screenshot({ path: path.join(shots, "m" + String(++nf).padStart(2, "0") + "-" + n + ".png") }); };
const fase = (t) => t.page.evaluate(() => { const e = window.__coartadaEstado(); return e.S.multi && e.S.multi.E ? e.S.multi.E.fase : null; });
const volcado = async (todos) => { for (const x of todos) { try { console.log("VOLCADO", x.nombre, x.id, JSON.stringify(await x.page.evaluate(() => { const e = window.__coartadaEstado(), m = e.S.multi; return { pantalla: e.pantalla, rol: m && m.rol, fase: m && m.E && m.E.fase, rev: m && m.E && m.E.rev, revelado: m && m.E && m.E.revelado, conteo: m && m.E && m.E.conteo, votos: m && m.H && m.H.ronda && m.H.ronda.votos, culp: m && m.H && m.H.ronda && m.H.ronda.culpable, faseH: m && m.H && m.H.fase, banda: (document.querySelector(".banda") || {}).textContent }; }))); } catch (e) { console.log("VOLCADO", x.nombre, "error", String(e).slice(0, 80)); } } };
let grupo = [];
const espFase = (t, f) => t.page.waitForFunction((f) => { const e = window.__coartadaEstado(); return e.pantalla === "multi" && e.S.multi && e.S.multi.E && e.S.multi.E.fase === f; }, f, { timeout: 15000 }).catch(async (err) => { console.log("FALLO esperando", f, "en", t.nombre); await volcado(grupo); throw err; });
const multi = (t) => t.page.evaluate(() => window.__coartadaEstado().S.multi);
const clic = (t, a) => t.page.click(`[data-a="${a}"]`);

async function crear(t) {
  await t.page.goto(url);
  await clic(t, "salaCrear"); await t.page.fill("#miNombre", t.nombre); await clic(t, "mCrear");
  await espFase(t, "sala");
  return (await multi(t)).sala;
}
async function unir(t, codigo, porEnlace) {
  await t.page.goto(porEnlace ? url + "?sala=" + codigo.toLowerCase() : url);
  if (!porEnlace) { await clic(t, "salaUnirse"); await t.page.fill("#codigo", codigo); }
  else if ((await t.page.inputValue("#codigo")) !== codigo) throw new Error("el enlace no rellenó el código");
  await t.page.fill("#miNombre", t.nombre); await clic(t, "mUnirse");
  await espFase(t, "sala");
}
async function verCartas(todos) {
  const info = {};
  for (const t of todos) {
    await espFase(t, "caso");
    await t.page.waitForFunction(() => { const m = window.__coartadaEstado().S.multi; return m.P && m.P.numCaso === m.E.numCaso; });
    await clic(t, "mCarta");
    const box = await t.page.locator("#mCartaCaja").boundingBox();
    await t.page.mouse.move(box.x + 60, box.y + 60); await t.page.mouse.down(); await t.page.waitForTimeout(120);
    const sello = await t.page.locator("#mCartaCaja .carta-frente .sello").textContent();
    if (!info.foto) { info.foto = true; await foto(t, "carta"); }
    await t.page.mouse.up();
    const P = (await multi(t)).P;
    if ((sello === "CULPABLE") !== P.culpable) throw new Error("la carta mostrada no coincide");
    if (P.culpable) { if (info.culpable) throw new Error("dos culpables"); info.culpable = t; } else { info.evento = info.evento || P.carta.evento; if (info.evento !== P.carta.evento) throw new Error("datos secretos distintos"); }
    await clic(t, "mCerrarCarta"); await clic(t, "mListo");
  }
  if (!info.culpable) throw new Error("nadie es culpable");
  return info;
}
async function interrogar(todos, turnos, conTexto) {
  for (let q = 0; q < turnos; q++) {
    await espFase(todos[0], "interrogatorio");
    await todos[0].page.waitForFunction((q) => { const E = window.__coartadaEstado().S.multi.E; return E.fase === "interrogatorio" && (E.int.ronda - 1) * E.int.n + E.int.idx === q; }, q, { timeout: 15000 });
    const E = (await multi(todos[0])).E;
    const t = todos.find((x) => x.id === E.int.turno);
    await t.page.waitForSelector('[data-a="mRespondi"]');
    for (const o of todos) if (o !== t && (await o.page.locator('[data-a="mRespondi"]').count())) throw new Error("dos jugadores con el turno");
    if (conTexto) { await t.page.fill("#mTexto", "respuesta de " + t.nombre); if (q === 0) await foto(t, "turno-ia"); }
    else if (q === 0) { await foto(t, "turno"); await foto(todos.find((x) => x !== t), "turno-otro"); }
    await clic(t, "mRespondi");
  }
}
async function votar(todos, culpable, alCulpable) {
  for (const t of todos) {
    await espFase(t, "voto");
    const objetivo = alCulpable && t !== culpable ? culpable : todos.find((x) => x !== t && x !== culpable);
    await t.page.click(`.sospechoso[data-id="${objetivo.id}"]`);
    if (t === todos[1]) await foto(t, "voto");
    await clic(t, "mVotar");
  }
}

// ---------- Partida clásica con 4 teléfonos ----------
{
  const [a, b, c, d] = await Promise.all(["Jere", "Caro", "Luis", "Mafe"].map(telefono));
  const todos = [a, b, c, d]; grupo = todos;
  const codigo = await crear(a);
  if (!/^[A-HJ-NP-Z]{5}$/.test(codigo)) throw new Error("código raro: " + codigo);
  await unir(b, codigo, true); await unir(c, codigo, false); await unir(d, codigo, false);
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.jugadores.length === 4);
  for (const t of todos) t.id = (await multi(t)).id;
  // Un quinto con el mismo nombre entra, se renombra y el anfitrión lo saca.
  const e = await telefono("Caro");
  await unir(e, codigo, false);
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.jugadores.length === 5);
  if ((await multi(e)).nombre !== "Caro 2") throw new Error("no renombró el duplicado");
  await a.page.click(`[data-a="mExpulsar"][data-id="${(await multi(e)).id}"]`);
  await e.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio" && !window.__coartadaEstado().S.multi);
  await a.page.click('[data-a="mCfg"][data-k="casos"][data-d="-1"]');
  await b.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.cfg.casos === 2);
  await foto(a, "sala-anfitrion"); await foto(b, "sala-invitado");
  await clic(a, "mEmpezar");

  for (let caso = 1; caso <= 2; caso++) {
    await espFase(b, "caso");
    if (caso === 1) await foto(b, "caso");
    const { culpable, evento } = await verCartas(todos);
    // Entrar con la partida empezada no se puede.
    if (caso === 1) { await e.page.goto(url); await clic(e, "salaUnirse"); await e.page.fill("#codigo", codigo); await e.page.fill("#miNombre", "Colado"); await clic(e, "mUnirse"); await e.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio", null, { timeout: 15000 }); }
    await interrogar(todos, 8, false);
    await espFase(a, "careo"); await espFase(d, "careo");
    await d.page.waitForFunction(() => /^[01]:\d\d$/.test(document.querySelector("#mCrono").textContent) && document.querySelector("#mCrono").textContent !== "2:00");
    if (caso === 1) await foto(d, "careo");
    // Un invitado recarga la página en mitad de la partida y vuelve solo.
    if (caso === 1) { await c.page.goto(url); await espFase(c, "careo"); if ((await multi(c)).id !== c.id) throw new Error("perdió su identidad al recargar"); }
    await clic(a, "mAVotar");
    await votar(todos, culpable, caso === 1);
    await espFase(b, "revelacion"); if (caso === 1) await foto(b, "votos");
    await clic(a, "mRevelar");
    if (caso === 1) {
      for (const t of todos) await espFase(t, "ultima");
      await foto(culpable, "ultima-culpable"); await foto(todos.find((x) => x !== culpable), "ultima-otros");
      const ops = (await multi(culpable)).E.opciones;
      // El anfitrión recarga justo ahora: la sala debe seguir.
      await a.page.goto(url);
      await espFase(a, "ultima");
      await culpable.page.click(`[data-a="mAdivinar"][data-i="${ops.indexOf(evento)}"]`);
      for (const t of todos) await espFase(t, "resultado");
      const E = (await multi(d)).E;
      for (const t of todos) if (E.puntos[t.id] !== 2) throw new Error("puntos caso 1: " + JSON.stringify(E.puntos));
      await foto(d, "resultado");
    } else {
      for (const t of todos) await espFase(t, "revelacion");
      await b.page.waitForSelector(".revela");
      await clic(a, "mCerrar");
      for (const t of todos) await espFase(t, "resultado");
      const E = (await multi(b)).E;
      if (E.puntos[culpable.id] !== 2 + 4) throw new Error("el culpable que escapa debía sumar 4");
    }
    await clic(a, "mSiguiente");
  }
  for (const t of todos) await espFase(t, "final");
  await b.page.waitForTimeout(400); await foto(b, "final");
  await clic(a, "mRevancha");
  for (const t of todos) await espFase(t, "sala");
  await clic(a, "mSalir");
  for (const t of [b, c, d]) await t.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio" && !window.__coartadaEstado().S.multi, null, { timeout: 15000 });
  for (const t of [...todos, e]) await t.ctx.close();
}

// ---------- Detective IA en sala (API simulada solo en el anfitrión) ----------
{
  const [a, b, c] = await Promise.all(["Ana", "Beto", "Caro"].map(telefono));
  const todos = [a, b, c]; grupo = todos;
  const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "*" };
  let llamadas = 0;
  for (const t of [b, c]) await t.page.route("https://api.groq.com/**", () => { throw new Error("un invitado llamó a la IA"); });
  await a.page.route("https://api.groq.com/**", async (route) => {
    const req = route.request();
    if (req.method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
    const body = JSON.parse(req.postData()), sys = body.messages[0].content, usr = body.messages[1].content;
    llamadas++;
    let out;
    if (sys.includes('"lugares"')) out = { titulo: "El caso del flan robado", relato: "Alguien se comió el flan en la cocina.", lugar_crimen: "la cocina", hora: "10 de la noche", pistas: ["Una cuchara tibia."],
      lugares: ["el patio", "la sala", "el balcón", "el baño", "la terraza"].map((n) => ({ nombre: n, actividades: ["regando matas", "bailando solo"] })),
      coartada_falsa: { lugar: "el garaje", actividad: "buscando una llave" }, evento_secreto: "tembló la tierra un segundo", eventos_falsos: ["llovió", "cantó un gallo", "se fue la luz", "pasó un tren", "ladró un perro"], verdad: "Se comió el flan." };
    else if (sys.includes('"preguntas"')) { if (!usr.includes("respuesta de Beto")) throw new Error("el detective no recibió las respuestas"); out = { preguntas: ["Ana", "Beto", "Caro"].map((j) => ({ jugador: j, pregunta: "PREGUNTA-IA para " + j })) }; }
    else out = { informe: "Algo no me cuadra.", contradicciones: ["Beto dudó."], acusado: "Beto", frase_final: "Fuiste tú, Beto." };
    await route.fulfill({ status: 200, contentType: "application/json", headers: cors, body: JSON.stringify({ choices: [{ finish_reason: "stop", message: { role: "assistant", content: JSON.stringify(out) } }] }) });
  });
  await a.page.goto(url);
  await clic(a, "ajustes"); await a.page.fill("#apiKey", "gsk_prueba"); await clic(a, "guardarAjustes"); await a.page.click(".atras");
  await clic(a, "salaCrear"); await a.page.fill("#miNombre", "Ana"); await clic(a, "mCrear"); await espFase(a, "sala");
  const codigo = (await multi(a)).sala;
  await unir(b, codigo, true); await unir(c, codigo, true);
  for (const t of todos) t.id = (await multi(t)).id;
  await a.page.click('[data-a="mModo"][data-v="ia"]');
  await a.page.fill("#mAmb", "asado en casa de Jere"); await a.page.locator("#mAmb").blur();
  await a.page.click('[data-a="mCfg"][data-k="casos"][data-d="-1"]'); await a.page.click('[data-a="mCfg"][data-k="casos"][data-d="-1"]');
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.jugadores.length === 3 && window.__coartadaEstado().S.multi.E.cfg.casos === 1);
  await clic(a, "mEmpezar");
  const { culpable } = await verCartas(todos);
  if ((await multi(b)).E.caso.titulo !== "El caso del flan robado") throw new Error("no usó el caso de la IA");
  await interrogar(todos, 6, true);
  await espFase(a, "careo");
  if (!(await multi(a)).H.ronda.entradas.some((x) => x.respuesta.startsWith("respuesta de ") && x.pregunta.startsWith("PREGUNTA-IA"))) throw new Error("no se usaron las preguntas de la IA");
  await clic(a, "mAVotar");
  await votar(todos, culpable, false);
  for (const t of todos) await espFase(t, "veredicto");
  await c.page.waitForSelector(".acusacion"); await foto(c, "veredicto");
  await clic(a, "mARevelacion"); await espFase(a, "revelacion"); await clic(a, "mRevelar");
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.revelado === true);
  await clic(a, "mCerrar");
  for (const t of todos) await espFase(t, "resultado");
  const E = (await multi(c)).E;
  const esperado = 4 + (culpable.nombre !== "Beto" ? 1 : 0);
  if (E.puntos[culpable.id] !== esperado) throw new Error("puntos IA: " + E.puntos[culpable.id] + " != " + esperado);
  if (llamadas !== 3) throw new Error("se esperaban 3 llamadas a la IA, hubo " + llamadas);
  for (const t of todos) await t.ctx.close();
}

await browser.close();
await new Promise((r) => aedes.close(r)); http.close();
if (errores.length) { console.error("Errores en consola:\n" + errores.join("\n")); process.exit(1); }
console.log("OK: sala clásica con 4 teléfonos (2 casos, recargas, expulsión) y sala con Detective IA, sin errores.");
process.exit(0);
