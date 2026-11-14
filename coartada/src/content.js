// Archivo de casos. Cada escenario combina lugares, crímenes y «secretos» de la noche.
// Evento: t = texto, e = emoji, s = sentido con que se notó, r = reacción de la gente,
// p = palabras que lo insinúan sin decirlo (las usan los bots).

export const SENTIDOS = [
  { k: "vista", e: "👀", t: "Lo vi" },
  { k: "oido", e: "👂", t: "Lo oí" },
  { k: "olfato", e: "👃", t: "Lo olí" },
  { k: "tacto", e: "🖐️", t: "Lo sentí" },
];
export const REACCIONES = [
  { k: "risa", e: "😂", t: "Risas" },
  { k: "susto", e: "😱", t: "Sustos" },
  { k: "enojo", e: "😡", t: "Enojo" },
  { k: "asombro", e: "😲", t: "Asombro" },
];
export const PREGUNTAS_R2 = {
  sentido: { titulo: "¿Cómo notaste «eso» primero?", opciones: SENTIDOS },
  reaccion: { titulo: "¿Cómo reaccionó la gente con «eso»?", opciones: REACCIONES },
};
// Palabras de quien no sabe nada e intenta no mojarse.
export const VAGAS = ["raro", "caos", "locura", "sorpresa", "inolvidable", "drama", "momento", "intenso", "increíble", "desastre"];

const L = (n, e) => ({ n, e });
const C = (e, titulo, relato) => ({ e, titulo, relato });
const E = (t, e, s, r, p) => ({ t, e, s, r, p });

