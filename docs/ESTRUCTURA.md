# Estructura del proyecto

```
project.godot            Configuración del motor (renderizador Mobile, horizontal, autoloads)
export_presets.cfg       Preset de exportación "Android" (APK)
icon.svg                 Icono
data/
  lang/es.json           Todos los textos de la interfaz (traducción)
  teams/demo.json        Dos equipos de prueba (la base de datos completa llega en la Fase 4)
audio/
  narracion/             (Fase 3) clips de narración intercambiables
scenes/
  match/match.tscn       Escena principal del partido
  match/ball.tscn        Balón
  match/player.tscn      Jugador
  ui/hud.tscn            HUD + controles táctiles + opciones
scripts/
  core/                  Autoloads (siempre cargados)
    game_settings.gd     Ajustes persistentes: calidad (Baja/Media/Alta/Auto), cámara,
                         hora del día, vibración, opacidad/tamaño/posición de botones
    input_hub.gd         Mapa de entrada (teclado + mando) y gestos táctiles (swipe, efecto)
    lang.gd              Lang.t("clave") lee data/lang/<idioma>.json
  match/
    pitch_dims.gd        Medidas reglamentarias del campo
    ball.gd              Física del balón: gravedad, aire, efecto Magnus, botes según
                         superficie, rodadura, postes, travesaño, red, gol y fuera
    football_player.gd   Jugador/portero: inercia, sprint, resistencia, conducción, pases,
                         tiros, regates, entradas, barrida, estiradas; lo mueven
                         "intenciones" que envían el humano o la IA
    formations.gd        Formaciones (4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 5-3-2) y afinidad de puestos
    team.gd              Equipo: alineación, bloque dinámico, asistencia de pase e IA por roles
    human_controller.gd  Control humano: carga de golpeos, cambio de jugador, presión, gestos
    player_model.gd      Cuerpo procedural articulado + animación procedural con mezcla
                         suave entre estados; aspecto personalizable (piel, pelo, barba,
                         altura, complexión, botines, dorsal y nombre en la espalda)
    camera_rig.gd        Cámaras Transmisión, Amplia, Cercana y Detrás del jugador
    stadium_builder.gd   Estadio procedural: césped, porterías y red, vallas, banquillos,
                         gradas, techo, torres de luz, público animado (MultiMesh), luz
    match.gd             Orquesta el partido: saques, goles, reloj, tiempos, estadísticas,
                         choques entre jugadores y pruebas automáticas
  ui/
    touch_controls.gd    Joystick flotante, botones contextuales, gestos, modo edición
    hud.gd               Marcador, reloj, panel del jugador, pausa, opciones y estadísticas
    radar.gd             Radar del campo
    ui_theme.gd          Identidad visual (azul oscuro, blanco y amarillo)
shaders/
  pitch.gdshader         Césped con 5 patrones de corte, desgaste y líneas antialias
  net.gdshader           Red que se deforma con el impacto del balón
  crowd.gdshader         Público con siluetas, color por persona y animación por emoción
  ball.gdshader          Paneles del balón
  blob_shadow.gdshader   Sombra barata para calidad Baja/Media
tools/                   Scripts auxiliares (generar datos de prueba)
docs/                    Documentación
build/                   Salida de exportación (no se sube el .apk de build/)
releases/                APK entregado al cerrar cada fase
```

## Convenciones

- Eje **X** = largo del campo (porterías en x = ±52,5 m), eje **Z** = ancho, **Y** = altura.
  Todo en metros y segundos.
- Los modelos miran hacia **-Z** local.
- Las acciones de juego se leen siempre con `Input` (`act_pass`, `act_shoot`…); los botones
  táctiles las pulsan con `Input.action_press`, así táctil, teclado y mando funcionan igual.
- Ningún texto visible va fijo en el código: se usa `Lang.t("clave")`.
- No hay assets externos con copyright: geometría, texturas y efectos son procedurales.
