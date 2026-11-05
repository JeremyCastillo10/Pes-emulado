# Estructura del proyecto

```
project.godot              Configuración (renderizador Mobile, horizontal, autoloads, TTS)
export_presets.cfg         Preset "Android" (APK, permisos de vibración y almacenamiento)
data/
  db/database.json         Base de datos completa (ligas, clubes, selecciones, jugadores)
  lang/es.json             Textos de la interfaz
  lang/narracion_es.json   Frases de la narración
audio/narracion/           Clips de narración opcionales (.ogg)
audio/sfx/                 Sonidos opcionales que sustituyen a los sintetizados (.ogg)
scenes/
  menu/main_menu.tscn      Escena inicial: menú con estadio 3D
  menu/replay_viewer.tscn  Visor de repeticiones guardadas
  match/match.tscn         Partido; ball.tscn, player.tscn
  ui/hud.tscn              HUD del partido
scripts/
  core/                    Autoloads
    game_settings.gd       Ajustes persistentes (calidad, cámara, controles, audio, dificultad)
    input_hub.gd           Mapa de entrada (teclado, mandos, 2 jugadores) y gestos táctiles
    lang.gd                Textos traducibles
    database.gd            "DB": carga en segundo plano, consultas, edición, importar/exportar
    game_state.gd          "Game": configuración del partido, cambio de escena, guardado
    audio_manager.gd       "Audio": síntesis de sonidos/música, público dinámico
  match/
    match.gd               Orquestador y reglamento del partido, estadísticas y resultado
    team.gd                Equipo: bloque, asistencia de pase, IA por roles, cambios, estrategias
    football_player.gd     Jugador: movimiento con inercia, golpeos, regates, entradas, portero
    player_model.gd        Esqueleto + malla procedural y animación procedural
    human_controller.gd    Control humano (táctil, teclado, mando concreto, Leyenda)
    ball.gd                Física del balón
    stadium_builder.gd     Estadio procedural (construcción por partes)
    camera_rig.gd          Cámaras y cámaras cinemáticas (presentación, repetición)
    commentary.gd          Narración TTS / clips
    replay.gd              Grabación, cámara lenta y guardado de repeticiones
    referee.gd             Árbitro
    weather.gd             Lluvia
    training.gd            Modos de entrenamiento
    formations.gd          Formaciones y afinidad de puestos
    pitch_dims.gd          Medidas del campo
  modes/
    competition.gd         Ligas, copas, grupos, torneo de selecciones, simulación
    mode_flow.gd           Aplica resultados al modo activo
    master_league.gd       Liga Máster
    legend_mode.gd         Ser una Leyenda
  menu/                    Pantallas del menú (principal, amistoso, competiciones, Liga Máster,
                           Leyenda, entrenamiento, editor, alineación, selector de equipos,
                           repeticiones, opciones)
  ui/                      HUD, controles táctiles, radar, tema visual, escudos, fichas
shaders/                   Césped, red, público, balón, sombra, desenfoque de repetición
tools/                     Generadores: base de datos, frases de narración
tests/                     Pruebas automáticas (modos, flujo menú-partido, capturas)
releases/                  APK final
```

## Pruebas automáticas

```bash
godot --headless --fixed-fps 60 --path . res://scenes/match/match.tscn -- --autotest          # partido IA vs IA
godot --headless --fixed-fps 60 --path . res://scenes/match/match.tscn -- --autotest --humantest
godot --headless --path . res://tests/test_modes.tscn                     # ligas, copas, ML, Leyenda, menús
godot --headless --fixed-fps 60 --path . res://tests/test_flow.tscn       # menú -> partido -> menú
```
