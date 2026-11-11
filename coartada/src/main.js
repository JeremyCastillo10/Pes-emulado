import { ESCENARIOS } from "./content.js";
import { generarCasoLocal, armarCasoIA, preguntasLocales, contarVotos, puntuar, opcionesEvento, shuffle, pick } from "./engine.js";
import { instalarMulti } from "./multi.js";
import { MODELOS, MODELO_POR_DEFECTO, ErrorIA, probarConexion, listarModelos, generarCasoIA, preguntasIA, veredictoIA } from "./ai.js";

// ---------- Estado ----------
const CLAVE = "coartada.v1";
// Dirección pública del juego: se usa en el enlace de invitación a una sala.
const URL_WEB = "__URL_WEB__";
const MIN_J = 3, MAX_J = 10;
let S = { cfg: { apiKey: "", modelo: MODELO_POR_DEFECTO, modelos: [] }, nombres: ["", "", ""], prefs: { casos: 3, preguntas: 2, modo: "clasico", escenario: "azar", ambientacion: "", tono: "absurdo", reloj: true }, partida: null, multi: null, miNombre: "" };
let pantalla = "inicio";
let ui = {}; // estado efímero de la pantalla actual
let veredictoPendiente = null; // promesa en curso del veredicto IA

function cargar() {
  try {
    const d = JSON.parse(localStorage.getItem(CLAVE) || "null");
    if (d) S = { ...S, ...d, cfg: { ...S.cfg, ...(d.cfg || {}) }, prefs: { ...S.prefs, ...(d.prefs || {}) } };
  } catch (e) { /* almacenamiento no disponible: se juega sin guardar */ }
}
function guardar() {
  try { localStorage.setItem(CLAVE, JSON.stringify(S)); } catch (e) { /* idem */ }
}

// ---------- Utilidades ----------
const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const vibrar = (ms) => { try { navigator.vibrate && navigator.vibrate(ms); } catch (e) { /* sin vibración */ } };
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
let tictac = null;
function pararReloj() { if (tictac) { clearInterval(tictac); tictac = null; } }
function ponerReloj(fn, ms) { pararReloj(); tictac = setInterval(fn, ms); }
const EFECTOS = {}; // efectos extra por pantalla (los registra el modo de salas)
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg; t.classList.add("ver");
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove("ver"), 3600);
}
function modal(html) { $("#modal").innerHTML = `<div class="modal-caja">${html}</div>`; $("#modal").classList.add("ver"); }
function cerrarModal() { $("#modal").classList.remove("ver"); $("#modal").innerHTML = ""; }
function pitido() {
  try {
    const C = window.AudioContext || window.webkitAudioContext; if (!C) return;
    const ctx = pitido.ctx || (pitido.ctx = new C());
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = "square"; o.frequency.value = 660; g.gain.value = 0.06;
    o.connect(g); g.connect(ctx.destination); o.start(); o.stop(ctx.currentTime + 0.25);
  } catch (e) { /* sin audio */ }
}

const EN_JUEGO = new Set(["cargando", "caso", "reparto", "interrogatorio", "careo", "voto", "veredicto", "revelacion", "ultima", "resultado", "final"]);
function ir(p, datos = {}) {
  pararReloj();
  pantalla = p; ui = datos;
  if (S.partida && EN_JUEGO.has(p)) S.partida.pantalla = p;
  guardar();
  pintar();
  window.scrollTo(0, 0);
}
const P = () => S.partida;
const R = () => S.partida.ronda;

// ---------- Flujo de partida ----------
function nuevaPartida() {
  const jugadores = S.nombres.map((n) => n.trim()).filter(Boolean);
  S.partida = {
    jugadores, casos: S.prefs.casos, numCaso: 0, modo: S.prefs.modo, preguntasPorJugador: S.prefs.preguntas,
    escenario: S.prefs.escenario, ambientacion: S.prefs.ambientacion, tono: S.prefs.tono, reloj: S.prefs.reloj,
    puntos: Object.fromEntries(jugadores.map((j) => [j, 0])), usados: [], culpablesPrevios: [], ronda: null, pantalla: "caso",
  };
  prepararCaso();
}

async function prepararCaso() {
  const p = P();
  p.numCaso++;
  // Reparte la culpa: evita repetir culpable hasta que todos lo hayan sido.
  let candidatos = p.jugadores.filter((j) => !p.culpablesPrevios.includes(j));
  if (!candidatos.length) { p.culpablesPrevios = []; candidatos = p.jugadores.slice(); }
  const culpable = pick(Math.random, candidatos);
  p.culpablesPrevios.push(culpable);
  p.ronda = { culpable, caso: null, origen: "local", reparto: 0, entradas: [], rondaInt: 1, orden: [], idx: 0, votos: {}, votoIdx: 0, veredicto: null, errorVeredicto: null, adivino: null, opciones: null, resultado: null };
  veredictoPendiente = null;
  if (p.modo === "ia") {
    ir("cargando", { titulo: "El detective abre un nuevo expediente", frases: ["Revisando la escena…", "Entrevistando al portero…", "Fabricando coartadas…", "Escondiendo las pruebas…"] });
    try {
      const material = await generarCasoIA({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo, jugadores: p.jugadores, culpable, ambientacion: p.ambientacion, tono: p.tono, titulosUsados: p.usados });
      R().caso = armarCasoIA({ jugadores: p.jugadores, culpable, material });
      R().origen = "ia";
    } catch (e) {
      toast((e instanceof ErrorIA ? e.message : "El caso de la IA salió defectuoso.") + " Se usa un caso del archivo.");
    }
  }
  if (!R().caso) R().caso = generarCasoLocal({ jugadores: p.jugadores, culpable, escenarioId: p.escenario, usados: p.usados });
  p.usados.push(R().caso.titulo);
  ir("caso");
}

