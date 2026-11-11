// Lógica del anfitrión de una sala: su teléfono lleva la partida y publica el estado a los demás.
// No sabe nada de la red ni de la pantalla: recibe acciones y avisa con `publicar`.
import { generarCasoLocal, armarCasoIA, preguntasLocales, contarVotos, puntuar, opcionesEvento, shuffle, pick } from "./engine.js";
import { ErrorIA, generarCasoIA, preguntasIA, veredictoIA } from "./ai.js";

export const MIN_J = 3, MAX_J = 10;
const SEG_TURNO = 45, SEG_CAREO = 120;

export function nuevaSala({ sala, id, nombre }) {
  return {
    sala, rev: 0, fase: "sala", anfitrion: id, jugadores: [{ id, nombre }],
    cfg: { casos: 3, preguntas: 2, ia: false, ambientacion: "", tono: "absurdo", escenario: "azar", reloj: true },
    numCaso: 0, puntos: {}, acks: {}, usados: [], culpablesPrevios: [], ronda: null, aviso: "",
  };
}

/**
 * H: estado completo de la sala (se guarda en el teléfono del anfitrión).
 * ia(): devuelve { apiKey, modelo } vigentes.
 * publicar({ estado, privados }): estado público y, si toca, { id: carta } para cada jugador.
 */
