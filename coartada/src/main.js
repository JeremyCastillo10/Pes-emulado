// Arranque de la app: estado guardado, pantallas de inicio, ayuda y ajustes, y utilidades compartidas.
import { instalarJuego } from "./juego.js";
import { crearAudio } from "./audio.js";
import { MODELOS, MODELO_POR_DEFECTO, probarConexion, listarModelos } from "./ai.js";

const CLAVE = "coartada.v3";
// Dirección pública del juego: se usa en el enlace de invitación a una sala.
const URL_WEB = "https://coartada-delta.vercel.app";
const VERSION = "3.0";

const S = {
  cfg: { apiKey: "", modelo: MODELO_POR_DEFECTO, modelos: [], musica: true, sonido: true },
  prefs: { casos: 3, bots: 4, modo: "clasico", escenario: "azar", ambientacion: "", tono: "absurdo" },
  multi: null, miNombre: "", vioAyuda: false,
};
let pantalla = "inicio";
let ui = {};

function cargar() {
  try {
    const d = JSON.parse(localStorage.getItem(CLAVE) || "null");
    if (!d) return;
    Object.assign(S, d, { cfg: { ...S.cfg, ...(d.cfg || {}) }, prefs: { ...S.prefs, ...(d.prefs || {}) } });
  } catch (e) { /* sin almacenamiento: se juega sin guardar */ }
}
function guardar() {
  try { localStorage.setItem(CLAVE, JSON.stringify(S)); } catch (e) { /* idem */ }
}

// ---------- Utilidades ----------
const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const vibrar = (ms) => { try { navigator.vibrate && navigator.vibrate(ms); } catch (e) { /* sin vibración */ } };
let tictac = null;
function pararReloj() { if (tictac) { clearInterval(tictac); tictac = null; } }
function ponerReloj(fn, ms) { pararReloj(); tictac = setInterval(fn, ms); }
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg; t.classList.add("ver");
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove("ver"), 3800);
}
function modal(html, clase = "") { $("#modal").innerHTML = `<div class="modal-caja ${clase}">${html}</div>`; $("#modal").classList.add("ver"); }
function cerrarModal() { $("#modal").classList.remove("ver"); $("#modal").innerHTML = ""; }
function confeti() {
  const fx = $("#fx"), colores = ["#ffd23f", "#ff4d6d", "#3ddc97", "#4cc9f0", "#c77dff", "#ffffff"];
  let html = "";
  for (let i = 0; i < 70; i++) html += `<i style="left:${Math.random() * 100}%; background:${colores[i % colores.length]}; --d:${(Math.random() * 0.8).toFixed(2)}s; --t:${(2 + Math.random() * 1.6).toFixed(2)}s; --x:${Math.round(Math.random() * 160 - 80)}px; --g:${Math.round(Math.random() * 720)}deg; width:${6 + Math.round(Math.random() * 8)}px"></i>`;
  fx.innerHTML = html;
  clearTimeout(confeti.t); confeti.t = setTimeout(() => { fx.innerHTML = ""; }, 4200);
}
const audio = crearAudio(() => S.cfg);
const EFECTOS = {}; // efectos por pantalla, tras pintar

function ir(p, datos = {}) {
  pararReloj();
  pantalla = p; ui = datos;
  guardar();
  pintar(true);
  window.scrollTo(0, 0);
}

// ---------- Pantallas ----------
const V = {};
const A = {};
const altavoz = () => `<button class="redondo" data-a="sonido" aria-label="Sonido">${S.cfg.musica || S.cfg.sonido ? "🔊" : "🔇"}</button>`;

V.inicio = () => `
  <section class="portada">
    <div class="portada-top">${altavoz()}</div>
    <div class="cinta"><span>NO PASAR · ESCENA DEL CRIMEN · NO PASAR · ESCENA DEL CRIMEN · NO PASAR · ESCENA DEL CRIMEN · </span></div>
    <div class="logo sube"><span class="lupa-logo">🔍</span><h1>COARTADA</h1><p>Uno de ustedes lo hizo.<br>Todos juran que no.</p></div>
    <div class="pila">
      ${S.multi ? `<button class="boton verde sube" data-a="salaVolver">▶ Volver a ${S.multi.H && S.multi.H.local ? "la partida" : "la sala " + esc(S.multi.sala)}</button>` : ""}
      <button class="boton sube" style="--i:1" data-a="jugarBots">🤖 Jugar con bots</button>
      <button class="boton rosa sube" style="--i:2" data-a="salaCrear">🎉 Crear sala con amigos</button>
      <button class="boton azul sube" style="--i:3" data-a="salaUnirse">🔑 Unirme con un código</button>
      <div class="fila sube" style="--i:4"><button class="boton fantasma" data-a="como">❓ Cómo se juega</button><button class="boton fantasma" data-a="ajustes">⚙️ Ajustes</button></div>
    </div>
    <p class="pie">3 a 8 jugadores · cada quien en su teléfono · v${VERSION}</p>
  </section>`;

