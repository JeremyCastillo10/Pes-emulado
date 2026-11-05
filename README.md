# Golazo Pro 3D

Juego de fútbol 3D original para Android hecho con **Godot 4.3** (GDScript, renderizador Mobile,
horizontal). Es de uso personal y no se publicará. APK: `releases/GolazoPro3D.apk`.

## Qué incluye

- **Partido 11 contra 11** con física propia del balón (efecto, bote según el césped, postes,
  red), inercia y peso de los jugadores, valoraciones que influyen en todo y cansancio.
- **IA por roles** con 5 dificultades, formaciones 4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 5-3-2 y
  personalizadas, y estrategias (presión alta, contraataque, posesión, bandas, fuera de juego).
- **Reglamento completo**: banda, córner, meta, fuera de juego, faltas con ventaja, tarjetas,
  expulsiones, lesiones, 5 cambios, penales, tiros libres con barrera, prórroga y penales.
- **Animaciones procedurales** con mezcla suave: carrera, sprint, frenada, giros, conducción,
  pases, tiros, globo, colocado, volea, cabezazo, chilena, taco, control orientado, bicicleta,
  recorte, amague, caño, ruleta, barrida, entrada, carga, caídas, portero (estiradas, puños,
  saques), celebraciones, lamentos, protestas, árbitro y salida al campo.
- **Narración** en español latinoamericano (307 frases, dos voces) y clips intercambiables;
  público dinámico, cánticos, silbato y música originales sintetizados.
- **Repeticiones** en cámara lenta con desenfoque y visor de goles guardados.
- **Cámaras**: Transmisión, Amplia, Cercana y Detrás del jugador. Día, atardecer, noche y lluvia.
- **Modos**: Amistoso (contra la IA o 2 jugadores con mandos), Liga, Copa (eliminatoria o grupos),
  Torneo de selecciones (32 equipos), Liga Máster (varias temporadas, fichajes, cesiones,
  contratos, cantera, evolución y retiros, directiva), Ser una Leyenda y Entrenamiento (libre,
  tiros libres, penales y desafío).
- **Base de datos** en JSON (20 ligas, 352 clubes, 211 selecciones) con editor completo e
  importación/exportación desde el teléfono.
- **Controles táctiles** (joystick flotante, botones contextuales ajustables, gestos, vibración),
  mando Bluetooth y teclado. Calidad Baja/Media/Alta/Auto, LOD y carga del estadio por partes.

## Documentación

- [Compilar el APK paso a paso](docs/COMPILAR_ANDROID.md)
- [Estructura del proyecto](docs/ESTRUCTURA.md)
- [Formato de la base de datos y qué puede estar desactualizado](docs/BASE_DE_DATOS.md)
- [Narración y sonidos](docs/NARRACION.md)

## Controles

| Táctil | Con balón | Sin balón | Mando | Teclado |
|---|---|---|---|---|
| Joystick flotante (izquierda) | Mover | Mover | Stick izq. | WASD |
| Pase | Pase raso (mantener = más fuerte) | Presión / carga | A | J |
| Largo | Pase elevado / centro | Doble presión | X | U |
| Profund. | Pase en profundidad | Salida del portero | Y | I |
| Tiro | Tiro (mantener para cargar) | Barrida | B | K |
| Regate | Regate (al soltar) | Cambiar jugador | LB | Q |
| Sprint | Sprint | Sprint | RB / RT | Shift |
| II (arriba derecha) | Pausa: cambios, estrategia, repetición, estadísticas, opciones | | Start | Esc |

Combinaciones: **Largo + Tiro** = globo · **Regate + Tiro** = tiro colocado · Regate con el
joystick hacia atrás = ruleta, hacia un lado = recorte, con un rival delante = caño, doble toque
= amague · Tiro/Pase con el balón en el aire = cabezazo, volea o chilena · arrastrar el dedo al
cargar = efecto · deslizar rápido a la derecha = pase en profundidad.
