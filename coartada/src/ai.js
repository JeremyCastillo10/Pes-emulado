// Detective IA: genera casos, hace preguntas a partir de las respuestas y dicta un veredicto.
// Usa la API de Groq (compatible con OpenAI, modo JSON). En el APK las peticiones salen por el
// puente nativo (window.CoartadaNative) para no depender de CORS dentro del WebView.
import { delataEvento } from "./engine.js";

const BASE = "https://api.groq.com/openai/v1";
export const MODELO_POR_DEFECTO = "openai/gpt-oss-120b";
// Lista de respaldo; en Ajustes se carga la lista real de modelos de la cuenta.
export const MODELOS = [
  { id: "openai/gpt-oss-120b", nombre: "GPT-OSS 120B (recomendado)" },
  { id: "openai/gpt-oss-20b", nombre: "GPT-OSS 20B (más rápido)" },
];
// Modelos de la cuenta que no sirven para conversar (voz, transcripción, filtros).
const NO_CHAT = /whisper|guard|orpheus|tts|safeguard|allam/i;

export class ErrorIA extends Error {
  constructor(mensaje, tipo = "general") { super(mensaje); this.tipo = tipo; }
}

// ---- Red: puente nativo en el APK, fetch en el navegador -------------------
let seq = 0;
const pendientes = new Map();
if (typeof window !== "undefined") {
  window.__coartadaHttp = (id, status, cabeceras, cuerpo) => {
    const p = pendientes.get(id);
    if (!p) return;
    pendientes.delete(id);
    if (status <= 0) p.reject(new TypeError(cuerpo || "Sin conexión"));
    else p.resolve({ status, headers: cabeceras || {}, text: cuerpo });
  };
}
const hayPuente = () => typeof window !== "undefined" && window.CoartadaNative && typeof window.CoartadaNative.http === "function";
function http(url, { method = "GET", headers = {}, body = "" } = {}) {
  if (hayPuente()) {
    return new Promise((resolve, reject) => {
      const id = "r" + ++seq;
      pendientes.set(id, { resolve, reject });
      try { window.CoartadaNative.http(id, url, method, JSON.stringify(headers), body); }
      catch (e) { pendientes.delete(id); reject(new TypeError("No se pudo usar la red del teléfono")); }
    });
  }
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 120000);
  return fetch(url, { method, headers, body: method === "GET" ? undefined : body, signal: ctrl.signal })
    .then(async (r) => ({ status: r.status, headers: { "retry-after": r.headers.get("retry-after") }, text: await r.text() }))
    .finally(() => clearTimeout(t));
}

function errorDeEstado(status, texto) {
  let detalle = "";
  try { detalle = JSON.parse(texto).error.message || ""; } catch (e) { /* cuerpo no JSON */ }
  if (status === 401) return new ErrorIA("La clave de Groq no es válida. Revísala en Ajustes.", "clave");
  if (status === 403) return new ErrorIA("Groq rechazó el acceso con esta clave.", "clave");
  if (status === 404) return new ErrorIA("Ese modelo no está disponible en tu cuenta. Elige otro en Ajustes.", "modelo");
  if (status === 429 || status === 413) return new ErrorIA("Llegaste al límite de uso de Groq. Espera un minuto.", "limite");
  if (status === 400) return new ErrorIA("Groq no aceptó la petición" + (detalle ? ": " + detalle : "."), "peticion");
  return new ErrorIA("El servicio de Groq falló (" + status + "). Intenta de nuevo.", "servidor");
}
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));

async function llamar(apiKey, ruta, opciones) {
  if (!apiKey) throw new ErrorIA("Falta la clave de Groq. Ponla en Ajustes.", "clave");
  const headers = { authorization: "Bearer " + apiKey, "content-type": "application/json" };
  for (let intento = 0; ; intento++) {
    let r;
    try { r = await http(BASE + ruta, { ...opciones, headers }); }
    catch (e) { throw new ErrorIA(e && e.name === "AbortError" ? "Groq tardó demasiado en responder." : "No hay conexión a internet.", "red"); }
    if (r.status >= 200 && r.status < 300) {
      try { return JSON.parse(r.text); } catch (e) { throw new ErrorIA("Groq devolvió una respuesta ilegible.", "formato"); }
    }
    // Un reintento si es un límite momentáneo o un fallo del servidor.
    const espera = Math.min(25, Math.max(2, parseFloat(r.headers["retry-after"]) || 3));
    if (intento === 0 && (r.status === 429 || r.status >= 500)) { await esperar(espera * 1000); continue; }
    throw errorDeEstado(r.status, r.text);
  }
}

