# Coartada

Juego de fiesta para 3 a 10 personas con un solo teléfono. Uno del grupo es el culpable de un
«crimen» absurdo; los demás son inocentes y comparten un dato secreto que el culpable no conoce.
Un detective interroga a todos en voz alta, el grupo discute y vota.

## Cómo se juega

1. **El caso.** El teléfono presenta el crimen y las pistas.
2. **Las cartas.** Se pasa el teléfono; cada quien mantiene presionada su carta para verla en secreto.
   Los inocentes saben dónde estaban, a quién vieron y el dato secreto de esa noche. El culpable
   recibe una coartada falsa sugerida.
3. **El interrogatorio.** El detective pregunta a cada jugador. Regla de oro: nadie puede decir el
   dato secreto de forma directa, solo con rodeos.
4. **Careo y votación secreta.**
5. **El final.** Si el culpable es el más votado, cae; pero puede rescatar puntos si adivina el
   dato secreto entre seis opciones.

Puntos: culpable que escapa +4 · inocente que votó al culpable +2 (si cayó) o +1 (si escapó) ·
culpable atrapado que adivina el dato secreto +2 · con Detective IA, +1 al culpable si la IA acusa
a un inocente.

## Dos detectives

- **Clásico (sin internet).** Casos del archivo: 6 escenarios, 18 crímenes y un generador que
  reparte lugares, testigos y eventos, así que no se repiten.
- **Detective IA.** Con una clave de API de Groq (Ajustes), la IA inventa el escenario a la medida
  del grupo y del lugar donde están (las cartas las reparte siempre el motor, para que cuadren), lee el resumen de cada respuesta, hace preguntas que cruzan
  las versiones y al final acusa a alguien sin saber quién es el culpable. La clave se guarda solo
  en el teléfono. Si la IA falla o no hay conexión, la partida sigue en modo Clásico.

## Estructura

| Ruta | Qué es |
|---|---|
| `src/content.js` | Escenarios, crímenes, eventos y preguntas del modo Clásico |
| `src/engine.js` | Generador de casos, validación y puntuación |
| `src/ai.js` | Detective IA (API de Groq, modo JSON) |
| `src/main.js` | Pantallas y flujo de la partida |
| `www/` | La app web lista para abrir (`index.html`, `style.css`, `app.js` empaquetado) |
| `apk-src/` | Envoltorio Android: manifiesto, icono y `MainActivity` (WebView) |
| `build_apk.sh` | Compila `releases/Coartada.apk` |
| `tests/` | Pruebas del motor y partida completa automática |

## Desarrollo

```bash
npm install
npm run build          # genera www/app.js
npm test               # 3200 casos generados y verificados
node tests/e2e.mjs     # juega dos partidas completas en un navegador sin cabeza (requiere Playwright)
```

Para probar en el computador basta abrir `www/index.html` en un navegador.

## Compilar el APK

Hace falta el SDK de Android con `build-tools;35.0.0` y `platforms;android-34`:

```bash
export ANDROID_HOME=/ruta/al/sdk
./build_apk.sh         # deja el instalable en ../releases/Coartada.apk
```

La primera vez se crea una firma local (`firma-local.keystore`) que no se sube al repositorio.
Android solo actualiza una app instalada si el APK nuevo lleva la misma firma, así que conserva
ese archivo; si lo pierdes, hay que desinstalar la app antes de instalar la versión nueva.
