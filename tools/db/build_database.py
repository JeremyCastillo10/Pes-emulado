"""Genera data/db/database.json: 20 ligas, sus clubes, todas las selecciones FIFA y jugadores.
Los jugadores con nombre real tienen valoraciones aproximadas; el resto de cada plantilla se
completa con jugadores genéricos ("generic": true) editables desde el juego.
Uso: python3 tools/db/build_database.py"""
import json, os, random, hashlib, sys
sys.path.insert(0, os.path.dirname(__file__))
import nations as N, names as NM
from leagues_a import ENG, ESP
from leagues_b import ITA, GER, FRA
from leagues_c import POR, NED, BEL, TUR, SCO, GRE, AUT, SUI
from leagues_d import BRA, ARG, MEX, USA, KSA, JPN, COL

LEAGUES = [ENG, ESP, ITA, GER, FRA, POR, NED, BRA, ARG, BEL, TUR, MEX, USA, KSA, SCO, JPN, COL, GRE, AUT, SUI]
LEAGUE_LEVEL = {"eng": 4, "esp": 4, "ita": 3, "ger": 3, "fra": 2, "por": 1, "ned": 1, "bra": 1, "arg": 0, "bel": 0,
                "tur": 0, "mex": 0, "usa": -1, "ksa": 0, "sco": -2, "jpn": -2, "col": -3, "gre": -2, "aut": -3, "sui": -3}
SEASON = 2026
NATIONS = {n["code"]: n for n in N.parse()}
KEYS = ["speed", "acceleration", "shot_accuracy", "shot_power", "short_pass", "long_pass", "dribbling",
        "ball_control", "defense", "heading", "physical", "stamina", "curl", "agility", "reflexes", "positioning"]
PROFILE = {
    "GK": {"reflexes": 6, "positioning": 5, "speed": -25, "acceleration": -20, "shot_accuracy": -40, "shot_power": -10,
           "dribbling": -35, "ball_control": -20, "defense": -25, "heading": -20, "curl": -30, "short_pass": -15, "long_pass": -8},
    "CB": {"defense": 6, "heading": 5, "physical": 4, "dribbling": -14, "shot_accuracy": -22, "curl": -18, "agility": -8, "speed": -5},
    "RB": {"speed": 3, "stamina": 4, "defense": 0, "shot_accuracy": -14, "heading": -6},
    "LB": {"speed": 3, "stamina": 4, "defense": 0, "shot_accuracy": -14, "heading": -6},
    "DMF": {"defense": 3, "short_pass": 2, "stamina": 3, "physical": 2, "shot_accuracy": -8, "dribbling": -5},
    "CMF": {"short_pass": 3, "long_pass": 2, "stamina": 3, "defense": -6, "shot_accuracy": -4},
    "AMF": {"short_pass": 3, "dribbling": 4, "ball_control": 4, "curl": 3, "defense": -25, "heading": -10, "physical": -8},
    "RMF": {"speed": 3, "dribbling": 2, "stamina": 3, "defense": -14}, "LMF": {"speed": 3, "dribbling": 2, "stamina": 3, "defense": -14},
    "RWF": {"speed": 5, "acceleration": 5, "dribbling": 4, "defense": -28, "heading": -10},
    "LWF": {"speed": 5, "acceleration": 5, "dribbling": 4, "defense": -28, "heading": -10},
    "SS": {"dribbling": 3, "shot_accuracy": 3, "ball_control": 3, "defense": -28},
    "CF": {"shot_accuracy": 5, "shot_power": 4, "heading": 2, "defense": -32, "long_pass": -8},
}
SQUAD_TEMPLATE = ["GK", "GK", "GK", "RB", "RB", "LB", "LB", "CB", "CB", "CB", "CB", "DMF", "DMF", "CMF", "CMF", "CMF",
                  "AMF", "RWF", "RMF", "LWF", "LMF", "CF", "CF"]