/** Pide un objeto JSON al modelo. `forma` es un ejemplo del objeto que debe devolver. */
async function pedirJSON({ apiKey, modelo, system, user, forma, esfuerzo = "low", maxTokens = 4000, temperatura = 0.9 }) {
  const model = modelo || MODELO_POR_DEFECTO;
  const cuerpo = {
    model,
    messages: [
      { role: "system", content: system + "\n\nResponde únicamente con un objeto JSON válido, sin texto antes ni después, con exactamente esta forma:\n" + forma },
      { role: "user", content: user },
    ],
    response_format: { type: "json_object" },
    temperature: temperatura,
    max_completion_tokens: maxTokens,
  };
  if (model.startsWith("openai/gpt-oss")) cuerpo.reasoning_effort = esfuerzo; // estos modelos razonan antes de responder
  const res = await llamar(apiKey, "/chat/completions", { method: "POST", body: JSON.stringify(cuerpo) });
  const op = res.choices && res.choices[0];
  if (!op || !op.message || !op.message.content) throw new ErrorIA(op && op.finish_reason === "length" ? "La respuesta de la IA quedó cortada." : "La IA no devolvió nada.", "formato");
  try { return JSON.parse(op.message.content); }
  catch (e) { throw new ErrorIA(op.finish_reason === "length" ? "La respuesta de la IA quedó cortada." : "La IA devolvió una respuesta ilegible.", "formato"); }
}

/** Modelos de chat disponibles para la clave. */
export async function listarModelos({ apiKey }) {
  const res = await llamar(apiKey, "/models", { method: "GET" });
  const ids = (res.data || []).filter((m) => m.active !== false && !NO_CHAT.test(m.id) && (m.context_window || 0) >= 16000).map((m) => m.id).sort();
  return ids.map((id) => ({ id, nombre: (MODELOS.find((m) => m.id === id) || {}).nombre || id }));
}

// ---- Formas de respuesta ---------------------------------------------------
const FORMA_CASO = `{"titulo": "...", "relato": "...", "lugar_crimen": "...", "hora": "...", "pistas": ["...", "..."], "lugares": [{"nombre": "...", "actividades": ["...", "..."]}], "coartada_falsa": {"lugar": "...", "actividad": "..."}, "evento_secreto": "...", "eventos_falsos": ["...", "...", "...", "...", "..."], "verdad": "..."}`;
const FORMA_PREGUNTAS = `{"preguntas": [{"jugador": "...", "pregunta": "..."}]}`;
const FORMA_VEREDICTO = `{"informe": "...", "contradicciones": ["..."], "acusado": "...", "frase_final": "..."}`;

const TONOS = {
  absurdo: "humor absurdo y ligero, crímenes ridículos e inofensivos (nada de violencia real)",
  noir: "novela negra clásica narrada con ironía, sin violencia gráfica",
  picante: "humor pícaro para adultos entre amigos, atrevido pero sin contenido sexual explícito ni humillaciones",
};

// ---- Llamadas del juego ----------------------------------------------------
export async function probarConexion({ apiKey, modelo }) {
  const r = await pedirJSON({
    apiKey, modelo, maxTokens: 600,
    system: "Eres un detective de novela negra con humor seco.",
    user: "Saluda al grupo en una frase corta, en español.",
    forma: `{"saludo": "..."}`,
  });
  if (!r.saludo) throw new ErrorIA("La IA respondió algo inesperado.", "formato");
  return String(r.saludo);
}

/**
 * Pide a la IA el «material» de un caso: el crimen, los lugares y el dato secreto.
 * Las cartas las reparte después el motor (armarCasoIA) para que nunca se contradigan.
 */
