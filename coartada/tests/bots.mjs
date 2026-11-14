// Juega partidas completas contra bots en un navegador sin cabeza, tocando la interfaz como un jugador.
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
const { chromium } = createRequire(import.meta.url)("playwright");
const here = path.dirname(fileURLToPath(import.meta.url));
const url = "file://" + path.join(here, "../www/index.html");
const shots = process.env.SHOTS || "";
if (shots) fs.mkdirSync(shots, { recursive: true });
const browser = await chromium.launch();
const errores = [];
let nf = 0;
const vistas = new Set();
async function foto(page, nombre, unaVez = true) { if (!shots || (unaVez && vistas.has(nombre))) return; vistas.add(nombre); await page.waitForTimeout(900); await page.screenshot({ path: path.join(shots, String(++nf).padStart(2, "0") + "-" + nombre + ".png") }); }
const est = (page) => page.evaluate(() => { const e = window.__coartadaEstado(), m = e.S.multi; return { pantalla: e.pantalla, fase: m && m.E && m.E.fase, E: m && m.E, P: m && m.P, id: m && m.id, H: m && m.H }; });
const clic = (page, a) => page.click(`[data-a="${a}"]`);

async function partida({ nombre, bots, casos, semilla }) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => errores.push(String(e)));
  page.on("console", (m) => { if (m.type() === "error") errores.push(m.text()); });
  await page.goto(url);
  // La primera vez se abre la ayuda.
  if ((await est(page)).pantalla !== "como") throw new Error("no mostró la ayuda al estrenar");
  await foto(page, "ayuda");
  await clic(page, "jugarBots");
  await page.fill("#miNombre", nombre);
  for (let i = 4; i < bots; i++) await clic(page, "eBots");
  for (let i = 4; i > bots; i--) await page.click('[data-a="eBots"][data-d="-1"]');
  for (let i = 3; i > casos; i--) await page.click('[data-a="eCasos"][data-d="-1"]');
  if ((await page.inputValue("#miNombre")) !== nombre) throw new Error("se perdió el nombre al ajustar");
  await foto(page, "entrar");
  await clic(page, "ePracticar");
  const roles = { culpable: 0, inocente: 0 };
  let caso = 0, guard = 0;
  for (;;) {
    if (++guard > 400) throw new Error("la partida no avanza: " + (await est(page)).fase);
    const s = await est(page), f = s.fase, E = s.E;
    if (f === "final") break;
    const listo = E.listos && E.listos.includes(s.id);
    if (f === "cargando" || (!s.P && ["caso", "r1", "r2", "r3"].includes(f))) { await page.waitForTimeout(100); continue; }
    if (f === "caso") {
      if (listo) { await page.waitForTimeout(150); continue; }
      if (await page.locator('[data-a="jListo"]').isEnabled()) throw new Error("se puede seguir sin ver la carta");
      await foto(page, "caso");
      await clic(page, "jGirar"); await page.waitForTimeout(750);
      const rol = s.P.culpable ? "culpable" : "inocente"; roles[rol]++; caso++;
      const txt = await page.locator(".carta .rol b").innerText();
      if ((rol === "culpable") !== /CULPABLE/.test(txt)) throw new Error("carta equivocada");
      await foto(page, "carta-" + rol);
      await clic(page, "jListo");
    } else if (f === "r1") {
      if (listo) { await page.waitForTimeout(150); continue; }
      if (s.P.culpable) {
        if (await page.locator('[data-a="jR1"]').isEnabled()) throw new Error("declarar sin elegir");
        await foto(page, "r1-culpable");
        const usarSeguro = (caso + semilla) % 2 === 0;
        const lugar = usarSeguro ? s.P.seguro : E.caso.lugares.findIndex((_, i) => i !== E.caso.lugar_crimen && i !== s.P.seguro);
        await page.click(`[data-a="jR1Set"][data-k="lugar"][data-v="${lugar}"]`);
        await page.click(`[data-a="jR1Set"][data-k="vio"][data-v="${s.P.pista.id}"]`);
        await page.click(`[data-a="jR1Set"][data-k="vioLugar"][data-v="${usarSeguro ? s.P.pista.lugar : E.caso.lugar_crimen}"]`);
        await foto(page, "r1-culpable-listo");
      } else await foto(page, "r1-inocente");
      await clic(page, "jR1");
    } else if (f === "r2") {
      if (listo) { await page.waitForTimeout(150); continue; }
      await foto(page, "r2");
      await page.locator(".opcion").nth((caso + semilla) % 4).click();
      await clic(page, "jR2");
    } else if (f === "r3") {
      if (listo) { await page.waitForTimeout(150); continue; }
      if (!s.P.culpable) {
        // Una palabra del propio secreto debe quedar bloqueada.
        const prohibida = s.P.evento.t.split(" ").find((w) => w.length >= 5);
        await page.fill("#jPalabra", prohibida);
        if (await page.locator('[data-a="jR3"]').isEnabled()) throw new Error("dejó enviar una palabra del secreto: " + prohibida);
        await foto(page, "r3-bloqueada");
      }
      await page.fill("#jPalabra", "Misterio total");
      await foto(page, "r3");
      await clic(page, "jR3");
    } else if (["r1v", "r2v", "r3v"].includes(f)) {
      await page.waitForTimeout(1900); await foto(page, f);
      if (f === "r1v" && E.analisis.choques.length) await foto(page, "r1v-choque");
      if (f === "r3v" && E.r3[s.id] !== "misterio") throw new Error("palabra mal guardada: " + E.r3[s.id]);
      await clic(page, "jSeguir");
    } else if (f === "voto") {
      if (listo) { await page.waitForTimeout(150); continue; }
      await page.locator("button.fila").first().click();
      await foto(page, "voto");
      await clic(page, "jVotar");
    } else if (f === "veredicto") {
      await page.waitForTimeout(1600); await foto(page, "veredicto"); await clic(page, "jSeguir");
    } else if (f === "revelacion") {
      if (!E.revelado) { await page.waitForTimeout(900); await foto(page, "votos"); await clic(page, "jRevelar"); await page.waitForFunction(() => { const E = window.__coartadaEstado().S.multi.E; return E.fase !== "revelacion" || E.revelado; }); }
      else { await page.waitForTimeout(1000); await foto(page, "escapo"); await clic(page, "jSeguir"); }
    } else if (f === "ultima") {
      await page.waitForTimeout(700);
      if (E.culpable === s.id) { await foto(page, "ultima-yo"); await page.locator('[data-a="jAdivinar"]').nth(2).click(); }
      else { await foto(page, "ultima-bot"); await page.waitForFunction(() => window.__coartadaEstado().S.multi.E.fase !== "ultima", null, { timeout: 15000 }); }
    } else if (f === "resultado") {
      await page.waitForTimeout(700); await foto(page, "resultado");
      // Recargar a mitad de partida no debe perder nada.
      if (caso === 1) { await page.reload(); if ((await est(page)).fase !== "resultado") throw new Error("no reanudó tras recargar"); }
      await clic(page, "jSeguir");
    } else if (f === "careo") throw new Error("con un solo humano no debe haber debate");
    else throw new Error("fase inesperada " + f);
  }
  await page.waitForTimeout(900); await foto(page, "final");
  const fin = await est(page);
  if (Object.keys(fin.E.puntos).length !== bots + 1) throw new Error("marcador incompleto");
  await clic(page, "jSeguir"); // revancha: vuelve a la mesa
  await page.waitForFunction(() => window.__coartadaEstado().S.multi.E.fase === "sala");
  await foto(page, "mesa");
  await clic(page, "jSalir");
  if ((await est(page)).pantalla !== "inicio") throw new Error("no volvió al inicio");
  await foto(page, "inicio");
  await ctx.close();
  return roles;
}

const total = { culpable: 0, inocente: 0 };
const N = Number(process.env.PARTIDAS || 6);
for (let i = 0; i < N; i++) {
  const r = await partida({ nombre: "Jere", bots: 2 + (i % 5), casos: i === 0 ? 3 : 2, semilla: i });
  total.culpable += r.culpable; total.inocente += r.inocente;
}
await browser.close();
if (errores.length) { console.error("Errores en consola:\n" + [...new Set(errores)].join("\n")); process.exit(1); }
console.log(`OK: ${N} partidas contra bots en la interfaz (${total.inocente} casos como inocente, ${total.culpable} como culpable), sin errores.`);
