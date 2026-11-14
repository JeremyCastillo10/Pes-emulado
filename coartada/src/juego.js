// Pantallas y red de la partida. Sirve para las tres formas de jugar:
//   - práctica con bots (todo en este teléfono, sin internet),
//   - sala como anfitrión (este teléfono lleva la partida y la publica),
//   - sala como invitado (sigue el estado del anfitrión y envía sus jugadas).
// Los teléfonos se hablan por un servidor MQTT público:
//   <base>/e estado público (retenido) · <base>/p/<id> carta privada (retenida)
//   <base>/h jugadas hacia el anfitrión · <base>/v «1» mientras el anfitrión está conectado
import { crearMqtt } from "./mqtt.js";
import { crearAnfitrion, nuevaSala, MIN_J, MAX_J } from "./anfitrion.js";
import { ESCENARIOS, AVATARES, PREGUNTAS_R2 } from "./content.js";
import { palabraProhibida, limpiarPalabra } from "./engine.js";

const SERVIDORES = ["wss://broker.emqx.io:8084/mqtt", "wss://broker.hivemq.com:8884/mqtt", "wss://mqtt.eclipseprojects.io/mqtt"];
const LETRAS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const azar = (n) => Math.floor(Math.random() * n);
const nuevoId = () => Math.random().toString(36).slice(2, 10) + Math.random().toString(36).slice(2, 6);
const ETAPAS = [["caso", "Caso"], ["r1", "Coartadas"], ["r2", "Pregunta"], ["r3", "Palabra"], ["voto", "Voto"]];
const ETAPA_DE = { caso: 0, r1: 1, r1v: 1, r2: 2, r2v: 2, r3: 3, r3v: 3, careo: 4, voto: 4, veredicto: 4, revelacion: 4, ultima: 4, resultado: 4 };