function empezarInterrogatorio() {
  const p = P(), r = R();
  r.rondaInt = 1; r.entradas = [];
  cargarRondaInt(preguntasLocales({ ronda: 1, jugadores: p.jugadores, caso: r.caso }));
  ir("interrogatorio");
}
function cargarRondaInt(preguntas) {
  const p = P(), r = R();
  r.orden = shuffle(Math.random, p.jugadores);
  r.idx = 0;
  r.preguntas = preguntas;
}
async function siguientePregunta(respuesta) {
  const p = P(), r = R();
  const jugador = r.orden[r.idx];
  r.entradas.push({ ronda: r.rondaInt, jugador, pregunta: r.preguntas[jugador], respuesta: respuesta || "" });
  r.idx++;
  if (r.idx < r.orden.length) return ir("interrogatorio");
  if (r.rondaInt >= p.preguntasPorJugador) return empezarCareo();
  r.rondaInt++;
  let preguntas = null;
  if (p.modo === "ia" && r.origen === "ia") {
    ir("cargando", { titulo: "El detective repasa sus notas", frases: ["Subrayando contradicciones…", "Afilando el lápiz…", "Mirando fijo a alguien…"] });
    try {
      preguntas = await preguntasIA({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo, caso: r.caso, jugadores: p.jugadores, entradas: r.entradas, ronda: r.rondaInt, ultima: r.rondaInt >= p.preguntasPorJugador });
    } catch (e) {
      toast((e instanceof ErrorIA ? e.message : "La IA falló.") + " Siguen las preguntas clásicas.");
    }
  }
  const locales = preguntasLocales({ ronda: r.rondaInt, jugadores: p.jugadores, caso: r.caso });
  cargarRondaInt({ ...locales, ...(preguntas || {}) });
  ir("interrogatorio");
}
function pedirVeredicto() {
  const p = P(), r = R();
  r.errorVeredicto = null;
  veredictoPendiente = veredictoIA({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo, caso: r.caso, jugadores: p.jugadores, entradas: r.entradas })
    .then((v) => { if (S.partida && S.partida.ronda === r) { r.veredicto = v; guardar(); } return v; })
    .catch((e) => { if (S.partida && S.partida.ronda === r) { r.errorVeredicto = e instanceof ErrorIA ? e.message : "La IA falló."; guardar(); } return null; });
  return veredictoPendiente;
}
function empezarCareo() {
  const p = P(), r = R();
  // El veredicto de la IA se pide ya, mientras el grupo discute, para no hacer esperar.
  if (p.modo === "ia" && r.origen === "ia" && !r.veredicto) pedirVeredicto();
  ir("careo");
}
function trasVotar() {
  const p = P(), r = R();
  if (p.modo === "ia" && r.origen === "ia") return ir("veredicto");
  ir("revelacion");
}
function cerrarRonda(adivino) {
  const p = P(), r = R();
  r.adivino = adivino;
  r.resultado = puntuar({ jugadores: p.jugadores, culpable: r.culpable, votos: r.votos, adivinoEvento: adivino === true, acusadoIA: r.veredicto ? r.veredicto.acusado : null });
  for (const j of p.jugadores) p.puntos[j] += r.resultado.puntos[j];
  ir("resultado");
}

// ---------- Pantallas ----------
const V = {};

V.inicio = () => `
  <section class="portada">
    <div class="cinta">ESCENA DEL CRIMEN · NO PASAR · ESCENA DEL CRIMEN · NO PASAR</div>
    <div class="logo">
      <span class="logo-sub">Expediente N.º 07</span>
      <h1>COARTADA</h1>
      <span class="sello sello-rojo">CONFIDENCIAL</span>
    </div>
    <p class="lema">Uno de ustedes lo hizo.<br>Todos juran que no.</p>
    <div class="pila">
      ${S.multi ? `<button class="btn btn-claro" data-a="salaVolver">Volver a la sala ${esc(S.multi.sala)}</button>` : ""}
      <button class="btn btn-rojo" data-a="salaCrear">Crear sala</button>
      <button class="btn btn-claro" data-a="salaUnirse">Unirme a una sala</button>
      <button class="btn btn-linea" data-a="${S.partida ? "continuar" : "config"}">${S.partida ? "Continuar en un solo teléfono" : "Jugar en un solo teléfono"}</button>
      ${S.partida ? `<button class="btn btn-linea" data-a="config">Nueva partida en un teléfono</button>` : ""}
      <div class="fila"><button class="btn btn-linea" data-a="reglas">Cómo se juega</button><button class="btn btn-linea" data-a="ajustes">Ajustes</button></div>
    </div>
    <p class="pie">3 a 10 jugadores · cada quien en su teléfono</p>
  </section>`;

