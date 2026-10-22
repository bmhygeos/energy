# Energy

Gouverneur d'une cité-État (Godot 4.7, GDScript) — voir [PLAN_v2.md](PLAN_v2.md).

La v1 (compagnie d'électricité, du bois à la fusion, voir [PLAN.md](PLAN.md))
est figée au tag `v1.0` et sur la branche `main`. La branche `v2` en repart :
l'électricité, la compagnie (argent, ventes, marché), la recherche, les
véhicules, routes, rails et villes ont été retirés (étape V0) ; la carte, le
temps, la météo et l'interface sont conservés.

## Commandes

```bash
godot -e                                   # ouvrir l'éditeur
godot                                      # lancer le jeu
godot --headless -s res://tests/run_tests.gd   # tests de la simulation
godot -s res://tools/ui_click_test.gd          # test de l'interface (vrais clics ; déplace le pointeur)
godot --headless --export-release "Windows Desktop" build/windows/Energy.exe
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8060      # tester la version web : http://localhost:8060

# Outils
godot --headless -s res://tools/generate_tile_art.gd        # régénère assets/tiles/*.png
godot --headless -s res://tools/render_map_preview.gd -- 42 /tmp/carte.png   # aperçu d'une carte
```

L'export nécessite les modèles d'export Godot 4.7.2 (Éditeur → Gérer les
modèles d'export).

La version web est exportée sans threads : elle fonctionne sur n'importe quel
hébergement statique (itch.io, GitHub Pages…) sans en-têtes COOP/COEP. Elle
doit être servie en HTTP (pas d'ouverture directe du fichier `index.html`) et
nécessite un navigateur avec WebGL 2.

## Contrôles

| Action | Touches |
|---|---|
| Déplacer la caméra | ZQSD (AZERTY) / WASD (QWERTY), flèches, glisser clic milieu ou droit |
| Zoom | molette (centré sur le curseur), `+` / `-` |
| Recentrer | Origine (Home) |
| Pause / vitesses | Espace, `1` ×1, `2` ×2, `3` ×4 |
| Sélectionner une tuile / un bâtiment | clic gauche (re-clic ou Échap pour désélectionner) |
| Construire | bouton du menu « Construction » puis clic sur la carte (le fantôme est vert si le placement est valide, sinon le motif s'affiche en bas) ; Échap ou re-clic sur le bouton pour quitter |
| Démolir | `X` ou bouton « Démolir », puis clic sur un bâtiment |
| Statistiques et jalons | `G` ou bouton « Stats » du bandeau ; Échap pour fermer |
| Tutoriel | `H` pour l'afficher ou le masquer (affiché au lancement) |
| Calque d'information | `O` (relief, vent, soleil, eau, gisements) ou boutons en bas à droite |
| Nouvelle carte | champ « Graine » + Générer, ou Aléatoire |

## État de la v2 (V0 : nettoyage)

- **Carte** : génération par graine, terrains, relief, vent, soleil, eau et
  gisements (visibles d'emblée en attendant l'exploration).
- **Temps** : tick d'une heure, saisons, météo, jour et nuit.
- **Bâtiments** : seul le **grenier** est proposé (chantier de 36 h, sans
  coût) ; il n'a pas encore d'effet. Les bâtiments de la ville (maisons,
  grenier…) prendront sens avec la population et les stocks (V3–V4).
- **Statistiques et jalons** : fenêtre conservée, contenus à écrire avec les
  simulations de la v2.
