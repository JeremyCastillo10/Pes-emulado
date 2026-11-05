# Base de datos (`data/db/database.json`)

Todo el contenido (ligas, clubes, selecciones y jugadores) está en un único JSON. El juego carga
`data/db/database.json` o, si existe, la copia editada del usuario (`user://db/database.json`,
que se crea al guardar desde el editor o en las carreras).

Se genera con `python3 tools/db/build_database.py` a partir de:
- `tools/db/nations.py`: las 211 selecciones FIFA (colores, confederación, fuerza).
- `tools/db/leagues_*.py`: las 20 ligas y sus clubes con los jugadores reales conocidos.
- `tools/db/names.py`: nombres por idioma para completar plantillas con jugadores genéricos.

## Contenido

| Ligas (20) | |
|---|---|
| Europa | Premier League, LaLiga, Serie A, Bundesliga, Ligue 1, Liga Portugal, Eredivisie, Pro League (Bélgica), Süper Lig, Scottish Premiership, Super League (Grecia), Bundesliga (Austria), Super League (Suiza) |
| América | Brasileirão, Liga Profesional (Argentina), Liga MX, MLS, Liga BetPlay (Colombia) |
| Asia | Saudi Pro League, J1 League |

352 clubes, 211 selecciones y unos 10.600 jugadores: unos 1.740 con nombre real y valoraciones
aproximadas, y el resto genéricos (`"generic": true`), editables desde el juego.

## Qué puede estar desactualizado

- Los datos corresponden a la temporada 2025-26 tal como la conocía al generarlos. Los fichajes,
  ascensos y descensos posteriores no están; actualízalos con el editor o importando un JSON.
- Las ligas grandes (Inglaterra, España, Italia, Alemania, Francia) tienen las plantillas más
  completas en los clubes principales; en los clubes modestos hay menos jugadores reales.
- Portugal, Países Bajos, Bélgica, Turquía, Escocia, Grecia, Austria, Suiza, Japón, Colombia,
  Arabia Saudí, México, Argentina, Brasil y MLS tienen pocos jugadores reales por club (las
  figuras conocidas) y el resto genéricos. Varios clubes de esas ligas son casi del todo genéricos.
- MLS (30 clubes) y Argentina (28-30) están reducidas a 20 clubes; Alemania y Francia tienen 18,
  Bélgica 16, Grecia 14 y Escocia, Austria y Suiza 12, como en la realidad.
- Las selecciones pequeñas se completan con jugadores genéricos de su país.
- Escudos y uniformes son genéricos con los colores de cada club (sin logos oficiales).

## Formato

```json
{
  "version": 1,
  "season": 2026,
  "leagues": [
    {"id": "esp", "name": "LaLiga", "country": "ESP", "teams": ["esp_rma", "esp_bar", "..."]}
  ],
  "teams": [
    {
      "id": "esp_rma", "name": "Real Madrid", "short": "RMA", "country": "ESP", "league": "esp",
      "prestige": 5, "formation": "4-3-3", "strategy": "normal", "budget": 300.0,
      "kits": {
        "home":  {"shirt": "#ffffff", "shirt2": "#febe10", "shorts": "#ffffff", "socks": "#ffffff"},
        "away":  {"shirt": "#febe10", "shirt2": "#ffffff", "shorts": "#febe10", "socks": "#febe10"},
        "third": {"shirt": "#1a1a2e", "shirt2": "#ffffff", "shorts": "#1a1a2e", "socks": "#1a1a2e"},
        "gk":    {"shirt": "#2fbf4a", "shirt2": "#111111", "shorts": "#111111", "socks": "#111111"}
      },
      "crest": {"shape": "shield", "c1": "#ffffff", "c2": "#febe10", "text": "RMA"},
      "stadium": {"name": "Santiago Bernabéu", "capacity": 81000, "roof": true, "seat_color": "#ffffff", "pattern": 0},
      "players": ["esp_rma_courtois", "esp_rma_mbappé", "..."],
      "lineup":  ["esp_rma_courtois", "..."]
    }
  ],
  "nations": [
    {"id": "nat_ARG", "code": "ARG", "name": "Argentina", "short": "ARG", "confed": "CONMEBOL", "strength": 88,
     "formation": "4-4-2", "kits": {"...": "..."}, "crest": {"...": "..."}, "players": ["..."], "lineup": ["..."]}
  ],
  "players": [
    {
      "id": "esp_rma_mbappé", "name": "Mbappé", "nation": "FRA", "position": "CF", "number": 9,
      "foot": "right", "age": 27, "height": 178, "ovr": 92,
      "speed": 97, "acceleration": 96, "shot_accuracy": 95, "shot_power": 93, "short_pass": 86,
      "long_pass": 80, "dribbling": 93, "ball_control": 92, "defense": 40, "heading": 82,
      "physical": 84, "stamina": 88, "curl": 85, "agility": 92, "reflexes": 35, "positioning": 38,
      "appearance": {"skin": "#8d5a36", "hair_style": 0, "hair_color": "#1a1310", "beard": 0, "build": 0.55, "boots": "#ff6a00"},
      "team": "esp_rma", "value": 180.0, "wage": 9.0, "contract": 2029, "potential": 93
    }
  ]
}
```

### Campos

- `position`: GK, CB, RB, LB, DMF, CMF, AMF, RMF, LMF, RWF, LWF, SS, CF.
- Valoraciones de 0 a 99. `reflexes` y `positioning` son las de portero.
- `appearance.hair_style`: 0 rapado, 1 corto, 2 largo, 3 cresta, 4 afro, 5 moño.
  `beard`: 0 nada, 1 corta, 2 completa, 3 bigote. `build`: 0 delgado – 1 corpulento.
- `team`: id del club o `null` (libre). Las selecciones listan sus jugadores en `players`.
- `crest.shape`: shield, circle, round_shield, diamond. `stadium.pattern`: corte del césped 0-4.
- `formation`: 4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 5-3-2 o `custom_<id>` con `custom_slots`
  (`[["GK",0,0], ["CB",0.0,0.28], ...]`: rol, profundidad 0-1, anchura -1..1).
- `value` y `wage` en millones; `contract` = último año de contrato.

## Importar y exportar desde el teléfono

Editor → *Importar / exportar base de datos*:
- **Exportar** crea `Documentos/GolazoPro/database.json` (pide permiso de almacenamiento).
- **Importar** lista los `.json` de esa carpeta. Un archivo completo reemplaza la base; un
  archivo **parcial** con solo `players` y/o `teams` actualiza o añade esos registros por `id`
  (si cambia `team`, el jugador se traspasa). Ejemplo para actualizar dos fichajes:

```json
{"players": [
  {"id": "esp_rma_mbappé", "ovr": 93, "speed": 96},
  {"id": "eng_liv_salah", "team": "ksa_hil", "age": 34}
]}
```
- **Restaurar** vuelve a la base original del juego.