V.reglas = () => `
  ${cabecera("Cómo se juega")}
  <article class="papel reglas">
    <h3>1. El caso</h3>
    <p>El teléfono presenta un «crimen» absurdo. Uno de ustedes es el <b>culpable</b>; los demás son <b>inocentes</b>.</p>
    <h3>2. Las cartas</h3>
    <p>Cada quien mira su carta en secreto en su teléfono (o pasándose uno solo). Los inocentes saben dónde estaban, a quién vieron y un <b>dato secreto</b>: algo que pasó esa noche y que el culpable no sabe.</p>
    <h3>3. El interrogatorio</h3>
    <p>El detective pregunta a cada jugador y se responde <b>en voz alta</b>. Los inocentes dicen la verdad de su carta; el culpable improvisa.</p>
    <p class="nota"><b>Regla de oro:</b> nadie puede decir el dato secreto de forma directa. Hablen de él con rodeos: así el culpable no puede copiarlo… y se nota quién no lo vivió.</p>
    <h3>4. Careo y votación</h3>
    <p>Discutan libremente y luego voten en secreto.</p>
    <h3>Salas</h3>
    <p>Uno crea la sala y comparte el código de 5 letras; los demás entran desde su teléfono con la app o con el enlace. El teléfono del anfitrión lleva la partida, así que debe mantener la app abierta. También se puede jugar sin internet pasándose un solo teléfono.</p>
    <h3>5. El final</h3>
    <p>Si el culpable es el más votado, cae. Pero tiene una última jugada: si adivina el dato secreto, rescata puntos.</p>
    <h3>Puntos</h3>
    <ul>
      <li>Culpable que escapa: <b>+4</b>.</li>
      <li>Inocente que votó al culpable: <b>+2</b> si cayó, <b>+1</b> si escapó.</li>
      <li>Culpable atrapado que adivina el dato secreto: <b>+2</b>.</li>
      <li>Con Detective IA: si la IA acusa a un inocente, <b>+1</b> para el culpable.</li>
    </ul>
    <h3>Detective IA</h3>
    <p>Con una clave de API, la IA inventa el caso a la medida del grupo, lee lo que responden, hace preguntas que cruzan las versiones y al final acusa a alguien. Sin clave, el juego funciona completo con casos del archivo.</p>
  </article>`;

V.ajustes = () => {
  const lista = (S.cfg.modelos && S.cfg.modelos.length ? S.cfg.modelos : MODELOS).slice();
  if (!lista.some((m) => m.id === S.cfg.modelo)) lista.unshift({ id: S.cfg.modelo, nombre: S.cfg.modelo });
  return `
  ${cabecera("Ajustes")}
  <article class="papel">
    <h3>Detective IA</h3>
    <p class="chico">Pega tu clave de la API de Groq. Se guarda solo en este teléfono y se usa únicamente para hablar con la IA. El uso se descuenta de tu cuenta de Groq.</p>
    <label class="campo"><span>Clave de API de Groq</span>
      <input id="apiKey" type="password" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="gsk_…" value="${esc(S.cfg.apiKey)}">
    </label>
    <label class="campo"><span>Modelo</span>
      <select id="modelo">${lista.map((m) => `<option value="${esc(m.id)}" ${S.cfg.modelo === m.id ? "selected" : ""}>${esc(m.nombre)}</option>`).join("")}</select>
    </label>
    <div class="fila">
      <button class="btn btn-rojo" data-a="guardarAjustes">Guardar</button>
      <button class="btn btn-linea" data-a="probar">Probar conexión</button>
    </div>
    <p id="pruebaRes" class="chico"></p>
    <p class="chico">La clave se crea en console.groq.com, sección «API Keys». Al probar la conexión se carga la lista de modelos de tu cuenta.</p>
  </article>
  <article class="papel">
    <h3>Partida guardada</h3>
    <p class="chico">Si cierras la app, la partida sigue donde la dejaste.</p>
    <button class="btn btn-linea" data-a="borrarPartida" ${S.partida ? "" : "disabled"}>Borrar partida en curso</button>
  </article>`;
};

V.config = () => {
  const n = S.nombres.length, pr = S.prefs, hayClave = !!S.cfg.apiKey;
  return `
  ${cabecera("Nueva partida")}
  <article class="papel">
    <h3>Sospechosos <span class="cuenta">${S.nombres.filter((x) => x.trim()).length}/${MAX_J}</span></h3>
    <div id="nombres">
      ${S.nombres.map((nom, i) => `
        <div class="nombre-fila">
          <span class="num">${i + 1}</span>
          <input class="nombre" data-i="${i}" maxlength="14" autocomplete="off" autocapitalize="words" placeholder="Nombre" value="${esc(nom)}">
          ${n > MIN_J ? `<button class="quitar" data-a="quitar" data-i="${i}" aria-label="Quitar">×</button>` : ""}
        </div>`).join("")}
    </div>
    ${n < MAX_J ? `<button class="btn btn-linea btn-chico" data-a="agregar">+ Agregar jugador</button>` : ""}
  </article>
  <article class="papel">
    <h3>Detective</h3>
    <div class="segmento">
      <button class="${pr.modo === "clasico" ? "on" : ""}" data-a="modo" data-v="clasico">Clásico<small>sin internet</small></button>
      <button class="${pr.modo === "ia" ? "on" : ""}" data-a="modo" data-v="ia">Detective IA<small>${hayClave ? "casos a la medida" : "requiere clave"}</small></button>
    </div>
    ${pr.modo === "ia" ? `
      <label class="campo"><span>¿Dónde están o de qué quieren el caso?</span>
        <input id="ambientacion" maxlength="120" placeholder="Ej.: asado en casa de Jere, viaje a la playa…" value="${esc(pr.ambientacion)}">
      </label>
      <label class="campo"><span>Tono</span>
        <select id="tono">
          <option value="absurdo" ${pr.tono === "absurdo" ? "selected" : ""}>Absurdo (para todos)</option>
          <option value="noir" ${pr.tono === "noir" ? "selected" : ""}>Novela negra</option>
          <option value="picante" ${pr.tono === "picante" ? "selected" : ""}>Picante (adultos)</option>
        </select>
      </label>
      <p class="chico">En este modo, quien responde escribe o dicta un resumen de su respuesta para que el detective la lea.</p>` : `
      <label class="campo"><span>Escenario</span>
        <select id="escenario">
          <option value="azar">Al azar</option>
          ${ESCENARIOS.map((e) => `<option value="${e.id}" ${pr.escenario === e.id ? "selected" : ""}>${e.emoji} ${esc(e.nombre)}</option>`).join("")}
        </select>
      </label>`}
  </article>
  <article class="papel">
    <h3>Partida</h3>
    <div class="ajuste"><span>Casos a resolver</span>${contador("casos", pr.casos, 1, 8)}</div>
    <div class="ajuste"><span>Preguntas por jugador</span>${contador("preguntas", pr.preguntas, 1, 3)}</div>
    <div class="ajuste"><span>Reloj en las respuestas</span>
      <button class="interruptor ${pr.reloj ? "on" : ""}" data-a="reloj" aria-pressed="${pr.reloj}"><i></i></button>
    </div>
  </article>
  <button class="btn btn-rojo btn-fijo" data-a="empezar">Abrir el primer caso</button>`;
};
const contador = (k, v, min, max) => `<div class="contador"><button data-a="menos" data-k="${k}" ${v <= min ? "disabled" : ""}>−</button><b>${v}</b><button data-a="mas" data-k="${k}" ${v >= max ? "disabled" : ""}>+</button></div>`;
const cabecera = (t) => `<header class="barra"><button class="atras" data-a="inicio" aria-label="Volver">‹</button><h2>${esc(t)}</h2></header>`;
const cabeceraJuego = (t) => `<header class="barra"><button class="atras" data-a="salir" aria-label="Salir">×</button><h2>${esc(t)}</h2><span class="chip">Caso ${P().numCaso}/${P().casos}</span></header>`;

