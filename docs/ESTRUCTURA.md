# Estructura del proyecto

```
project.godot            Configuración del motor (renderizador Mobile, horizontal, autoloads)
export_presets.cfg       Preset de exportación "Android" (APK)
icon.svg                 Icono
data/
  lang/es.json           Todos los textos de la interfaz (traducción)
  (Fase 4: equipos, jugadores, ligas, estadios en JSON)
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
    football_player.gd   Jugador: inercia, sprint, resistencia, conducción, pases, tiros,
                         regates, barrida; todo depende de las valoraciones (0-99)
    player_model.gd      Cuerpo procedural articulado + animación procedural con mezcla
                         suave entre estados; aspecto personalizable (piel, pelo, barba,
                         altura, complexión, botines, dorsal y nombre en la espalda)
    camera_rig.gd        Cámaras Transmisión, Amplia, Cercana y Detrás del jugador
    stadium_builder.gd   Estadio procedural: césped, porterías y red, vallas, banquillos,
                         gradas, techo, torres de luz, público animado (MultiMesh), luz
    match.gd             Orquesta el partido (en Fase 1: práctica libre)
  ui/
    touch_controls.gd    Joystick flotante, botones contextuales, gestos, modo edición
    hud.gd               Marcador/HUD, mensajes, barras de potencia y resistencia, opciones
shaders/
  pitch.gdshader         Césped con 5 patrones de corte, desgaste y líneas antialias
  net.gdshader           Red que se deforma con el impacto del balón
  crowd.gdshader         Público con siluetas, color por persona y animación por emoción
  ball.gdshader          Paneles del balón
  blob_shadow.gdshader   Sombra barata para calidad Baja/Media
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
