# Golazo Pro 3D

Juego de fútbol 3D original para Android hecho en **Godot 4.3** (GDScript, renderizador
Mobile, horizontal). Es para uso personal y no se va a publicar. Se entrega por fases y cada
fase trae un `.apk` jugable.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Campo, cámaras, un jugador, balón, controles táctiles y física | ✅ Hecha (`releases/GolazoPro3D-fase1.apk`) |
| 2 | 11 contra 11, IA básica, porteros, goles y HUD | ✅ Hecha (`releases/GolazoPro3D-fase2.apk`) |
| 3 | Animaciones completas, reglas, repeticiones y narración | ⏳ |
| 4 | Menús, base de datos JSON, editor, Amistoso, Liga y Copa | ⏳ |
| 5 | Liga Máster, Ser una Leyenda y Torneo de selecciones | ⏳ |
| 6 | Gráficos avanzados, clima, optimización y pulido | ⏳ |

- Cómo compilar el APK: [docs/COMPILAR_ANDROID.md](docs/COMPILAR_ANDROID.md)
- Estructura del código: [docs/ESTRUCTURA.md](docs/ESTRUCTURA.md)
- Detalle de cada fase: [docs/FASE1.md](docs/FASE1.md), [docs/FASE2.md](docs/FASE2.md)

## Controles

| Táctil | Con balón | Sin balón | Mando | Teclado |
|---|---|---|---|---|
| Joystick flotante (mitad izquierda) | Mover | Mover | Stick izq. / cruceta | WASD / flechas |
| Pase | Pase raso (mantener = más fuerte) | Presión (va al balón) | A | J |
| Largo | Pase elevado | Doble presión | X | U |
| Profund. | Pase en profundidad | Salida del portero | Y | I |
| Tiro | Tiro (mantener para cargar) | Barrida | B | K |
| Regate | Bicicleta / recorte (con dirección) | Cambiar jugador | LB | Q |
| Sprint | Sprint | Sprint | RB / RT | Shift |
| Pausa (II, arriba a la derecha) | | | Start | Esc |
| Cámara (en la pausa) | | | Back | C |

Gestos:
- **Efecto:** mientras cargas un tiro o un pase, arrastra el dedo hacia un lado.
- **Pase en profundidad:** desliza rápido en la zona libre de la derecha de la pantalla.
- **Mover botones:** en Opciones → *Mover botones*; también hay opacidad y tamaño.