export function crearAnfitrion({ H, ia, publicar, ahora = () => Date.now(), random = Math.random }) {
  let veredictoPendiente = null;
  const nombreDe = (id) => (H.jugadores.find((j) => j.id === id) || {}).nombre;
  const idDe = (nombre) => (H.jugadores.find((j) => j.nombre === nombre) || {}).id;
  const nombres = () => H.jugadores.map((j) => j.nombre);
  const R = () => H.ronda;
  const conIA = () => R() && R().origen === "ia";

  function publico() {
    const r = H.ronda, f = H.fase;
    const E = {
      rev: H.rev, sala: H.sala, fase: f, anfitrion: H.anfitrion, jugadores: H.jugadores,
      cfg: { casos: H.cfg.casos, preguntas: H.cfg.preguntas, ia: H.cfg.ia, reloj: H.cfg.reloj },
      numCaso: H.numCaso, puntos: H.puntos, acks: H.acks, aviso: H.aviso || "",
    };
    if (f === "cargando") E.cargando = H.cargando || "";
    if (!r || !r.caso) return E;
    const c = r.caso;
    E.caso = { titulo: c.titulo, relato: c.relato, lugar_crimen: c.lugar_crimen, hora: c.hora, pistas: c.pistas, origen: r.origen };
    if (f === "caso") E.listos = r.listos;
    if (f === "interrogatorio") {
      const turno = r.orden[r.idx];
      E.int = { ronda: r.rondaInt, total: H.cfg.preguntas, idx: r.idx, n: r.orden.length, turno, pregunta: r.preguntas[nombreDe(turno)], fin: r.turnoFin, ia: conIA() };
    }
    if (f === "careo") E.careoFin = r.careoFin;
    if (f === "voto") E.votaron = Object.keys(r.votos);
    if (f === "veredicto") { E.veredicto = r.veredicto; E.sinVeredicto = r.errorVeredicto || ""; }
    if (["revelacion", "ultima", "resultado"].includes(f)) {
      const t = contarVotos(votosPorNombre(), nombres());
      E.conteo = { cuenta: t.cuenta, acusado: t.acusado };
    }
    if ((f === "revelacion" && r.revelado) || f === "ultima" || f === "resultado") { E.culpable = r.culpable; E.atrapado = contarVotos(votosPorNombre(), nombres()).acusado === nombreDe(r.culpable); }
    if (f === "revelacion") E.revelado = !!r.revelado;
    if (f === "ultima") E.opciones = r.opciones;
    if (f === "resultado") {
      E.resultado = {
        puntos: r.resultado.puntosId, motivos: r.resultado.motivos, verdad: c.verdad, evento: c.evento_secreto,
        cartas: c.cartas, coartada: c.coartada_falsa, adivino: r.adivino, eligio: r.eligio || null,
      };
    }
    return E;
  }
  function privados() {
    const r = H.ronda;
    if (!r || !r.caso) return null;
    const out = {};
    for (const j of H.jugadores) {
      const base = { numCaso: H.numCaso, nombre: j.nombre };
      if (j.id === r.culpable) out[j.id] = { ...base, culpable: true, coartada: r.caso.coartada_falsa };
      else {
        const k = r.caso.cartas.find((x) => x.jugador === j.nombre);
        out[j.id] = { ...base, culpable: false, carta: k ? { lugar: k.lugar, actividad: k.actividad, visto: k.visto, extra: k.extra, evento: r.caso.evento_secreto } : null };
      }
    }
    return out;
  }
  function emitir(conPrivados = false) {
    H.rev++;
    publicar({ estado: publico(), privados: conPrivados ? privados() : null });
  }
  const votosPorNombre = () => Object.fromEntries(Object.entries(R().votos).map(([a, b]) => [nombreDe(a), nombreDe(b)]).filter(([a, b]) => a && b));

  // ---------- Fases ----------
  async function iniciarCaso() {
    H.numCaso++;
    let candidatos = H.jugadores.filter((j) => !H.culpablesPrevios.includes(j.id));
    if (!candidatos.length) { H.culpablesPrevios = []; candidatos = H.jugadores.slice(); }
    const culp = pick(random, candidatos);
    H.culpablesPrevios.push(culp.id);
    const r = H.ronda = { culpable: culp.id, caso: null, origen: "local", listos: [], entradas: [], rondaInt: 1, orden: [], idx: 0, preguntas: {}, turnoFin: null, careoFin: null, votos: {}, veredicto: null, errorVeredicto: null, revelado: false, opciones: null, adivino: null, eligio: null, resultado: null };
    veredictoPendiente = null;
    H.aviso = "";
    H.fase = "cargando"; H.cargando = H.cfg.ia ? "El detective abre un nuevo expediente" : "Abriendo el expediente";
    emitir();
    if (H.cfg.ia) {
      try {
        const material = await generarCasoIA({ ...ia(), jugadores: nombres(), culpable: culp.nombre, ambientacion: H.cfg.ambientacion, tono: H.cfg.tono, titulosUsados: H.usados });
        if (H.ronda !== r) return;
        r.caso = armarCasoIA({ jugadores: nombres(), culpable: culp.nombre, material, random });
        r.origen = "ia";
      } catch (e) {
        if (H.ronda !== r) return;
        H.aviso = (e instanceof ErrorIA ? e.message : "El caso de la IA salió defectuoso.") + " Se usa un caso del archivo.";
      }
    }
    if (!r.caso) r.caso = generarCasoLocal({ jugadores: nombres(), culpable: culp.nombre, escenarioId: H.cfg.escenario, usados: H.usados, random });
    H.usados.push(r.caso.titulo);
    H.fase = "caso";
    emitir(true);
  }
  function cargarRonda(preguntas) {
    const r = R();
    r.orden = shuffle(random, H.jugadores.map((j) => j.id));
    r.idx = 0; r.preguntas = preguntas;
    r.turnoFin = H.cfg.reloj ? ahora() + SEG_TURNO * 1000 : null;
  }
  function empezarInterrogatorio() {
    const r = R();
    r.rondaInt = 1; r.entradas = [];
    cargarRonda(preguntasLocales({ ronda: 1, jugadores: nombres(), caso: r.caso, random }));
    H.fase = "interrogatorio";
    emitir();
  }
  async function registrarRespuesta(texto) {
    const r = R(), turno = r.orden[r.idx], nombre = nombreDe(turno);
    r.entradas.push({ ronda: r.rondaInt, jugador: nombre, pregunta: r.preguntas[nombre], respuesta: String(texto || "").slice(0, 400) });
    r.idx++;
    if (r.idx < r.orden.length) { r.turnoFin = H.cfg.reloj ? ahora() + SEG_TURNO * 1000 : null; return emitir(); }
    if (r.rondaInt >= H.cfg.preguntas) return empezarCareo();
    r.rondaInt++;
    let deIA = null;
    if (conIA()) {
      H.fase = "cargando"; H.cargando = "El detective repasa sus notas";
      emitir();
      try { deIA = await preguntasIA({ ...ia(), caso: r.caso, jugadores: nombres(), entradas: r.entradas, ronda: r.rondaInt, ultima: r.rondaInt >= H.cfg.preguntas }); }
      catch (e) { H.aviso = (e instanceof ErrorIA ? e.message : "La IA falló.") + " Siguen las preguntas clásicas."; }
      if (H.ronda !== r) return;
    }
    cargarRonda({ ...preguntasLocales({ ronda: r.rondaInt, jugadores: nombres(), caso: r.caso, random }), ...(deIA || {}) });
    H.fase = "interrogatorio";
    emitir();
  }
  function pedirVeredicto() {
    const r = R();
    r.errorVeredicto = null;
    veredictoPendiente = veredictoIA({ ...ia(), caso: r.caso, jugadores: nombres(), entradas: r.entradas })
      .then((v) => { if (H.ronda === r) r.veredicto = v; })
      .catch((e) => { if (H.ronda === r) r.errorVeredicto = e instanceof ErrorIA ? e.message : "La IA falló."; })
      .then(() => { if (H.ronda === r && H.fase === "veredicto") emitir(); });
  }
  function empezarCareo() {
    const r = R();
    // El veredicto de la IA se pide ya, mientras el grupo discute, para no hacer esperar.
    if (conIA() && !r.veredicto) pedirVeredicto();
    r.careoFin = ahora() + SEG_CAREO * 1000;
    H.fase = "careo";
    emitir();
  }
  function trasVotar() {
    const r = R();
    if (conIA()) { H.fase = "veredicto"; if (!r.veredicto && !veredictoPendiente) pedirVeredicto(); }
    else H.fase = "revelacion";
    emitir();
  }
  function cerrarRonda(adivino, eligio) {
    const r = R();
    r.adivino = adivino; r.eligio = eligio || null;
    const res = puntuar({ jugadores: nombres(), culpable: nombreDe(r.culpable), votos: votosPorNombre(), adivinoEvento: adivino === true, acusadoIA: r.veredicto ? r.veredicto.acusado : null });
    const puntosId = {};
    for (const j of H.jugadores) { puntosId[j.id] = res.puntos[j.nombre] || 0; H.puntos[j.id] = (H.puntos[j.id] || 0) + puntosId[j.id]; }
    r.resultado = { puntosId, motivos: res.motivos };
    H.fase = "resultado";
    emitir();
  }

  // ---------- Acciones de los jugadores (llegan por la red o del propio anfitrión) ----------
  function accion(m) {
    if (!m || typeof m !== "object" || typeof m.id !== "string") return;
    const esJugador = H.jugadores.some((j) => j.id === m.id);
    if (typeof m.n === "number") {
      if (esJugador && m.n <= (H.acks[m.id] || 0)) return; // repetida
    }
    const r = H.ronda;
    let cambio = false;
    if (m.t === "unirse") {
      if (esJugador) cambio = true; // reconexión: se le reenvía el estado
      else if (H.fase === "sala" && H.jugadores.length < MAX_J) {
        let nombre = String(m.nombre || "").trim().slice(0, 14) || "Jugador";
        const base = nombre; let k = 2;
        while (H.jugadores.some((j) => j.nombre.toLowerCase() === nombre.toLowerCase())) nombre = (base.slice(0, 12) + " " + k++);
        H.jugadores.push({ id: m.id, nombre });
        cambio = true;
      } else return;
    } else if (!esJugador) return;
    else if (m.t === "salir" && H.fase === "sala" && m.id !== H.anfitrion) { H.jugadores = H.jugadores.filter((j) => j.id !== m.id); delete H.acks[m.id]; return emitir(); }
    else if (m.t === "listo" && H.fase === "caso") {
      if (!r.listos.includes(m.id)) r.listos.push(m.id);
      H.acks[m.id] = m.n || H.acks[m.id] || 0;
      if (H.jugadores.every((j) => r.listos.includes(j.id))) return empezarInterrogatorio();
      cambio = true;
    } else if (m.t === "respuesta" && H.fase === "interrogatorio" && r.orden[r.idx] === m.id && m.idx === r.idx && m.ronda === r.rondaInt) {
      H.acks[m.id] = m.n || H.acks[m.id] || 0;
      return registrarRespuesta(m.texto);
    } else if (m.t === "voto" && H.fase === "voto" && m.a !== m.id && H.jugadores.some((j) => j.id === m.a)) {
      r.votos[m.id] = m.a;
      H.acks[m.id] = m.n || H.acks[m.id] || 0;
      if (H.jugadores.every((j) => r.votos[j.id])) return trasVotar();
      cambio = true;
    } else if (m.t === "adivina" && H.fase === "ultima" && m.id === r.culpable && r.opciones[m.i] != null) {
      H.acks[m.id] = m.n || H.acks[m.id] || 0;
      return cerrarRonda(r.opciones[m.i] === r.caso.evento_secreto, r.opciones[m.i]);
    }
    if (typeof m.n === "number" && H.jugadores.some((j) => j.id === m.id)) H.acks[m.id] = Math.max(H.acks[m.id] || 0, m.n);
    if (cambio) emitir(m.t === "unirse" && H.fase !== "sala");
  }

  // ---------- Controles del anfitrión ----------
  const mando = {
    configurar(cambios) { if (H.fase !== "sala") return; Object.assign(H.cfg, cambios); emitir(); },
    expulsar(id) { if (H.fase !== "sala" || id === H.anfitrion) return; H.jugadores = H.jugadores.filter((j) => j.id !== id); delete H.acks[id]; emitir(); },
    empezar() { if (H.fase !== "sala" || H.jugadores.length < MIN_J) return; H.numCaso = 0; H.puntos = Object.fromEntries(H.jugadores.map((j) => [j.id, 0])); H.usados = []; H.culpablesPrevios = []; return iniciarCaso(); },
    forzarCartas() { if (H.fase === "caso") empezarInterrogatorio(); },
    saltarTurno() { if (H.fase === "interrogatorio") return registrarRespuesta(""); },
    masCareo() { if (H.fase === "careo") { R().careoFin = Math.max(R().careoFin, ahora()) + 30000; emitir(); } },
    aVotar() { if (H.fase === "careo") { R().votos = {}; H.fase = "voto"; emitir(); } },
    cerrarVoto() { if (H.fase === "voto" && Object.keys(R().votos).length) trasVotar(); },
    reintentarVeredicto() { if (H.fase === "veredicto" && !R().veredicto) { pedirVeredicto(); emitir(); } },
    aRevelacion() { if (H.fase === "veredicto") { H.fase = "revelacion"; emitir(); } },
    revelar() {
      if (H.fase !== "revelacion" || R().revelado) return;
      const r = R(); r.revelado = true;
      if (contarVotos(votosPorNombre(), nombres()).acusado === nombreDe(r.culpable)) { r.opciones = opcionesEvento(r.caso, random); H.fase = "ultima"; }
      emitir();
    },
    cerrar() { if (H.fase === "revelacion" && R().revelado) cerrarRonda(null); else if (H.fase === "ultima") cerrarRonda(false); },
    siguiente() { if (H.fase !== "resultado") return; if (H.numCaso < H.cfg.casos) return iniciarCaso(); H.fase = "final"; emitir(); },
    revancha() { if (H.fase === "final") { H.fase = "sala"; H.ronda = null; H.numCaso = 0; H.puntos = {}; emitir(); } },
    /** Tras reabrir la app: retoma lo que quedó a medias y vuelve a publicar todo. */
    reanudar() {
      if (H.fase === "cargando") {
        const r = H.ronda;
        if (!r || !r.caso) { H.numCaso = Math.max(0, H.numCaso - 1); H.culpablesPrevios.pop(); return iniciarCaso(); }
        cargarRonda(preguntasLocales({ ronda: r.rondaInt, jugadores: nombres(), caso: r.caso, random }));
        H.fase = "interrogatorio";
      }
      emitir(true);
    },
    republicar() { publicar({ estado: publico(), privados: privados() }); },
  };
  return { accion, mando, publico, privados };
}