export const ESCENARIOS = [
  {
    id: "asado", nombre: "El asado", emoji: "🔥", ambiente: "un asado en casa de un amigo",
    lugares: [L("la cocina", "🍳"), L("el patio", "🌿"), L("la sala", "🛋️"), L("el balcón", "🌙"), L("el garaje", "🚗"), L("la terraza", "✨"), L("el baño", "🚿"), L("la entrada", "🚪"), L("la piscina", "🏊")],
    crimenes: [
      C("🥩", "El caso de la picaña desaparecida", "Tres kilos de picaña marinada desde ayer se esfumaron de {lugar}. Solo quedó la bandeja vacía."),
      C("🍰", "El caso del postre profanado", "Alguien se comió medio tres leches reservado para el final y dejó la cuchara clavada como bandera en {lugar}."),
      C("🎵", "El caso de la playlist saboteada", "Alguien entró a {lugar}, cambió la música por tres horas de flauta andina y bloqueó el celular del anfitrión."),
    ],
    eventos: [
      E("se fue la luz y todo quedó a oscuras", "💡", "vista", "susto", ["velas", "linterna", "negro", "tropezón", "fusible", "ciegos"]),
      E("el perro del vecino aulló como lobo", "🐺", "oido", "risa", ["luna", "colmillos", "coro", "mascota", "escalofrío", "serenata"]),
      E("alguien tumbó la torre de vasos", "🥤", "oido", "susto", ["estruendo", "vidrios", "dominó", "escoba", "torpeza", "añicos"]),
      E("cayó un aguacero repentino", "🌧️", "tacto", "enojo", ["mojados", "paraguas", "charcos", "carrera", "goteras", "nubes"]),
      E("se quemó la carne y la casa se llenó de humo", "🔥", "olfato", "enojo", ["chamuscado", "tos", "ventanas", "carbón", "alarma", "ceniza"]),
      E("explotó una botella de refresco agitada", "🍾", "vista", "risa", ["espuma", "pegajoso", "géiser", "burbujas", "techo", "ducha"]),
    ],
  },
  {
    id: "boda", nombre: "La boda", emoji: "💍", ambiente: "la boda de una prima lejana",
    lugares: [L("la pista de baile", "💃"), L("la mesa de dulces", "🍬"), L("la barra", "🍸"), L("el jardín", "🌷"), L("el parqueo", "🅿️"), L("la capilla", "⛪"), L("el salón de regalos", "🎁"), L("el pasillo", "🪞"), L("la cabina de fotos", "📸")],
    crimenes: [
      C("🎂", "El caso del pastel mordido", "Antes del corte oficial, el pastel de cinco pisos apareció en {lugar} con un mordisco enorme en el segundo nivel."),
      C("✉️", "El caso del sobre vacío", "La caja de regalos en efectivo apareció abierta en {lugar}. Falta el sobre más gordo: el del padrino."),
      C("📜", "El caso del discurso cambiado", "El padrino abrió su discurso en {lugar} y encontró la letra de una bachata. Alguien cambió las hojas."),
    ],
    eventos: [
      E("al DJ se le fue el audio y hubo un silencio eterno", "🔇", "oido", "asombro", ["grillos", "incómodo", "mudo", "pausa", "cables", "vacío"]),
      E("un tío borracho agarró el micrófono y cantó", "🎤", "oido", "risa", ["ranchera", "desafinado", "vergüenza", "karaoke", "aplausos", "gallo"]),
      E("un niño tumbó la torre de copas de champán", "🥂", "vista", "susto", ["cristales", "cascada", "travieso", "trapeador", "dominó", "brindis"]),
      E("una paloma se metió al salón y voló sobre las mesas", "🕊️", "vista", "risa", ["plumas", "alas", "pájaro", "persecución", "peinados", "aleteo"]),
      E("los fuegos artificiales empezaron antes de tiempo", "🎆", "vista", "asombro", ["chispas", "cielo", "colores", "pólvora", "adelantados", "estallidos"]),
      E("se regó un perfume entero y no se podía respirar", "🌸", "olfato", "enojo", ["frasco", "estornudos", "empalagoso", "mareo", "flores", "nariz"]),
    ],
  },
  {
    id: "oficina", nombre: "La oficina", emoji: "🗂️", ambiente: "la fiesta de fin de año de la oficina",
    lugares: [L("la sala de reuniones", "📊"), L("la cocineta", "☕"), L("la recepción", "🛎️"), L("el cuarto de impresoras", "🖨️"), L("la azotea", "🏙️"), L("el almacén", "📦"), L("el ascensor", "🛗"), L("la oficina del jefe", "💼"), L("el parqueo", "🚙")],
    crimenes: [
      C("⌚", "El caso del regalo cambiado", "El reloj carísimo del amigo secreto fue cambiado por un par de medias usadas. La caja estaba en {lugar}."),
      C("📧", "El caso del correo a toda la empresa", "Desde una computadora en {lugar} salió un correo firmado por el jefe: «Renuncio y me voy a vender empanadas»."),
      C("🥡", "El caso de la nevera saqueada", "Todos los almuerzos con nombre desaparecieron. Los envases vacíos aparecieron apilados en {lugar}."),
    ],
    eventos: [
      E("sonó la alarma de incendios por error", "🚨", "oido", "susto", ["sirena", "evacuación", "bomberos", "oídos", "pánico", "simulacro"]),
      E("el jefe cantó en el karaoke y desafinó horrible", "🎙️", "oido", "risa", ["gallos", "vergüenza", "ranchera", "aplausos", "grabaciones", "micrófono"]),
      E("se cayó el arbolito con todo y luces", "🎄", "vista", "asombro", ["esferas", "enredo", "cables", "navidad", "derrumbe", "estrella"]),
      E("se fue el internet y todos gritaron a la vez", "📶", "vista", "enojo", ["router", "señal", "desconectados", "dinosaurio", "cargando", "caída"]),
      E("explotó una botella de sidra y bañó el techo", "🍾", "vista", "risa", ["corcho", "espuma", "lluvia", "pegajoso", "burbujas", "ducha"]),
      E("alguien calentó pescado en el microondas", "🐟", "olfato", "enojo", ["mar", "ventanas", "peste", "almuerzo", "narices", "delito"]),
    ],
  },
  {
    id: "camping", nombre: "El campamento", emoji: "⛺", ambiente: "un campamento en la montaña",
    lugares: [L("la fogata", "🔥"), L("el río", "🏞️"), L("la carpa grande", "⛺"), L("el mirador", "🔭"), L("la camioneta", "🛻"), L("el sendero", "🥾"), L("la hamaca", "🌴"), L("la mesa de picnic", "🧺"), L("el muelle", "🎣")],
    crimenes: [
      C("🍡", "El caso de los malvaviscos fantasma", "Las tres bolsas de malvaviscos desaparecieron de {lugar}. Solo quedó un palito chamuscado."),
      C("🏕️", "El caso de la carpa desinflada", "Alguien sacó las estacas de la carpa principal y la dejó hecha un panqueque. Las estacas aparecieron en {lugar}."),
      C("🗺️", "El caso del mapa quemado", "El único mapa del sendero apareció medio quemado en {lugar}. Mañana nadie sabe cómo volver."),
    ],
    eventos: [
      E("se escuchó un aullido lejano que heló a todos", "🐺", "oido", "susto", ["lobo", "luna", "escalofrío", "bosque", "silencio", "manada"]),
      E("pasó una estrella fugaz enorme", "🌠", "vista", "asombro", ["deseo", "cielo", "cometa", "destello", "rápida", "brillo"]),
      E("una vaca apareció de la nada y cruzó el campamento", "🐄", "vista", "risa", ["cuernos", "leche", "visita", "cencerro", "pasto", "intrusa"]),
      E("empezó a llover y se mojaron los sacos de dormir", "🌧️", "tacto", "enojo", ["empapados", "goteras", "frío", "nubes", "charcos", "toallas"]),
      E("un zorrillo pasó cerca y dejó su recuerdo", "🦨", "olfato", "enojo", ["peste", "narices", "rayas", "huida", "tomate", "apestoso"]),
      E("tembló la tierra unos segundos", "🫨", "tacto", "susto", ["sacudida", "suelo", "réplica", "piedras", "mareo", "vibración"]),
    ],
  },
  {
    id: "crucero", nombre: "El crucero", emoji: "🚢", ambiente: "un crucero barato por el Caribe",
    lugares: [L("el buffet", "🍤"), L("la piscina", "🏊"), L("el casino", "🎰"), L("la cubierta", "⚓"), L("el teatro", "🎭"), L("el gimnasio", "🏋️"), L("la tienda", "🛍️"), L("el pasillo", "🚪"), L("el spa", "🧖")],
    crimenes: [
      C("🧢", "El caso de la gorra del capitán", "La gorra oficial del capitán desapareció minutos antes de la cena de gala. Estaba sobre una mesa en {lugar}."),
      C("🐙", "El caso del pulpo liberado", "El pulpo del acuario apareció nadando en la piscina de niños. El tanque, en {lugar}, tenía la tapa abierta."),
      C("🎱", "El caso del bingo amañado", "Alguien cambió las bolas del bingo y salió el mismo número siete veces. La tómbola se guardaba en {lugar}."),
    ],
    eventos: [
      E("el barco dio un bandazo y todo se inclinó", "🌊", "tacto", "susto", ["mareo", "resbalón", "platos", "barandas", "equilibrio", "estómago"]),
      E("sonó la bocina del barco tan fuerte que todos saltaron", "📯", "oido", "susto", ["trompeta", "oídos", "brinco", "sordera", "puerto", "elefante"]),
      E("pasó un grupo de delfines junto al barco", "🐬", "vista", "asombro", ["aletas", "saltos", "fotos", "mar", "cámaras", "espectáculo"]),
      E("el capitán estornudó por el altavoz", "🤧", "oido", "risa", ["salud", "pañuelo", "parlantes", "alergia", "anuncio", "resfriado"]),
      E("una ola enorme empapó la cubierta", "💦", "tacto", "risa", ["mojados", "sal", "toallas", "chapuzón", "salpicón", "peinados"]),
      E("se quemaron las palomitas del cine y apestó todo", "🍿", "olfato", "enojo", ["chamuscado", "humo", "maíz", "película", "ventilación", "tos"]),
    ],
  },
  {
    id: "edificio", nombre: "El edificio", emoji: "🏢", ambiente: "la reunión de vecinos de un edificio",
    lugares: [L("el lobby", "🛋️"), L("la azotea", "📡"), L("el parqueo", "🚗"), L("la piscina", "🏊"), L("las escaleras", "🪜"), L("el salón de actos", "🪑"), L("el cuarto de basura", "🗑️"), L("la caseta del conserje", "🔑"), L("la lavandería", "🧺")],
    crimenes: [
      C("🧙", "El caso del gnomo secuestrado", "El gnomo de jardín de la presidenta desapareció de {lugar}. Dejaron una nota: «Bajen la cuota de mantenimiento»."),
      C("📶", "El caso del wifi bautizado", "Alguien entró a {lugar}, donde está el router, y renombró el wifi como «El del 3C no paga»."),
      C("🪅", "El caso de la piñata adelantada", "La piñata del cumpleaños del 5A apareció rota y vacía en {lugar}, un día antes de la fiesta."),
    ],
    eventos: [
      E("se quedó trancado el ascensor con alguien adentro", "🛗", "oido", "susto", ["encerrado", "botones", "rescate", "gritos", "claustrofobia", "bomberos"]),
      E("se fue el agua en todo el edificio", "🚰", "tacto", "enojo", ["jabón", "ducha", "cubetas", "sequía", "tubería", "grifo"]),
      E("el loro del 6B gritó una mala palabra clarísima", "🦜", "oido", "risa", ["plumas", "grosero", "pico", "jaula", "vocabulario", "repetidor"]),
      E("explotó un transformador en la esquina", "⚡", "vista", "susto", ["chispas", "cañonazo", "poste", "apagón", "destello", "cables"]),
      E("cayó una maceta desde un piso alto", "🪴", "vista", "asombro", ["tierra", "balcón", "añicos", "suerte", "geranio", "puntería"]),
      E("alguien quemó arroz y el olor llegó a todos los pisos", "🍚", "olfato", "enojo", ["pegado", "olla", "humo", "almuerzo", "ventanas", "carbón"]),
    ],
  },
];

