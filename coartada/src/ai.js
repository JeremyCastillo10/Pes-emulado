// Detective IA: genera casos, hace preguntas a partir de las respuestas y dicta un veredicto.
// Usa el SDK oficial de Anthropic. En el APK las peticiones salen por el puente nativo
// (window.CoartadaNative) para no depender de CORS dentro del WebView.
import Anthropic from "@anthropic-ai/sdk";

export const MODELOS = [
  { id: "claude-opus-5-5", nombre: "Claude Opus 5.5 (recomendado)" },
  { id: "claude-sonnet-5-5", nombre: "Claude Sonnet 5.5 (más barato)" },
  { id: "claude-haiku-5-5", nombre: "Claude Haiku 5.5 (el más barato y rápido)" },
];
export const MODELO_POR_DEFECTO = "claude-opus-5-5";
// Modelos que aceptan el relevo automático del servidor si una petición es rechazada.
const CON_RELEVO = new Set(["claude-opus-5-5", "claude-sonnet-5-5"]);

export class ErrorIA extends Error {
  constructor(mensaje, tipo = "general") { super(mensaje); this.tipo = tipo; }
}

// ---- Puente nativo -> fetch ------------------------------------------------
let seq = 0;
const pendientes = new Map();
if (typeof window !== "undefined") {
  window.__coartadaHttp = (id, status, cabeceras, cuerpo) => {
    const p = pendientes.get(id);
    if (!p) return;
    pendientes.delete(id);
    if (status <= 0) p.reject(new TypeError(cuerpo || "Sin conexión"));
    else p.resolve(new Response(cuerpo, { status, headers: cabeceras || {} }));
  };
}
function fetchNativo(url, init = {}) {
  return new Promise((resolve, reject) => {
    const id = "r" + ++seq;
    const cab = {};
    new Headers(init.headers || {}).forEach((v, k) => { cab[k] = v; });
    pendientes.set(id, { resolve, reject });
    try {
      window.CoartadaNative.http(id, String(url), init.method || "GET", JSON.stringify(cab), typeof init.body === "string" ? init.body : "");
    } catch (e) {
      pendientes.delete(id);
      reject(new TypeError("No se pudo usar la red del teléfono"));
    }
  });
}
const hayPuente = () => typeof window !== "undefined" && window.CoartadaNative && typeof window.CoartadaNative.http === "function";

// ---- Cliente ---------------------------------------------------------------
function cliente(apiKey) {
  if (!apiKey) throw new ErrorIA("Falta la clave de API. Ponla en Ajustes.", "clave");
  return new Anthropic({
    apiKey,
    dangerouslyAllowBrowser: true, // la clave es del propio usuario y vive solo en su teléfono
    maxRetries: 1,
    timeout: 120000,
    ...(hayPuente() ? { fetch: fetchNativo } : {}),
  });
}

function traducirError(e) {
  if (e instanceof ErrorIA) return e;
  if (e instanceof Anthropic.AuthenticationError) return new ErrorIA("La clave de API no es válida. Revísala en Ajustes.", "clave");
  if (e instanceof Anthropic.PermissionDeniedError) return new ErrorIA("Tu clave no tiene permiso para usar este modelo.", "clave");
  if (e instanceof Anthropic.NotFoundError) return new ErrorIA("Ese modelo no está disponible para tu cuenta. Elige otro en Ajustes.", "modelo");
  if (e instanceof Anthropic.RateLimitError) return new ErrorIA("Demasiadas peticiones seguidas. Espera un momento.", "limite");
  if (e instanceof Anthropic.BadRequestError) return new ErrorIA("La IA rechazó la petición: " + e.message, "peticion");
  if (e instanceof Anthropic.APIConnectionError) return new ErrorIA("No hay conexión a internet.", "red");
  if (e instanceof Anthropic.APIError) return new ErrorIA("El servicio de IA falló (" + (e.status || "?") + "). Intenta de nuevo.", "servidor");
  if (e instanceof SyntaxError) return new ErrorIA("La IA devolvió una respuesta ilegible.", "formato");
  return new ErrorIA(e && e.message ? e.message : "Error desconocido", "general");
}

async function pedirJSON({ apiKey, modelo, system, user, schema, effort, maxTokens = 8000 }) {
  try {
    const c = cliente(apiKey);
    const params = {
      model: modelo || MODELO_POR_DEFECTO,
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content: user }],
      output_config: { effort, format: { type: "json_schema", schema } },
    };
    let res;
    if (CON_RELEVO.has(params.model)) {
      res = await c.beta.messages.create({ ...params, betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" });
    } else {
      res = await c.messages.create(params);
    }
    if (res.stop_reason === "refusal") throw new ErrorIA("La IA no quiso generar esto. Prueba con otra ambientación.", "rechazo");
    if (res.stop_reason === "max_tokens") throw new ErrorIA("La respuesta de la IA quedó cortada.", "formato");
    const texto = res.content.filter((b) => b.type === "text").map((b) => b.text).join("");
    return JSON.parse(texto);
  } catch (e) {
    throw traducirError(e);
  }
}