FORMATIONS = ["4-3-3", "4-3-3", "4-2-3-1", "4-2-3-1", "4-4-2", "3-5-2", "5-3-2"]
SLOTS = {
    "4-4-2": ["GK", "RB", "CB", "CB", "LB", "RMF", "CMF", "CMF", "LMF", "CF", "CF"],
    "4-3-3": ["GK", "RB", "CB", "CB", "LB", "DMF", "CMF", "CMF", "RWF", "CF", "LWF"],
    "4-2-3-1": ["GK", "RB", "CB", "CB", "LB", "DMF", "DMF", "RMF", "AMF", "LMF", "CF"],
    "3-5-2": ["GK", "CB", "CB", "CB", "RMF", "DMF", "CMF", "CMF", "LMF", "CF", "CF"],
    "5-3-2": ["GK", "RB", "CB", "CB", "CB", "LB", "CMF", "CMF", "CMF", "CF", "CF"],
}
SIMILAR = {"GK": ["GK"], "CB": ["CB", "DMF"], "RB": ["RB", "RMF", "CB"], "LB": ["LB", "LMF", "CB"], "DMF": ["DMF", "CMF", "CB"],
           "CMF": ["CMF", "DMF", "AMF"], "AMF": ["AMF", "CMF", "SS"], "RMF": ["RMF", "RWF", "RB"], "LMF": ["LMF", "LWF", "LB"],
           "RWF": ["RWF", "RMF", "CF"], "LWF": ["LWF", "LMF", "CF"], "CF": ["CF", "SS", "RWF", "LWF"], "SS": ["SS", "CF", "AMF"]}
SKIN = {"light": ["#f3d2b6", "#ecc4a2", "#e0ac83"], "mid": ["#d29b6e", "#c68b5e", "#b07650"],
        "dark": ["#8d5a36", "#734626", "#5a3620", "#4a2c18"], "asian": ["#efcba3", "#e5bb92", "#d8a97d"]}
POOL_SKIN = {"es": [("light", 5), ("mid", 4), ("dark", 1)], "pt": [("light", 3), ("mid", 4), ("dark", 3)],
             "en": [("light", 7), ("mid", 1), ("dark", 2)], "it": [("light", 8), ("mid", 2)], "de": [("light", 8), ("mid", 1), ("dark", 1)],
             "fr": [("light", 5), ("mid", 2), ("dark", 3)], "nl": [("light", 7), ("mid", 1), ("dark", 2)], "tr": [("light", 5), ("mid", 5)],
             "ar": [("mid", 7), ("light", 2), ("dark", 1)], "ja": [("asian", 10)], "ko": [("asian", 10)], "gr": [("light", 7), ("mid", 3)],
             "slav": [("light", 9), ("mid", 1)], "nordic": [("light", 9), ("dark", 1)], "afr_fr": [("dark", 9), ("mid", 1)], "afr_en": [("dark", 9), ("mid", 1)]}
HAIR = ["#1a1310", "#2b1d14", "#3b2618", "#6b4423", "#a8784a", "#d9c27a", "#2b2b2b", "#111111"]
BOOTS = ["#111111", "#f5f5f5", "#ff6a00", "#1e90ff", "#ffd400", "#e0115f", "#32cd32", "#7fffd4", "#c0c0c0"]


def rng_for(*parts):
    h = int(hashlib.md5("|".join(map(str, parts)).encode()).hexdigest()[:12], 16)
    return random.Random(h)


def pick_weighted(r, items):
    total = sum(w for _, w in items)
    x = r.uniform(0, total)
    for k, w in items:
        x -= w
        if x <= 0:
            return k
    return items[-1][0]


def attrs_for(ovr, pos, r):
    prof = PROFILE.get(pos, {})
    out = {}
    for k in KEYS:
        v = ovr + prof.get(k, 0) + r.randint(-5, 5)
        if pos != "GK" and k in ("reflexes", "positioning"):
            v = 30 + r.randint(0, 15)
        out[k] = max(25, min(99, v))
    return out


def appearance(nat, r):
    pool = NATIONS.get(nat, {}).get("pool", "en")
    tone = pick_weighted(r, POOL_SKIN.get(pool, [("light", 5), ("mid", 3), ("dark", 2)]))
    dark = tone == "dark"
    return {"skin": r.choice(SKIN[tone]), "hair_style": r.choice([0, 1, 1, 1, 2, 3, 4 if dark else 1, 5]),
            "hair_color": r.choice(HAIR[:3] if dark or tone == "asian" else HAIR), "beard": r.choice([0, 0, 0, 1, 2, 3]),
            "build": round(r.uniform(0.25, 0.85), 2), "boots": r.choice(BOOTS)}


def height(pos, r):
    if pos == "GK":
        return r.randint(185, 198)
    if pos == "CB":
        return r.randint(182, 195)
    if pos in ("CF",):
        return r.randint(175, 192)
    return r.randint(167, 186)


def value_of(ovr, age):
    af = 1.6 if age <= 21 else 1.3 if age <= 24 else 1.0 if age <= 28 else 0.65 if age <= 31 else 0.35
    return round(max(0.2, 0.06 * (1.28 ** (ovr - 60)) * af), 1)


PLAYERS = []
USED_IDS = set()


