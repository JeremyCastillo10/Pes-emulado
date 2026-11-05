# Fase 2 — 11 contra 11, IA, porteros, goles y HUD

APK: `releases/GolazoPro3D-fase2.apk` (debug, arm64-v8a + armeabi-v7a, Godot 4.3).

## Qué incluye

**Partido completo 11 contra 11**
- Dos equipos de prueba ficticios (`data/teams/demo.json`, generados con
  `tools/generar_equipos_demo.py`). La base de datos real llega en la Fase 4.
- Saque inicial, saques de banda, de esquina y de meta (los rivales se colocan a 9,15 m),
  goles con celebración y lamento, medio tiempo con cambio de campo y final.
- Reloj de 90 minutos con duración real configurable (2, 4, 6, 8 o 10 minutos por tiempo).
- Estadísticas de medio tiempo y final: posesión, tiros, tiros a puerta, córners, faltas
  (las faltas se pitan en la Fase 3) y pases completados.

**IA por roles**
- Formaciones 4-4-2, 4-3-3, 4-2-3-1, 3-5-2 y 5-3-2; cada jugador ocupa la casilla que mejor
  encaja con su posición.
- El equipo funciona como un bloque: se adelanta y se ensancha al atacar y se compacta al
  defender, desplazándose hacia el lado del balón.
- Defensa: presión del más cercano con entradas, cobertura del segundo (doble marca),
  marcaje en zona del rival más cercano por el lado de la portería y persecución de balones
  sueltos.
- Ataque: conducción hacia portería esquivando rivales, regates cuando hay un rival delante,
  pases buscando líneas libres y espacio, pases en profundidad, centros desde la banda y tiros
  según distancia, ángulo y presión. Los delanteros se desmarcan a la espalda de la defensa.
- 5 dificultades (Principiante, Amateur, Profesional, Superestrella, Leyenda): cambian el tiempo
  de reacción, las valoraciones efectivas, el error de golpeo, la presión y los reflejos del portero.

**Porteros**
- Colocación en la bisectriz balón-portería, posición de espera agachada.
- Detecta tiros, calcula por dónde llegará el balón y se estira (arriba o abajo); según los
  reflejos y la velocidad del tiro ataja o despeja.
- Sale a por balones sueltos en el área y a los pies en un mano a mano.
- Saque con la mano (raso a un compañero libre) o con el pie (largo).

**Jugadores**
- Nuevo modelo con esqueleto y una sola malla (una llamada de dibujo por jugador, necesario para
  22 jugadores en el móvil). Rostro con ojos, cejas, nariz, orejas y boca; 6 peinados, 3 tipos de
  barba, tono de piel, altura, complexión y botines desde los datos; guantes para el portero.
- La cadencia de las piernas se calcula a partir de la longitud de zancada para que los pies no
  patinen; rebote del cuerpo al apoyar; inclinación al acelerar, frenar y girar; los corpulentos
  giran algo peor.
- Choques entre jugadores: se empujan según su físico y en la carga hombro con hombro el más
  fuerte puede quitar el balón.

**Control**
- Cambio de jugador automático (al recibir un pase, al perder el balón, si otro está mucho más
  cerca) y manual con el botón Cambiar (LB).
- Asistencia de pase: el pase va al compañero mejor situado en la dirección del joystick; la
  potencia elige la distancia preferida.
- Presión (mantener Pase), doble presión (mantener Largo), barrida, salida del portero
  (mantener Profund.).

**HUD (azul oscuro y amarillo)**
- Marcador y reloj arriba a la izquierda, botón de pausa arriba a la derecha.
- Radar abajo en el centro, jugador controlado con resistencia y barra de potencia abajo a la
  izquierda, flecha y aro amarillos sobre el jugador controlado.
- Menú de pausa: reanudar, cámara, estadísticas, opciones, reiniciar partido y salir.

## Verificación hecha

- Compila e importa sin errores de script en Godot 4.3.
- Partidos IA contra IA completos sin pantalla (`--autotest`), incluidos medio tiempo, cambio
  de campo, saques y final. En un partido de 2 × 10 minutos reales salieron unos 8 tiros, 1 gol
  y unos 300 pases con ~60 % de acierto.
- Prueba de control humano (`--humantest`): saque inicial, cambio automático de jugador,
  presión, tiro y saque tras gol.
- El paquete exportado para Android jugó un partido completo en escritorio. APK firmado.
- No se pudo probar en un teléfono real desde este entorno.

## Qué falta (próximas fases)

- La IA todavía es básica: genera pocas ocasiones y pierde muchos balones con pases
  interceptados. Se seguirá afinando en la Fase 3 junto con las reglas.
- Faltas, ventaja, tarjetas, fuera de juego, lesiones, cambios, penales y tiros libres (Fase 3).
- Animaciones de cabezazo, volea, chilena, taco, caño, ruleta, saque de banda con las manos,
  portero (despeje de puños), túnel, protestas (Fase 3). Repeticiones y narración (Fase 3).
- Sonido y música (Fase 3–4). Menús, base de datos real, alineaciones y modos (Fase 4–5).
- Rostros: son geométricos (ojos, cejas, nariz, boca), no fotorrealistas; las expresiones
  faciales no están hechas.
