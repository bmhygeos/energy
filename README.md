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
| Main-d'œuvre | `M` ou bouton « Travail » du bandeau : places, affectés, production prévue, priorités |
| Explorer | « Expédition » du menu, régler explorateurs et jours de vivres, puis cliquer la destination sur la carte |
| Annexer | « Annexer » du menu puis glisser sur des tuiles explorées au bord du territoire |
| Recherche | `R` ou bouton « Recherche » du bandeau, puis « Rechercher » |
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

### V4 : production et saisons (première version jouable)
- **Rendement** d'une tuile = travailleurs × base × qualité × saison × proximité :
  agriculture 12 nourriture/travailleur/j du printemps à l'automne (rien en
  hiver), élevage 2,4 toute l'année (×0,8 l'hiver), coupe du
  bois 4,5.
- **Fertilité** : un champ cultivé s'use, il se reconstitue au repos.
- **Forêt** : la coupe vide le bois sur pied (rendement qui baisse avec la
  densité) ; coupée à blanc, la tuile devient plaine et perd sa zone, puis
  redevient forêt après 120 jours sans zone ni bâtiment ; une forêt entamée se
  densifie au repos.
- **Stocks** (nourriture, bois) : capacité du village + greniers (600) et
  réserves de bois (300) ; surplus perdu ; la nourriture se gâte (1 %/j de
  l'excédent au-delà de la moitié du grenier). Les bâtiments coûtent du bois.
- **Consommation** heure par heure ; **satisfaction** = couverture des besoins
  sur 10 jours. **Croissance** si les besoins sont couverts et qu'il reste des
  logements (maisons : 5 habitants) ; départs si la satisfaction baisse ou sans
  logement ; famine : déclin rapide.
- **Départ** : grenier et 4 maisons construits, et des réserves de nourriture et de bois.
- **Mode automatique** : champs et élevage en priorité quand la nourriture ne
  tiendra pas jusqu'aux prochaines récoltes (ou moins de 20 jours) ; coupe du
  bois quand le bois manque ou ne couvrira pas l'hiver (réserves visées
  plafonnées par la capacité des stocks) ; personne sur les zones sans
  production de saison ni quand le stock est plein (plein à 95 %, de nouveau à
  remplir sous 75 %). Dans la répartition, les places ne comptent que jusqu'au
  nombre d'actifs.
- **Palier** de la ville dans le bandeau (Hameau → Cité-État : population et
  80 % de satisfaction).
- **Puissance de la cité** dans le bandeau : énergie produite (nourriture
  10,5 MJ, bois 150 MJ par unité), moyenne sur 30 jours, totale et par habitant
  (≈ 0,5 kW/hab pour un hameau). Statistiques : population, satisfaction,
  stocks, production, pertes, puissance.
- Champs qui changent d'aspect avec les saisons (labour, blé vert, blé mûr,
  chaume).

### V6 (partie 1) : village — pierre, eau, pêche, atelier
- **Palier Village** (100 habitants, 80 % de satisfaction) : zones et bâtiments
  du village grisés avant, avec le palier indiqué.
- **Pierre** (nouvelle marchandise, 300 de capacité) : zone **Carrière** sur
  collines et montagnes (2 carriers par tuile, 1,5 pierre/j chacun) ; le
  territoire de départ compte au moins 4 collines.
- **Pêche** : zone sur rivières, lacs et mer, 2 nourriture/j par pêcheur
  (×0,6 l'hiver).
- **Eau** : besoin à partir du village ; chaque **puits** (5 bois, 15 pierre)
  sert 30 habitants. Sans eau, la satisfaction baisse jusqu'à −30 % et la
  population ne grandit plus. Bandeau : « Eau x % ».
- **Maison en pierre** (10 bois, 20 pierre) : 10 habitants.
- **Atelier** (30 bois, 20 pierre) : recherche ×2 pour 100 habitants (les
  habitants au-delà comptent pour 1).
- **Expéditions** : 3 à la fois et jusqu'à 40 jours de vivres au village
  (1 et 20 au hameau).

### Recherche (avancée de V6)
- **Points de recherche** : 1 par habitant et par jour, de 50 % à 100 % selon
  la satisfaction ; une recherche à la fois ; sans recherche en cours, les
  points sont mis de côté et versés à la suivante.
- **Panneau Recherche** (`R` ou bouton du bandeau) : points par jour,
  recherche en cours, recherches du palier avec coût, avancement et effet.
- **Irrigation** (hameau, 500 points) : champs à 3 tuiles ou moins d'une
  rivière ou d'un lac : rendement +30 % (indiqué dans la fiche de la tuile).

### V5 : exploration
- **Expédition** (menu, section Territoire) : 1 à 5 habitants actifs quittent
  le travail avec des vivres pris au grenier (1 par explorateur et par jour),
  partent du centre du village en ligne droite vers la tuile cliquée (inconnue
  comprise) et reviennent. Une expédition à la fois au palier 1.
- **Marche** : 4 tuiles/j en plaine et prairie, 3 en désert et toundra, 2 en
  forêt et colline, 1,5 sur la glace, 1 en montagne et aux gués ; lacs et mer
  infranchissables (arrêt devant l'eau).
- **Vue** : rayon de 3 tuiles ; les tuiles inconnues deviennent explorées.
- **Demi-tour** à la cible, devant l'eau ou quand il ne reste que les vivres
  du retour ; les vivres restants reviennent au grenier.
- **Annexion** (glisser un rectangle) : tuiles explorées reliées au territoire
  de proche en proche, gratuitement, au plus 8 tuiles de territoire par
  habitant.
- Trajet prévu, position et rayon de vue de l'expédition sur la carte ; aperçu
  de l'annexion ; explorateurs dans le bandeau et le panneau Main-d'œuvre.