export const HORAS = ["las 9:40 de la noche", "las 10:15 de la noche", "las 8:50 de la noche", "las 11:05 de la noche", "las 7:30 de la tarde"];

export const VERDADES = [
  "{culpable} esperó a que nadie mirara, se escabulló hasta {lugar_crimen} y actuó en menos de dos minutos.",
  "Mientras todos estaban distraídos, {culpable} fue directo a {lugar_crimen} y volvió con cara de no haber roto un plato.",
  "{culpable} lo tenía planeado desde que llegó: aprovechó el alboroto, pasó por {lugar_crimen} y regresó silbando.",
];

// Avatares de los jugadores (por orden de llegada) y nombres de bots.
export const AVATARES = [
  { e: "🦊", c: "#ff7a3d" }, { e: "🐼", c: "#4cc9f0" }, { e: "🐸", c: "#3ddc97" }, { e: "🦉", c: "#c77dff" },
  { e: "🐙", c: "#ff5d8f" }, { e: "🦁", c: "#ffd23f" }, { e: "🐵", c: "#f4a261" }, { e: "🐨", c: "#90e0ef" },
];
export const NOMBRES_BOT = ["Lupa", "Sabueso", "Rayo", "Tuerca", "Chispa", "Pixel", "Gato", "Cobra", "Nube", "Kiwi"];

// Frases de los bots tras cada revelación. {x} = jugador señalado.
export const CHARLA = {
  choque: ["Ese choque entre {x} y {y} me huele mal.", "{x} y {y} no pueden tener razón los dos.", "Anoten: {x} contra {y}. Alguien miente."],
  sinTestigo: ["A {x} no lo vio nadie…", "Curioso: nadie puede confirmar a {x}.", "{x}, ¿quién te vio a ti?"],
  raro: ["{x} respondió distinto a todos.", "Mmm, lo de {x} no me cuadra.", "¿De qué noche está hablando {x}?"],
  palabra: ["«{p}»… ¿en serio, {x}?", "Lo de «{p}» no tiene nada que ver, {x}.", "{x} dijo «{p}». Sospechoso."],
  calma: ["Todo cuadra… demasiado.", "Aquí alguien miente muy bien.", "Sigo sin tenerlo claro."],
};