// ---- Esquemas --------------------------------------------------------------
const str = { type: "string" };
const obj = (properties) => ({ type: "object", properties, required: Object.keys(properties), additionalProperties: false });
const ESQUEMA_CASO = obj({
  titulo: str,
  relato: str,
  lugar_crimen: str,
  hora: str,
  pistas: { type: "array", items: str },
  evento_secreto: str,
  eventos_falsos: { type: "array", items: str },
  cartas: { type: "array", items: obj({ jugador: str, lugar: str, actividad: str, visto: str, extra: { anyOf: [str, { type: "null" }] } }) },
  coartada_falsa: obj({ lugar: str, actividad: str }),
  verdad: str,
});
const ESQUEMA_PREGUNTAS = obj({ preguntas: { type: "array", items: obj({ jugador: str, pregunta: str }) } });
const ESQUEMA_VEREDICTO = obj({ informe: str, contradicciones: { type: "array", items: str }, acusado: str, frase_final: str });

const TONOS = {
  absurdo: "humor absurdo y ligero, crímenes ridículos e inofensivos (nada de violencia real)",
  noir: "novela negra clásica narrada con ironía, sin violencia gráfica",
  picante: "humor pícaro para adultos entre amigos, atrevido pero sin contenido sexual explícito ni humillaciones",
};

// ---- Llamadas del juego ----------------------------------------------------
export async function probarConexion({ apiKey, modelo }) {
  const r = await pedirJSON({
    apiKey, modelo, effort: "low", maxTokens: 2000,
    system: "Responde solo con el JSON pedido.",
    user: "Devuelve una frase corta de saludo de un detective, en español.",
    schema: obj({ saludo: str }),
  });
  return r.saludo;
}

export async function generarCasoIA({ apiKey, modelo, jugadores, culpable, ambientacion, tono = "absurdo", titulosUsados = [] }) {
  const inocentes = jugadores.filter((j) => j !== culpable);
  const system = `Eres el guionista de «Coartada», un juego de fiesta en español donde un grupo de amigos busca al culpable de un «crimen» cómico. Escribes en español latino neutro, tuteando, con frases cortas que se leen bien en voz alta desde un teléfono.

Cómo funciona el juego, para que el caso sea jugable:
- Hay un culpable y el resto son inocentes. Cada inocente recibe una carta secreta con dónde estaba, qué hacía y a quién vio. Las cartas de los inocentes deben encajar entre sí sin contradicciones: si dos comparten lugar, ambos lo saben; si A vio a B yendo a un sitio, B realmente estaba allí.
- Todos los inocentes conocen un «evento secreto»: algo llamativo que pasó esa noche y que cualquiera presente habría notado. El culpable no lo conoce, porque estaba ocupado cometiendo el crimen. Durante el interrogatorio se le pregunta a cada uno por ese evento de forma indirecta, así que debe ser concreto, sensorial y fácil de comentar sin nombrarlo.
- El culpable recibe una coartada falsa sugerida: un lugar donde no había ningún inocente y una actividad creíble.
- Al final el culpable intenta adivinar el evento secreto entre seis opciones, así que necesitas cinco eventos falsos igual de creíbles y del mismo estilo que el verdadero.

Tono: ${TONOS[tono] || TONOS.absurdo}. El «crimen» es siempre una travesura o un robo cómico; no impliques a los jugadores en violencia, delitos graves ni nada humillante, porque son personas reales jugando entre amigos.`;
  const user = `Jugadores: ${jugadores.join(", ")}.
Culpable de este caso: ${culpable}.
Inocentes (una carta para cada uno, usando el nombre exactamente como está escrito): ${inocentes.join(", ")}.
Ambientación pedida por el grupo: ${ambientacion && ambientacion.trim() ? ambientacion.trim() : "sorpréndenos con un lugar original"}.
${titulosUsados.length ? "Casos ya jugados hoy, no los repitas: " + titulosUsados.join("; ") + "." : ""}

Devuelve el caso con estos campos:
- titulo: estilo «El caso de…».
- relato: 2 o 3 frases que se leen en voz alta a todos. Cuenta qué pasó y dónde, sin insinuar quién fue y sin mencionar el evento secreto.
- lugar_crimen y hora.
- pistas: 2 pistas públicas, sugerentes pero que no delaten al culpable.
- evento_secreto: una frase que complete «Esa noche…», por ejemplo «se fue la luz diez segundos».
- eventos_falsos: exactamente 5.
- cartas: una por inocente con lugar, actividad (en gerundio, completando «Estabas…»), visto (una frase sobre a quién vio o con quién estaba) y extra (null, salvo que haya 4 o más inocentes: entonces exactamente uno recibe una frase diciendo que pasó por el lugar de la coartada falsa y estaba vacío).
- coartada_falsa: lugar y actividad (en gerundio) para el culpable.
- verdad: 2 frases que revelan al final cómo lo hizo ${culpable}.`;
  return pedirJSON({ apiKey, modelo, system, user, schema: ESQUEMA_CASO, effort: "medium", maxTokens: 12000 });
}

