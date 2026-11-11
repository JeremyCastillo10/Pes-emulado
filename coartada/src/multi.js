// Salas: cada jugador en su teléfono. El anfitrión lleva la partida y los demás la siguen.
// Los teléfonos se hablan por un servidor MQTT público (sin cuentas):
//   <base>/e      estado público de la sala (retenido)
//   <base>/p/<id> carta privada de cada jugador (retenido)
//   <base>/h      acciones de los jugadores hacia el anfitrión
//   <base>/v      «1» mientras el anfitrión está conectado
import { crearMqtt } from "./mqtt.js";
import { crearAnfitrion, nuevaSala, MIN_J, MAX_J } from "./anfitrion.js";
import { ESCENARIOS } from "./content.js";

const SERVIDORES = ["wss://broker.emqx.io:8084/mqtt", "wss://broker.hivemq.com:8884/mqtt", "wss://mqtt.eclipseprojects.io/mqtt"];
const LETRAS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const azar = (n) => Math.floor(Math.random() * n);
const nuevoId = () => Math.random().toString(36).slice(2, 10) + Math.random().toString(36).slice(2, 6);

export function instalarMulti(k) {
  const { S, guardar, ir, pintar, esc, cap, toast, modal, cerrarModal, vibrar, pitido, V, A, EFECTOS, pantalla, pararReloj, ponerReloj } = k;
  let cx = null, anf = null, pend = [], conectado = false, anfVivo = true, reenvio = null, latido = null, vigia = null;
  let u = {}; // estado efímero de la pantalla (voto elegido, texto a medio escribir…)
  let firma = "";
  const M = () => S.multi;
  const soyAnf = () => M() && M().rol === "anfitrion";
  const base = () => "coartada/v1/" + M().sala;

  function servidores() {
    const s = window.__coartadaServidores; // solo para las pruebas automáticas
    return Array.isArray(s) && s.length ? s : SERVIDORES;
  }
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
    if (pantalla() !== "multi") return;
    const act = document.activeElement, id = act && act.id, sel = act && act.selectionStart;
    pintar();
    if (id) { const el = document.getElementById(id); if (el && el.focus) { el.focus(); try { el.setSelectionRange(sel, sel); } catch (e) { /* no es texto */ } } }
  }
  function salirDeSala(mensaje) {
    desconectar();
    S.multi = null; u = {}; firma = "";
    cerrarModal();
    ir("inicio");
    if (mensaje) toast(mensaje);
  }

  function conectarAnfitrion() {
    const m = M();
    anf = crearAnfitrion({
      H: m.H,
      ia: () => ({ apiKey: S.cfg.apiKey, modelo: S.cfg.modelo }),
      publicar: ({ estado, privados }) => {
        m.E = estado;
        if (privados) { m.P = privados[m.id] || null; for (const id of Object.keys(privados)) cx.publicar(base() + "/p/" + id, JSON.stringify(privados[id]), true); }
        cx.publicar(base() + "/e", JSON.stringify(estado), true);
        guardar();
        if (estado.aviso && estado.aviso !== u.avisoVisto) { u.avisoVisto = estado.aviso; toast(estado.aviso); }
        repintar();
      },
    });
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
    // El estado retenido se vuelve a publicar cada tanto por si algún mensaje se perdió.
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
        const dentro = E.jugadores.some((j) => j.id === m.id);
        if (!dentro && (m.dentro || E.fase !== "sala")) return salirDeSala(m.dentro ? "Ya no estás en la sala." : "Esa partida ya empezó. Espera a la siguiente.");
        if (dentro) { m.dentro = true; m.nombre = E.jugadores.find((j) => j.id === m.id).nombre; }
        const cambio = !m.E || m.E.rev !== E.rev;
        m.E = E;
        clearTimeout(vigia);
        guardar();
        if (cambio) repintar();
      },
    });
    cx.suscribir(base() + "/e"); cx.suscribir(base() + "/p/" + m.id); cx.suscribir(base() + "/v");
    // Las acciones se reenvían hasta que el anfitrión confirma que las recibió.
    reenvio = setInterval(() => {
      const E = m.E; if (!E) return;
      const ack = (E.acks && E.acks[m.id]) || 0;
      pend = pend.filter((a) => a.n > ack && a.fase === E.fase && (a.t !== "respuesta" || (E.int && E.int.idx === a.idx && E.int.ronda === a.ronda)));
      for (const a of pend) cx.publicar(base() + "/h", JSON.stringify(a));
    }, 2500);
    if (!m.E) vigia = setTimeout(() => { if (M() === m && !m.E) salirDeSala(conectado ? "No existe ninguna sala con ese código." : "No se pudo conectar. Revisa tu internet."); }, 12000);
  }

  /** Envía una acción de jugador (el anfitrión se la aplica a sí mismo). */
  function enviar(t, datos = {}) {
    const m = M();
    const a = { id: m.id, n: ++m.seq, t, fase: m.E.fase, ...datos };
    guardar();
    if (soyAnf()) return anf.accion(a);
    pend.push(a);
    cx.publicar(base() + "/h", JSON.stringify(a));
    repintar();
  }
  const enviado = (t) => pend.some((a) => a.t === t);

  function crearSala(nombre) {
    desconectar();
    const lista = servidores();
    let intento = 0;
    const probar = () => {
      if (intento >= lista.length) { S.multi = null; ir("entrar", { modo: "crear" }); return toast("No se pudo conectar con el servidor de salas. Revisa tu internet."); }
      const indice = intento++;
      const sala = codigoPara(indice), id = nuevoId();
      S.multi = { rol: "anfitrion", sala, id, nombre, seq: 0, E: null, P: null, H: nuevaSala({ sala, id, nombre }) };
      S.multi.H.cfg.casos = S.prefs.casos; S.multi.H.cfg.preguntas = S.prefs.preguntas; S.multi.H.cfg.reloj = S.prefs.reloj;
      S.multi.H.cfg.ia = S.prefs.modo === "ia" && !!S.cfg.apiKey; S.multi.H.cfg.ambientacion = S.prefs.ambientacion; S.multi.H.cfg.tono = S.prefs.tono; S.multi.H.cfg.escenario = S.prefs.escenario;
      const propia = S.multi;
      conectarAnfitrion();
      setTimeout(() => { if (M() === propia && !conectado && !propia.E) { desconectar(); probar(); } }, 6000);
    };
    probar();
    ir("multi");
  }
  function unirse(nombre, codigo) {
    desconectar();
    S.multi = { rol: "invitado", sala: codigo, id: nuevoId(), nombre, seq: 0, E: null, P: null, dentro: false };
    guardar();
    conectarInvitado();
    ir("multi");
  }
  /** Al abrir la app con una sala guardada. */
  function reanudar() {
    if (!M()) return false;
    desconectar();
    if (soyAnf()) { conectarAnfitrion(); anf.mando.reanudar(); }
    else conectarInvitado();
    return true;
  }

  // ---------- Vistas ----------
  const nombreDe = (id) => { const j = M().E.jugadores.find((x) => x.id === id); return j ? j.nombre : "?"; };
  const barra = (titulo) => {
    const m = M(), E = m.E, conCarta = m.P && E && E.caso && m.P.numCaso === E.numCaso && !["sala", "final", "resultado"].includes(E.fase);
    return `<header class="barra"><button class="atras" data-a="mSalir" aria-label="Salir">×</button><h2>${esc(titulo)}</h2>
      ${conCarta ? `<button class="chip chip-btn" data-a="mCarta">Mi carta</button>` : `<span class="chip">Sala ${esc(m.sala)}</span>`}</header>
      ${!conectado ? `<p class="banda">Sin conexión. Reintentando…</p>` : !soyAnf() && !anfVivo ? `<p class="banda">El anfitrión se desconectó. Esperando a que vuelva…</p>` : ""}`;
  };
  const espera = (texto) => `<p class="espera"><i></i>${esc(texto)}</p>`;
  const fijo = (accion, texto, extra = "") => `<button class="btn btn-rojo btn-fijo" data-a="${accion}" ${extra}>${texto}</button>`;
  const contador = (clave, v, min, max) => `<div class="contador"><button data-a="mCfg" data-k="${clave}" data-d="-1" ${v <= min ? "disabled" : ""}>−</button><b>${v}</b><button data-a="mCfg" data-k="${clave}" data-d="1" ${v >= max ? "disabled" : ""}>+</button></div>`;
  const expediente = (c, n) => `
    <article class="papel expediente">
      <span class="sello sello-rojo sello-esq">${c.origen === "ia" ? "CASO IA" : "ARCHIVO"}</span>
      <p class="etiqueta">Expediente ${String(n).padStart(3, "0")}</p>
      <h2 class="titular">${esc(c.titulo)}</h2>
      <p class="relato">${esc(c.relato)}</p>
      <dl class="ficha"><div><dt>Lugar</dt><dd>${esc(cap(c.lugar_crimen))}</dd></div><div><dt>Hora</dt><dd>${esc(c.hora)}</dd></div></dl>
      ${c.pistas.length ? `<h3>Pistas halladas</h3><ul class="pistas">${c.pistas.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>` : ""}
    </article>`;
  function htmlCarta(P) {
    if (P.culpable) return `
      <span class="sello sello-rojo sello-grande">CULPABLE</span>
      <h2>Tú lo hiciste, ${esc(P.nombre)}.</h2>
      <p class="linea"><b>Tu coartada falsa (sugerida)</b>Di que estabas en ${esc(P.coartada.lugar)}, ${esc(P.coartada.actividad)}.</p>
      <p class="linea"><b>Lo que no sabes</b>Esa noche pasó algo que todos los inocentes notaron. Te preguntarán por «eso»: escucha a los demás y finge que también lo viviste.</p>
      <p class="linea"><b>Cómo ganas</b>Que voten a otra persona. Si te atrapan, aún puedes adivinar qué fue «eso».</p>`;
    const c = P.carta;
    return `
      <span class="sello sello-verde sello-grande">INOCENTE</span>
      <h2>${esc(P.nombre)}, esto es lo que viviste.</h2>
      <p class="linea"><b>Dónde estabas</b>En ${esc(c.lugar)}, ${esc(c.actividad)}.</p>
      <p class="linea"><b>Lo que viste</b>${esc(c.visto)}</p>
      ${c.extra ? `<p class="linea"><b>Dato extra</b>${esc(c.extra)}</p>` : ""}
      <p class="linea secreto"><b>Dato secreto · el culpable no lo sabe</b>Esa noche ${esc(c.evento)}.</p>
      <p class="chico">Di la verdad de tu carta. Nunca nombres el dato secreto de forma directa.</p>`;
  }
  const marcador = (E, puntosRonda) => `<table class="marcador">${E.jugadores.slice().sort((a, b) => (E.puntos[b.id] || 0) - (E.puntos[a.id] || 0)).map((j, i) => `
    <tr><td>${i + 1}</td><td>${esc(j.nombre)}${E.culpable === j.id && puntosRonda ? " <small>culpable</small>" : ""}</td><td class="mas">${puntosRonda && puntosRonda[j.id] ? "+" + puntosRonda[j.id] : ""}</td><td><b>${E.puntos[j.id] || 0}</b></td></tr>`).join("")}</table>`;
  const barras = (E) => {
    const max = Math.max(1, ...Object.values(E.conteo.cuenta));
    return E.jugadores.slice().sort((a, b) => E.conteo.cuenta[b.nombre] - E.conteo.cuenta[a.nombre]).map((j) => `
      <div class="barra-voto"><span>${esc(j.nombre)}</span><div><i style="width:${(E.conteo.cuenta[j.nombre] / max) * 100}%"></i></div><b>${E.conteo.cuenta[j.nombre]}</b></div>`).join("");
  };

  V.entrar = () => {
    const ui = k.ui(), crear = ui.modo === "crear";
    return `
    <header class="barra"><button class="atras" data-a="inicio" aria-label="Volver">‹</button><h2>${crear ? "Crear sala" : "Unirme a una sala"}</h2></header>
    <article class="papel">
      <label class="campo"><span>Tu nombre</span>
        <input id="miNombre" maxlength="14" autocomplete="off" autocapitalize="words" placeholder="Como te dicen" value="${esc(S.miNombre || "")}"></label>
      ${crear ? `<p class="chico">Vas a ser el anfitrión: tu teléfono lleva la partida. Mantén la app abierta mientras juegan.</p>` : `
      <label class="campo"><span>Código de la sala</span>
        <input id="codigo" class="codigo-in" maxlength="5" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ABCDE" value="${esc(ui.codigo || "")}"></label>
      <p class="chico">El código de 5 letras aparece en el teléfono de quien creó la sala.</p>`}
    </article>
    ${fijo(crear ? "mCrear" : "mUnirse", crear ? "Crear la sala" : "Entrar")}`;
  };

  V.multi = () => {
    const m = M();
    if (!m) return V.inicio();
    const E = m.E;
    if (!E) return `<header class="barra"><button class="atras" data-a="mSalir" aria-label="Salir">×</button><h2>Conectando</h2></header>
      <section class="centro"><div class="lupa"><i></i></div><h2>${m.rol === "anfitrion" ? "Abriendo la sala" : "Buscando la sala " + esc(m.sala)}</h2><p class="maquina">Un momento…</p></section>`;
    const yo = m.id, anfitrion = soyAnf(), f = E.fase, n = E.jugadores.length;
    const nuevaFirma = f + "|" + E.numCaso + "|" + (E.int ? E.int.ronda + "." + E.int.idx : "");
    if (nuevaFirma !== firma) { firma = nuevaFirma; u = { avisoVisto: u.avisoVisto }; pend = pend.filter((a) => a.fase === f); }
    const progreso = E.numCaso ? `<span>Caso ${E.numCaso} de ${E.cfg.casos}</span>` : "";

    if (f === "sala") {
      const c = anfitrion ? m.H.cfg : E.cfg;
      return `
      ${barra("Sala de espera")}
      <section class="codigo-caja">
        <p class="etiqueta">Código de la sala</p>
        <h1 class="codigo">${esc(m.sala)}</h1>
        <div class="fila"><button class="btn btn-linea btn-chico" data-a="mCompartir">Invitar amigos</button></div>
      </section>
      <article class="papel">
        <h3>Sospechosos <span class="cuenta">${n}/${MAX_J}</span></h3>
        ${E.jugadores.map((j) => `<div class="jug"><span class="avatar">${esc(j.nombre.charAt(0).toUpperCase())}</span><b>${esc(j.nombre)}</b>${j.id === E.anfitrion ? "<small>anfitrión</small>" : ""}${j.id === yo ? "<small>tú</small>" : ""}${anfitrion && j.id !== yo ? `<button class="quitar" data-a="mExpulsar" data-id="${esc(j.id)}" aria-label="Quitar">×</button>` : ""}</div>`).join("")}
        ${n < MIN_J ? `<p class="chico">Hacen falta al menos ${MIN_J} jugadores.</p>` : ""}
      </article>
      ${anfitrion ? `
      <article class="papel">
        <h3>Detective</h3>
        <div class="segmento">
          <button class="${!c.ia ? "on" : ""}" data-a="mModo" data-v="clasico">Clásico<small>casos del archivo</small></button>
          <button class="${c.ia ? "on" : ""}" data-a="mModo" data-v="ia">Detective IA<small>${S.cfg.apiKey ? "casos a la medida" : "requiere clave"}</small></button>
        </div>
        ${c.ia ? `
        <label class="campo"><span>¿Dónde están o de qué quieren el caso?</span>
          <input id="mAmb" maxlength="120" placeholder="Ej.: asado en casa de Jere, viaje a la playa…" value="${esc(c.ambientacion)}"></label>
        <label class="campo"><span>Tono</span>
          <select id="mTono">
            <option value="absurdo" ${c.tono === "absurdo" ? "selected" : ""}>Absurdo (para todos)</option>
            <option value="noir" ${c.tono === "noir" ? "selected" : ""}>Novela negra</option>
            <option value="picante" ${c.tono === "picante" ? "selected" : ""}>Picante (adultos)</option>
          </select></label>
        <p class="chico">Solo tú necesitas la clave de Groq. Cada quien escribe o dicta su respuesta en su teléfono.</p>` : `
        <label class="campo"><span>Escenario</span>
          <select id="mEsc"><option value="azar">Al azar</option>${ESCENARIOS.map((e) => `<option value="${e.id}" ${c.escenario === e.id ? "selected" : ""}>${e.emoji} ${esc(e.nombre)}</option>`).join("")}</select></label>`}
        <div class="ajuste"><span>Casos a resolver</span>${contador("casos", c.casos, 1, 8)}</div>
        <div class="ajuste"><span>Preguntas por jugador</span>${contador("preguntas", c.preguntas, 1, 3)}</div>
        <div class="ajuste"><span>Reloj en las respuestas</span><button class="interruptor ${c.reloj ? "on" : ""}" data-a="mReloj" aria-pressed="${c.reloj}"><i></i></button></div>
      </article>
      ${fijo("mEmpezar", n < MIN_J ? "Esperando jugadores…" : `Empezar con ${n} jugadores`, n < MIN_J ? "disabled" : "")}` : `
      <article class="papel"><h3>Partida</h3><p>${E.cfg.casos} ${E.cfg.casos === 1 ? "caso" : "casos"} · ${E.cfg.preguntas} ${E.cfg.preguntas === 1 ? "pregunta" : "preguntas"} por jugador · ${E.cfg.ia ? "Detective IA" : "Detective clásico"}</p></article>
      ${espera("Esperando a que " + nombreDe(E.anfitrion) + " empiece la partida")}`}`;
    }

    if (f === "cargando") return `${barra("Un momento")}<section class="centro"><div class="lupa"><i></i></div><h2>${esc(E.cargando || "Un momento")}</h2><p class="maquina">${progreso}</p></section>`;

    if (f === "caso") {
      const listo = E.listos.includes(yo) || enviado("listo"), faltan = E.jugadores.filter((j) => !E.listos.includes(j.id));
      return `
      ${barra("El caso")}
      ${expediente(E.caso, E.numCaso)}
      ${listo ? `${espera(faltan.length ? "Faltan por ver su carta: " + faltan.map((j) => j.nombre).join(", ") : "Todos listos")}
        ${anfitrion && faltan.length ? fijo("mForzarCartas", "Empezar sin esperar") : ""}` : `
        <p class="guia">Mira tu carta en secreto. Nadie más debe ver tu pantalla.</p>
        ${fijo(u.vista ? "mListo" : "mCarta", u.vista ? "Ya la memoricé" : "Ver mi carta")}`}`;
    }

    if (f === "interrogatorio") {
      const t = E.int, mio = t.turno === yo, ya = enviado("respuesta");
      return `
      ${barra("Interrogatorio")}
      <div class="progreso"><span>Ronda ${t.ronda} de ${t.total}</span><span>${t.idx + 1}/${t.n}</span></div>
      <div class="barra-prog"><i style="width:${(t.idx / t.n) * 100}%"></i></div>
      <section class="interroga">
        <p class="etiqueta">${mio ? "Te toca responder" : "El detective interroga a"}</p>
        <h1 class="nombre-grande">${esc(nombreDe(t.turno))}</h1>
        <blockquote class="pregunta">${esc(t.pregunta)}</blockquote>
        ${t.fin ? `<div class="reloj" id="mRelojTurno"><i></i><b></b></div>` : ""}
        ${mio ? (t.ia ? `<label class="campo"><span>Responde en voz alta y deja aquí un resumen para el detective (puedes dictarlo con el micrófono del teclado)</span>
            <textarea id="mTexto" rows="3" maxlength="400" placeholder="Lo que respondiste…">${esc(u.texto || "")}</textarea></label>` : `<p class="guia">Responde en voz alta para todos.</p>`)
          : `<p class="guia">${esc(nombreDe(t.turno))} responde en voz alta. Los demás pueden repreguntar.</p>${anfitrion ? `<div class="fila"><button class="btn btn-linea btn-chico" data-a="mSaltar">Saltar este turno</button></div>` : ""}`}
      </section>
      ${mio ? (ya ? espera("Enviando…") : fijo("mRespondi", "Ya respondí")) : ""}`;
    }

    if (f === "careo") return `
      ${barra("Careo")}
      <section class="centro">
        <p class="etiqueta">Todos contra todos</p>
        <h1 class="crono" id="mCrono">2:00</h1>
        ${anfitrion ? `<div class="fila"><button class="btn btn-linea btn-chico" data-a="mMasCareo">+30 s</button></div>` : ""}
        <ul class="tips"><li>Acusen, defiéndanse y pidan detalles.</li><li>¿Quién habló raro de «eso» que pasó?</li><li>¿Las versiones de quienes estaban juntos coinciden?</li></ul>
      </section>
      ${anfitrion ? fijo("mAVotar", "Pasar a la votación") : espera(nombreDe(E.anfitrion) + " abrirá la votación")}`;

    if (f === "voto") {
      const voto = E.votaron.includes(yo) || enviado("voto");
      if (voto) return `
        ${barra("Votación secreta")}
        <section class="centro"><span class="sello sello-verde sello-grande">VOTO ENVIADO</span>
          <p class="guia">Han votado ${E.votaron.length} de ${n}.</p>
          <div class="puntos-paso">${E.jugadores.map((j) => `<i class="${E.votaron.includes(j.id) ? "hecho" : ""}"></i>`).join("")}</div></section>
        ${anfitrion && E.votaron.length < n ? fijo("mCerrarVoto", "Cerrar la votación ya") : espera("Esperando los demás votos")}`;
      return `
        ${barra("Votación secreta")}
        <section class="voto">
          <p class="etiqueta">${esc(m.nombre)}, ¿quién lo hizo?</p>
          <div class="lista-voto">${E.jugadores.filter((j) => j.id !== yo).map((j) => `<button class="sospechoso ${u.elegido === j.id ? "on" : ""}" data-a="mElegir" data-id="${esc(j.id)}"><span class="avatar">${esc(j.nombre.charAt(0).toUpperCase())}</span>${esc(j.nombre)}</button>`).join("")}</div>
        </section>
        ${fijo("mVotar", "Confirmar voto", u.elegido ? "" : "disabled")}`;
    }

    if (f === "veredicto") {
      const v = E.veredicto;
      if (!v) return `
        ${barra("El detective")}
        <section class="centro">${E.sinVeredicto ? `<h2>El detective se quedó sin palabras</h2><p class="guia">${esc(E.sinVeredicto)}</p>${anfitrion ? `<div class="pila"><button class="btn btn-linea" data-a="mReintentar">Reintentar</button></div>` : ""}` : `<div class="lupa"><i></i></div><h2>El detective ordena sus notas</h2><p class="maquina">Ya casi tiene un nombre…</p>`}</section>
        ${anfitrion ? fijo("mARevelacion", "Seguir sin su veredicto") : ""}`;
      return `
        ${barra("El detective")}
        <article class="papel expediente">
          <p class="etiqueta">Informe del detective</p>
          <p class="relato maquina">${esc(v.informe)}</p>
          ${v.contradicciones.length ? `<h3>Lo que no le cuadra</h3><ul class="pistas">${v.contradicciones.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>` : ""}
          <div class="acusacion"><p>${esc(v.frase_final)}</p><span class="sello sello-rojo sello-grande golpe">${esc(v.acusado)}</span></div>
        </article>
        ${anfitrion ? fijo("mARevelacion", "Ver los votos del grupo") : espera("Ahora, los votos del grupo")}`;
    }

    if (f === "revelacion") {
      if (!E.revelado) return `
        ${barra("Los votos")}
        <article class="papel"><h3>El grupo votó</h3>${barras(E)}<p class="guia">${E.conteo.acusado ? `El más votado es <b>${esc(E.conteo.acusado)}</b>.` : "Hay empate: nadie queda señalado."}</p></article>
        ${anfitrion ? fijo("mRevelar", "Revelar al culpable") : espera("Esperando la revelación")}`;
      return `
        ${barra("La verdad")}
        <section class="centro revela"><p class="etiqueta">El culpable era</p><h1 class="nombre-grande golpe">${esc(nombreDe(E.culpable))}</h1>
          <span class="sello sello-verde sello-grande">ESCAPÓ</span><p class="guia">${esc(nombreDe(E.culpable))} engañó al grupo.</p></section>
        ${anfitrion ? fijo("mCerrar", "Ver el resultado") : espera("Esperando el resultado")}`;
    }

    if (f === "ultima") {
      const culp = nombreDe(E.culpable);
      if (E.culpable !== yo) return `
        ${barra("Última jugada")}
        <section class="centro revela"><p class="etiqueta">El culpable era</p><h1 class="nombre-grande golpe">${esc(culp)}</h1>
          <span class="sello sello-rojo sello-grande">ATRAPADO</span>
          <p class="guia">Pero tiene una última jugada: si adivina el dato secreto, rescata 2 puntos. ¡No le den pistas!</p></section>
        ${anfitrion ? fijo("mCerrar", "Saltar la última jugada") : espera(culp + " está eligiendo")}`;
      return `
        ${barra("Última jugada")}
        <section class="voto">
          <p class="etiqueta">Te atraparon, ${esc(culp)}. ¿Qué pasó esa noche?</p>
          <p class="guia">Adivina el dato secreto y rescata 2 puntos.</p>
          ${enviado("adivina") ? espera("Enviando…") : `<div class="lista-voto">${E.opciones.map((o, i) => `<button class="sospechoso opcion" data-a="mAdivinar" data-i="${i}">${esc(cap(o))}</button>`).join("")}</div>`}
        </section>`;
    }

    if (f === "resultado") {
      const r = E.resultado, culp = nombreDe(E.culpable);
      return `
      ${barra("Resultado")}
      <article class="papel expediente">
        <span class="sello sello-rojo sello-esq">${E.atrapado ? "ATRAPADO" : "ESCAPÓ"}</span>
        <p class="etiqueta">Lo que pasó de verdad</p>
        <p class="relato">${esc(r.verdad)}</p>
        <p class="linea secreto"><b>El dato secreto</b>Esa noche ${esc(r.evento)}.</p>
        ${r.eligio ? `<p class="linea"><b>${esc(culp)} apostó por</b>${esc(cap(r.eligio))}. ${r.adivino ? "¡Acertó!" : "Falló."}</p>` : ""}
        <ul class="pistas">${r.motivos.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>
      </article>
      <article class="papel"><h3>Marcador</h3>${marcador(E, r.puntos)}</article>
      <details class="papel"><summary>Ver las cartas de todos</summary>
        ${r.cartas.map((c) => `<p class="linea"><b>${esc(c.jugador)}</b>En ${esc(c.lugar)}, ${esc(c.actividad)}. ${esc(c.visto)}${c.extra ? " " + esc(c.extra) : ""}</p>`).join("")}
        <p class="linea"><b>${esc(culp)} (culpable)</b>Coartada falsa: en ${esc(r.coartada.lugar)}, ${esc(r.coartada.actividad)}.</p>
      </details>
      ${anfitrion ? fijo("mSiguiente", E.numCaso < E.cfg.casos ? "Siguiente caso" : "Ver al ganador") : espera("Esperando a " + nombreDe(E.anfitrion))}`;
    }

    if (f === "final") {
      const orden = E.jugadores.slice().sort((a, b) => (E.puntos[b.id] || 0) - (E.puntos[a.id] || 0)), top = E.puntos[orden[0].id] || 0;
      const ganadores = orden.filter((j) => (E.puntos[j.id] || 0) === top);
      return `
      <section class="centro final">
        <div class="cinta">CASO CERRADO · CASO CERRADO · CASO CERRADO · CASO CERRADO</div>
        <p class="etiqueta">${ganadores.length > 1 ? "Mentes criminales empatadas" : "La mente más brillante"}</p>
        <h1 class="nombre-grande golpe">${ganadores.map((j) => esc(j.nombre)).join(" y ")}</h1>
        <span class="sello sello-verde sello-grande">${top} PUNTOS</span>
        <article class="papel">${marcador(E)}</article>
        <div class="pila">
          ${anfitrion ? `<button class="btn btn-rojo" data-a="mRevancha">Revancha en la misma sala</button><button class="btn btn-linea" data-a="mSalirSi">Cerrar la sala</button>` : `${espera("El anfitrión puede abrir la revancha")}<button class="btn btn-linea" data-a="mSalirSi">Salir de la sala</button>`}
        </div>
      </section>`;
    }
    return `${barra("Sala")}<section class="centro"><p class="guia">Actualiza la app para seguir esta partida.</p></section>`;
  };

  // ---------- Efectos (relojes) ----------
  EFECTOS.multi = () => {
    const m = M(), E = m && m.E;
    if (!E) return;
    if (E.fase === "interrogatorio" && E.int.fin) {
      const el = document.getElementById("mRelojTurno");
      const tic = () => {
        if (!el.isConnected) return pararReloj();
        const s = Math.max(0, Math.ceil((E.int.fin - Date.now()) / 1000));
        el.querySelector("b").textContent = Math.min(45, s);
        el.querySelector("i").style.width = Math.min(100, (s / 45) * 100) + "%";
        if (s === 0 && !el.classList.contains("fin")) { el.classList.add("fin"); el.querySelector("i").style.width = "100%"; if (E.int.turno === m.id && !u.sono) { u.sono = true; vibrar([120, 80, 120]); pitido(); } }
      };
      tic(); ponerReloj(tic, 500);
    }
    if (E.fase === "careo") {
      const el = document.getElementById("mCrono");
      const tic = () => {
        if (!el.isConnected) return pararReloj();
        const s = Math.max(0, Math.ceil((E.careoFin - Date.now()) / 1000));
        el.textContent = Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
        el.classList.toggle("fin", s === 0);
        if (s === 0 && !u.sono) { u.sono = true; vibrar([200, 100, 200]); pitido(); }
      };
      tic(); ponerReloj(tic, 500);
    }
    const t = document.getElementById("mTexto");
    if (t) t.addEventListener("input", () => { u.texto = t.value; });
    const amb = document.getElementById("mAmb"), tono = document.getElementById("mTono"), escn = document.getElementById("mEsc");
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
    const n = (document.getElementById("miNombre").value || "").trim().slice(0, 14);
    if (!n) { toast("Escribe tu nombre."); return null; }
    S.miNombre = n; guardar();
    return n;
  }
  function abrirCarta() {
    const P = M().P;
    if (!P) return toast("Tu carta todavía no llega. Espera un momento.");
    modal(`<div class="carta ${P.culpable ? "carta-culpable" : ""}" id="mCartaCaja">
        <div class="carta-dorso"><div class="huella"></div><p>Mantén presionado<br>para ver tu carta</p><small>${esc(P.nombre)}</small></div>
        <div class="carta-frente">${htmlCarta(P)}</div></div>
      <div class="fila"><button class="btn btn-linea" data-a="mCerrarCarta">Cerrar</button></div>`);
    const carta = document.getElementById("mCartaCaja");
    carta.addEventListener("pointerdown", (e) => { e.preventDefault(); carta.classList.add("abierta"); u.vista = true; });
    ["pointerup", "pointerleave", "pointercancel"].forEach((ev) => carta.addEventListener(ev, () => carta.classList.remove("abierta")));
    carta.addEventListener("contextmenu", (e) => e.preventDefault());
  }
  Object.assign(A, {
    salaCrear: () => ir("entrar", { modo: "crear" }),
    salaUnirse: () => ir("entrar", { modo: "unirse", codigo: k.ui().codigo || "" }),
    salaVolver: () => { if (M()) { if (!cx) reanudar(); ir("multi"); } },
    mCrear: () => { const n = leerNombre(); if (n) crearSala(n); },
    mUnirse: () => {
      const n = leerNombre(); if (!n) return;
      const c = limpiarCodigo(document.getElementById("codigo").value);
      if (c.length !== 5) return toast("El código tiene 5 letras.");
      unirse(n, c);
    },
    mSalir: () => {
      const E = M() && M().E;
      if (!E || E.fase === "sala" || E.fase === "final") return A.mSalirSi();
      modal(`<h3>${soyAnf() ? "¿Cerrar la sala?" : "¿Salir de la partida?"}</h3><p>${soyAnf() ? "Eres el anfitrión: si cierras la sala, la partida termina para todos." : "Puedes volver a entrar con el mismo teléfono mientras la sala siga abierta."}</p>
        <div class="fila"><button class="btn btn-linea" data-a="cerrarModal">Seguir jugando</button><button class="btn btn-rojo" data-a="${soyAnf() ? "mSalirSi" : "mPausa"}">${soyAnf() ? "Cerrar la sala" : "Salir"}</button></div>`);
    },
    mPausa: () => { cerrarModal(); desconectar(); ir("inicio"); },
    mSalirSi: () => {
      const m = M();
      if (m && cx) {
        if (soyAnf()) { // borra los mensajes retenidos de la sala
          for (const j of m.H.jugadores) cx.publicar(base() + "/p/" + j.id, "", true);
          cx.publicar(base() + "/e", "", true); cx.publicar(base() + "/v", "", true);
        } else if (m.E && m.E.fase === "sala") cx.publicar(base() + "/h", JSON.stringify({ id: m.id, t: "salir" }));
      }
      const tmp = cx; cx = null;
      setTimeout(() => { if (tmp) tmp.terminar(); }, 400);
      salirDeSala();
    },
    mCompartir: async () => {
      const m = M(), enlace = k.URL_WEB ? k.URL_WEB + "/?sala=" + m.sala : "";
      const texto = `Entra a mi sala de Coartada con el código ${m.sala}` + (enlace ? `: ${enlace}` : "");
      try {
        if (navigator.share) return await navigator.share({ title: "Coartada", text: texto });
        await navigator.clipboard.writeText(texto); toast("Invitación copiada.");
      } catch (e) { if (!e || e.name !== "AbortError") modal(`<h3>Invita a tus amigos</h3><p>${esc(texto)}</p><div class="fila"><button class="btn btn-rojo" data-a="cerrarModal">Listo</button></div>`); }
    },
    mExpulsar: (d) => anf.mando.expulsar(d.id),
    mModo: (d) => {
      if (d.v === "ia" && !S.cfg.apiKey) return modal(`<h3>Falta la clave</h3><p>El Detective IA necesita tu clave de Groq. Ponla en Ajustes (desde el inicio); la sala sigue abierta mientras tanto.</p><div class="fila"><button class="btn btn-rojo" data-a="cerrarModal">Entendido</button></div>`);
      S.prefs.modo = d.v; anf.mando.configurar({ ia: d.v === "ia" });
    },
    mCfg: (d) => { const c = M().H.cfg, v = c[d.k] + Number(d.d); S.prefs[d.k] = v; anf.mando.configurar({ [d.k]: v }); },
    mReloj: () => { const v = !M().H.cfg.reloj; S.prefs.reloj = v; anf.mando.configurar({ reloj: v }); },
    mEmpezar: () => anf.mando.empezar(),
    mCarta: () => abrirCarta(),
    mCerrarCarta: () => { cerrarModal(); repintar(); },
    mListo: () => enviar("listo"),
    mForzarCartas: () => anf.mando.forzarCartas(),
    mRespondi: () => { const E = M().E, t = document.getElementById("mTexto"); enviar("respuesta", { texto: t ? t.value.trim() : "", idx: E.int.idx, ronda: E.int.ronda }); },
    mSaltar: () => anf.mando.saltarTurno(),
    mMasCareo: () => anf.mando.masCareo(),
    mAVotar: () => anf.mando.aVotar(),
    mElegir: (d) => { u.elegido = d.id; repintar(); },
    mVotar: () => { if (u.elegido) { vibrar(30); enviar("voto", { a: u.elegido }); } },
    mCerrarVoto: () => anf.mando.cerrarVoto(),
    mReintentar: () => anf.mando.reintentarVeredicto(),
    mARevelacion: () => anf.mando.aRevelacion(),
    mRevelar: () => anf.mando.revelar(),
    mCerrar: () => anf.mando.cerrar(),
    mAdivinar: (d) => { vibrar(120); enviar("adivina", { i: Number(d.i) }); },
    mSiguiente: () => anf.mando.siguiente(),
    mRevancha: () => anf.mando.revancha(),
  });

  return { reanudar, haySala: () => !!M(), desconectar };
}
