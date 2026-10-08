# Energy

Jeu de gestion énergétique (Godot 4.7, GDScript) — voir [PLAN.md](PLAN.md).

## Commandes

```bash
godot -e                                   # ouvrir l'éditeur
godot                                      # lancer le jeu
godot --headless -s res://tests/run_tests.gd   # tests de la simulation
godot --headless --export-release "Windows Desktop" build/windows/Energy.exe

# Outils
godot --headless -s res://tools/generate_tile_art.gd        # régénère assets/tiles/*.png
godot --headless -s res://tools/render_map_preview.gd -- 42 /tmp/carte.png   # aperçu d'une carte
```

L'export nécessite les modèles d'export Godot 4.7.2 (Éditeur → Gérer les
modèles d'export).

## Contrôles

| Action | Touches |
|---|---|
| Déplacer la caméra | ZQSD (AZERTY) / WASD (QWERTY), flèches, glisser clic milieu ou droit |
| Zoom | molette (centré sur le curseur), `+` / `-` |
| Recentrer | Origine (Home) |
| Pause / vitesses | Espace, `1` ×1, `2` ×2, `3` ×4 |
| Sélectionner une tuile | clic gauche (re-clic ou Échap pour désélectionner) |
| Calque d'information | `O` (relief, vent, soleil, eau, gisements) ou boutons en bas à droite |
| Nouvelle carte | champ « Graine » + Générer, ou Aléatoire |
