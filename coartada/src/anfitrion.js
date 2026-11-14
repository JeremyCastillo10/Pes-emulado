// La partida: el teléfono anfitrión (o el único, si se juega con bots) lleva el estado y mueve a los bots.
// No sabe de red ni de pantallas: recibe acciones y avisa con `publicar`.
import {
  MIN_J, MAX_J, pick, shuffle, armarCaso, materialLocal, materialIA, opcionesEvento, declaracionVerdadera, declaracionValida,
  analizarR1, limpiarPalabra, palabraProhibida, botR1, botR2, botR3, botVoto, botAdivina, charlaBots, detectiveLocal, contarVotos, puntuar,
} from "./engine.js";
import { AVATARES, NOMBRES_BOT, PREGUNTAS_R2 } from "./content.js";
import { ErrorIA, generarCasoIA, veredictoIA } from "./ai.js";

export { MIN_J, MAX_J };
const SEG_CAREO = 90;
const nuevoId = (r) => "b" + Math.floor(r() * 1e9).toString(36) + Math.floor(r() * 1e9).toString(36);

export function nuevaSala({ sala, id, nombre, local = false }) {
  return {
    sala, local, rev: 0, fase: "sala", anfitrion: id, jugadores: [{ id, nombre, bot: false, av: 0 }],
    cfg: { casos: 3, ia: false, ambientacion: "", tono: "absurdo", escenario: "azar" },
    numCaso: 0, puntos: {}, acks: {}, usados: [], culpablesPrevios: [], ronda: null, aviso: "",
  };
}

/**
 * H: estado completo (se guarda en el teléfono del anfitrión).
 * ia(): { apiKey, modelo }.   publicar({ estado, privados }).
 * despues(ms, fn): temporizador (los bots «piensan» un momento); en las pruebas es inmediato.
 */
