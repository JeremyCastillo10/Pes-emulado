# Fase 1 — Campo, cámara, un jugador, balón, controles táctiles y física

APK: `releases/GolazoPro3D-fase1.apk` (debug, arm64-v8a + armeabi-v7a, Godot 4.3).

## Qué incluye

**Campo y estadio**
- Césped por shader con 5 patrones de corte (franjas, cuadros, círculos, diagonal y franjas
  finas), variación de color, desgaste en área chica, punto penal, círculo central y bandas.
- Líneas reglamentarias nítidas (antialias por píxel, sin texturas).
- Porterías con postes, travesaño, soportes y red que se deforma con el gol.
- Vallas publicitarias genéricas (marcas inventadas), banquillos, 4 gradas con muro, techo,
  esquinas, 4 torres de focos y público animado con colores variados.
- Día, atardecer y noche (con focos); césped seco o mojado. Sombras dinámicas solo en Alta.

**Balón (física propia)**
- Gravedad, resistencia del aire y **efecto Magnus** (curva lateral, liftado y cortado).
- Bote distinto según el estado del césped; el efecto modifica el bote; rodadura con fricción.
- Choques con postes y travesaño, red que retiene el balón, detección de gol (balón entero
  dentro), fuera de banda y de fondo.

**Jugador**
- Inercia real: velocidad y rumbo separados, aceleración según "Aceleración", giro más lento
  a alta velocidad, frenada en giros bruscos.
- Sprint con resistencia que se gasta y se recupera y que baja la velocidad máxima y la precisión.
- Conducción por toques: corta al ir despacio, larga al esprintar; controla mejor quien tiene
  más "Regate"/"Control". Control de balones rápidos que puede fallar.
- Pase raso, pase elevado, pase en profundidad y tiro con barra de potencia; la precisión depende
  de la valoración, el cansancio, la carrera y la potencia (demasiada potencia = se va alto).
- Efecto con gesto táctil. Regates: bicicleta y recorte. Barrida con polvo. Presión automática.
- Modelo articulado procedural con animaciones de trote, carrera, sprint, inclinación al
  acelerar/frenar/girar, toque de conducción, golpeo, barrida, regates y celebración, con
  mezcla suave entre estados. Dorsal y nombre en la espalda.

**Cámaras:** Transmisión (por defecto), Amplia, Cercana y Detrás del jugador.

**Controles:** joystick flotante, 6 botones contextuales semitransparentes (opacidad, tamaño y
posición ajustables y guardados), vibración al tirar y al marcar, mando Bluetooth y teclado.

**Rendimiento:** calidad Baja / Media / Alta / Auto (detecta RAM y núcleos). Baja = 30 fps y
render al 70 %, Media = 60 fps al 85 %, Alta = 60 fps, 100 %, MSAA 2x y sombras. El público se
reduce según la calidad. Botón "atrás" de Android abre las opciones.

## Verificación hecha

- El proyecto importa y arranca sin errores de script en Godot 4.3.
- Prueba automática (`-- --autotest`) que conduce, regatea, tira, hace un pase largo y una
  barrida: el tiro desde 30 m acaba en gol y la red retiene el balón.
- El paquete exportado para Android se cargó en escritorio y pasó la misma prueba.
- APK firmado y verificado con `apksigner`.
- **No** se pudo probar en un teléfono real desde este entorno: el rendimiento en gama
  media/baja está pendiente de que lo pruebes tú.

## Qué falta (para fases siguientes)

- Compañeros, rivales, porteros, IA, árbitro y reglas (Fase 2–3).
- Saque de banda/córner/meta reales: ahora un balón fuera solo se recoloca.
- Animaciones de taco, chilena, volea, cabezazo, caño, ruleta, entradas de pie, cargas, caídas,
  portero, túnel, lamentos y protestas (Fase 3).
- Narración, sonidos y música: la Fase 1 no tiene audio (Fase 3).
- Menús, base de datos JSON, modos de juego y editor (Fases 4–5).
- Lluvia visual, LOD de jugadores, carga de estadios en segundo plano y pulido gráfico (Fase 6).