const PASOS = [
  ["🎭", "Uno es el culpable", "El juego lo elige en secreto. Los demás son inocentes."],
  ["🤫", "Los inocentes saben un secreto", "Algo que pasó esa noche (por ejemplo, «se fue la luz»). El culpable no lo sabe."],
  ["📍", "Ronda 1 · Coartadas", "Cada quien declara dónde estaba y a quién vio. Los inocentes dicen la verdad; el culpable inventa. Si dos versiones chocan, salta a la vista."],
  ["❓", "Ronda 2 · La pregunta", "Una pregunta sobre «eso» que pasó. Quien no lo vivió tiene que adivinar."],
  ["✍️", "Ronda 3 · Palabra clave", "Una palabra que insinúe el secreto sin decirlo. Muy obvia y el culpable lo adivina; muy rara y sospechan de ti."],
  ["🗳️", "Voten al culpable", "Con todas las pruebas en el tablero. Si lo atrapan, aún puede salvar puntos adivinando el secreto."],
];
V.como = () => `
  <header class="cab"><button class="redondo" data-a="inicio" aria-label="Volver">‹</button><h2>Cómo se juega</h2>${altavoz()}</header>
  <div class="pasos">${PASOS.map(([e, t, d], i) => `<article class="paso sube" style="--i:${i}"><span>${e}</span><div><b>${t}</b><p>${d}</p></div></article>`).join("")}</div>
  <section class="tarjeta sube" style="--i:7">
    <h3>Puntos</h3>
    <ul class="motivos">
      <li>😈 Culpable que escapa: <b>+4</b></li>
      <li>😇 Inocente que votó al culpable: <b>+2</b> si cayó, <b>+1</b> si escapó</li>
      <li>🤫 Culpable atrapado que adivina el secreto: <b>+2</b></li>
      <li>🕵️ Si el detective acusa a un inocente: <b>+1</b> para el culpable</li>
    </ul>
  </section>
  <div class="dock"><button class="boton" data-a="${ui.primera ? "jugarBots" : "inicio"}">${ui.primera ? "¡Probar con bots!" : "Entendido"}</button></div>`;

V.ajustes = () => {
  const lista = (S.cfg.modelos && S.cfg.modelos.length ? S.cfg.modelos : MODELOS).slice();
  if (!lista.some((m) => m.id === S.cfg.modelo)) lista.unshift({ id: S.cfg.modelo, nombre: S.cfg.modelo });
  return `
  <header class="cab"><button class="redondo" data-a="inicio" aria-label="Volver">‹</button><h2>Ajustes</h2></header>
  <section class="tarjeta sube">
    <h3>Sonido</h3>
    <div class="ajuste"><span>🎵 Música</span><button class="interruptor ${S.cfg.musica ? "on" : ""}" data-a="aMusica" aria-pressed="${S.cfg.musica}"><i></i></button></div>
    <div class="ajuste"><span>🔔 Efectos</span><button class="interruptor ${S.cfg.sonido ? "on" : ""}" data-a="aSonido" aria-pressed="${S.cfg.sonido}"><i></i></button></div>
  </section>
  <section class="tarjeta sube" style="--i:1">
    <h3>Casos con IA <small>opcional</small></h3>
    <p class="nota">Con tu clave de Groq, la IA inventa casos nuevos según dónde estén. Sin clave, el juego usa su archivo de casos. La clave se guarda solo en este teléfono.</p>
    <label class="campo"><span>Clave de API de Groq</span>
      <input id="apiKey" type="password" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="gsk_…" value="${esc(S.cfg.apiKey)}"></label>
    <label class="campo"><span>Modelo</span>
      <select id="modelo">${lista.map((m) => `<option value="${esc(m.id)}" ${S.cfg.modelo === m.id ? "selected" : ""}>${esc(m.nombre)}</option>`).join("")}</select></label>
    <div class="fila"><button class="boton chico" data-a="guardarAjustes">Guardar</button><button class="boton chico fantasma" data-a="probar">Probar conexión</button></div>
    <p id="pruebaRes" class="nota"></p>
    <p class="nota">La clave se crea en console.groq.com, sección «API Keys».</p>
  </section>
  <section class="tarjeta sube" style="--i:2">
    <h3>Partida guardada</h3>
    <button class="boton chico fantasma" data-a="borrarPartida" ${S.multi ? "" : "disabled"}>Borrar la partida en curso</button>
  </section>`;
};

