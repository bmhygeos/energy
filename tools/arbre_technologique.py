#!/usr/bin/env python3
"""Génère ARBRE_TECHNOLOGIQUE.txt à partir des données du jeu.

Recherches (data/research, dans l'ordre de scripts/world/research_db.gd),
bâtiments qu'elles débloquent (data/buildings, champ research) et bâtiments
débloqués par le seul palier. Le schéma de l'arbre (fin du fichier) est écrit
à la main : le script vérifie qu'il cite toutes les recherches.

Lancer depuis la racine du projet : python3 tools/arbre_technologique.py
"""
import glob
import re
import sys

TIERS = ["Hameau", "Village", "Bourg", "Ville", "Cité-État", "Cité des étoiles (capitale seule)"]
# Réseaux posés au glisser, débloqués par une recherche (pas de fichier de bâtiment).
NETWORKS = {
    "irrigation": ["Canal d'irrigation (réseau, monde, 1 bois par tuile)"],
    "locomotive": ["Voie ferrée (réseau, monde)"],
    "conductivity": ["Ligne électrique (réseau, monde, 1 cuivre par tuile)"],
}
DIAGRAM = """Arbre (prérequis → recherche)
-----------------------------
Palier 1 : Irrigation
Palier 2 :
  Collier d'attelage ──────────────────┐
  Métallurgie du fer → Outils ─────────┴→ Charrue → Assolement
  Engrenage ─┬→ Pompe à eau
             └→ Moulin à vent
Palier 3 :
  Méthode expérimentale
  Métallurgie du fer → Coke → Machine à vapeur → Locomotive
  Moulin à vent → Moulin à eau
  Assolement → Sylviculture → Charbon de bois
Palier 4 :
  Méthode expérimentale ─┬→ Raffinage du pétrole → Moteur à explosion → Tracteur
                         ├→ Conductivité du cuivre → Hydroélectricité
                         ├→ Enseignement supérieur
                         └→ Médecine
  Coke → Cimenterie
Palier 5 :
  Conductivité ─┬→ Électronique ─┬→ Informatique (+ Enseignement supérieur) → Intelligence artificielle → Véhicules autonomes
                │                ├→ Photovoltaïque
                │                ├→ Électrochimie du lithium → Véhicule électrique (+ Moteur à explosion)
                │                └→ Fusée (+ Moteur à explosion)
                ├→ Radioactivité
                └→ Énergie éolienne
Palier 6 (Cité des étoiles, capitale seule) :
  Radioactivité + Intelligence artificielle → Fusion nucléaire → Voyage sur la Lune (+ Fusée)"""


def field(text, key):
    m = re.search(rf"^{key} = (.*)$", text, re.M)
    return m.group(1) if m else ""


def number(value):
    return f"{int(value):,}".replace(",", " ")


def main():
    order = re.findall(r"research/([a-z_]+)\.tres", open("scripts/world/research_db.gd", encoding="utf-8").read())
    research = {}
    for rid in order:
        s = open(f"data/research/{rid}.tres", encoding="utf-8").read()
        research[rid] = {
            "name": field(s, "display_name").strip('"'),
            "tier": int(field(s, "tier") or 1),
            "cost": float(field(s, "cost") or 0),
            "pre": re.findall(r'&"([a-z_]+)"', field(s, "prerequisites")),
            "effect": field(s, "effect").strip('"'),
        }
    unlocked = {}
    by_tier = {}
    for path in sorted(glob.glob("data/buildings/*.tres")):
        s = open(path, encoding="utf-8").read()
        if field(s, "player_buildable") == "false":
            continue
        name = field(s, "display_name").strip('"')
        site = "monde" if field(s, "site") == "1" else "ville"
        rid = field(s, "research").strip('&"')
        if rid:
            unlocked.setdefault(rid, []).append(f"{name} ({site})")
        else:
            by_tier.setdefault(int(field(s, "tier") or 1), []).append(f"{name} ({site})")
    costs = [r["cost"] for r in research.values()]
    out = [
        "ARBRE TECHNOLOGIQUE — Energy (v2)", "=" * 34, "",
        "Fichier généré par tools/arbre_technologique.py à partir des données du jeu.",
        "Une recherche se lance quand son palier est atteint et ses prérequis terminés.",
        "Une seule recherche à la fois ; points de recherche par habitant et par jour,",
        "multipliés par l'atelier (×2), le laboratoire (×5), l'université (×10),",
        "le centre informatique (×20) et le datacenter (×100).",
        "Entre parenthèses après chaque bâtiment : la carte où il se construit (ville ou monde).",
        f"{len(order)} recherches, de {number(min(costs))} à {number(max(costs))} points.", "",
    ]
    for t in range(1, len(TIERS) + 1):
        title = f"Palier {t} — {TIERS[t - 1]}"
        out += [title, "-" * len(title)]
        for rid in order:
            r = research[rid]
            if r["tier"] != t:
                continue
            pre = ", ".join(research[p]["name"] for p in r["pre"]) or "aucun"
            out.append(f"* {r['name']}  ({number(r['cost'])} points)")
            out.append(f"    Prérequis : {pre}")
            built = unlocked.get(rid, []) + NETWORKS.get(rid, [])
            if built:
                out.append(f"    Débloque : {', '.join(built)}")
            out.append(f"    Effet : {r['effect']}")
        if by_tier.get(t):
            out.append(f"  Sans recherche (palier atteint) : {', '.join(by_tier[t])}")
        out.append("")
    out += [DIAGRAM, ""]
    missing = [research[r]["name"] for r in order if research[r]["name"] not in DIAGRAM]
    if missing:
        sys.exit("Recherches absentes du schéma : " + ", ".join(missing))
    open("ARBRE_TECHNOLOGIQUE.txt", "w", encoding="utf-8").write("\n".join(out))
    print(f"ARBRE_TECHNOLOGIQUE.txt : {len(order)} recherches")


if __name__ == "__main__":
    main()