def new_player(name, pos, nat, age, ovr, club, generic, r, number=0):
    base = "".join(ch for ch in name.lower() if ch.isalnum())[:14] or "p"
    pid = f"{club or 'free'}_{base}"
    i = 2
    while pid in USED_IDS:
        pid = f"{club or 'free'}_{base}{i}"
        i += 1
    USED_IDS.add(pid)
    p = {"id": pid, "name": name, "nation": nat, "position": pos, "number": number, "foot": "left" if r.random() < 0.24 else "right",
         "age": age, "height": height(pos, r), "ovr": ovr}
    p.update(attrs_for(ovr, pos, r))
    p["appearance"] = appearance(nat, r)
    p["team"] = club
    p["value"] = value_of(ovr, age)
    p["wage"] = round(p["value"] * 0.05 + 0.05, 2)
    p["contract"] = SEASON + r.randint(1, 5)
    p["potential"] = min(95, ovr + max(0, (24 - age)) * r.randint(1, 3))
    if generic:
        p["generic"] = True
    PLAYERS.append(p)
    return p


def generic_name(nat, r):
    pool = NATIONS.get(nat, {}).get("pool", "en")
    first, last = NM.pool(pool)
    return f"{r.choice(first)[0]}. {r.choice(last)}"


def kits(c1, c2, r):
    def lum(h):
        h = h.lstrip("#")
        rr, gg, bb = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return 0.299 * rr + 0.587 * gg + 0.114 * bb
    light1 = lum(c1) > 150
    home = {"shirt": c1, "shirt2": c2 if abs(lum(c1) - lum(c2)) > 60 else ("#000000" if light1 else "#ffffff"),
            "shorts": c2 if r.random() < 0.5 else (c1 if not light1 else "#ffffff"), "socks": c1}
    away_shirt = "#ffffff" if lum(c1) < 200 else "#1a1a2e"
    away = {"shirt": c2 if abs(lum(c1) - lum(c2)) > 80 else away_shirt, "shirt2": c1, "shorts": c2 if r.random() < 0.5 else c1, "socks": c2}
    if abs(lum(away["shirt"]) - lum(home["shirt"])) < 60:
        away["shirt"] = away_shirt
    third = {"shirt": r.choice(["#1a1a2e", "#2d2d2d", "#0b6e4f", "#5b2c86", "#f2a900", "#8a1538"]), "shirt2": "#ffffff", "shorts": "#1a1a2e", "socks": "#1a1a2e"}
    gk = {"shirt": r.choice(["#2fbf4a", "#ff9f1a", "#e6e600", "#111111", "#00bcd4"]), "shirt2": "#111111", "shorts": "#111111", "socks": "#111111"}
    return {"home": home, "away": away, "third": third, "gk": gk}


def pick_lineup(players, formation):
    used, lineup = set(), []
    for role in SLOTS[formation]:
        best = None
        for pass_i in range(3):
            cands = [p for p in players if p["id"] not in used and (
                (pass_i == 0 and p["position"] == role) or (pass_i == 1 and p["position"] in SIMILAR.get(role, [role])) or
                (pass_i == 2 and (p["position"] != "GK") == (role != "GK")))]
            if cands:
                best = max(cands, key=lambda p: p["ovr"])
                break
        if best is None:
            best = max([p for p in players if p["id"] not in used], key=lambda p: p["ovr"])
        used.add(best["id"])
        lineup.append(best["id"])
    return lineup


def build_squad(club_id, country, base_ovr, roster, r, nation_mode=False):
    players = []
    numbers = set()
    for entry in [e for e in roster.split(";") if e.strip()]:
        name, pos, nat, age, ovr = entry.split(":")
        p = new_player(name.strip(), pos, nat, int(age), int(ovr), club_id, False, r)
        players.append(p)
    # Completar con genéricos hasta cubrir la plantilla tipo
    need = list(SQUAD_TEMPLATE)
    for p in players:
        for i, role in enumerate(need):
            if p["position"] == role or p["position"] in SIMILAR.get(role, []):
                need.pop(i)
                break
    real_avg = sum(p["ovr"] for p in players) / len(players) if players else base_ovr
    gen_base = min(base_ovr, real_avg - 3) if players else base_ovr
    while len(players) + len(need) < 23:
        need.append(r.choice(["CMF", "CB", "CF", "RWF"]))
    for role in need[: max(0, 23 - len(players))]:
        nat = country if (nation_mode or r.random() < 0.72) else r.choice(list(NATIONS.keys()))
        age = r.randint(18, 33)
        ovr = int(max(45, min(80, gen_base + r.randint(-6, 3) - (4 if role == "GK" and len([q for q in players if q["position"] == "GK"]) else 0))))
        players.append(new_player(generic_name(nat, r), role, nat, age, ovr, club_id, True, r))
    # Dorsales
    pref = {"GK": [1, 13, 25], "RB": [2, 22], "LB": [3, 12], "CB": [4, 5, 15, 24], "DMF": [6, 16], "CMF": [8, 14, 18],
            "AMF": [10, 20], "RWF": [7, 17], "RMF": [7, 19], "LWF": [11, 21], "LMF": [11, 23], "CF": [9, 19, 27], "SS": [10, 29]}
    for p in sorted(players, key=lambda q: -q["ovr"]):
        n = next((x for x in pref.get(p["position"], []) if x not in numbers), None)
        if n is None:
            n = next(x for x in range(2, 99) if x not in numbers)
        numbers.add(n)
        p["number"] = n
    return players