// ---------- Pintado ----------
function pintar(estreno = false) {
  const app = $("#app");
  app.innerHTML = (V[pantalla] || V.inicio)();
  app.dataset.p = pantalla;
  if (pantalla !== "juego") { app.classList.toggle("anim", estreno); audio.musica("menu"); }
  if (EFECTOS[pantalla]) EFECTOS[pantalla]();
}

// ---------- Acciones ----------
Object.assign(A, {
  inicio: () => ir("inicio"),
  como: () => ir("como"),
  ajustes: () => ir("ajustes"),
  cerrarModal: () => cerrarModal(),
  sonido: () => { const v = !(S.cfg.musica || S.cfg.sonido); S.cfg.musica = S.cfg.sonido = v; guardar(); audio.desbloquear(); audio.refrescar(); pintar(); },
  aMusica: () => { S.cfg.musica = !S.cfg.musica; guardar(); audio.refrescar(); pintar(); },
  aSonido: () => { S.cfg.sonido = !S.cfg.sonido; guardar(); pintar(); },
  guardarAjustes: () => { S.cfg.apiKey = $("#apiKey").value.trim(); S.cfg.modelo = $("#modelo").value; guardar(); toast("Ajustes guardados."); },
  probar: async () => {
    A.guardarAjustes();
    $("#pruebaRes").textContent = "Llamando al detective…";
    let msg;
    try {
      const modelos = await listarModelos({ apiKey: S.cfg.apiKey });
      if (modelos.length) { S.cfg.modelos = modelos; if (!modelos.some((m) => m.id === S.cfg.modelo)) S.cfg.modelo = modelos[0].id; guardar(); }
      msg = "Conectado. El detective dice: «" + (await probarConexion({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo })) + "»";
    } catch (e) { msg = "No funcionó: " + e.message; }
    if (pantalla === "ajustes") { pintar(); $("#pruebaRes").textContent = msg; }
  },
  borrarPartida: () => { juego.desconectar(); S.multi = null; ir("ajustes"); toast("Partida borrada."); },
});

cargar();
const juego = instalarJuego({
  S, guardar, ir, pintar, esc, cap, toast, modal, cerrarModal, vibrar, audio, confeti, V, A, EFECTOS, pararReloj, ponerReloj,
  pantalla: () => pantalla, ui: () => ui, URL_WEB: location.protocol.startsWith("http") ? location.origin : URL_WEB,
});

document.addEventListener("click", (e) => {
  const b = e.target.closest("[data-a]");
  if (!b || b.disabled) return;
  audio.desbloquear();
  const fn = A[b.dataset.a];
  if (!fn) return;
  if (b.matches(".boton, .redondo, .pastilla, .silla, .interruptor, .contador button, .segmento button")) audio.sfx("toque");
  fn(b.dataset, b);
});
document.addEventListener("pointerdown", () => audio.desbloquear(), { once: true });
$("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") cerrarModal(); });

// Botón «atrás» de Android. Devuelve true si la app lo manejó.
window.__coartadaAtras = () => {
  if ($("#modal").classList.contains("ver")) { cerrarModal(); return true; }
  if (pantalla === "inicio") return false;
  if (pantalla === "juego") { A.jSalir(); return true; }
  A.inicio(); return true;
};
// Para las pruebas automáticas.
window.__coartadaEstado = () => ({ pantalla, ui, S });

const salaEnlace = (new URLSearchParams(location.search).get("sala") || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 5);
if (salaEnlace.length === 5 && !(S.multi && S.multi.sala === salaEnlace)) { pantalla = "entrar"; ui = { modo: "unirse", codigo: salaEnlace }; }
else if (S.multi) { juego.reanudar(); pantalla = "juego"; }
else if (!S.vioAyuda) { S.vioAyuda = true; guardar(); pantalla = "como"; ui = { primera: true }; }
pintar(true);