export async function generarCasoIA({ apiKey, modelo, jugadores, culpable, ambientacion, tono = "absurdo", titulosUsados = [] }) {
  const system = `Eres el guionista de «Coartada», un juego de fiesta en español donde un grupo de amigos busca al culpable de un «crimen» cómico. Escribes en español latino neutro, tuteando, con frases cortas que se leen bien en voz alta desde un teléfono.

Cómo funciona el juego, para que tu caso sea jugable:
- Hay un culpable y el resto son inocentes. El juego reparte a cada inocente uno de tus lugares y una de sus actividades, y le dice a quién vio. Tú no escribes esas cartas: solo das los lugares y las actividades.
- Todos los inocentes conocen un «evento secreto»: algo llamativo que pasó esa noche y que cualquiera presente, en cualquiera de los lugares, habría notado (un ruido, un apagón, un olor, algo que se ve desde todas partes). El culpable no lo conoce porque estaba ocupado. En el interrogatorio se pregunta por él con rodeos, así que debe ser concreto, sensorial y dar tema de conversación.
- El culpable recibe una coartada falsa: un lugar apartado donde no había nadie y una actividad creíble.
- Al final el culpable intenta adivinar el evento secreto entre seis opciones, así que necesitas cinco eventos falsos igual de creíbles, del mismo estilo y bien distintos entre sí.

Tono: ${TONOS[tono] || TONOS.absurdo}. El «crimen» es siempre una travesura o un robo cómico; no impliques a los jugadores en violencia, delitos graves ni nada humillante, porque son personas reales jugando entre amigos.`;
  const user = `Jugadores: ${jugadores.join(", ")}.
Culpable de este caso: ${culpable}.
Ambientación pedida por el grupo: ${ambientacion && ambientacion.trim() ? ambientacion.trim() : "sorpréndenos con un lugar original"}.
${titulosUsados.length ? "Casos ya jugados hoy, no los repitas: " + titulosUsados.join("; ") + "." : ""}

Campos:
- titulo: estilo «El caso de…».
- relato: 2 o 3 frases para leer en voz alta. Cuenta qué pasó y en qué lugar, con un detalle gracioso. No insinúes quién fue ni menciones el evento secreto.
- lugar_crimen: con artículo y en minúscula, por ejemplo «la cocina». Debe coincidir con el relato.
- hora: por ejemplo «10:30 de la noche».
- pistas: 2 pistas físicas halladas en el lugar, sugerentes, que no señalen a nadie.
- lugares: exactamente 7 lugares de la ambientación, distintos entre sí, del lugar del crimen y del de la coartada falsa. Cada nombre con artículo y en minúscula («el patio»). Cada uno con 2 actividades concretas y graciosas en gerundio y segunda persona, que completen «Estabas en el patio, …» (por ejemplo «peleando con la bocina para poner música»). No nombres a ningún jugador en las actividades.
- coartada_falsa: otro lugar distinto (con artículo, en minúscula) y una actividad en gerundio, para ${culpable}.
- evento_secreto: completa «Esa noche…» sin repetir esas dos palabras, en minúscula y sin punto final, por ejemplo «se fue la luz diez segundos y alguien gritó». No debe tener relación con el crimen.
- eventos_falsos: exactamente 5, con el mismo formato.
- verdad: 2 frases que revelan al final cómo lo hizo ${culpable} y que mintió diciendo que estaba en el lugar de la coartada falsa.`;
  return pedirJSON({ apiKey, modelo, system, user, forma: FORMA_CASO, esfuerzo: "medium", maxTokens: 6000, temperatura: 1 });
}

const SYSTEM_DETECTIVE = `Eres el Detective, el interrogador de «Coartada», un juego de fiesta en español. Un grupo de amigos tiene un culpable escondido y tú lo buscas: alguien lee tus preguntas en voz alta desde un teléfono y el interrogado responde delante de todos.

Lo que sabes: el caso público, las pistas y un «evento secreto» que todos los inocentes presenciaron y el culpable no. No sabes quién es el culpable; lo deduces de las respuestas. Los inocentes tienen prohibido nombrar el evento secreto, solo pueden aludirlo, así que no cuenta en su contra que hablen de él con rodeos; sí es sospechoso quien dice que no pasó nada raro, quien lo describe mal o quien esquiva el tema.

Regla que no puedes romper: en tus preguntas y en tu informe nunca nombres ni describas el evento secreto, ni uses sus palabras. Si lo haces, el culpable lo copia y el juego se arruina. Refiérete a él solo como «eso que pasó» o «el momento que todos recuerdan».

Tu estilo: detective de novela negra con humor seco, tuteando, en español latino neutro. Frases cortas para leer en voz alta. Las respuestas que recibes son resúmenes escritos o dictados a toda prisa: tolera faltas y lenguaje informal, y no inventes cosas que nadie dijo.`;