V.cargando = () => `
  <section class="centro">
    <div class="lupa"><i></i></div>
    <h2>${esc(ui.titulo || "Un momento")}</h2>
    <p id="fraseCarga" class="maquina">${esc((ui.frases || ["…"])[0])}</p>
  </section>`;

V.caso = () => {
  const c = R().caso;
  return `
  ${cabeceraJuego("El caso")}
  <article class="papel expediente">
    <span class="sello sello-rojo sello-esq">${R().origen === "ia" ? "CASO IA" : "ARCHIVO"}</span>
    <p class="etiqueta">Expediente ${String(P().numCaso).padStart(3, "0")}</p>
    <h2 class="titular">${esc(c.titulo)}</h2>
    <p class="relato">${esc(c.relato)}</p>
    <dl class="ficha">
      <div><dt>Lugar</dt><dd>${esc(cap(c.lugar_crimen))}</dd></div>
      <div><dt>Hora</dt><dd>${esc(c.hora)}</dd></div>
    </dl>
    ${c.pistas.length ? `<h3>Pistas halladas</h3><ul class="pistas">${c.pistas.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>` : ""}
  </article>
  <p class="guia">Léanlo en voz alta. Después cada quien verá su carta en secreto.</p>
  <button class="btn btn-rojo btn-fijo" data-a="repartir">Repartir las cartas</button>`;
};

V.reparto = () => {
  const p = P(), r = R(), j = p.jugadores[r.reparto];
  if (!ui.paso) {
    return `
    ${cabeceraJuego("Cartas secretas")}
    <section class="centro pase">
      <p class="etiqueta">Pásale el teléfono a</p>
      <h1 class="nombre-grande">${esc(j)}</h1>
      <p class="guia">Que nadie más mire la pantalla.</p>
      <div class="puntos-paso">${p.jugadores.map((_, i) => `<i class="${i < r.reparto ? "hecho" : i === r.reparto ? "actual" : ""}"></i>`).join("")}</div>
    </section>
    <button class="btn btn-rojo btn-fijo" data-a="soyYo">Soy ${esc(j)}</button>`;
  }
  const esCulpable = j === r.culpable, c = r.caso;
  const carta = esCulpable ? `
      <span class="sello sello-rojo sello-grande">CULPABLE</span>
      <h2>Tú lo hiciste, ${esc(j)}.</h2>
      <p class="linea"><b>Tu coartada falsa (sugerida)</b>Di que estabas en ${esc(c.coartada_falsa.lugar)}, ${esc(c.coartada_falsa.actividad)}.</p>
      <p class="linea"><b>Lo que no sabes</b>Esa noche pasó algo que todos los inocentes notaron. Te preguntarán por «eso»: escucha a los demás y finge que también lo viviste.</p>
      <p class="linea"><b>Cómo ganas</b>Que voten a otra persona. Si te atrapan, aún puedes adivinar qué fue «eso».</p>` : (() => {
    const k = c.cartas.find((x) => x.jugador === j);
    return `
      <span class="sello sello-verde sello-grande">INOCENTE</span>
      <h2>${esc(j)}, esto es lo que viviste.</h2>
      <p class="linea"><b>Dónde estabas</b>En ${esc(k.lugar)}, ${esc(k.actividad)}.</p>
      <p class="linea"><b>Lo que viste</b>${esc(k.visto)}</p>
      ${k.extra ? `<p class="linea"><b>Dato extra</b>${esc(k.extra)}</p>` : ""}
      <p class="linea secreto"><b>Dato secreto · el culpable no lo sabe</b>Esa noche ${esc(c.evento_secreto)}.</p>
      <p class="chico">Di la verdad de tu carta. Nunca nombres el dato secreto de forma directa.</p>`;
  })();
  return `
    ${cabeceraJuego("Cartas secretas")}
    <section class="zona-carta">
      <div class="carta ${esCulpable ? "carta-culpable" : ""} ${ui.viendo ? "abierta" : ""}" id="carta">
        <div class="carta-dorso"><div class="huella"></div><p>Mantén presionado<br>para ver tu carta</p><small>${esc(j)}</small></div>
        <div class="carta-frente">${carta}</div>
      </div>
    </section>
    <button class="btn btn-rojo btn-fijo" data-a="cartaLista" ${ui.vista ? "" : "disabled"}>${ui.vista ? "Ya la memoricé" : "Primero mira tu carta"}</button>`;
};

V.interrogatorio = () => {
  const p = P(), r = R(), j = r.orden[r.idx], ia = p.modo === "ia" && r.origen === "ia";
  return `
  ${cabeceraJuego("Interrogatorio")}
  <div class="progreso"><span>Ronda ${r.rondaInt} de ${p.preguntasPorJugador}</span><span>${r.idx + 1}/${r.orden.length}</span></div>
  <div class="barra-prog"><i style="width:${((r.idx) / r.orden.length) * 100}%"></i></div>
  <section class="interroga">
    <p class="etiqueta">El detective interroga a</p>
    <h1 class="nombre-grande">${esc(j)}</h1>
    <blockquote class="pregunta">${esc(r.preguntas[j])}</blockquote>
    ${p.reloj ? `<div class="reloj" id="reloj"><i></i><b>45</b></div>` : ""}
    ${ia ? `<label class="campo"><span>Resumen de la respuesta (escribe o usa el micrófono del teclado)</span>
      <textarea id="respuesta" rows="3" maxlength="400" placeholder="Lo que respondió ${esc(j)}…"></textarea></label>` : `<p class="guia">${esc(j)} responde en voz alta. Los demás pueden repreguntar.</p>`}
  </section>
  <button class="btn btn-rojo btn-fijo" data-a="siguiente">${r.idx + 1 < r.orden.length ? "Siguiente sospechoso" : r.rondaInt < p.preguntasPorJugador ? "Terminar la ronda" : "Ir al careo"}</button>`;
};

V.careo = () => `
  ${cabeceraJuego("Careo")}
  <section class="centro">
    <p class="etiqueta">Todos contra todos</p>
    <h1 class="crono" id="crono">2:00</h1>
    <div class="fila">
      <button class="btn btn-linea btn-chico" data-a="cronoToggle" id="cronoBtn">Iniciar</button>
      <button class="btn btn-linea btn-chico" data-a="cronoMas">+30 s</button>
    </div>
    <ul class="tips">
      <li>Acusen, defiéndanse y pidan detalles.</li>
      <li>¿Quién habló raro de «eso» que pasó?</li>
      <li>¿Las versiones de quienes estaban juntos coinciden?</li>
    </ul>
  </section>
  <button class="btn btn-rojo btn-fijo" data-a="aVotar">Pasar a la votación</button>`;

V.voto = () => {
  const p = P(), r = R(), j = p.jugadores[r.votoIdx];
  if (!ui.paso) {
    return `
    ${cabeceraJuego("Votación secreta")}
    <section class="centro pase">
      <p class="etiqueta">Pásale el teléfono a</p>
      <h1 class="nombre-grande">${esc(j)}</h1>
      <div class="puntos-paso">${p.jugadores.map((_, i) => `<i class="${i < r.votoIdx ? "hecho" : i === r.votoIdx ? "actual" : ""}"></i>`).join("")}</div>
    </section>
    <button class="btn btn-rojo btn-fijo" data-a="votoYo">Soy ${esc(j)}</button>`;
  }
  return `
    ${cabeceraJuego("Votación secreta")}
    <section class="voto">
      <p class="etiqueta">${esc(j)}, ¿quién lo hizo?</p>
      <div class="lista-voto">
        ${p.jugadores.filter((o) => o !== j).map((o) => `<button class="sospechoso ${ui.elegido === o ? "on" : ""}" data-a="elegir" data-v="${esc(o)}"><span class="avatar">${esc(o.charAt(0).toUpperCase())}</span>${esc(o)}</button>`).join("")}
      </div>
    </section>
    <button class="btn btn-rojo btn-fijo" data-a="confirmarVoto" ${ui.elegido ? "" : "disabled"}>Confirmar voto</button>`;
};

V.veredicto = () => {
  const r = R(), v = r.veredicto;
  if (!v && !r.errorVeredicto) return `
    ${cabeceraJuego("El detective")}
    <section class="centro"><div class="lupa"><i></i></div><h2>El detective ordena sus notas</h2><p class="maquina">Ya casi tiene un nombre…</p></section>`;
  if (!v) return `
    ${cabeceraJuego("El detective")}
    <section class="centro"><h2>El detective se quedó sin palabras</h2><p class="guia">${esc(r.errorVeredicto)}</p>
      <div class="pila"><button class="btn btn-linea" data-a="reintentarVeredicto">Reintentar</button></div></section>
    <button class="btn btn-rojo btn-fijo" data-a="aRevelacion">Seguir sin su veredicto</button>`;
  return `
    ${cabeceraJuego("El detective")}
    <article class="papel expediente">
      <p class="etiqueta">Informe del detective</p>
      <p class="relato maquina">${esc(v.informe)}</p>
      ${v.contradicciones.length ? `<h3>Lo que no le cuadra</h3><ul class="pistas">${v.contradicciones.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>` : ""}
      ${ui.acusa ? `<div class="acusacion"><p>${esc(v.frase_final)}</p><span class="sello sello-rojo sello-grande golpe">${esc(v.acusado)}</span></div>` : ""}
    </article>
    <button class="btn btn-rojo btn-fijo" data-a="${ui.acusa ? "aRevelacion" : "acusar"}">${ui.acusa ? "Ver los votos del grupo" : "¿A quién acusa?"}</button>`;
};

V.revelacion = () => {
  const p = P(), r = R(), t = contarVotos(r.votos, p.jugadores), max = Math.max(1, ...Object.values(t.cuenta));
  const barras = p.jugadores.slice().sort((a, b) => t.cuenta[b] - t.cuenta[a]).map((j) => `
    <div class="barra-voto"><span>${esc(j)}</span><div><i style="width:${(t.cuenta[j] / max) * 100}%"></i></div><b>${t.cuenta[j]}</b></div>`).join("");
  if (!ui.revelado) return `
    ${cabeceraJuego("Los votos")}
    <article class="papel"><h3>El grupo votó</h3>${barras}
      <p class="guia">${t.acusado ? `El más votado es <b>${esc(t.acusado)}</b>.` : "Hay empate: nadie queda señalado."}</p></article>
    <button class="btn btn-rojo btn-fijo" data-a="revelar">Revelar al culpable</button>`;
  const atrapado = t.acusado === r.culpable;
  return `
    ${cabeceraJuego("La verdad")}
    <section class="centro revela">
      <p class="etiqueta">El culpable era</p>
      <h1 class="nombre-grande golpe">${esc(r.culpable)}</h1>
      <span class="sello ${atrapado ? "sello-rojo" : "sello-verde"} sello-grande">${atrapado ? "ATRAPADO" : "ESCAPÓ"}</span>
      <p class="guia">${atrapado ? `Pero ${esc(r.culpable)} tiene una última jugada.` : `${esc(r.culpable)} engañó al grupo.`}</p>
    </section>
    <button class="btn btn-rojo btn-fijo" data-a="${atrapado ? "ultima" : "cerrar"}">${atrapado ? "Última jugada del culpable" : "Ver el resultado"}</button>`;
};

V.ultima = () => {
  const r = R();
  if (ui.respondido != null) {
    const ok = ui.respondido === r.caso.evento_secreto;
    return `
    ${cabeceraJuego("Última jugada")}
    <section class="centro"><span class="sello ${ok ? "sello-verde" : "sello-rojo"} sello-grande golpe">${ok ? "ACERTÓ" : "FALLÓ"}</span>
      <p class="guia">El dato secreto era:</p><p class="relato">Esa noche ${esc(r.caso.evento_secreto)}.</p></section>
    <button class="btn btn-rojo btn-fijo" data-a="cerrarUltima" data-ok="${ok ? 1 : 0}">Ver el resultado</button>`;
  }
  return `
    ${cabeceraJuego("Última jugada")}
    <section class="voto">
      <p class="etiqueta">${esc(r.culpable)}, ¿qué pasó esa noche?</p>
      <p class="guia">Adivina el dato secreto y rescata 2 puntos.</p>
      <div class="lista-voto">${r.opciones.map((o, i) => `<button class="sospechoso opcion" data-a="adivinar" data-i="${i}">${esc(cap(o))}</button>`).join("")}</div>
    </section>`;
};

V.resultado = () => {
  const p = P(), r = R(), res = r.resultado, c = r.caso;
  const tabla = p.jugadores.slice().sort((a, b) => p.puntos[b] - p.puntos[a]).map((j, i) => `
    <tr class="${j === r.culpable ? "culp" : ""}"><td>${i + 1}</td><td>${esc(j)}${j === r.culpable ? " <small>culpable</small>" : ""}</td><td class="mas">${res.puntos[j] ? "+" + res.puntos[j] : ""}</td><td><b>${p.puntos[j]}</b></td></tr>`).join("");
  return `
  ${cabeceraJuego("Resultado")}
  <article class="papel expediente">
    <span class="sello sello-rojo sello-esq">CERRADO</span>
    <p class="etiqueta">Lo que pasó de verdad</p>
    <p class="relato">${esc(c.verdad)}</p>
    <p class="linea secreto"><b>El dato secreto</b>Esa noche ${esc(c.evento_secreto)}.</p>
    <ul class="pistas">${res.motivos.map((m) => `<li>${esc(m)}</li>`).join("")}</ul>
  </article>
  <article class="papel"><h3>Marcador</h3><table class="marcador">${tabla}</table></article>
  <details class="papel"><summary>Ver las cartas de todos</summary>
    ${c.cartas.map((k) => `<p class="linea"><b>${esc(k.jugador)}</b>En ${esc(k.lugar)}, ${esc(k.actividad)}. ${esc(k.visto)}${k.extra ? " " + esc(k.extra) : ""}</p>`).join("")}
    <p class="linea"><b>${esc(r.culpable)} (culpable)</b>Coartada falsa: en ${esc(c.coartada_falsa.lugar)}, ${esc(c.coartada_falsa.actividad)}.</p>
  </details>
  <button class="btn btn-rojo btn-fijo" data-a="${p.numCaso < p.casos ? "otroCaso" : "final"}">${p.numCaso < p.casos ? "Siguiente caso" : "Ver al ganador"}</button>`;
};

V.final = () => {
  const p = P(), orden = p.jugadores.slice().sort((a, b) => p.puntos[b] - p.puntos[a]), top = p.puntos[orden[0]];
  const ganadores = orden.filter((j) => p.puntos[j] === top);
  return `
  <section class="centro final">
    <div class="cinta">CASO CERRADO · CASO CERRADO · CASO CERRADO · CASO CERRADO</div>
    <p class="etiqueta">${ganadores.length > 1 ? "Mentes criminales empatadas" : "La mente más brillante"}</p>
    <h1 class="nombre-grande golpe">${ganadores.map(esc).join(" y ")}</h1>
    <span class="sello sello-verde sello-grande">${top} PUNTOS</span>
    <article class="papel"><table class="marcador">${orden.map((j, i) => `<tr><td>${i + 1}</td><td>${esc(j)}</td><td></td><td><b>${p.puntos[j]}</b></td></tr>`).join("")}</table></article>
    <div class="pila">
      <button class="btn btn-rojo" data-a="revancha">Revancha con los mismos</button>
      <button class="btn btn-linea" data-a="terminar">Volver al inicio</button>
    </div>
  </section>`;
};

// ---------- Pintado y efectos por pantalla ----------
function pintar() {
  const fn = V[pantalla] || V.inicio;
  $("#app").innerHTML = fn();
  $("#app").dataset.p = pantalla;
  efectos();
}
function efectos() {
  if (EFECTOS[pantalla]) EFECTOS[pantalla]();
  if (pantalla === "cargando" && ui.frases) {
    let i = 0;
    tictac = setInterval(() => { const el = $("#fraseCarga"); if (el) el.textContent = ui.frases[++i % ui.frases.length]; }, 2200);
  }
  if (pantalla === "interrogatorio" && P().reloj) {
    let t = 45; const el = $("#reloj");
    tictac = setInterval(() => {
      t--; if (!el.isConnected) return pararReloj();
      el.querySelector("b").textContent = Math.max(0, t);
      el.querySelector("i").style.width = Math.max(0, (t / 45) * 100) + "%";
      if (t === 0) { el.classList.add("fin"); vibrar([120, 80, 120]); pitido(); pararReloj(); }
    }, 1000);
  }
  if (pantalla === "careo") { ui.seg = ui.seg == null ? 120 : ui.seg; pintarCrono(); }
  if (pantalla === "veredicto" && !R().veredicto && !R().errorVeredicto) {
    const r = R();
    (veredictoPendiente || pedirVeredicto()).then(() => { if (pantalla === "veredicto" && S.partida && R() === r) pintar(); });
  }
  if (pantalla === "reparto" && ui.paso) {
    const carta = $("#carta");
    const abrir = (e) => { e.preventDefault(); carta.classList.add("abierta"); if (!ui.vista) { ui.vista = true; const b = $(".btn-fijo"); b.disabled = false; b.textContent = "Ya la memoricé"; } };
    const cerrar = () => carta.classList.remove("abierta");
    carta.addEventListener("pointerdown", abrir);
    ["pointerup", "pointerleave", "pointercancel"].forEach((ev) => carta.addEventListener(ev, cerrar));
    carta.addEventListener("contextmenu", (e) => e.preventDefault());
  }
}
function pintarCrono() {
  const el = $("#crono"); if (!el) return;
  el.textContent = Math.floor(ui.seg / 60) + ":" + String(ui.seg % 60).padStart(2, "0");
  el.classList.toggle("fin", ui.seg === 0);
}

// ---------- Acciones ----------
function leerConfig() {
  document.querySelectorAll("input.nombre").forEach((el) => { S.nombres[+el.dataset.i] = el.value; });
  const a = $("#ambientacion"), t = $("#tono"), e = $("#escenario");
  if (a) S.prefs.ambientacion = a.value;
  if (t) S.prefs.tono = t.value;
  if (e) S.prefs.escenario = e.value;
}
const A = {
  inicio: () => { if (pantalla === "config") leerConfig(); ir("inicio"); },
  reglas: () => ir("reglas"),
  ajustes: () => ir("ajustes"),
  config: () => ir("config"),
  continuar: () => {
    const p = P(), r = p.ronda;
    if (!r || !r.caso) return prepararCasoReanudado();
    let dest = p.pantalla || "caso";
    if (dest === "cargando") {
      // Se cerró mientras la IA preparaba la siguiente ronda de preguntas.
      if (r.orden.length && r.idx >= r.orden.length) { cargarRondaInt(preguntasLocales({ ronda: r.rondaInt, jugadores: p.jugadores, caso: r.caso })); dest = "interrogatorio"; }
      else dest = "caso";
    }
    ir(dest);
  },
  agregar: () => { leerConfig(); if (S.nombres.length < MAX_J) S.nombres.push(""); ir("config"); const els = document.querySelectorAll("input.nombre"); els[els.length - 1].focus(); },
  quitar: (d) => { leerConfig(); S.nombres.splice(+d.i, 1); ir("config"); },
  modo: (d) => {
    leerConfig();
    if (d.v === "ia" && !S.cfg.apiKey) return modal(`<h3>Falta la clave</h3><p>El Detective IA necesita una clave de API de Groq. Se configura una sola vez.</p><div class="fila"><button class="btn btn-linea" data-a="cerrarModal">Ahora no</button><button class="btn btn-rojo" data-a="irAjustes">Ir a Ajustes</button></div>`);
    S.prefs.modo = d.v; ir("config");
  },
  irAjustes: () => { cerrarModal(); ir("ajustes"); },
  cerrarModal: () => cerrarModal(),
  menos: (d) => { leerConfig(); S.prefs[d.k]--; ir("config"); },
  mas: (d) => { leerConfig(); S.prefs[d.k]++; ir("config"); },
  reloj: () => { leerConfig(); S.prefs.reloj = !S.prefs.reloj; ir("config"); },
  empezar: () => {
    leerConfig();
    const nombres = S.nombres.map((n) => n.trim()).filter(Boolean);
    if (nombres.length < MIN_J) return toast("Hacen falta al menos 3 jugadores con nombre.");
    if (new Set(nombres.map((n) => n.toLowerCase())).size !== nombres.length) return toast("Hay nombres repetidos. Cámbialos para distinguirlos.");
    if (S.prefs.modo === "ia" && !S.cfg.apiKey) S.prefs.modo = "clasico";
    S.nombres = nombres;
    nuevaPartida();
  },
  guardarAjustes: () => { S.cfg.apiKey = $("#apiKey").value.trim(); S.cfg.modelo = $("#modelo").value; guardar(); toast("Ajustes guardados."); },
  probar: async () => {
    A.guardarAjustes();
    $("#pruebaRes").textContent = "Llamando al detective…";
    let msg;
    try {
      const modelos = await listarModelos({ apiKey: S.cfg.apiKey });
      if (modelos.length) { S.cfg.modelos = modelos; if (!modelos.some((m) => m.id === S.cfg.modelo)) S.cfg.modelo = modelos[0].id; guardar(); }
      const s = await probarConexion({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo });
      msg = "Conectado. El detective dice: «" + s + "»";
    } catch (e) { msg = "No funcionó: " + e.message; }
    if (pantalla === "ajustes") { pintar(); $("#pruebaRes").textContent = msg; }
  },
  borrarPartida: () => { S.partida = null; ir("ajustes"); toast("Partida borrada."); },
  salir: () => modal(`<h3>¿Salir del caso?</h3><p>La partida queda guardada y puedes continuarla desde el inicio.</p><div class="fila"><button class="btn btn-linea" data-a="cerrarModal">Seguir jugando</button><button class="btn btn-rojo" data-a="salirSi">Salir</button></div>`),
  salirSi: () => { cerrarModal(); const p = pantalla; pararReloj(); pantalla = "inicio"; ui = {}; if (S.partida) S.partida.pantalla = p; guardar(); pintar(); },
  repartir: () => { R().reparto = 0; ir("reparto"); },
  soyYo: () => { ui = { paso: 1 }; pintar(); },
  cartaLista: () => {
    const p = P(), r = R();
    r.reparto++;
    if (r.reparto < p.jugadores.length) return ir("reparto");
    empezarInterrogatorio();
  },
  siguiente: () => { const t = $("#respuesta"); siguientePregunta(t ? t.value.trim() : ""); },
  cronoToggle: () => {
    if (tictac) { pararReloj(); $("#cronoBtn").textContent = "Reanudar"; return; }
    if (ui.seg === 0) ui.seg = 60;
    $("#cronoBtn").textContent = "Pausar";
    tictac = setInterval(() => { ui.seg = Math.max(0, ui.seg - 1); pintarCrono(); if (ui.seg === 0) { pararReloj(); vibrar([200, 100, 200]); pitido(); const b = $("#cronoBtn"); if (b) b.textContent = "Iniciar"; } }, 1000);
  },
  cronoMas: () => { ui.seg += 30; pintarCrono(); },
  aVotar: () => { R().votos = {}; R().votoIdx = 0; ir("voto"); },
  votoYo: () => { ui = { paso: 1 }; pintar(); },
  elegir: (d) => { ui.elegido = d.v; pintar(); },
  confirmarVoto: () => {
    const p = P(), r = R();
    r.votos[p.jugadores[r.votoIdx]] = ui.elegido;
    r.votoIdx++;
    vibrar(30);
    if (r.votoIdx < p.jugadores.length) return ir("voto");
    trasVotar();
  },
  acusar: () => { ui.acusa = true; vibrar(150); pintar(); },
  reintentarVeredicto: () => { pedirVeredicto(); pintar(); },
  aRevelacion: () => ir("revelacion"),
  revelar: () => { ui.revelado = true; vibrar([60, 60, 200]); pintar(); },
  ultima: () => { R().opciones = opcionesEvento(R().caso); ir("ultima"); },
  adivinar: (d) => { ui.respondido = R().opciones[+d.i]; vibrar(120); pintar(); },
  cerrarUltima: (d) => cerrarRonda(d.ok === "1"),
  cerrar: () => cerrarRonda(null),
  otroCaso: () => prepararCaso(),
  final: () => ir("final"),
  revancha: () => { S.nombres = P().jugadores.slice(); nuevaPartida(); },
  terminar: () => { S.partida = null; ir("inicio"); },
};
function prepararCasoReanudado() {
  // La app se cerró mientras se generaba un caso: se vuelve a generar el mismo número de caso.
  const p = P(); p.numCaso = Math.max(0, p.numCaso - 1); if (p.ronda) p.culpablesPrevios.pop();
  prepararCaso();
}

document.addEventListener("click", (e) => {
  const b = e.target.closest("[data-a]");
  if (!b || b.disabled) return;
  const fn = A[b.dataset.a];
  if (fn) fn(b.dataset, b);
});
$("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") cerrarModal(); });