export function crearAnfitrion({ H, ia, publicar, despues = (ms, fn) => setTimeout(fn, ms), ahora = () => Date.now(), random = Math.random }) {
  const R = () => H.ronda;
  const ids = () => H.jugadores.map((j) => j.id);
  const jug = (id) => H.jugadores.find((j) => j.id === id);
  const humanos = () => H.jugadores.filter((j) => !j.bot);
  const pub = () => { const r = R(); return { r1: r.r1v ? r.r1 : null, analisis: r.r1v ? r.analisis : null, r2: r.r2v ? r.r2 : null, r3: r.r3v ? r.r3 : null }; };
  const todo = () => { const r = R(); return { r1: r.r1, analisis: r.analisis, r2: r.r2, r3: r.r3 }; };

  // ---------- Estado público y cartas privadas ----------
  function publico() {
    const r = H.ronda, f = H.fase;
    const E = {
      rev: H.rev, sala: H.sala, local: !!H.local, fase: f, anfitrion: H.anfitrion, jugadores: H.jugadores,
      cfg: { casos: H.cfg.casos, ia: H.cfg.ia }, numCaso: H.numCaso, puntos: H.puntos, acks: H.acks, aviso: H.aviso || "",
    };
    if (f === "cargando") E.cargando = H.cargando || "";
    if (!r || !r.caso) return E;
    const c = r.caso;
    E.caso = { emoji: c.emoji, titulo: c.titulo, relato: c.relato, lugares: c.lugares, lugar_crimen: c.lugar_crimen, origen: r.origen, tipoR2: c.tipoR2 };
    if (["caso", "r1", "r2", "r3", "voto"].includes(f)) E.listos = r.listos;
    if (r.r1v) { E.r1 = r.r1; E.analisis = r.analisis; }
    if (r.r2v) E.r2 = r.r2;
    if (r.r3v) E.r3 = r.r3;
    if (["r1v", "r2v", "r3v"].includes(f)) E.charla = r.charla || [];
    if (f === "careo") E.careoFin = r.careoFin;
    const tras = ["veredicto", "revelacion", "ultima", "resultado"].includes(f);
    if (tras) { const t = contarVotos(r.votos, ids()); E.conteo = { cuenta: t.cuenta, acusado: t.acusado }; E.votos = r.votos; E.veredicto = r.veredicto; }
    if ((f === "revelacion" && r.revelado) || f === "ultima" || f === "resultado") { E.culpable = c.culpable.id; E.atrapado = contarVotos(r.votos, ids()).acusado === c.culpable.id; }
    if (f === "revelacion") E.revelado = !!r.revelado;
    if (f === "ultima") E.opciones = r.opciones;
    if (f === "resultado") E.resultado = { puntos: r.resultado.puntos, motivos: r.resultado.motivos, verdad: c.verdad, evento: { t: c.evento.t, e: c.evento.e }, eligio: r.eligio, adivino: r.adivino, cartas: c.cartas, seguro: c.culpable.seguro };
    return E;
  }
  function privados() {
    const r = H.ronda;
    if (!r || !r.caso) return null;
    const c = r.caso, out = {};
    for (const j of humanos()) {
      if (j.id === c.culpable.id) out[j.id] = { numCaso: H.numCaso, culpable: true, seguro: c.culpable.seguro, pista: c.culpable.pista, rumor: c.culpable.rumor };
      else out[j.id] = { numCaso: H.numCaso, culpable: false, lugar: c.cartas[j.id].lugar, vio: c.cartas[j.id].vio, evento: { t: c.evento.t, e: c.evento.e } };
    }
    return out;
  }
  function emitir(conPrivados = false) { H.rev++; publicar({ estado: publico(), privados: conPrivados ? privados() : null }); }

  // ---------- Bots ----------
  /** Programa la jugada de cada bot para la fase actual. */
  function moverBots() {
    const r = R(), f = H.fase;
    H.jugadores.filter((j) => j.bot).forEach((b, i) => {
      despues(700 + i * 450 + Math.floor(random() * 900), () => {
        if (H.ronda !== r || H.fase !== f || r.listos.includes(b.id)) return;
        if (f === "caso") aplicar(b.id, "listo");
        else if (f === "r1") aplicar(b.id, "r1", botR1(r.caso, b.id, random));
        else if (f === "r2") aplicar(b.id, "r2", { op: botR2(r.caso, b.id, random) });
        else if (f === "r3") aplicar(b.id, "r3", { palabra: botR3(r.caso, b.id, { ...pub(), r3: r.r3 }, random) });
        else if (f === "voto") aplicar(b.id, "voto", { a: botVoto(r.caso, b.id, todo(), ids(), random) });
      });
    });
  }
  function entrar(fase) { R().listos = []; H.fase = fase; emitir(); moverBots(); }

  // ---------- Fases ----------
  async function iniciarCaso() {
    H.numCaso++;
    let cand = H.jugadores.filter((j) => !H.culpablesPrevios.includes(j.id));
    if (!cand.length) { H.culpablesPrevios = []; cand = H.jugadores.slice(); }
    const culp = pick(random, cand);
    H.culpablesPrevios.push(culp.id);
    const r = H.ronda = { caso: null, origen: "local", listos: [], r1: {}, r1v: false, analisis: null, r2: {}, r2v: false, r3: {}, r3v: false, charla: [], votos: {}, veredicto: null, careoFin: null, revelado: false, opciones: null, adivino: null, eligio: null, resultado: null };
    H.aviso = ""; H.fase = "cargando"; H.cargando = H.cfg.ia ? "El detective escribe un caso a la medida" : "Abriendo el expediente";
    emitir();
    let material = null;
    if (H.cfg.ia) {
      // Dos intentos: a veces la IA entrega un caso que no pasa la revisión (por ejemplo, el relato delata el secreto).
      for (let intento = 0; intento < 2 && !material; intento++) {
        try {
          const crudo = await generarCasoIA({ ...ia(), jugadores: H.jugadores.map((j) => j.nombre), ambientacion: H.cfg.ambientacion, tono: H.cfg.tono, titulosUsados: H.usados });
          if (H.ronda !== r) return;
          material = materialIA(crudo, { nJugadores: H.jugadores.length });
          r.origen = "ia";
        } catch (e) {
          if (H.ronda !== r) return;
          H.aviso = (e instanceof ErrorIA ? e.message : "El caso de la IA salió defectuoso.") + " Se usa un caso del archivo.";
          if (e instanceof ErrorIA) break; // sin clave, sin red o sin cupo: no tiene sentido repetir
        }
      }
      if (material) H.aviso = "";
    }
    if (!material) material = materialLocal({ escenarioId: H.cfg.escenario, usados: H.usados, culpableNombre: culp.nombre, random });
    r.caso = armarCaso({ jugadores: H.jugadores, culpable: culp.id, material, random });
    if (r.origen === "ia") r.caso.verdad = r.caso.verdad.replace(/\{culpable\}/g, culp.nombre);
    H.usados.push(r.caso.titulo);
    H.fase = "caso"; r.listos = [];
    emitir(true);
    moverBots();
  }
  function cerrarR(n) {
    const r = R();
    if (n === 1) { r.analisis = analizarR1(r.r1, ids()); r.r1v = true; }
    if (n === 2) r.r2v = true;
    if (n === 3) r.r3v = true;
    r.charla = charlaBots(r.caso, pub(), H.jugadores, "r" + n, random);
    H.fase = "r" + n + "v";
    emitir();
  }
  function trasVotar() {
    const r = R();
    r.veredicto = detectiveLocal(r.caso, todo(), H.jugadores, random);
    H.fase = "veredicto";
    emitir();
    if (r.origen === "ia") { // la IA redacta el informe; el del archivo queda de respaldo
      veredictoIA({ ...ia(), caso: r.caso, jugadores: H.jugadores, pruebas: todo(), base: r.veredicto })
        .then((v) => { if (H.ronda === r && H.fase === "veredicto" && v) { r.veredicto = v; emitir(); } })
        .catch(() => { /* se queda el veredicto del archivo */ });
    }
  }
  function cerrarRonda(adivino, eligio) {
    const r = R();
    r.adivino = adivino; r.eligio = eligio || null;
    const res = puntuar({ ids: ids(), culpable: r.caso.culpable.id, votos: r.votos, adivino: adivino === true, acusadoDetective: r.veredicto ? r.veredicto.acusado : null });
    for (const id of ids()) H.puntos[id] = (H.puntos[id] || 0) + res.puntos[id];
    r.resultado = { puntos: res.puntos, motivos: res.motivos };
    H.fase = "resultado";
    emitir();
  }
  function revelar() {
    const r = R(), c = r.caso;
    r.revelado = true;
    if (contarVotos(r.votos, ids()).acusado !== c.culpable.id) return emitir();
    r.opciones = opcionesEvento(c, random);
    H.fase = "ultima";
    emitir();
    if (jug(c.culpable.id).bot) despues(2600, () => { if (H.ronda === r && H.fase === "ultima") { const i = botAdivina(c, todo(), r.opciones, random); cerrarRonda(r.opciones[i].t === c.evento.t, r.opciones[i]); } });
  }

  // ---------- Acciones de jugadores ----------
  /** Aplica una jugada ya validada en origen (humano o bot). Devuelve true si se aceptó. */
  function aplicar(id, t, d = {}) {
    const r = H.ronda, f = H.fase;
    if (!r || r.listos.includes(id)) return false;
    const c = r.caso, todos = ids();
    if (t === "listo" && f === "caso") { /* solo marca */ }
    else if (t === "r1" && f === "r1") {
      const esCulp = id === c.culpable.id;
      const decl = esCulp ? declaracionValida(c, todos, id, d) : declaracionVerdadera(c, id);
      if (!decl) return false;
      r.r1[id] = decl;
    } else if (t === "r2" && f === "r2") {
      if (!PREGUNTAS_R2[c.tipoR2].opciones.some((o) => o.k === d.op)) return false;
      r.r2[id] = d.op;
    } else if (t === "r3" && f === "r3") {
      const w = limpiarPalabra(d.palabra);
      // Al culpable no se le bloquea nada: un rechazo le chivaría palabras del secreto.
      if (w.length < 2 || (id !== c.culpable.id && palabraProhibida(w, c.evento.t))) return false;
      r.r3[id] = w;
    } else if (t === "voto" && f === "voto") {
      if (d.a === id || !todos.includes(d.a)) return false;
      r.votos[id] = d.a;
    } else return false;
    r.listos.push(id);
    if (todos.every((x) => r.listos.includes(x))) avanzarTrasTodos(); else emitir();
    return true;
  }
  function avanzarTrasTodos() {
    const f = H.fase;
    if (f === "caso") entrar("r1");
    else if (f === "r1") cerrarR(1);
    else if (f === "r2") cerrarR(2);
    else if (f === "r3") cerrarR(3);
    else if (f === "voto") trasVotar();
  }

  function accion(m) {
    if (!m || typeof m !== "object" || typeof m.id !== "string") return;
    const j = jug(m.id);
    if (j && typeof m.n === "number" && m.n <= (H.acks[m.id] || 0)) return; // repetida
    if (m.t === "unirse") {
      if (j) return emitir(H.fase !== "sala"); // reconexión
      if (H.fase !== "sala" || H.jugadores.length >= MAX_J) return;
      let nombre = String(m.nombre || "").trim().slice(0, 12) || "Jugador";
      const base = nombre; let k = 2;
      while (H.jugadores.some((x) => x.nombre.toLowerCase() === nombre.toLowerCase())) nombre = base.slice(0, 10) + " " + k++;
      H.jugadores.push({ id: m.id, nombre, bot: false, av: avatarLibre() });
      return emitir();
    }
    if (!j || j.bot) return;
    if (typeof m.n === "number") H.acks[m.id] = Math.max(H.acks[m.id] || 0, m.n);
    if (m.t === "salir") { if (H.fase === "sala" && m.id !== H.anfitrion) { quitar(m.id); emitir(); } return; }
    if (m.t === "adivina") {
      const r = H.ronda;
      if (H.fase === "ultima" && r && m.id === r.caso.culpable.id && r.opciones[m.i]) cerrarRonda(r.opciones[m.i].t === r.caso.evento.t, r.opciones[m.i]);
      return;
    }
    if (!aplicar(m.id, m.t, m)) emitir(); // rechazada: se reenvía el estado para que el jugador se ponga al día
  }
  const avatarLibre = () => { const usados = H.jugadores.map((x) => x.av); const i = AVATARES.findIndex((_, k) => !usados.includes(k)); return i < 0 ? H.jugadores.length % AVATARES.length : i; };
  function quitar(id) { H.jugadores = H.jugadores.filter((x) => x.id !== id); delete H.acks[id]; }

  // ---------- Controles del anfitrión ----------
  const mando = {
    configurar(c) { if (H.fase === "sala") { Object.assign(H.cfg, c); emitir(); } },
    agregarBot() {
      if (H.fase !== "sala" || H.jugadores.length >= MAX_J) return;
      const libres = NOMBRES_BOT.filter((n) => !H.jugadores.some((x) => x.nombre === n));
      H.jugadores.push({ id: nuevoId(random), nombre: pick(random, libres.length ? libres : NOMBRES_BOT), bot: true, av: avatarLibre() });
      emitir();
    },
    quitar(id) { if (H.fase === "sala" && id !== H.anfitrion) { quitar(id); emitir(); } },
    empezar() {
      if (H.fase !== "sala" || H.jugadores.length < MIN_J) return;
      H.numCaso = 0; H.puntos = Object.fromEntries(ids().map((id) => [id, 0])); H.usados = []; H.culpablesPrevios = [];
      return iniciarCaso();
    },
    /** Avanza desde las pantallas que esperan al anfitrión. */
    continuar() {
      const r = R(), f = H.fase;
      if (f === "r1v") entrar("r2");
      else if (f === "r2v") entrar("r3");
      else if (f === "r3v") { if (humanos().length >= 2) { r.careoFin = ahora() + SEG_CAREO * 1000; H.fase = "careo"; emitir(); } else entrar("voto"); }
      else if (f === "careo") entrar("voto");
      else if (f === "veredicto") { H.fase = "revelacion"; emitir(); }
      else if (f === "revelacion" && !r.revelado) revelar();
      else if (f === "revelacion") cerrarRonda(null);
      else if (f === "ultima") cerrarRonda(false);
      else if (f === "resultado") { if (H.numCaso < H.cfg.casos) return iniciarCaso(); H.fase = "final"; emitir(); }
      else if (f === "final") { H.fase = "sala"; H.ronda = null; H.numCaso = 0; H.puntos = {}; emitir(); }
    },
    masCareo() { if (H.fase === "careo") { R().careoFin = Math.max(R().careoFin, ahora()) + 30000; emitir(); } },
    /** No espera más a los humanos que faltan: juegan en automático. */
    forzar() {
      const r = R(), f = H.fase;
      if (!r || !["caso", "r1", "r2", "r3", "voto"].includes(f)) return;
      for (const j of H.jugadores) {
        if (H.ronda !== r || H.fase !== f) break;
        if (r.listos.includes(j.id)) continue;
        if (f === "caso") aplicar(j.id, "listo");
        else if (f === "r1") aplicar(j.id, "r1", botR1(r.caso, j.id, random));
        else if (f === "r2") aplicar(j.id, "r2", { op: botR2(r.caso, j.id, random) });
        else if (f === "r3") aplicar(j.id, "r3", { palabra: botR3(r.caso, j.id, { ...pub(), r3: r.r3 }, random) });
        else if (f === "voto") aplicar(j.id, "voto", { a: botVoto(r.caso, j.id, todo(), ids(), random) });
      }
    },
    /** Tras reabrir la app: retoma lo que quedó a medias y vuelve a publicar todo. */
    reanudar() {
      const r = H.ronda;
      if (H.fase === "cargando" && (!r || !r.caso)) { H.numCaso = Math.max(0, H.numCaso - 1); H.culpablesPrevios.pop(); return iniciarCaso(); }
      emitir(true);
      if (r && ["caso", "r1", "r2", "r3", "voto"].includes(H.fase)) moverBots();
      if (r && H.fase === "ultima" && jug(r.caso.culpable.id).bot) despues(1500, () => { if (H.ronda === r && H.fase === "ultima") { const i = botAdivina(r.caso, todo(), r.opciones, random); cerrarRonda(r.opciones[i].t === r.caso.evento.t, r.opciones[i]); } });
    },
    republicar() { publicar({ estado: publico(), privados: privados() }); },
  };
  return { accion, mando, publico, privados };
}
