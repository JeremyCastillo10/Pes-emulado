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
const EV = `{"texto": "...", "emoji": "...", "sentido": "vista|oido|olfato|tacto", "reaccion": "risa|susto|enojo|asombro", "palabras": ["...", "...", "...", "...", "..."]}`;
const FORMA_CASO = `{"emoji": "...", "titulo": "...", "relato": "...", "lugar_crimen": {"nombre": "...", "emoji": "..."}, "lugares": [{"nombre": "...", "emoji": "..."}], "evento_secreto": ${EV}, "eventos_falsos": [${EV}], "verdad": "..."}`;
const FORMA_VEREDICTO = `{"acusado": "...", "razones": ["...", "..."], "frase": "..."}`;

const TONOS = {
  absurdo: "humor absurdo y ligero, travesuras ridículas e inofensivas",
  noir: "novela negra clásica narrada con ironía, sin violencia",
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
 * Pide a la IA el material de un caso: el crimen, los lugares y el secreto de la noche.
 * Las cartas las reparte el motor (armarCaso), así nunca se contradicen.
 */
export async function generarCasoIA({ apiKey, modelo, jugadores, ambientacion, tono = "absurdo", titulosUsados = [] }) {
  const system = `Eres el guionista de «Coartada», un juego de fiesta en español. Escribes en español latino neutro, con frases cortas y graciosas que se leen de un vistazo en un teléfono.

Cómo funciona, para que tu caso sea jugable:
- Hay un culpable de una travesura cómica y el resto son inocentes. El juego reparte a cada inocente uno de tus lugares.
- Todos los inocentes presenciaron «el secreto»: algo llamativo que pasó esa noche y que cualquiera habría notado desde cualquier lugar. El culpable no lo sabe.
- El juego pregunta a todos con qué sentido lo notaron y cómo reaccionó la gente, y pide una palabra que lo insinúe sin decirlo. Por eso cada secreto lleva: el sentido principal, la reacción principal y 5 palabras sueltas que lo sugieren sin repetir ninguna palabra de su texto.
- Al final el culpable intenta adivinar el secreto entre seis opciones: el verdadero y cinco falsos igual de creíbles. Entre los seis deben repartirse sentidos y reacciones distintos, para que las respuestas den pistas.

Tono: ${TONOS[tono] || TONOS.absurdo}. Nada de violencia, delitos graves ni cosas humillantes: los jugadores son personas reales entre amigos. No nombres a ningún jugador en el relato.`;
  const user = `Jugadores: ${jugadores.join(", ")}.
Ambientación pedida por el grupo: ${ambientacion && ambientacion.trim() ? ambientacion.trim() : "sorpréndenos con un lugar original"}.
${titulosUsados.length ? "Casos ya jugados hoy, no los repitas: " + titulosUsados.join("; ") + "." : ""}

Campos:
- emoji: un emoji del objeto de la travesura.
- titulo: estilo «El caso de…», máximo 7 palabras.
- relato: máximo 2 frases cortas. Qué pasó y en qué lugar, con un detalle gracioso. No menciones el secreto.
- lugar_crimen: nombre con artículo y en minúscula («la cocina») y un emoji.
- lugares: exactamente 8 lugares más de la ambientación, distintos entre sí y del lugar del crimen, cada uno con artículo, en minúscula, máximo 3 palabras, y un emoji.
- evento_secreto: texto que completa «Esa noche…» en minúscula, sin punto y de máximo 10 palabras (ejemplo: «se fue la luz y todo quedó a oscuras»); un emoji; sentido; reaccion; y 5 palabras sueltas (una sola palabra cada una).
- eventos_falsos: exactamente 5, con el mismo formato, bien distintos entre sí y del verdadero.
- verdad: 1 o 2 frases que cuentan cómo lo hizo el culpable; escribe {culpable} donde va su nombre.`;
  return pedirJSON({ apiKey, modelo, system, user, forma: FORMA_CASO, esfuerzo: "medium", maxTokens: 6000, temperatura: 1 });
}

/** La IA redacta el veredicto del detective a partir del tablero de pruebas. */
export async function veredictoIA({ apiKey, modelo, caso, jugadores, pruebas, base }) {
  const nombre = (id) => (jugadores.find((j) => j.id === id) || {}).nombre || "?";
  const lugar = (i) => (caso.lugares[i] ? caso.lugares[i].n : "?");
  const avalados = (pruebas.analisis && pruebas.analisis.avalados) || [];
  const filas = jugadores.map((j) => {
    const d = pruebas.r1[j.id] || {};
    return `- ${j.nombre}: dice que estaba en ${lugar(d.lugar)}${d.vio ? ` y que vio a ${nombre(d.vio)} en ${lugar(d.vioLugar)}` : " y que no vio a nadie"}. ${avalados.includes(j.id) ? "Alguien confirma dónde estaba." : "Nadie confirma dónde estaba."} Sobre «eso» respondió «${pruebas.r2[j.id] || "nada"}». Su palabra clave: «${pruebas.r3[j.id] || "ninguna"}».`;
  }).join("\n");
  const choques = ((pruebas.analisis && pruebas.analisis.choques) || []).map((c) => c.tipo === "lugar" ? `${nombre(c.a)} dice que vio a ${nombre(c.b)} en ${lugar(c.lugar)}, pero ${nombre(c.b)} dice otra cosa.` : `${nombre(c.a)} y ${nombre(c.b)} dicen que estaban en ${lugar(c.lugar)} y no se vieron.`).join(" ") || "Ninguno.";
  const system = `Eres el Detective de «Coartada», un juego de fiesta en español: detective de novela negra con humor seco, que tutea y habla en frases cortas. Tienes las pruebas de la noche y debes acusar a un sospechoso.

Conoces el secreto que presenciaron los inocentes, pero el culpable todavía puede intentar adivinarlo: no lo nombres, no lo describas y no uses sus palabras. Refiérete a él solo como «eso».`;
  const user = `Caso: ${caso.titulo}. ${caso.relato}
El secreto (solo para ti): esa noche ${caso.evento.t}. Se notó con: ${caso.evento.s}. Reacción general: ${caso.evento.r}.

Pruebas:
${filas}
Choques entre versiones: ${choques}

Elige a quién acusas (el nombre exacto de un sospechoso), da 2 o 3 razones cortas basadas solo en estas pruebas (máximo 14 palabras cada una) y una frase final dramática dirigida a esa persona.`;
  const r = await pedirJSON({ apiKey, modelo, system, user, forma: FORMA_VEREDICTO, esfuerzo: "medium", maxTokens: 3000, temperatura: 0.7 });
  const acusado = jugadores.find((j) => j.nombre.toLowerCase() === String(r.acusado || "").trim().toLowerCase());
  if (!acusado) return null;
  const limpio = (t) => typeof t === "string" && t.trim() && !delataEvento(t, caso.evento.t);
  const razones = (Array.isArray(r.razones) ? r.razones : []).filter(limpio).map((t) => t.trim().slice(0, 140)).slice(0, 3);
  return { acusado: acusado.id, razones: razones.length ? razones : base.razones, frase: limpio(r.frase) ? r.frase.trim().slice(0, 160) : `${acusado.nombre}, todas las pistas llevan a ti.` };
}
