// Salas con varios «teléfonos» (pestañas aisladas) y un bot, contra un servidor MQTT local.
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

const aedes = await Aedes.createBroker();
const http = createServer();
new WebSocketServer({ server: http }).on("connection", (ws) => aedes.handle(createWebSocketStream(ws)));
await new Promise((r) => http.listen(0, r));
const servidor = "ws://localhost:" + http.address().port;

const browser = await chromium.launch();
const errores = [];
let grupo = [];
async function telefono(nombre) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
  // Ojo: un script de inicio que escriba en localStorage hace que Chromium pierda datos al recargar.
  await ctx.addInitScript((s) => { window.__coartadaServidores = [s]; }, servidor);
  const page = await ctx.newPage();
  page.on("pageerror", (e) => errores.push(nombre + ": " + e));
  page.on("console", (m) => { if (m.type() === "error" && !/ERR_CONNECTION|WebSocket/.test(m.text())) errores.push(nombre + ": " + m.text()); });
  await page.goto(url);
  await page.click('[data-a="inicio"]'); // cierra la ayuda del estreno
  return { ctx, page, nombre };
}
let nf = 0;
const foto = async (t, n) => { if (shots) { await t.page.waitForTimeout(900); await t.page.screenshot({ path: path.join(shots, "s" + String(++nf).padStart(2, "0") + "-" + n + ".png") }); } };
const multi = (t) => t.page.evaluate(() => window.__coartadaEstado().S.multi);
const volcado = async () => { for (const x of grupo) { try { console.log("VOLCADO", x.nombre, JSON.stringify(await x.page.evaluate(() => { const e = window.__coartadaEstado(), m = e.S.multi; return { pantalla: e.pantalla, fase: m && m.E && m.E.fase, rev: m && m.E && m.E.rev, listos: m && m.E && m.E.listos, P: !!(m && m.P), banda: (document.querySelector(".banda") || {}).textContent }; }))); } catch (e) { console.log("VOLCADO", x.nombre, String(e).slice(0, 80)); } } };
const espFase = (t, f) => t.page.waitForFunction((f) => { const e = window.__coartadaEstado(); return e.pantalla === "juego" && e.S.multi && e.S.multi.E && [].concat(f).includes(e.S.multi.E.fase); }, f, { timeout: 15000 }).catch(async (err) => { console.log("FALLO esperando", f, "en", t.nombre); await volcado(); throw err; });
const clic = (t, a) => t.page.click(`[data-a="${a}"]`);

async function unir(t, codigo, porEnlace) {
  if (porEnlace) { await t.page.goto(url + "?sala=" + codigo.toLowerCase()); if ((await t.page.inputValue("#codigo")) !== codigo) throw new Error("el enlace no rellenó el código"); }
  else { await clic(t, "salaUnirse"); await t.page.fill("#codigo", codigo); }
  await t.page.fill("#miNombre", t.nombre); await clic(t, "eUnirse");
  await espFase(t, "sala");
}
/** Cada humano juega la fase actual desde su teléfono. */
async function jugarFase(humanos, fase, n) {
  for (const t of humanos) {
    await espFase(t, fase);
    await t.page.waitForFunction(() => { const m = window.__coartadaEstado().S.multi; return m.P && m.P.numCaso === m.E.numCaso; });
    const m = await multi(t);
    if (fase === "caso") { await clic(t, "jGirar"); await t.page.waitForTimeout(650); await clic(t, "jListo"); }
    else if (fase === "r1") {
      if (m.P.culpable) { await t.page.click(`[data-a="jR1Set"][data-k="lugar"][data-v="${m.P.seguro}"]`); await t.page.click(`[data-a="jR1Set"][data-k="vio"][data-v=""]`); }
      await clic(t, "jR1");
    } else if (fase === "r2") { await t.page.locator(".opcion").nth(n % 4).click(); await clic(t, "jR2"); }
    else if (fase === "r3") { await t.page.fill("#jPalabra", "raro"); await clic(t, "jR3"); }
    else if (fase === "voto") { await t.page.locator("button.fila").nth(n % 2).click(); await clic(t, "jVotar"); }
  }
}