const SYSTEM_DETECTIVE = `Eres el Detective, el interrogador de «Coartada», un juego de fiesta en español. Un grupo de amigos tiene un culpable escondido y tú lo buscas en voz alta: alguien lee tus preguntas desde un teléfono y el interrogado responde delante de todos.

Lo que sabes: el caso público, los lugares, y un «evento secreto» que todos los inocentes presenciaron y el culpable no. No sabes quién es el culpable; lo deduces de las respuestas. Nunca nombres ni describas el evento secreto en tus preguntas o informes hasta el veredicto: si lo revelas, el culpable lo copia y el juego se rompe. Puedes rodearlo («eso que pasó», «el momento que todos recuerdan»).

Tu estilo: detective de novela negra con humor seco, tuteando, en español latino neutro. Frases cortas, pensadas para leerse en voz alta. Las respuestas que recibes son resúmenes escritos o dictados a toda prisa, así que tolera faltas y lenguaje informal.`;

const publico = (caso) => `Caso: ${caso.titulo}. ${caso.relato}
Lugar del hecho: ${caso.lugar_crimen}. Hora: ${caso.hora}.
Pistas: ${caso.pistas.join(" | ") || "ninguna"}.
Evento secreto (solo lo conocen los inocentes; no lo reveles): ${caso.evento_secreto}.`;

const transcripcion = (entradas) => entradas.map((e) => `[Ronda ${e.ronda}] Detective a ${e.jugador}: ${e.pregunta}\n${e.jugador}: ${e.respuesta && e.respuesta.trim() ? e.respuesta.trim() : "(respondió en voz alta, sin dejar nota)"}`).join("\n\n");

export async function preguntasIA({ apiKey, modelo, caso, jugadores, entradas, ronda, ultima }) {
  const user = `${publico(caso)}

Sospechosos: ${jugadores.join(", ")}.

Interrogatorio hasta ahora:
${transcripcion(entradas)}

Escribe la pregunta de la ronda ${ronda} para cada sospechoso: exactamente una por persona, usando su nombre tal como aparece. Cada pregunta debe apoyarse en lo que esa persona u otra ya dijo: cruza versiones, pide el detalle que falta, o tantea de forma indirecta si de verdad vivió el evento secreto. ${ultima ? "Es la última ronda: aprieta donde más duda tengas." : ""} Máximo 30 palabras por pregunta.`;
  const r = await pedirJSON({ apiKey, modelo, system: SYSTEM_DETECTIVE, user, schema: ESQUEMA_PREGUNTAS, effort: "low", maxTokens: 6000 });
  const out = {};
  const norm = (s) => String(s).trim().toLowerCase();
  for (const j of jugadores) {
    const p = (r.preguntas || []).find((x) => norm(x.jugador) === norm(j));
    if (p && p.pregunta) out[j] = p.pregunta;
  }
  return out;
}

export async function veredictoIA({ apiKey, modelo, caso, jugadores, entradas }) {
  const user = `${publico(caso)}

Sospechosos: ${jugadores.join(", ")}.

Interrogatorio completo:
${transcripcion(entradas)}

Dicta tu veredicto:
- informe: 3 o 4 frases para leer en voz alta, repasando lo que te llamó la atención. Aquí todavía no reveles el evento secreto.
- contradicciones: hasta 3 frases cortas, cada una con una contradicción o respuesta floja concreta y quién la dijo. Si no hay ninguna clara, lista vacía.
- acusado: el nombre exacto de un sospechoso. Tienes que elegir uno aunque dudes.
- frase_final: una frase dramática de acusación dirigida a esa persona.`;
  const r = await pedirJSON({ apiKey, modelo, system: SYSTEM_DETECTIVE, user, schema: ESQUEMA_VEREDICTO, effort: "medium", maxTokens: 8000 });
  const norm = (s) => String(s).trim().toLowerCase();
  const acusado = jugadores.find((j) => norm(j) === norm(r.acusado)) || null;
  if (!acusado) throw new ErrorIA("El detective no supo a quién acusar.", "formato");
  return { informe: r.informe, contradicciones: (r.contradicciones || []).slice(0, 3), acusado, frase_final: r.frase_final };
}
