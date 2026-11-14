# Coartada

Juego de fiesta para 3 a 10 personas, **cada una en su teléfono**. Uno del grupo es el culpable de
un «crimen» absurdo; los demás son inocentes y comparten un dato secreto que el culpable no conoce.
Un detective interroga a todos en voz alta, el grupo discute y vota.

- Jugar en el navegador (Android o iPhone): https://coartada-delta.vercel.app
- Instalable para Android: `releases/Coartada.apk`

## Salas

Uno toca **Crear sala** y comparte el código de 5 letras (o el enlace de invitación); los demás
tocan **Unirme a una sala**. El teléfono de quien creó la sala es el anfitrión: lleva la partida y
debe mantener la app abierta. Si alguien recarga o pierde la conexión, vuelve solo a la partida.

Los teléfonos se comunican por un servidor MQTT público (EMQX, HiveMQ o Eclipse, según la primera
letra del código), sin cuentas ni configuración. Por ahí solo viajan datos de la partida (nombres,
cartas, votos); la clave de Groq nunca sale del teléfono del anfitrión. Al ser servicios públicos
y gratuitos no tienen garantía de disponibilidad.

## Cómo se juega

1. **El caso y la carta.** Uno es el culpable. Los inocentes saben dónde estaban, a quién vieron y
   el secreto de la noche; el culpable no sabe el secreto.
2. **Ronda 1 · Coartadas.** Cada quien declara dónde estaba y a quién vio. Los inocentes dicen la
   verdad y el culpable inventa; el juego cruza las versiones y marca los choques.
3. **Ronda 2 · La pregunta.** Una pregunta sobre «eso» que pasó, con cuatro respuestas.
4. **Ronda 3 · Palabra clave.** Una palabra que insinúe el secreto sin decirlo.
5. **Voto.** Con el tablero de pruebas delante. Si el culpable cae, puede rescatar puntos
   adivinando el secreto entre seis opciones.

Puntos: culpable que escapa +4 · inocente que votó al culpable +2 (si cayó) o +1 (si escapó) ·
culpable atrapado que adivina el secreto +2 · +1 al culpable si el detective acusa a un inocente.

**Bots.** «Jugar con bots» funciona sin internet, y en una sala el anfitrión puede añadir bots.

**Casos con IA (opcional).** Con una clave de Groq en Ajustes, la IA inventa el caso según dónde
estén. Las cartas las reparte siempre el motor. Si la IA falla, se usa un caso del archivo.

## Estructura

| Ruta | Qué es |
|---|---|
| `src/content.js` | Escenarios, crímenes, secretos, avatares y frases de los bots |
| `src/engine.js` | Casos, cruce de coartadas, bots, detective y puntos |
| `src/anfitrion.js` | La partida: fases, jugadas y bots |
| `src/juego.js` | Pantallas de la partida y red de las salas |
| `src/main.js` | Inicio, ayuda, ajustes y arranque |
| `src/audio.js` | Música y efectos generados con WebAudio |
| `src/ai.js` | Casos y veredicto con la API de Groq |
| `src/mqtt.js` | Cliente MQTT mínimo sobre WebSocket |
| `www/` | La app lista para abrir |
| `apk-src/`, `build_apk.sh` | Envoltorio Android y compilación del APK |
| `tests/` | Motor (partidas simuladas), partidas contra bots y salas en navegador |

## Desarrollo

```bash
npm install
npm run build          # genera www/app.js
npm test               # casos verificados y 1500 partidas simuladas con bots
node tests/bots.mjs    # partidas contra bots en un navegador sin cabeza (requiere Playwright)
node tests/salas.mjs   # sala con varios teléfonos simulados y un servidor MQTT local
```

Para probar en el computador basta abrir `www/index.html` en un navegador.

La web se publica en Vercel desde esta carpeta (`vercel.json`: sirve `www/` tal cual, sin compilar).

## Compilar el APK

Hace falta el SDK de Android con `build-tools;35.0.0` y `platforms;android-34`:

```bash
export ANDROID_HOME=/ruta/al/sdk
./build_apk.sh         # deja el instalable en ../releases/Coartada.apk
```

La primera vez se crea una firma local (`firma-local.keystore`) que no se sube al repositorio.
Android solo actualiza una app instalada si el APK nuevo lleva la misma firma, así que conserva
ese archivo; si lo pierdes, hay que desinstalar la app antes de instalar la versión nueva.