{
  const [a, b, c] = await Promise.all(["Jere", "Caro", "Luis"].map(telefono));
  const humanos = [a, b, c]; grupo = humanos;
  await clic(a, "salaCrear"); await a.page.fill("#miNombre", "Jere"); await clic(a, "eCrear"); await espFase(a, "sala");
  const codigo = (await multi(a)).sala;
  if (!/^[A-HJ-NP-Z]{5}$/.test(codigo)) throw new Error("código raro: " + codigo);
  await unir(b, codigo, true); await unir(c, codigo, false);
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.jugadores.length === 3);
  for (const t of humanos) t.id = (await multi(t)).id;
  // Un cuarto con nombre repetido entra, se renombra y el anfitrión lo saca. Luego se añade un bot.
  const e = await telefono("Caro"); grupo = [...humanos, e];
  await unir(e, codigo, false);
  await a.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.jugadores.length === 4);
  if ((await multi(e)).nombre !== "Caro 2") throw new Error("no renombró el duplicado");
  await a.page.click(`[data-a="jQuitar"][data-id="${(await multi(e)).id}"]`);
  await e.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio" && !window.__coartadaEstado().S.multi);
  grupo = humanos;
  await clic(a, "jBot");
  await b.page.waitForFunction(() => { const E = window.__coartadaEstado().S.multi.E; return E.jugadores.length === 4 && E.jugadores.filter((j) => j.bot).length === 1; });
  await a.page.click('[data-a="jCfg"][data-d="-1"]');
  await c.page.waitForFunction(() => window.__coartadaEstado().S.multi.E.cfg.casos === 2);
  await foto(a, "sala-anfitrion"); await foto(b, "sala-invitado");
  await clic(a, "jEmpezar");

  for (let caso = 1; caso <= 2; caso++) {
    await jugarFase(humanos, "caso", caso);
    if (caso === 1) { // entrar con la partida empezada no se puede
      await clic(e, "salaUnirse"); await e.page.fill("#codigo", codigo); await e.page.fill("#miNombre", "Colado"); await clic(e, "eUnirse");
      await e.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio", null, { timeout: 15000 });
    }
    await jugarFase(humanos, "r1", caso);
    for (const t of humanos) await espFase(t, "r1v");
    if (caso === 1) await foto(b, "r1v");
    // Las cartas privadas no viajan en el estado público.
    const E1 = (await multi(b)).E;
    if (JSON.stringify(E1).includes('"evento"') || E1.culpable !== undefined) throw new Error("el estado público filtra secretos");
    // Un invitado recarga la página en mitad de la partida y vuelve solo.
    if (caso === 1) { await c.page.goto(url); await espFase(c, "r1v"); if ((await multi(c)).id !== c.id) throw new Error("perdió su identidad al recargar"); }
    await clic(a, "jSeguir");
    await jugarFase(humanos, "r2", caso);
    for (const t of humanos) await espFase(t, "r2v");
    await clic(a, "jSeguir");
    // En la ronda 3, uno no responde y el anfitrión sigue sin esperarlo.
    await jugarFase(caso === 1 ? [a, b] : humanos, "r3", caso);
    if (caso === 1) { await a.page.waitForSelector('[data-a="jForzar"]'); await clic(a, "jForzar"); }
    for (const t of humanos) await espFase(t, "r3v");
    await clic(a, "jSeguir");
    for (const t of humanos) await espFase(t, "careo");
    await b.page.waitForFunction(() => /^[01]:\d\d$/.test(document.querySelector("#jCrono").textContent) && document.querySelector("#jCrono").textContent !== "1:30");
    if (caso === 1) await foto(b, "careo");
    // El anfitrión recarga: la sala debe seguir.
    if (caso === 1) { await a.page.goto(url); await espFase(a, "careo"); }
    await clic(a, "jSeguir");
    await jugarFase(humanos, "voto", caso);
    for (const t of humanos) await espFase(t, "veredicto");
    await clic(a, "jSeguir");
    for (const t of humanos) await espFase(t, "revelacion");
    await clic(a, "jRevelar");
    await a.page.waitForFunction(() => { const E = window.__coartadaEstado().S.multi.E; return E.fase !== "revelacion" || E.revelado; });
    let E = (await multi(a)).E;
    if (E.fase === "revelacion") await clic(a, "jSeguir");
    else if (E.fase === "ultima") {
      const culp = humanos.find((t) => t.id === E.culpable);
      if (culp) { await espFase(culp, "ultima"); await foto(culp, "ultima"); await culp.page.locator('[data-a="jAdivinar"]').first().click(); }
    }
    for (const t of humanos) await espFase(t, "resultado");
    E = (await multi(c)).E;
    const suma = Object.values(E.resultado.puntos).reduce((x, y) => x + y, 0);
    if (!(suma > 0) || Object.keys(E.puntos).length !== 4) throw new Error("marcador raro: " + JSON.stringify(E.puntos));
    for (const t of humanos) { const mio = (await multi(t)).E.puntos; if (JSON.stringify(mio) !== JSON.stringify(E.puntos)) throw new Error("marcadores distintos entre teléfonos"); }
    if (caso === 1) await foto(c, "resultado");
    await clic(a, "jSeguir");
  }
  for (const t of humanos) await espFase(t, "final");
  await foto(b, "final");
  await clic(a, "jSeguir"); // revancha
  for (const t of humanos) await espFase(t, "sala");
  await clic(a, "jSalir");
  for (const t of [b, c]) await t.page.waitForFunction(() => window.__coartadaEstado().pantalla === "inicio" && !window.__coartadaEstado().S.multi, null, { timeout: 15000 });
  for (const t of [...humanos, e]) await t.ctx.close();
}

await browser.close();
await new Promise((r) => aedes.close(r)); http.close();
if (errores.length) { console.error("Errores en consola:\n" + [...new Set(errores)].join("\n")); process.exit(1); }
console.log("OK: sala con 3 teléfonos y un bot (2 casos, recargas, expulsión, jugador ausente), sin errores.");
process.exit(0);