// Botón «atrás» de Android. Devuelve true si la app lo manejó.
window.__coartadaAtras = () => {
  if ($("#modal").classList.contains("ver")) { cerrarModal(); return true; }
  if (pantalla === "inicio") return false;
  if (["reglas", "ajustes", "config", "entrar"].includes(pantalla)) { A.inicio(); return true; }
  if (pantalla === "multi") { A.mSalir(); return true; }
  if (pantalla === "final") { A.terminar(); return true; }
  A.salir(); return true;
};

// Para las pruebas automáticas.
window.__coartadaEstado = () => ({ pantalla, ui, S });

cargar();
const multi = instalarMulti({ S, guardar, ir, pintar, esc, cap, toast, modal, cerrarModal, vibrar, pitido, V, A, EFECTOS, pararReloj, ponerReloj, URL_WEB: location.protocol.startsWith("http") ? location.origin : (URL_WEB.startsWith("http") ? URL_WEB : ""), pantalla: () => pantalla, ui: () => ui });
const salaEnlace = (new URLSearchParams(location.search).get("sala") || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 5);
if (salaEnlace.length === 5 && !(S.multi && S.multi.sala === salaEnlace)) { pantalla = "entrar"; ui = { modo: "unirse", codigo: salaEnlace }; }
else if (S.multi) { multi.reanudar(); pantalla = "multi"; }
pintar();