def main():
    db = {"version": 1, "season": SEASON, "leagues": [], "teams": [], "nations": [], "players": []}
    for code, lname, country, clubs in LEAGUES:
        lvl = LEAGUE_LEVEL[code]
        league = {"id": code, "name": lname, "country": country, "teams": []}
        for cid, name, short, c1, c2, prestige, stadium, roster in clubs:
            tid = f"{code}_{cid}"
            r = rng_for(tid)
            base = 58 + prestige * 3 + lvl
            players = build_squad(tid, country, base, roster, r)
            formation = r.choice(FORMATIONS)
            team = {"id": tid, "name": name, "short": short, "country": country, "league": code, "prestige": prestige,
                    "formation": formation, "kits": kits(c1, c2, r),
                    "crest": {"shape": r.choice(["shield", "circle", "round_shield", "diamond"]), "c1": c1, "c2": c2, "text": short},
                    "stadium": {"name": stadium, "capacity": 15000 + prestige * 14000 + r.randint(0, 9000), "roof": prestige >= 3,
                                "seat_color": c1, "pattern": r.randint(0, 4)},
                    "budget": round(5 + prestige ** 2.6 * (1.5 + max(lvl, 0) * 0.6), 1),
                    "players": [p["id"] for p in players]}
            team["lineup"] = pick_lineup(players, formation)
            db["teams"].append(team)
            league["teams"].append(tid)
        db["leagues"].append(league)
    # Selecciones
    by_nat = {}
    for p in PLAYERS:
        by_nat.setdefault(p["nation"], []).append(p)
    for code, n in NATIONS.items():
        r = rng_for("nat", code)
        pool = sorted(by_nat.get(code, []), key=lambda p: -p["ovr"])
        squad, counts = [], {"GK": 0, "DEF": 0, "MID": 0, "FWD": 0}
        limits = {"GK": 3, "DEF": 8, "MID": 7, "FWD": 5}
        grp = lambda pos: "GK" if pos == "GK" else "DEF" if pos in ("CB", "RB", "LB") else "MID" if pos in ("DMF", "CMF", "AMF", "RMF", "LMF") else "FWD"
        for p in pool:
            if p.get("generic") and p["ovr"] < n["strength"] - 12:
                continue
            g = grp(p["position"])
            if counts[g] < limits[g]:
                squad.append(p)
                counts[g] += 1
            if len(squad) >= 23:
                break
        missing = []
        for g, lim in limits.items():
            role_cycle = {"GK": ["GK"], "DEF": ["CB", "RB", "LB", "CB"], "MID": ["DMF", "CMF", "AMF", "RMF", "LMF"], "FWD": ["CF", "RWF", "LWF"]}[g]
            for i in range(lim - counts[g]):
                missing.append(role_cycle[i % len(role_cycle)])
        base = n["strength"] - 6
        extra = [new_player(generic_name(code, r), role, code, r.randint(19, 33), max(40, min(80, base + r.randint(-6, 4))), None, True, r) for role in missing]
        squad += extra
        formation = r.choice(FORMATIONS)
        k = kits(n["c1"], n["c2"], r)
        nat = {"id": "nat_" + code, "code": code, "name": n["name"], "short": code, "confed": n["confed"], "strength": n["strength"],
               "formation": formation, "kits": k, "crest": {"shape": "round_shield", "c1": n["c1"], "c2": n["c2"], "text": code},
               "players": [p["id"] for p in squad]}
        nat["lineup"] = pick_lineup(squad, formation)
        db["nations"].append(nat)
    db["players"] = PLAYERS
    out = os.path.join(os.path.dirname(__file__), "..", "..", "data", "db", "database.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, separators=(",", ":"))
    real = sum(1 for p in PLAYERS if not p.get("generic"))
    print(f"ligas={len(db['leagues'])} clubes={len(db['teams'])} selecciones={len(db['nations'])} jugadores={len(PLAYERS)} (reales={real}) tamaño={os.path.getsize(out)//1024} KB")


if __name__ == "__main__":
    main()
