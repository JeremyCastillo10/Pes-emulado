"""Genera data/teams/demo.json con dos equipos ficticios para probar partidos.
Uso: python3 tools/generar_equipos_demo.py"""
import json, random

random.seed(2012)
SURNAMES = ["Ramírez", "Torres", "Vidal", "Quintero", "Salas", "Moreno", "Herrera", "Castaño", "Ibarra",
    "Fuentes", "Lozano", "Paredes", "Rivas", "Duarte", "Montoya", "Cárdenas", "Aguilar", "Benítez",
    "Navarro", "Ortega", "Medina", "Villalba", "Robles", "Campos", "Serrano", "Acosta", "Peralta",
    "Escobar", "Gallardo", "Molina", "Rojas", "Bravo", "Cabrera", "Delgado", "Espinoza", "Figueroa"]
SKINS = ["#f1c9a5", "#e0ac83", "#c68b5e", "#a26a42", "#7b4b2a", "#5a3620"]
HAIR = ["#1a1310", "#3b2618", "#6b4423", "#b08850", "#d9c27a", "#2b2b2b"]
BOOTS = ["#111111", "#f5f5f5", "#ff6a00", "#1e90ff", "#ffd400", "#e0115f", "#32cd32"]

SQUAD = [("GK", 1), ("RB", 2), ("CB", 4), ("CB", 5), ("LB", 3), ("DMF", 6), ("CMF", 8), ("AMF", 10),
    ("RWF", 7), ("CF", 9), ("LWF", 11), ("GK", 12), ("CB", 15), ("RB", 22), ("CMF", 14), ("CMF", 16),
    ("RWF", 17), ("CF", 19)]


def rating(base, pos, key):
    prof = {
        "GK": {"reflexes": 18, "positioning": 16, "speed": -15, "shot_accuracy": -35, "dribbling": -30, "defense": -10},
        "CB": {"defense": 14, "heading": 12, "physical": 10, "dribbling": -12, "shot_accuracy": -18},
        "RB": {"speed": 8, "stamina": 8, "defense": 6, "short_pass": 2},
        "LB": {"speed": 8, "stamina": 8, "defense": 6, "short_pass": 2},
        "DMF": {"defense": 10, "short_pass": 6, "stamina": 8, "physical": 6},
        "CMF": {"short_pass": 10, "long_pass": 8, "stamina": 8},
        "AMF": {"short_pass": 10, "dribbling": 10, "ball_control": 10, "curl": 8, "defense": -15},
        "RWF": {"speed": 12, "acceleration": 12, "dribbling": 10, "defense": -18},
        "LWF": {"speed": 12, "acceleration": 12, "dribbling": 10, "defense": -18},
        "CF": {"shot_accuracy": 14, "shot_power": 10, "heading": 8, "defense": -22},
    }[pos]
    v = base + prof.get(key, 0) + random.randint(-6, 6)
    if pos != "GK" and key in ("reflexes", "positioning"):
        v = 35 + random.randint(-5, 5)
    return max(30, min(97, v))


KEYS = ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling",
    "ball_control", "defense", "heading", "physical", "stamina", "curl", "agility", "reflexes", "positioning"]


def team(tid, name, short, base, kits, used):
    players = []
    for i, (pos, num) in enumerate(SQUAD):
        sur = random.choice([s for s in SURNAMES if s not in used])
        used.add(sur)
        b = base - (6 if i >= 11 else 0)
        p = {"id": f"{tid}_{num}", "name": sur, "number": num, "position": pos,
             "foot": "left" if random.random() < 0.25 else "right", "age": random.randint(19, 34),
             "height": random.randint(186, 196) if pos in ("GK", "CB") else random.randint(168, 188),
             "appearance": {"skin": random.choice(SKINS), "hair_style": random.randint(0, 5),
                            "hair_color": random.choice(HAIR), "beard": random.choice([0, 0, 0, 1, 2, 3]),
                            "build": round(random.uniform(0.25, 0.85), 2), "boots": random.choice(BOOTS)}}
        for k in KEYS:
            p[k] = rating(b, pos, k)
        players.append(p)
    return {"id": tid, "name": name, "short": short, "formation": "4-3-3",
            "kits": kits, "lineup": [p["id"] for p in players[:11]], "players": players}


used = set()
data = {"teams": [
    team("demo_azul", "Atlético Bahía Azul", "BAH", 78,
         {"home": {"shirt": "#0b2f7a", "shirt2": "#ffd200", "shorts": "#ffffff", "socks": "#0b2f7a"},
          "away": {"shirt": "#ffffff", "shirt2": "#0b2f7a", "shorts": "#0b2f7a", "socks": "#ffffff"},
          "gk": {"shirt": "#2fbf4a", "shirt2": "#111111", "shorts": "#111111", "socks": "#2fbf4a"}}, used),
    team("demo_rojo", "Deportivo Sierra Roja", "SIE", 76,
         {"home": {"shirt": "#c4161c", "shirt2": "#ffffff", "shorts": "#111111", "socks": "#c4161c"},
          "away": {"shirt": "#f2f2f2", "shirt2": "#c4161c", "shorts": "#c4161c", "socks": "#f2f2f2"},
          "gk": {"shirt": "#ff9f1a", "shirt2": "#111111", "shorts": "#111111", "socks": "#ff9f1a"}}, used),
]}
with open("data/teams/demo.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print("ok", sum(len(t["players"]) for t in data["teams"]), "jugadores")