export function instalarJuego(k) {
  const { S, guardar, ir, pintar, esc, cap, toast, modal, cerrarModal, vibrar, audio, confeti, V, A, EFECTOS, pantalla, ponerReloj, pararReloj } = k;
  let cx = null, anf = null, pend = [], conectado = false, anfVivo = true, reenvio = null, latido = null, vigia = null;
  let u = {};       // estado efímero de la pantalla (lo elegido, lo escrito…)
  let firma = "";   // cambia con cada fase: dispara animaciones y sonidos una sola vez
  let estrenar = false; // la fase acaba de cambiar y aún no se han lanzado sus efectos
  const M = () => S.multi;
  const soyAnf = () => M() && M().rol === "anfitrion";
  const base = () => "coartada/v3/" + M().sala;

  function servidores() { const s = window.__coartadaServidores; return Array.isArray(s) && s.length ? s : SERVIDORES; }
  const servidorDe = (codigo) => servidores()[Math.max(0, LETRAS.indexOf(codigo[0])) % servidores().length];
  function codigoPara(indice) {
    const n = servidores().length;
    let primera;
    do { primera = azar(LETRAS.length); } while (primera % n !== indice);
    let c = LETRAS[primera];
    for (let i = 0; i < 4; i++) c += LETRAS[azar(LETRAS.length)];
    return c;
  }
  const limpiarCodigo = (s) => String(s || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 5);

  // ---------- Conexión ----------
  function desconectar() {
    clearInterval(reenvio); clearInterval(latido); clearTimeout(vigia);
    reenvio = latido = vigia = null;
    if (cx) cx.terminar();
    cx = null; anf = null; pend = []; conectado = false; anfVivo = true;
  }
  function repintar() {
    if (pantalla() !== "juego") return;
    const act = document.activeElement, id = act && act.id, sel = act && act.selectionStart, y = window.scrollY;
    pintar();
    if (id) { const el = document.getElementById(id); if (el && el.focus) { el.focus(); try { el.setSelectionRange(sel, sel); } catch (e) { /* no es texto */ } } }
    window.scrollTo(0, y);
  }
  function salirDeSala(mensaje) {
    desconectar();
    S.multi = null; u = {}; firma = "";
    cerrarModal();
    ir("inicio");
    if (mensaje) toast(mensaje);
  }
  function crearMotor() {
    const m = M();
    anf = crearAnfitrion({
      H: m.H,
      ia: () => ({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo }),
      publicar: ({ estado, privados }) => {
        m.E = estado;
        if (privados) {
          m.P = privados[m.id] || null;
          if (cx) for (const id of Object.keys(privados)) if (id !== m.id) cx.publicar(base() + "/p/" + id, JSON.stringify(privados[id]), true);
        }
        if (cx) cx.publicar(base() + "/e", JSON.stringify(estado), true);
        guardar();
        if (estado.aviso && estado.aviso !== u.avisoVisto) { u.avisoVisto = estado.aviso; toast(estado.aviso); }
        repintar();
      },
    });
  }
  function conectarAnfitrion() {
    const m = M();
    crearMotor();
    if (m.H.local) { conectado = true; return; }
    cx = crearMqtt({
      url: servidorDe(m.sala),
      testamento: { tema: base() + "/v", texto: "0" },
      alEstado: (v) => { conectado = v; repintar(); },
      alConectar: () => { cx.publicar(base() + "/v", "1", true); anf.mando.republicar(); },
      alMensaje: (tema, texto) => {
        if (tema !== base() + "/h") return;
        let a; try { a = JSON.parse(texto); } catch (e) { return; }
        anf.accion(a);
      },
    });
    cx.suscribir(base() + "/h");
    latido = setInterval(() => { if (conectado && anf) anf.mando.republicar(); }, 15000);
  }
  function conectarInvitado() {
    const m = M();
    cx = crearMqtt({
      url: servidorDe(m.sala),
      alEstado: (v) => { conectado = v; repintar(); },
      alConectar: () => { cx.publicar(base() + "/h", JSON.stringify({ id: m.id, t: "unirse", nombre: m.nombre })); },
      alMensaje: (tema, texto) => {
        if (tema === base() + "/v") { anfVivo = texto !== "0"; return repintar(); }
        if (tema === base() + "/p/" + m.id) { try { m.P = texto ? JSON.parse(texto) : null; } catch (e) { return; } guardar(); return repintar(); }
        if (tema !== base() + "/e") return;
        if (!texto) { if (m.E) salirDeSala("El anfitrión cerró la sala."); return; }
        let E; try { E = JSON.parse(texto); } catch (e) { return; }
        if (m.E && E.rev < m.E.rev && E.fase !== "sala") return; // mensaje viejo
        const yo = E.jugadores.find((j) => j.id === m.id);
        if (!yo && (m.dentro || E.fase !== "sala")) return salirDeSala(m.dentro ? "Ya no estás en la sala." : "Esa partida ya empezó. Espera a la siguiente.");
        if (yo) { m.dentro = true; m.nombre = yo.nombre; }
        const cambio = !m.E || m.E.rev !== E.rev;
        m.E = E;
        clearTimeout(vigia);
        guardar();
        if (cambio) repintar();
      },
    });
    cx.suscribir(base() + "/e"); cx.suscribir(base() + "/p/" + m.id); cx.suscribir(base() + "/v");
    // Las jugadas se reenvían hasta que el anfitrión confirma que las recibió.
    reenvio = setInterval(() => {
      const E = m.E; if (!E) return;
      const ack = (E.acks && E.acks[m.id]) || 0;
      pend = pend.filter((a) => a.n > ack && a.firma === firmaDe(E));
      for (const a of pend) cx.publicar(base() + "/h", JSON.stringify(a));
    }, 2500);
    if (!m.E) vigia = setTimeout(() => { if (M() === m && !m.E) salirDeSala(conectado ? "No existe ninguna sala con ese código." : "No se pudo conectar. Revisa tu internet."); }, 12000);
  }
  const firmaDe = (E) => E.fase + "|" + E.numCaso;

  /** Envía una jugada (el anfitrión se la aplica a sí mismo). */
  function enviar(t, datos = {}) {
    const m = M();
    const a = { id: m.id, n: ++m.seq, t, firma: firmaDe(m.E), ...datos };
    guardar();
    if (soyAnf()) return anf.accion(a);
    pend.push(a);
    cx.publicar(base() + "/h", JSON.stringify(a));
    repintar();
  }
  const enviado = (t) => pend.some((a) => a.t === t);

  function practicar(nombre, nBots) {
    desconectar();
    const id = nuevoId();
    S.multi = { rol: "anfitrion", sala: "BOTS", id, nombre, seq: 0, E: null, P: null, H: nuevaSala({ sala: "BOTS", id, nombre, local: true }) };
    S.multi.H.cfg.casos = S.prefs.casos; S.multi.H.cfg.escenario = S.prefs.escenario;
    S.multi.H.cfg.ia = S.prefs.modo === "ia" && !!S.cfg.apiKey; S.multi.H.cfg.ambientacion = S.prefs.ambientacion; S.multi.H.cfg.tono = S.prefs.tono;
    conectarAnfitrion();
    for (let i = 0; i < nBots; i++) anf.mando.agregarBot();
    ir("juego");
    anf.mando.empezar();
  }
  function crearSala(nombre) {
    desconectar();
    const lista = servidores();
    let intento = 0;
    const probar = () => {
      if (intento >= lista.length) { S.multi = null; ir("entrar", { modo: "crear" }); return toast("No se pudo conectar con el servidor de salas. Revisa tu internet."); }
      const sala = codigoPara(intento++), id = nuevoId();
      S.multi = { rol: "anfitrion", sala, id, nombre, seq: 0, E: null, P: null, H: nuevaSala({ sala, id, nombre }) };
      S.multi.H.cfg.casos = S.prefs.casos; S.multi.H.cfg.escenario = S.prefs.escenario;
      S.multi.H.cfg.ia = S.prefs.modo === "ia" && !!S.cfg.apiKey; S.multi.H.cfg.ambientacion = S.prefs.ambientacion; S.multi.H.cfg.tono = S.prefs.tono;
      const propia = S.multi;
      conectarAnfitrion();
      setTimeout(() => { if (M() === propia && !conectado && !propia.E) { desconectar(); probar(); } }, 6000);
    };
    probar();
    ir("juego");
  }
  function unirse(nombre, codigo) {
    desconectar();
    S.multi = { rol: "invitado", sala: codigo, id: nuevoId(), nombre, seq: 0, E: null, P: null, dentro: false };
    guardar();
    conectarInvitado();
    ir("juego");
  }
  /** Al abrir la app con una partida guardada. */
  function reanudar() {
    if (!M()) return false;
    desconectar();
    if (soyAnf()) { conectarAnfitrion(); anf.mando.reanudar(); } else conectarInvitado();
    return true;
  }

  // ---------- Piezas de interfaz ----------
  const J = (id) => M().E.jugadores.find((x) => x.id === id) || { nombre: "?", av: 0 };
  const av = (j, clase = "") => { const a = AVATARES[j.av % AVATARES.length]; return `<span class="av ${clase}" style="--c:${a.c}">${a.e}${j.bot ? `<i>🤖</i>` : ""}</span>`; };
  const quien = (id) => { const j = J(id); return `${av(j, "mini")}<b>${esc(j.nombre)}</b>`; };
  const lug = (i) => { const l = M().E.caso.lugares[i]; return l ? `${l.e} ${esc(l.n)}` : "?"; };
  const fijo = (accion, texto, extra = "", clase = "") => `<div class="dock"><button class="boton ${clase}" data-a="${accion}" ${extra}>${texto}</button></div>`;
  const espera = (texto, lista) => `<div class="dock"><p class="espera"><i></i>${esc(texto)}</p>${lista || ""}</div>`;
  const quienes = (E) => `<div class="fichas">${E.jugadores.map((j) => `<span class="ficha ${E.listos.includes(j.id) ? "ok" : ""}">${av(j, "mini")}${E.listos.includes(j.id) ? "✓" : "…"}</span>`).join("")}</div>`;
  function cabecera(E, titulo) {
    const m = M(), etapa = ETAPA_DE[E.fase];
    const conCarta = m.P && E.caso && m.P.numCaso === E.numCaso && !["resultado", "final", "sala"].includes(E.fase);
    return `<header class="cab">
        <button class="redondo" data-a="jSalir" aria-label="Salir">✕</button>
        <h2>${esc(titulo)}</h2>
        ${conCarta ? `<button class="pastilla" data-a="jCarta">🃏 Mi carta</button>` : ""}
        <button class="redondo" data-a="sonido" aria-label="Sonido">${S.cfg.musica || S.cfg.sonido ? "🔊" : "🔇"}</button>
      </header>
      ${!conectado ? `<p class="banda">Sin conexión. Reintentando…</p>` : !soyAnf() && !anfVivo ? `<p class="banda">El anfitrión se desconectó. Esperando a que vuelva…</p>` : ""}
      ${etapa != null ? `<ol class="etapas">${ETAPAS.map(([, n], i) => `<li class="${i < etapa ? "hecha" : i === etapa ? "actual" : ""}"><i>${i < etapa ? "✓" : i + 1}</i>${n}</li>`).join("")}</ol>` : ""}`;
  }
  const charla = (E, desde) => (E.charla || []).map((c, i) => `<div class="burbuja sube" style="--i:${desde + i}">${av(J(c.id), "mini")}<p><b>${esc(J(c.id).nombre)}</b>${esc(c.txt)}</p></div>`).join("");
  const opcionR2 = (E, k) => PREGUNTAS_R2[E.caso.tipoR2].opciones.find((o) => o.k === k) || { e: "❓", t: "?" };

  /** Tablero de pruebas: lo que cada quien ha declarado hasta ahora. `elegir` lo vuelve seleccionable (votación). */
  function tablero(E, { elegir = false, animar = false } = {}) {
    const an = E.analisis || { avalados: [], choques: [] }, yo = M().id;
    const filas = E.jugadores.map((j, i) => {
      const d = E.r1 && E.r1[j.id];
      const contenido = `
        <div class="fila-cab">${av(j)}<div><b>${esc(j.nombre)}${j.id === yo ? " <small>tú</small>" : ""}</b>
          ${d ? `<span class="marca ${an.avalados.includes(j.id) ? "ok" : "duda"}">${an.avalados.includes(j.id) ? "✅ Con testigo" : "❓ Sin testigo"}</span>` : ""}</div></div>
        <div class="datos">
          ${d ? `<span>📍 ${lug(d.lugar)}</span><span>👀 ${d.vio ? `${esc(J(d.vio).nombre)} en ${lug(d.vioLugar)}` : "a nadie"}</span>` : ""}
          ${E.r2 && E.r2[j.id] ? `<span>${opcionR2(E, E.r2[j.id]).e} ${esc(opcionR2(E, E.r2[j.id]).t)}</span>` : ""}
          ${E.r3 && E.r3[j.id] ? `<span class="palabra">«${esc(E.r3[j.id])}»</span>` : ""}
        </div>`;
      const clase = `fila ${animar ? "sube" : ""} ${u.elegido === j.id ? "on" : ""}`;
      return elegir && j.id !== yo ? `<button class="${clase}" style="--i:${i}" data-a="jElegir" data-id="${esc(j.id)}">${contenido}</button>` : `<div class="${clase} ${elegir ? "propia" : ""}" style="--i:${i}">${contenido}</div>`;
    }).join("");
    const choques = an.choques.map((c, i) => `<div class="choque golpe" style="--i:${E.jugadores.length + i}"><b>💥 ¡Choque!</b> ${c.tipo === "lugar"
      ? `${esc(J(c.a).nombre)} dice que vio a ${esc(J(c.b).nombre)} en ${lug(c.lugar)}, pero ${esc(J(c.b).nombre)} dice que estaba en otro sitio.`
      : `${esc(J(c.a).nombre)} y ${esc(J(c.b).nombre)} dicen que estaban en ${lug(c.lugar)}… y ninguno vio al otro.`}</div>`).join("");
    return `<div class="tablero">${filas}${choques}</div>`;
  }
  function htmlCarta(E, P) {
    const yo = J(M().id);
    if (P.culpable) return `
      <div class="rol rol-malo"><span>😈</span><b>ERES CULPABLE</b></div>
      <ul class="hechos">
        <li><i>🙈</i><div><small>Lo que no sabes</small>El <b>secreto</b> de la noche. Todos los inocentes lo vieron menos tú.</div></li>
        <li><i>📍</i><div><small>Lugar seguro para tu coartada</small><b>${lug(P.seguro)}</b> (ahí no había nadie)</div></li>
        <li><i>👂</i><div><small>Chisme que te sirve</small><b>${esc(J(P.pista.id).nombre)}</b> estaba en <b>${lug(P.pista.lugar)}</b></div></li>
        ${P.rumor ? `<li><i>💡</i><div><small>Rumor sobre el secreto</small>${opcionR2(E, P.rumor).e} <b>${esc(opcionR2(E, P.rumor).t)}</b></div></li>` : ""}
      </ul>
      <p class="mision">🎯 Finge que sabes el secreto y logra que voten a otro, ${esc(yo.nombre)}.</p>`;
    return `
      <div class="rol rol-bueno"><span>😇</span><b>ERES INOCENTE</b></div>
      <ul class="hechos">
        <li><i>📍</i><div><small>Estabas en</small><b>${lug(P.lugar)}</b></div></li>
        <li><i>👀</i><div><small>Viste a</small>${P.vio ? `<b>${esc(J(P.vio.id).nombre)}</b> en <b>${lug(P.vio.lugar)}</b>` : "<b>Nadie</b>"}</div></li>
      </ul>
      <div class="secreto"><small>🤫 El secreto · el culpable no lo sabe</small><span>${P.evento.e}</span><b>Esa noche ${esc(P.evento.t)}</b></div>
      <p class="mision">🎯 Descubre quién no sabe el secreto… sin decirlo en voz alta.</p>`;
  }
  const marcador = (E, ronda) => `<div class="marcador">${E.jugadores.slice().sort((a, b) => (E.puntos[b.id] || 0) - (E.puntos[a.id] || 0)).map((j, i) => `
    <div class="puesto sube" style="--i:${i}"><em>${i + 1}</em>${av(j)}<b>${esc(j.nombre)}${E.culpable === j.id && ronda ? " <small>culpable</small>" : ""}</b>${ronda && ronda[j.id] ? `<span class="mas">+${ronda[j.id]}</span>` : ""}<strong>${E.puntos[j.id] || 0}</strong></div>`).join("")}</div>`;
  const MOTIVO = {
    atrapado: (E) => `${esc(J(E.culpable).nombre)} fue descubierto: +2 a quienes le votaron.`,
    adivino: (E) => `${esc(J(E.culpable).nombre)} adivinó el secreto: +2.`,
    escapo: (E) => `${esc(J(E.culpable).nombre)} escapó: +4.`,
    empate: (E) => `Empate en la votación: ${esc(J(E.culpable).nombre)} escapó y suma +4.`,
    olfato: () => "Quienes sí votaron al culpable: +1.",
    detective: (E, m) => `El detective acusó a ${esc(J(m.id).nombre)} por error: +1 para ${esc(J(E.culpable).nombre)}.`,
  };

  // ---------- Pantallas previas ----------
  V.entrar = () => {
    const ui = k.ui(), modo = ui.modo;
    const titulo = { bots: "Jugar con bots", crear: "Crear sala", unirse: "Unirme a una sala" }[modo];
    return `
    <header class="cab"><button class="redondo" data-a="inicio" aria-label="Volver">‹</button><h2>${titulo}</h2></header>
    <section class="tarjeta sube">
      <label class="campo"><span>Tu nombre</span>
        <input id="miNombre" maxlength="12" autocomplete="off" autocapitalize="words" placeholder="Como te dicen" value="${esc(S.miNombre || "")}"></label>
      ${modo === "unirse" ? `<label class="campo"><span>Código de la sala</span>
        <input id="codigo" class="codigo-in" maxlength="5" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABCDE" value="${esc(ui.codigo || "")}"></label>
        <p class="nota">El código de 5 letras aparece en el teléfono de quien creó la sala.</p>` : ""}
      ${modo === "bots" ? `
        <div class="ajuste"><span>🤖 Bots en la mesa</span><div class="contador"><button data-a="eBots" data-d="-1" ${S.prefs.bots <= 2 ? "disabled" : ""}>−</button><b>${S.prefs.bots}</b><button data-a="eBots" data-d="1" ${S.prefs.bots >= MAX_J - 1 ? "disabled" : ""}>+</button></div></div>
        <div class="ajuste"><span>🗂️ Casos</span><div class="contador"><button data-a="eCasos" data-d="-1" ${S.prefs.casos <= 1 ? "disabled" : ""}>−</button><b>${S.prefs.casos}</b><button data-a="eCasos" data-d="1" ${S.prefs.casos >= 8 ? "disabled" : ""}>+</button></div></div>
        <p class="nota">Funciona sin internet. Los bots declaran, responden y votan como jugadores.</p>` : ""}
      ${modo === "crear" ? `<p class="nota">Tu teléfono lleva la partida: mantén la app abierta. Podrás añadir bots si falta gente.</p>` : ""}
    </section>
    ${fijo({ bots: "ePracticar", crear: "eCrear", unirse: "eUnirse" }[modo], { bots: "¡A jugar!", crear: "Crear la sala", unirse: "Entrar" }[modo])}`;
  };

  // ---------- Pantalla de juego ----------
  V.juego = () => {
    const m = M();
    if (!m) return V.inicio();
    const E = m.E;
    if (!E) return `<header class="cab"><button class="redondo" data-a="jSalir" aria-label="Salir">✕</button><h2>Conectando</h2></header>
      <section class="centro"><div class="lupa">🔍</div><h2 class="titulo">${m.rol === "anfitrion" ? "Abriendo la sala" : "Buscando la sala " + esc(m.sala)}</h2></section>`;
    const nueva = E.fase + "|" + E.numCaso + "|" + (E.fase === "revelacion" ? E.revelado : "");
    if (nueva !== firma) { firma = nueva; u = { avisoVisto: u.avisoVisto }; estrenar = true; }
    const yo = m.id, anfitrion = soyAnf(), f = E.fase, n = E.jugadores.length, P = m.P && m.P.numCaso === E.numCaso ? m.P : null;
    const soyCulpable = !!(P && P.culpable), jefe = J(E.anfitrion).nombre;
    const listo = E.listos && (E.listos.includes(yo) || enviado(f === "caso" ? "listo" : f));

    if (f === "sala") {
      const c = anfitrion ? m.H.cfg : E.cfg;
      return `
      ${cabecera(E, E.local ? "Práctica" : "Sala de espera")}
      ${E.local ? `<section class="intro sube"><h1 class="titulo">Tu mesa de bots</h1><p>Añade o quita bots y empieza cuando quieras.</p></section>` : `<section class="codigo-caja sube">
        <small>Código de la sala</small>
        <h1 class="codigo">${esc(m.sala)}</h1>
        <button class="boton chico fantasma" data-a="jCompartir">📨 Invitar amigos</button>
      </section>`}
      <section class="tarjeta sube" style="--i:1">
        <h3>Jugadores <small>${n}/${MAX_J}</small></h3>
        <div class="mesa">${E.jugadores.map((j) => `<div class="silla">${av(j, "grande")}<b>${esc(j.nombre)}</b><small>${j.id === E.anfitrion ? "anfitrión" : j.bot ? "bot" : j.id === yo ? "tú" : "&nbsp;"}</small>${anfitrion && j.id !== yo ? `<button class="quitar" data-a="jQuitar" data-id="${esc(j.id)}" aria-label="Quitar">✕</button>` : ""}</div>`).join("")}
          ${anfitrion && n < MAX_J ? `<button class="silla vacia" data-a="jBot"><span class="av grande">＋</span><b>Añadir bot</b><small>&nbsp;</small></button>` : ""}</div>
        ${n < MIN_J ? `<p class="nota">Hacen falta al menos ${MIN_J} jugadores. Puedes completar con bots.</p>` : ""}
      </section>
      ${anfitrion ? `<section class="tarjeta sube" style="--i:2">
        <h3>Partida</h3>
        <div class="ajuste"><span>🗂️ Casos</span><div class="contador"><button data-a="jCfg" data-d="-1" ${c.casos <= 1 ? "disabled" : ""}>−</button><b>${c.casos}</b><button data-a="jCfg" data-d="1" ${c.casos >= 8 ? "disabled" : ""}>+</button></div></div>
        <div class="segmento"><button class="${!c.ia ? "on" : ""}" data-a="jModo" data-v="clasico">📁 Casos del archivo</button><button class="${c.ia ? "on" : ""}" data-a="jModo" data-v="ia">✨ Casos con IA</button></div>
        ${c.ia ? `<label class="campo"><span>¿Dónde están o de qué quieren el caso?</span><input id="jAmb" maxlength="100" placeholder="Ej.: asado en casa de Jere" value="${esc(c.ambientacion)}"></label>
          <label class="campo"><span>Tono</span><select id="jTono"><option value="absurdo" ${c.tono === "absurdo" ? "selected" : ""}>Absurdo (para todos)</option><option value="noir" ${c.tono === "noir" ? "selected" : ""}>Novela negra</option><option value="picante" ${c.tono === "picante" ? "selected" : ""}>Picante (adultos)</option></select></label>`
        : `<label class="campo"><span>Escenario</span><select id="jEsc"><option value="azar">🎲 Al azar</option>${ESCENARIOS.map((e) => `<option value="${e.id}" ${c.escenario === e.id ? "selected" : ""}>${e.emoji} ${esc(e.nombre)}</option>`).join("")}</select></label>`}
      </section>
      ${fijo("jEmpezar", n < MIN_J ? "Faltan jugadores" : `¡Empezar con ${n}!`, n < MIN_J ? "disabled" : "")}` : espera(`Esperando a que ${jefe} empiece`)}`;
    }

    if (f === "cargando") return `${cabecera(E, "Un momento")}<section class="centro"><div class="lupa">🔍</div><h2 class="titulo">${esc(E.cargando || "Un momento")}</h2></section>`;

    if (f === "caso") {
      const c = E.caso;
      return `
      ${cabecera(E, `Caso ${E.numCaso} de ${E.cfg.casos}`)}
      <section class="expediente sube">
        <div class="foco"><span>${c.emoji}</span></div>
        <h1 class="titulo">${esc(c.titulo)}</h1>
        <p>${esc(c.relato)}</p>
        <span class="pastilla fija">🚨 Lugar del crimen: ${lug(c.lugar_crimen)}</span>
      </section>
      ${P ? `<section class="sube" style="--i:2">
        <p class="guia">${u.vista ? "Tu carta secreta. Que nadie más la vea." : "👇 Toca tu carta secreta para darle la vuelta"}</p>
        <div class="carta ${u.vista ? "abierta" : ""} ${P.culpable ? "mala" : ""}" data-a="jGirar">
          <div class="cara dorso"><span>🕵️</span><b>TOP SECRET</b><small>toca para ver</small></div>
          <div class="cara frente">${htmlCarta(E, P)}</div>
        </div></section>` : `<p class="guia">Repartiendo las cartas…</p>`}
      ${listo ? espera("Esperando a los demás", quienes(E)) + (anfitrion ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jForzar">Seguir sin esperar</button></div>` : "") : fijo("jListo", u.vista ? "¡Entendido!" : "Primero mira tu carta", u.vista ? "" : "disabled")}`;
    }

    if (["r1", "r2", "r3"].includes(f) && !P) return `${cabecera(E, "Un momento")}<section class="centro"><div class="lupa">🔍</div><p class="guia">Recibiendo tu carta…</p></section>`;

    if (f === "r1") {
      if (listo) return `${cabecera(E, "Coartadas")}<section class="centro"><div class="sello-ok golpe">DECLARADO</div><p class="guia">Tu coartada ya está sobre la mesa.</p></section>${espera("Esperando las demás coartadas", quienes(E))}${anfitrion ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jForzar">Seguir sin esperar</button></div>` : ""}`;
      if (!soyCulpable && P) return `
        ${cabecera(E, "Coartadas")}
        <section class="intro sube"><h1 class="titulo">¿Dónde estabas?</h1><p>Cada quien declara dónde estaba y a quién vio. Después se cruzan todas las versiones.</p></section>
        <section class="tarjeta sube" style="--i:1">
          <h3>Tu declaración <small>la verdad de tu carta</small></h3>
          <p class="dicho">📍 Estaba en <b>${lug(P.lugar)}</b></p>
          <p class="dicho">👀 ${P.vio ? `Vi a <b>${esc(J(P.vio.id).nombre)}</b> en <b>${lug(P.vio.lugar)}</b>` : "No vi a <b>nadie</b>"}</p>
          <p class="nota">Los inocentes declaran lo que vivieron. Solo el culpable inventa.</p>
        </section>
        ${fijo("jR1", "Declarar")}`;
      const d = u.r1 || (u.r1 = { lugar: null, vio: undefined, vioLugar: null });
      const completo = d.lugar != null && d.vio !== undefined && (d.vio === null || d.vioLugar != null);
      const rejilla = (campo, sel) => `<div class="rejilla">${E.caso.lugares.map((l, i) => { const crimen = i === E.caso.lugar_crimen && campo === "lugar"; return `<button class="lugar ${sel === i ? "on" : ""}" data-a="jR1Set" data-k="${campo}" data-v="${i}" ${crimen ? "disabled" : ""}><span>${crimen ? "🚨" : l.e}</span>${esc(l.n)}${P && campo === "lugar" && i === P.seguro ? "<em>seguro</em>" : ""}</button>`; }).join("")}</div>`;
      return `
        ${cabecera(E, "Coartadas")}
        <section class="intro sube"><h1 class="titulo">Inventa tu coartada 😈</h1><p>Los demás dirán la verdad. Si tu historia choca con la de alguien, saltará a la vista.</p></section>
        ${P ? `<p class="consejo sube" style="--i:1">💡 Seguro: <b>${lug(P.seguro)}</b>. Y sabes que <b>${esc(J(P.pista.id).nombre)}</b> estaba en <b>${lug(P.pista.lugar)}</b>.</p>` : ""}
        <section class="tarjeta sube" style="--i:2"><h3>1 · ¿Dónde dirás que estabas?</h3>${rejilla("lugar", d.lugar)}</section>
        <section class="tarjeta sube" style="--i:3"><h3>2 · ¿A quién dirás que viste?</h3>
          <div class="personas">${E.jugadores.filter((j) => j.id !== yo).map((j) => `<button class="persona ${d.vio === j.id ? "on" : ""}" data-a="jR1Set" data-k="vio" data-v="${esc(j.id)}">${av(j)}<b>${esc(j.nombre)}</b></button>`).join("")}
            <button class="persona ${d.vio === null ? "on" : ""}" data-a="jR1Set" data-k="vio" data-v=""><span class="av">🚫</span><b>A nadie</b></button></div></section>
        ${d.vio ? `<section class="tarjeta sube"><h3>3 · ¿Dónde viste a ${esc(J(d.vio).nombre)}?</h3>${rejilla("vioLugar", d.vioLugar)}</section>` : ""}
        ${fijo("jR1", "Declarar", completo ? "" : "disabled")}`;
    }

    if (f === "r1v") return `
      ${cabecera(E, "Coartadas")}
      <section class="intro sube"><h1 class="titulo">Versiones sobre la mesa</h1><p>✅ alguien confirma dónde estaba · ❓ nadie lo vio. Al culpable nunca lo vio nadie.</p></section>
      ${tablero(E, { animar: true })}
      ${charla(E, n + 2)}
      ${anfitrion ? fijo("jSeguir", "Siguiente ronda") : espera(`${jefe} pasa a la siguiente ronda`)}`;

    if (f === "r2") {
      const q = PREGUNTAS_R2[E.caso.tipoR2];
      if (listo) return `${cabecera(E, "La pregunta")}<section class="centro"><div class="sello-ok golpe">RESPONDIDO</div></section>${espera("Esperando las demás respuestas", quienes(E))}${anfitrion ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jForzar">Seguir sin esperar</button></div>` : ""}`;
      return `
        ${cabecera(E, "La pregunta")}
        <section class="intro sube"><h1 class="titulo">${esc(q.titulo)}</h1><p>${soyCulpable ? "No lo sabes: arriésgate. Si respondes distinto a todos, cantarás." : "«Eso» es el secreto de tu carta. Responde lo que viviste."}</p></section>
        ${soyCulpable && P.rumor ? `<p class="consejo sube" style="--i:1">💡 Tu rumor: <b>${opcionR2(E, P.rumor).e} ${esc(opcionR2(E, P.rumor).t)}</b></p>` : ""}
        <div class="opciones">${q.opciones.map((o, i) => `<button class="opcion sube ${u.op === o.k ? "on" : ""}" style="--i:${i + 1}" data-a="jOp" data-v="${o.k}"><span>${o.e}</span>${esc(o.t)}</button>`).join("")}</div>
        ${fijo("jR2", "Responder", u.op ? "" : "disabled")}`;
    }

    if (f === "r2v") {
      const q = PREGUNTAS_R2[E.caso.tipoR2];
      const grupos = q.opciones.map((o) => ({ o, js: E.jugadores.filter((j) => E.r2[j.id] === o.k) })).filter((g) => g.js.length).sort((a, b) => b.js.length - a.js.length);
      return `
      ${cabecera(E, "La pregunta")}
      <section class="intro sube"><h1 class="titulo">${esc(q.titulo)}</h1><p>Quien no vivió «eso» tuvo que adivinar.</p></section>
      ${grupos.map((g, i) => `<div class="grupo sube" style="--i:${i + 1}"><div class="grupo-op"><span>${g.o.e}</span><b>${esc(g.o.t)}</b><em>${g.js.length}</em></div><div class="grupo-js">${g.js.map((j) => `<span class="ficha">${av(j, "mini")}${esc(j.nombre)}</span>`).join("")}</div></div>`).join("")}
      ${charla(E, grupos.length + 2)}
      ${anfitrion ? fijo("jSeguir", "Última ronda") : espera(`${jefe} pasa a la última ronda`)}`;
    }

    if (f === "r3") {
      if (listo) return `${cabecera(E, "Palabra clave")}<section class="centro"><div class="sello-ok golpe">ENVIADA</div></section>${espera("Esperando las demás palabras", quienes(E))}${anfitrion ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jForzar">Seguir sin esperar</button></div>` : ""}`;
      return `
        ${cabecera(E, "Palabra clave")}
        <section class="intro sube"><h1 class="titulo">Una sola palabra</h1><p>${soyCulpable ? "Escribe algo que suene a que estuviste ahí. Mira las pruebas antes de arriesgarte." : "Insinúa el secreto sin decirlo. Muy obvia y el culpable lo adivina; muy rara y sospecharán de ti."}</p></section>
        <section class="tarjeta sube" style="--i:1">
          <input id="jPalabra" class="palabra-in" maxlength="16" autocomplete="off" autocapitalize="none" spellcheck="false" placeholder="tu palabra" value="${esc(u.palabra || "")}">
          <p class="nota" id="jPalabraNota">${soyCulpable ? "Nadie sabrá que dudaste." : "No vale usar palabras del propio secreto."}</p>
        </section>
        <button class="boton chico fantasma sube" style="--i:2" data-a="jPruebas">🔎 Ver las pruebas</button>
        ${fijo("jR3", "Enviar palabra", (u.palabra || "").trim().length >= 2 ? "" : "disabled")}`;
    }

    if (f === "r3v") return `
      ${cabecera(E, "Palabra clave")}
      <section class="intro sube"><h1 class="titulo">Las palabras</h1><p>¿Cuál no encaja con lo que pasó?</p></section>
      <div class="notas">${E.jugadores.map((j, i) => `<div class="nota-p gira" style="--i:${i}; --r:${(i % 2 ? 1 : -1) * (2 + (i % 3))}deg">${av(j, "mini")}<small>${esc(j.nombre)}</small><b>${esc(E.r3[j.id] || "…")}</b></div>`).join("")}</div>
      ${charla(E, n + 1)}
      ${anfitrion ? fijo("jSeguir", E.jugadores.filter((j) => !j.bot).length >= 2 ? "A debatir" : "A votar") : espera(`${jefe} abre el debate`)}`;

    if (f === "careo") return `
      ${cabecera(E, "Debate")}
      <section class="intro sube"><h1 class="crono" id="jCrono">1:30</h1><p>Acusen, defiéndanse y miren las pruebas. Nadie puede decir el secreto.</p>
        ${anfitrion ? `<button class="boton chico fantasma" data-a="jMasCareo">+30 s</button>` : ""}</section>
      ${tablero(E)}
      ${anfitrion ? fijo("jSeguir", "A votar") : espera(`${jefe} abrirá la votación`)}`;

    if (f === "voto") {
      if (listo) return `${cabecera(E, "Votación")}<section class="centro"><div class="sello-ok golpe">VOTO SECRETO</div><p class="guia">Han votado ${E.listos.length} de ${n}.</p></section>${espera("Esperando los demás votos", quienes(E))}${anfitrion ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jForzar">Seguir sin esperar</button></div>` : ""}`;
      return `
        ${cabecera(E, "Votación")}
        <section class="intro sube"><h1 class="titulo">¿Quién fue?</h1><p>${soyCulpable ? "Vota a quien más sospechoso parezca. Disimula." : "Toca a tu sospechoso. Tienes todas las pruebas delante."}</p></section>
        ${tablero(E, { elegir: true })}
        ${fijo("jVotar", u.elegido ? `Votar a ${esc(J(u.elegido).nombre)}` : "Elige a alguien", u.elegido ? "" : "disabled", "rojo")}`;
    }

    if (f === "veredicto") {
      const v = E.veredicto, a = J(v.acusado);
      return `
        ${cabecera(E, "El detective")}
        <section class="detective sube"><div class="foco chico"><span>🕵️</span></div><h1 class="titulo">El detective acusa…</h1>
          <ul class="razones">${v.razones.map((x, i) => `<li class="sube" style="--i:${i + 2}">${esc(x)}</li>`).join("")}</ul>
          <div class="acusado golpe" style="--i:${v.razones.length + 3}">${av(a, "enorme")}<b>${esc(a.nombre)}</b><p>«${esc(v.frase)}»</p></div>
        </section>
        ${anfitrion ? fijo("jSeguir", "Ver los votos del grupo") : espera("Ahora, los votos del grupo")}`;
    }

    if (f === "revelacion" || f === "ultima") {
      const max = Math.max(1, ...Object.values(E.conteo.cuenta));
      const barras = `<section class="tarjeta sube"><h3>Los votos</h3>${E.jugadores.slice().sort((a, b) => E.conteo.cuenta[b.id] - E.conteo.cuenta[a.id]).map((j, i) => `
        <div class="barra-voto">${av(j, "mini")}<b>${esc(j.nombre)}</b><div><i style="--w:${(E.conteo.cuenta[j.id] / max) * 100}%; --i:${i}"></i></div><strong>${E.conteo.cuenta[j.id]}</strong>
          <span class="votantes">${E.jugadores.filter((x) => E.votos[x.id] === j.id).map((x) => av(x, "micro")).join("")}</span></div>`).join("")}</section>`;
      if (f === "revelacion" && !E.revelado) return `
        ${cabecera(E, "Los votos")}
        <section class="intro sube"><h1 class="titulo">${E.conteo.acusado ? `El grupo señala a ${esc(J(E.conteo.acusado).nombre)}` : "¡Empate! Nadie queda señalado"}</h1></section>
        ${barras}
        ${anfitrion ? fijo("jRevelar", "🥁 Revelar al culpable", "", "rojo") : espera("Redoble de tambores…")}`;
      const c = J(E.culpable), esYo = E.culpable === yo;
      const cab = `${cabecera(E, "La verdad")}
        <section class="revela"><small>El culpable era</small>${av(c, "enorme zoom")}<h1 class="titulo zoom">${esc(c.nombre)}</h1>
          <span class="sello ${E.atrapado ? "rojo" : "verde"} golpe" style="--i:3">${E.atrapado ? "ATRAPADO" : "ESCAPÓ"}</span></section>`;
      if (f === "revelacion") return `${cab}<p class="guia">${esYo ? "¡Los engañaste a todos!" : `${esc(c.nombre)} engañó al grupo.`}</p>${anfitrion ? fijo("jSeguir", "Ver el resultado") : espera("Esperando el resultado")}`;
      if (!esYo) return `${cab}<p class="guia">Última jugada: si ${esc(c.nombre)} adivina el secreto, rescata 2 puntos. ¡No le den pistas!</p>
        ${anfitrion && !c.bot ? `<div class="sobre-dock"><button class="boton chico fantasma" data-a="jSeguir">Saltar la última jugada</button></div>` : ""}${espera(`${c.nombre} está eligiendo`)}`;
      return `${cabecera(E, "Última jugada")}
        <section class="intro sube"><h1 class="titulo">Te atraparon 😅</h1><p>Adivina el secreto de la noche y rescata 2 puntos.</p></section>
        ${enviado("adivina") ? espera("Enviando…") : `<div class="opciones una">${E.opciones.map((o, i) => `<button class="opcion ancha sube" style="--i:${i + 1}" data-a="jAdivinar" data-i="${i}"><span>${o.e}</span>${esc(cap(o.t))}</button>`).join("")}</div>`}
        <button class="boton chico fantasma" data-a="jPruebas">🔎 Ver las pruebas</button>`;
    }

    if (f === "resultado") {
      const r = E.resultado, c = J(E.culpable);
      return `
      ${cabecera(E, "Resultado")}
      <section class="secreto grande sube"><small>🤫 El secreto de la noche</small><span>${r.evento.e}</span><b>Esa noche ${esc(r.evento.t)}</b></section>
      ${r.eligio ? `<p class="consejo sube ${r.adivino ? "bien" : "mal"}" style="--i:1">${av(c, "mini")} ${esc(c.nombre)} apostó por «${r.eligio.e} ${esc(r.eligio.t)}». ${r.adivino ? "¡Acertó!" : "Falló."}</p>` : ""}
      <section class="tarjeta sube" style="--i:2"><h3>Lo que pasó</h3><p>${esc(r.verdad)}</p>
        <ul class="motivos">${r.motivos.map((x) => `<li>${MOTIVO[x.k] ? MOTIVO[x.k](E, x) : ""}</li>`).join("")}</ul></section>
      <section class="tarjeta sube" style="--i:3"><h3>Marcador</h3>${marcador(E, r.puntos)}</section>
      ${anfitrion ? fijo("jSeguir", E.numCaso < E.cfg.casos ? "Siguiente caso" : "🏆 Ver al ganador") : espera(`Esperando a ${jefe}`)}`;
    }

    if (f === "final") {
      const orden = E.jugadores.slice().sort((a, b) => (E.puntos[b.id] || 0) - (E.puntos[a.id] || 0)), top = E.puntos[orden[0].id] || 0;
      const ganan = orden.filter((j) => (E.puntos[j.id] || 0) === top);
      return `
      <header class="cab"><span></span><h2>Caso cerrado</h2><button class="redondo" data-a="sonido" aria-label="Sonido">${S.cfg.musica || S.cfg.sonido ? "🔊" : "🔇"}</button></header>
      <section class="revela"><small>${ganan.length > 1 ? "Empate en la cima" : "La mente más brillante"}</small>
        <div class="ganadores">${ganan.map((j) => av(j, "enorme zoom")).join("")}</div>
        <h1 class="titulo zoom">${ganan.map((j) => esc(j.nombre)).join(" y ")}</h1><span class="sello verde golpe" style="--i:3">${top} PUNTOS</span></section>
      <section class="tarjeta sube" style="--i:4">${marcador(E)}</section>
      <div class="pila">${anfitrion ? `<button class="boton" data-a="jSeguir">🔁 Revancha</button><button class="boton fantasma" data-a="jSalirSi">Salir</button>` : `<p class="espera"><i></i>El anfitrión puede abrir la revancha</p><button class="boton fantasma" data-a="jSalirSi">Salir de la sala</button>`}</div>`;
    }
    return `${cabecera(E, "Sala")}<section class="centro"><p class="guia">Actualiza la app para seguir esta partida.</p></section>`;
  };

  // ---------- Efectos al pintar: animaciones, sonidos, relojes ----------
  const MUSICA = { sala: "menu", final: "final" };
  EFECTOS.juego = () => {
    const m = M(), E = m && m.E, app = document.getElementById("app");
    if (!E) return;
    const cambio = estrenar; estrenar = false;
    app.classList.toggle("anim", cambio);
    if (cambio) {
      pend = pend.filter((a) => a.firma === firmaDe(E));
      window.scrollTo(0, 0);
      audio.musica(MUSICA[E.fase] || "juego");
      const f = E.fase, n = E.jugadores.length;
      if (f === "caso") audio.sfx("revelar");
      if (["r1", "r2", "r3", "voto"].includes(f)) audio.sfx("turno");
      if (f === "r1v") { for (let i = 0; i < n; i++) audio.sfx("pop", 0.15 + i * 0.22); E.analisis.choques.forEach((_, i) => audio.sfx("choque", 0.3 + (n + i) * 0.22)); if (E.analisis.choques.length) setTimeout(() => vibrar([80, 50, 80]), (0.3 + n * 0.22) * 1000); }
      if (f === "r2v") for (let i = 0; i < 4; i++) audio.sfx("pop", 0.2 + i * 0.22);
      if (f === "r3v") for (let i = 0; i < n; i++) audio.sfx("carta", 0.1 + i * 0.22);
      if (["r1v", "r2v", "r3v"].includes(f)) (E.charla || []).forEach((_, i) => audio.sfx("mensaje", 0.6 + (n + i) * 0.22));
      if (f === "veredicto") audio.sfx("sello", 0.25 + (E.veredicto.razones.length + 3) * 0.22);
      if ((f === "revelacion" && E.revelado) || f === "ultima") { audio.sfx("revelar"); audio.sfx("sello", 0.9); vibrar([60, 60, 220]); if (E.atrapado !== (E.culpable === m.id)) confeti(); }
      if (f === "resultado") audio.sfx(E.resultado.puntos[m.id] ? "bien" : "mal", 0.3);
      if (f === "final") { audio.sfx("fanfarria", 0.2); confeti(); }
      // La votación se abre con el tablero entero: se elige con calma.
    }
    if (E.fase === "careo") {
      const el = document.getElementById("jCrono");
      const tic = () => {
        if (!el.isConnected) return pararReloj();
        const s = Math.max(0, Math.ceil((E.careoFin - Date.now()) / 1000));
        el.textContent = Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
        el.classList.toggle("fin", s === 0);
        if (s <= 5 && s > 0 && u.ultimoTic !== s) { u.ultimoTic = s; audio.sfx("tic"); }
        if (s === 0 && !u.sono) { u.sono = true; vibrar([200, 100, 200]); audio.sfx("mal"); }
      };
      tic(); ponerReloj(tic, 250);
    }
    const p = document.getElementById("jPalabra");
    if (p) p.addEventListener("input", () => {
      u.palabra = p.value;
      const w = limpiarPalabra(p.value), nota = document.getElementById("jPalabraNota"), boton = document.querySelector(".dock .boton");
      const mal = m.P && !m.P.culpable && w.length >= 2 && palabraProhibida(w, m.P.evento.t);
      nota.textContent = mal ? "Demasiado obvia: esa palabra está en el secreto." : /\s/.test(p.value.trim()) ? `Solo cuenta la primera: «${w}».` : m.P && m.P.culpable ? "Nadie sabrá que dudaste." : "No vale usar palabras del propio secreto.";
      nota.classList.toggle("error", !!mal);
      boton.disabled = w.length < 2 || !!mal;
    });
    const amb = document.getElementById("jAmb"), tono = document.getElementById("jTono"), escn = document.getElementById("jEsc");
    if (amb) amb.addEventListener("change", () => { S.prefs.ambientacion = amb.value; anf.mando.configurar({ ambientacion: amb.value }); });
    if (tono) tono.addEventListener("change", () => { S.prefs.tono = tono.value; anf.mando.configurar({ tono: tono.value }); });
    if (escn) escn.addEventListener("change", () => { S.prefs.escenario = escn.value; anf.mando.configurar({ escenario: escn.value }); });
  };
  EFECTOS.entrar = () => {
    const c = document.getElementById("codigo");
    if (c) c.addEventListener("input", () => { c.value = limpiarCodigo(c.value); });
  };

  // ---------- Acciones ----------
  function leerNombre() {
    const n = (document.getElementById("miNombre").value || "").trim().slice(0, 12);
    if (!n) { toast("Escribe tu nombre."); return null; }
    S.miNombre = n; guardar();
    return n;
  }
  const guardarNombre = () => { const el = document.getElementById("miNombre"); if (el) S.miNombre = el.value; };
  Object.assign(A, {
    jugarBots: () => ir("entrar", { modo: "bots" }),
    salaCrear: () => ir("entrar", { modo: "crear" }),
    salaUnirse: () => ir("entrar", { modo: "unirse", codigo: k.ui().codigo || "" }),
    salaVolver: () => { if (M()) { if (!anf && !cx) reanudar(); ir("juego"); } },
    eBots: (d) => { guardarNombre(); S.prefs.bots = Math.max(2, Math.min(MAX_J - 1, S.prefs.bots + Number(d.d))); ir("entrar", { modo: "bots" }); },
    eCasos: (d) => { guardarNombre(); S.prefs.casos = Math.max(1, Math.min(8, S.prefs.casos + Number(d.d))); ir("entrar", { modo: "bots" }); },
    ePracticar: () => { const n = leerNombre(); if (n) practicar(n, S.prefs.bots); },
    eCrear: () => { const n = leerNombre(); if (n) crearSala(n); },
    eUnirse: () => {
      const n = leerNombre(); if (!n) return;
      const c = limpiarCodigo(document.getElementById("codigo").value);
      if (c.length !== 5) return toast("El código tiene 5 letras.");
      unirse(n, c);
    },
    jSalir: () => {
      const m = M(), E = m && m.E;
      if (!E || E.fase === "sala" || E.fase === "final") return A.jSalirSi();
      const local = E.local;
      modal(`<h3>${local ? "¿Dejar la partida?" : soyAnf() ? "¿Cerrar la sala?" : "¿Salir de la partida?"}</h3><p>${local ? "Se perderá esta partida con los bots." : soyAnf() ? "Eres el anfitrión: si cierras la sala, la partida termina para todos." : "Puedes volver a entrar con el mismo teléfono mientras la sala siga abierta."}</p>
        <div class="fila"><button class="boton fantasma" data-a="cerrarModal">Seguir jugando</button><button class="boton rojo" data-a="${soyAnf() ? "jSalirSi" : "jPausa"}">Salir</button></div>`);
    },
    jPausa: () => { cerrarModal(); desconectar(); ir("inicio"); },
    jSalirSi: () => {
      const m = M();
      if (m && cx) {
        if (soyAnf()) { for (const j of m.H.jugadores) cx.publicar(base() + "/p/" + j.id, "", true); cx.publicar(base() + "/e", "", true); cx.publicar(base() + "/v", "", true); }
        else if (m.E && m.E.fase === "sala") cx.publicar(base() + "/h", JSON.stringify({ id: m.id, t: "salir" }));
      }
      const tmp = cx; cx = null;
      setTimeout(() => { if (tmp) tmp.terminar(); }, 400);
      salirDeSala();
    },
    jCompartir: async () => {
      const m = M(), enlace = k.URL_WEB ? k.URL_WEB + "/?sala=" + m.sala : "";
      const texto = `Entra a mi sala de Coartada con el código ${m.sala}` + (enlace ? `: ${enlace}` : "");
      try {
        if (navigator.share) return await navigator.share({ title: "Coartada", text: texto });
        await navigator.clipboard.writeText(texto); toast("Invitación copiada.");
      } catch (e) { if (!e || e.name !== "AbortError") modal(`<h3>Invita a tus amigos</h3><p>${esc(texto)}</p><div class="fila"><button class="boton" data-a="cerrarModal">Listo</button></div>`); }
    },
    jBot: () => { audio.sfx("pop"); anf.mando.agregarBot(); },
    jQuitar: (d) => anf.mando.quitar(d.id),
    jCfg: (d) => { const v = M().H.cfg.casos + Number(d.d); S.prefs.casos = v; anf.mando.configurar({ casos: v }); },
    jModo: (d) => {
      if (d.v === "ia" && !S.cfg.apiKey) return modal(`<h3>Falta la clave de Groq</h3><p>Los casos con IA necesitan tu clave. Ponla en Ajustes desde el inicio; la sala sigue abierta mientras tanto.</p><div class="fila"><button class="boton" data-a="cerrarModal">Entendido</button></div>`);
      S.prefs.modo = d.v; anf.mando.configurar({ ia: d.v === "ia" });
    },
    jEmpezar: () => anf.mando.empezar(),
    jGirar: () => { if (!u.vista) { u.vista = true; audio.sfx("carta"); vibrar(30); repintar(); } },
    jCarta: () => {
      const m = M();
      if (!m.P) return toast("Tu carta todavía no llega.");
      audio.sfx("carta");
      modal(`<div class="carta abierta suelta ${m.P.culpable ? "mala" : ""}"><div class="cara frente">${htmlCarta(m.E, m.P)}</div></div><div class="fila"><button class="boton" data-a="cerrarModal">Guardar carta</button></div>`, "oscuro");
    },
    jPruebas: () => modal(`<h3>Las pruebas</h3>${tablero(M().E)}<div class="fila"><button class="boton" data-a="cerrarModal">Cerrar</button></div>`, "alto"),
    jListo: () => enviar("listo"),
    jForzar: () => anf.mando.forzar(),
    jR1Set: (d) => {
      const r = u.r1 || (u.r1 = { lugar: null, vio: undefined, vioLugar: null });
      if (d.k === "vio") { r.vio = d.v || null; r.vioLugar = null; } else r[d.k] = Number(d.v);
      audio.sfx("toque"); repintar();
    },
    jR1: () => { const d = u.r1 || {}; audio.sfx("sello"); enviar("r1", { lugar: d.lugar, vio: d.vio === undefined ? null : d.vio, vioLugar: d.vioLugar }); },
    jOp: (d) => { u.op = d.v; audio.sfx("elegir"); repintar(); },
    jR2: () => { if (u.op) { audio.sfx("sello"); enviar("r2", { op: u.op }); } },
    jR3: () => { const w = limpiarPalabra(document.getElementById("jPalabra").value); if (w.length >= 2) { audio.sfx("sello"); enviar("r3", { palabra: w }); } },
    jElegir: (d) => { u.elegido = d.id; audio.sfx("elegir"); repintar(); },
    jVotar: () => { if (u.elegido) { audio.sfx("voto"); vibrar(40); enviar("voto", { a: u.elegido }); } },
    jSeguir: () => anf.mando.continuar(),
    jMasCareo: () => anf.mando.masCareo(),
    jRevelar: () => { audio.sfx("redoble"); const b = document.querySelector(".dock .boton"); if (b) { b.disabled = true; b.textContent = "🥁 …"; } setTimeout(() => { if (anf) anf.mando.continuar(); }, 1400); },
    jAdivinar: (d) => { vibrar(80); audio.sfx("sello"); enviar("adivina", { i: Number(d.i) }); },
  });

  return { reanudar, haySala: () => !!M(), desconectar };
}
