# Narración

El partido lo narran dos voces originales (narrador y comentarista) con frases de
`data/lang/narracion_es.json` (307 frases, generadas con `tools/frases_narracion.py`), con los
nombres de equipos, jugadores, porteros, estadio, minuto y marcador.

## Voz sintetizada (por defecto)

Se usa la síntesis de voz del teléfono en español (TTS de Android). Si suena en inglés o no
suena: Ajustes de Android → *Salida de texto a voz* → motor de Google → idioma **Español
(Estados Unidos/México)** e instala los datos de voz. Si hay dos voces en español instaladas,
el comentarista usa la segunda; si no, la misma con un tono más grave.

## Clips grabados (opcional, intercambiables)

Cualquier evento puede usar audios grabados en lugar de la voz sintetizada. Formato **.ogg**, con
el nombre del evento y un número: `goal_1.ogg`, `goal_2.ogg`, `save_1.ogg`…

- Dentro del juego: copia los archivos en `audio/narracion/` antes de compilar.
- Sin recompilar: copia los archivos en la carpeta de datos del juego, subcarpeta `narracion`
  (`/Android/data/com.personal.golazopro3d/files/narracion/`).

Eventos: `intro, kickoff, second_half, pass, dribble, shot, shot_wide, save, post, goal, own_goal,
foul, advantage, yellow, red, offside, corner, free_kick, penalty, penalty_miss, injury, sub, chance,
tackle, half_time, full_time, win_end, draw_end, comeback, rout, extra_time, shootout,
shootout_goal, shootout_miss, trophy, time_late, crowd, long_ball, through, pressure`.

Los clips no pueden decir nombres variables; lo habitual es grabar frases genéricas
("¡Gooool! ¡Qué golazo!") y dejar la voz sintetizada para el resto.

## Sonido y música

Silbato, golpeos, poste, red, público (murmullo, ovación, "uyyy" y cánticos con bombo y palmas)
y la música del menú se sintetizan por código al arrancar. Para sustituirlos, pon un `.ogg` con el
mismo nombre en `audio/sfx/` (kick, whistle, whistle_long, post, net, crowd, cheer, ooh, chant,
music, click, back, select).
