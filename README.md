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
godot --headless -s res://tools/render_map_preview.gd -- 42 /tmp/planete.png 2   # planète (1 pixel / 2 tuiles) et site de départ
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
| Tracer une zone | bouton de zone du menu (Agriculture, Élevage, Coupe du bois) puis glisser sur la carte (rectangle ; les tuiles non valides sont ignorées) ; « Effacer les zones » puis glisser pour les retirer |
| Main-d'œuvre | `M` ou bouton « Main-d'œuvre » du bandeau : places, affectés, priorités |
| Statistiques et jalons | `G` ou bouton « Stats » du bandeau ; Échap pour fermer |
| Tutoriel | `H` pour l'afficher ou le masquer (affiché au lancement) |
| Calque d'information | `O` (relief, fertilité, pâturage, eau, gisements prospectés, vent, soleil) ou boutons en bas à droite |
| Nouvelle carte | champ « Graine » + Générer, ou Aléatoire |

## État de la v2

### V0 : nettoyage
Électricité, compagnie, recherche, véhicules, routes et villes retirés ; temps,
météo et interface conservés.

### V1 : planète et territoire
- **Planète** de 1024×512 tuiles en longitude / latitude, qui boucle d'est en
  ouest (pôles au nord et au sud de la grille). Générée à la demande par blocs
  de 32×32 à partir de la graine : bruit 3D sur la sphère (sans couture),
  continents, collines, montagnes, rivières et lacs.
- **Climat selon la latitude** : glace aux pôles, toundra, forêts, plaines et
  prairies, déserts vers les tropiques ; l'altitude refroidit.
- **Attributs** par tuile : fertilité (plaines, berges), pâturage (prairies,
  collines), densité de forêt (bois sur pied), vent, ensoleillement.
- **Gisements** (charbon, fer, pétrole, cuivre, uranium, lithium) générés avec
  la planète mais **cachés** jusqu'à la prospection (expéditions, V5).
- **États des tuiles** : inconnue (noire), explorée (assombrie), territoire
  (encadré en jaune). Départ : 12×12 tuiles aux latitudes tempérées, avec forêt,
  plaine et eau garanties ; on ne construit que sur le territoire.
- **Bâtiments** : seul le grenier est proposé (chantier de 36 h, sans coût, sans
  effet pour l'instant).

### V2 : zones
- **Trois zones** peintes au glisser (rectangle) et effaçables, au plus une par
  tuile, sur le territoire, hors des bâtiments (et pas de bâtiment sur une zone) :
  - **Agriculture** (2 travailleurs par tuile) : plaine, prairie et berges
    fertiles ;
  - **Élevage** (1) : prairie, plaine, colline ;
  - **Coupe du bois** (1) : forêt.
- **Calque des zones** toujours affiché (couleur et liseré) ; aperçu du rectangle
  (vert : peinte, rouge : refusée, motif dans le bandeau d'aide).

### V3 : population et main-d'œuvre
- **Habitants** : 20 au départ, dont 60 % d'actifs. **Besoins** par jour :
  1 nourriture et 0,2 bois par habitant (bois ×2 en hiver), affichés dans le
  bandeau et le panneau ; consommés à partir de V4 (stocks).
- **Répartition automatique** des actifs entre les types de zone, au prorata
  priorité × places (tuiles × travailleurs par tuile), plafonnée par les places ;
  l'excédent va aux autres zones, puis au chômage (signalé en rouge).
- **Priorités** 0–5 ou automatique (3 pour l'instant ; suivra les stocks en V4).
- **Réaffectation** : un travailleur retiré d'une zone met 24 h à être de nouveau
  disponible ; les chômeurs sont affectés tout de suite.
- Dans une zone, les travailleurs vont d'abord aux **meilleures tuiles** :
  qualité (fertilité, pâturage ou densité de forêt) × proximité (−3 % par tuile
  au-delà de 6 du village). Silhouettes sur les tuiles occupées.
- **Panneau Main-d'œuvre** (M) et onglet **Population** des statistiques.
- Pas encore de production : rendements, saisons, stocks et croissance en V4.