const publico = (caso) => `Caso: ${caso.titulo}. ${caso.relato}
Lugar del hecho: ${caso.lugar_crimen}. Hora: ${caso.hora}.
Pistas: ${caso.pistas.join(" | ") || "ninguna"}.
Evento secreto (solo para ti; nunca lo escribas): esa noche ${caso.evento_secreto}.`;

const transcripcion = (entradas) => entradas.map((e) => `[Ronda ${e.ronda}] Detective a ${e.jugador}: ${e.pregunta}\n${e.jugador}: ${e.respuesta && e.respuesta.trim() ? e.respuesta.trim() : "(respondió en voz alta, sin dejar nota)"}`).join("\n\n");

const norm = (s) => String(s).trim().toLowerCase();

/** Devuelve {jugador: pregunta}. Se descartan las preguntas que delatan el dato secreto. */
export async function preguntasIA({ apiKey, modelo, caso, jugadores, entradas, ronda, ultima }) {
  const user = `${publico(caso)}

Sospechosos: ${jugadores.join(", ")}.

Interrogatorio hasta ahora:
${transcripcion(entradas)}

Escribe la pregunta de la ronda ${ronda} para cada sospechoso: exactamente una por persona, con su nombre tal como aparece. Cada pregunta se apoya en lo que esa persona u otra ya dijo: cruza dos versiones, pide el detalle que falta o tantea con rodeos si de verdad vivió «eso que pasó». A quien no dejó nota, pídele que repita su coartada con un detalle comprobable. ${ultima ? "Es la última ronda: aprieta donde más dudes." : ""} Una sola pregunta por persona, de 25 palabras como máximo, sin dar por hecho nada que nadie haya dicho.`;
  const r = await pedirJSON({ apiKey, modelo, system: SYSTEM_DETECTIVE, user, forma: FORMA_PREGUNTAS, esfuerzo: "medium", maxTokens: 4000, temperatura: 0.8 });
  const out = {};
  for (const j of jugadores) {
    const p = (Array.isArray(r.preguntas) ? r.preguntas : []).find((x) => x && norm(x.jugador) === norm(j));
    if (p && typeof p.pregunta === "string" && p.pregunta.trim() && !delataEvento(p.pregunta, caso.evento_secreto)) out[j] = p.pregunta.trim();
  }
  return out;
}

export async function veredictoIA({ apiKey, modelo, caso, jugadores, entradas }) {
  const user = `${publico(caso)}

Sospechosos: ${jugadores.join(", ")}.

Interrogatorio completo:
${transcripcion(entradas)}

Dicta tu veredicto:
- informe: 3 o 4 frases para leer en voz alta, repasando lo que te llamó la atención de las respuestas. No reveles el evento secreto: el culpable todavía puede intentar adivinarlo.
- contradicciones: hasta 3 frases cortas, cada una con una contradicción real entre dos versiones o una respuesta floja, diciendo de quién. Si no hay ninguna clara, lista vacía.
- acusado: el nombre exacto de un sospechoso. Elige uno aunque dudes.
- frase_final: una frase dramática de acusación dirigida a esa persona.`;
  const r = await pedirJSON({ apiKey, modelo, system: SYSTEM_DETECTIVE, user, forma: FORMA_VEREDICTO, esfuerzo: "high", maxTokens: 5000, temperatura: 0.6 });
  const acusado = jugadores.find((j) => norm(j) === norm(r.acusado)) || null;
  if (!acusado) throw new ErrorIA("El detective no supo a quién acusar.", "formato");
  const limpio = (t) => typeof t === "string" && t.trim() && !delataEvento(t, caso.evento_secreto);
  return {
    informe: limpio(r.informe) ? r.informe.trim() : "Escuché todas las versiones. Hay una que no encaja con lo que pasó esa noche.",
    contradicciones: (Array.isArray(r.contradicciones) ? r.contradicciones : []).filter(limpio).slice(0, 3),
    acusado,
    frase_final: limpio(r.frase_final) ? r.frase_final.trim() : `${acusado}, tu historia es la que menos me convence.`,
  };
}
