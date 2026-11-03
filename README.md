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
godot --headless -s res://tools/simulate_pacing.gd -- 42 8    # rythme des paliers : partie jouée seule (graine, années)
```

L'export nécessite les modèles d'export Godot 4.7.2 (Éditeur → Gérer les
modèles d'export).

La version web est exportée sans threads : elle fonctionne sur n'importe quel
hébergement statique (itch.io, GitHub Pages…) sans en-têtes COOP/COEP. Elle
doit être servie en HTTP (pas d'ouverture directe du fichier `index.html`) et
nécessite un navigateur avec WebGL 2.

Elle est publiée sur https://bmhygeos.github.io/energy/ (branche `gh-pages`,
contenu de `build/web` sans les fichiers `.import`). Sur tablette : toucher
pour sélectionner ou construire, glisser à un doigt (outil Sélection) ou à deux
doigts pour déplacer la vue, pincer pour zoomer ; bouton « Aide » pour le
tutoriel.

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
| Recherche | `R` ou bouton « Recherche » du bandeau, puis « Rechercher » |
| Améliorer | « Améliorer » du menu puis clic sur une maison ou un grenier |
| Statistiques et jalons | `G` ou bouton « Stats » du bandeau ; Échap pour fermer |
| Tutoriel | `H` pour l'afficher ou le masquer (affiché au lancement) |
| Calque d'information | `O` (relief, fertilité, pâturage, eau, gisements prospectés, vent, soleil) ou boutons en bas à droite |
| Nouvelle carte | champ « Graine » + « Carte », ou « Hasard » |

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
  1 nourriture et 0,2 bois par habitant (bois ×0,5 en été, ×2 en hiver), affichés dans le
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
  densité) ; coupée à blanc, la tuile devient plaine mais garde sa zone de
  coupe, qui ne fournit plus de bois (ni n'occupe de travailleurs) jusqu'à la
  repousse : la tuile redevient forêt après 120 jours sans bâtiment ni autre
  zone ; une forêt entamée se densifie au repos.
- **Stocks** (nourriture, bois) : capacité du village + greniers (600) et
  camps d'abattage (300 ; scierie au village : 600 et coupe du bois +20 %) ;
  surplus perdu ; la nourriture se gâte (1 %/j de l'excédent au-delà de la
  moitié du grenier). Les bâtiments coûtent du bois.
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
  collines et montagnes (2 carriers par tuile, 1,5 pierre/j chacun). Chaque
  carte place une colline à pierre près du village : au moins 4 tuiles de
  colline à 4 tuiles du centre au plus (bloc de 2×2 ajouté s'il le faut,
  laissé libre par les bâtiments de départ).
- **Pêche** : zone sur rivières, lacs et mer, 4 nourriture/j par pêcheur
  (×0,6 l'hiver).
- **Eau** : besoin à partir du village ; chaque **puits** (5 bois, 15 pierre)
  sert 30 habitants. Sans eau, la satisfaction baisse jusqu'à −30 % et la
  population ne grandit plus. Bandeau : « Eau x % ».
- **Maison en pierre** (10 bois, 20 pierre) : 10 habitants.
- **Atelier** (30 bois, 20 pierre) : recherche ×2 pour 100 habitants (les
  habitants au-delà comptent pour 1).
- **Expéditions** : 3 à la fois et jusqu'à 40 jours de vivres au village
  (1 et 20 au hameau).

### V6 (partie 2) : écurie et hippotraction
- **Écurie** (village, 20 bois, 10 pierre) : 6 chevaux. Les troupeaux des
  pâturages donnent des poulains (0,01 par tuile de pâturage et par jour, selon
  sa qualité) tant qu'il y a de la place ; chaque cheval mange 3 de fourrage par
  jour au grenier et dépérit sans lui (5 %/j).
- **Attelage** : les chevaux sont attelés automatiquement aux tuiles
  travaillées les plus lointaines (au-delà de 6 tuiles) ; la pénalité de
  distance y commence à 12 tuiles et vaut −1,5 % par tuile (au lieu de 6 et
  −3 %). Fiche de la tuile : « Attelage ».
- **Chevaux de bât** : réglage de l'expédition ; chacun porte 4 fois les
  vivres d'un explorateur (jours de vivres permis), absent de l'écurie pendant
  le voyage.
- **Puissance** : 700 W par cheval au travail. Panneau Main-d'œuvre : chevaux,
  attelés, en expédition, fourrage.

### V6 (partie 3) : inventions, fer et outils
- **Prospection** : au passage au village, le territoire est prospecté ; à
  partir du village, les expéditions prospectent ce qu'elles voient. Chaque
  gisement n'apparaît qu'à son palier (fer au village, charbon au bourg…).
- **Mine de fer** : zone sur un gisement de fer prospecté (2 mineurs, 1 fer/j
  chacun) ; le gisement s'épuise, puis la tuile perd sa zone. Chaque carte
  place un filon de fer près du village : au moins 2 tuiles de fer entre 3 et
  5 tuiles du centre (6 000 t chacune, ajoutées s'il le faut, laissées libres
  par les bâtiments de départ), visibles dès le passage au village.
- **Forge** (recherche Métallurgie du fer) : 2 outils/j, 1 fer et 0,5 bois
  chacun. Fer (200) et outils (100) au bandeau avec la pierre.
- **Stockage** (menu Stockage) : parc à pierre (village, 20 bois, +400
  pierre), entrepôt à outils (village, +200 outils),
  parc à fer (village, +400 fer), parc à charbon (bourg, +1 000 charbon),
  réservoir de pétrole (ville, +1 000 pétrole). Charbon (100 de base) et
  pétrole (aucune capacité sans réservoir) sont des marchandises prêtes pour
  les paliers 3 et 4, pas encore produites.
- **Inventions du village** (atelier ×2) :
  | Invention | Prérequis | Points | Effet |
  |---|---|---|---|
  | Collier d'attelage | — | 1 500 | Chevaux : bât et portée de l'attelage +50 % (pénalité à partir de 18 tuiles) |
  | Métallurgie du fer | — | 1 500 | Forge |
  | Outils | Métallurgie | 2 000 | Coupe du bois +40 %, maisons −25 % de bois |
  | Charrue | Collier, Outils | 2 500 | Agriculture +30 % attelée, +10 % sinon |
  | Assolement | Charrue | 3 000 | Fertilité stable, agriculture +15 % |
  | Engrenage | — | 1 500 | Carrières +15 %, puits +15 % |
  | Moulin à vent | Engrenage | 2 500 | Moulin : agriculture +20 %, gâchis ÷2, ≈ 3 kW selon le vent |
  | Pompe à eau | Engrenage | 2 000 | Puits +50 % d'habitants servis |
- **Besoin en outils** : bûcherons (après Outils) et laboureurs (après
  Charrue) usent 1 outil tous les 60 jours ; sans outils en stock, scie et
  charrue n'ont plus d'effet et la satisfaction baisse (jusqu'à −15 %).
- Menu : bâtiments grisés tant que leur recherche manque ; fiche de la tuile :
  bonus des inventions.
- **Greniers améliorables**, un niveau par palier (outil « Améliorer » du
  menu, puis clic sur le grenier ; il reste en service pendant les travaux) :
  | Niveau | Palier | Capacité | Coût de l'amélioration |
  |---|---|---|---|
  | Grenier | Hameau | 600 | (construction : 40 bois) |
  | Grenier en pierre | Village | 1 200 | 20 bois, 30 pierre |
  | Grand grenier | Bourg | 4 000 | 30 bois, 40 pierre, 10 fer |
  | Entrepôt | Ville | 7 000 | 20 bois, 60 pierre, 30 fer |
  | Silo | Cité-État | 12 000 | 80 pierre, 60 fer |
- **Maisons améliorables** de la même façon (logements gardés pendant les
  travaux ; la maison en pierre se construit aussi directement) :
  | Niveau | Palier | Habitants | Coût de l'amélioration |
  |---|---|---|---|
  | Maison | Hameau | 5 | (construction : 15 bois) |
  | Maison en pierre | Village | 10 | 10 bois, 20 pierre |
  | Maison bourgeoise | Bourg | 16 | 20 bois, 30 pierre, 5 fer |
  | Immeuble | Ville | 30 | 10 bois, 50 pierre, 20 fer |
  | Tour d'habitation | Cité-État | 60 | 80 pierre, 50 fer |

### V7 : interface et équilibrage
- **Statistiques** (`G`) : stocks et production de toutes les marchandises
  (pierre, fer et outils dès leur première production), eau servie avec la
  satisfaction, onglet « Territoire et village » (territoire, chevaux, points
  de recherche par jour).
- **Jalons** (onglet de la même fenêtre, annoncés en jeu) : premier hiver,
  au-delà de l'horizon (300 tuiles), irrigation, hameau prospère (50
  habitants), village, eau pour tous, maisons en dur, maître de forge, écurie
  pleine, inventions du village, grand territoire (2 000 tuiles), bourg.
- **Tutoriel** réécrit (11 étapes) : zones, camp d'abattage, hiver et
  panneau Main-d'œuvre, expédition, recherche, croissance jusqu'au village,
  puits et nouveautés du village, statistiques.
- **Rythme** : `godot --headless -s res://tools/simulate_pacing.gd -- 42 8`
  joue une partie avec une stratégie simple et affiche l'évolution, les
  paliers et les jalons. Mesuré : village vers le jour 270 (≈ 2 ans 1/4,
  11 min à ×1), bourg vers le jour 520. Les points mis de côté sont plafonnés
  à 10 jours : sans cela, le hameau finançait d'avance toutes les inventions
  du village, terminées en 4 semaines (désormais ≈ 2 mois et demi).

### V8 (partie 1) : bourg — charbon, vêtements, laboratoire, moulin à eau
- **Palier Bourg** (400 habitants, 80 % de satisfaction) : le territoire est
  prospecté, les gisements de **charbon** apparaissent. Chaque carte place un
  filon de charbon près du village (au moins 2 tuiles entre 4 et 5 tuiles du
  centre, 8 000 t chacune, ajoutées s'il le faut).
- **Mine de charbon** : zone sur un gisement de charbon prospecté (2 mineurs,
  1,5 charbon/j chacun) ; le gisement s'épuise.
- **Chauffage au charbon** : au bourg, tant qu'il y a du charbon en stock, il
  chauffe la moitié des maisons (1 charbon remplace 2 bois). Bandeau et panneau
  Main-d'œuvre : charbon brûlé par jour.
- **Vêtements** (nouveau besoin) : un vêtement par habitant tous les 100 jours ;
  sans eux, la satisfaction baisse (jusqu'à −15 %).
  - **Champ de lin** : zone sur les terres cultivables (2 travailleurs,
    1,5 fibre/j chacun, du printemps à l'automne ; charrue, assolement et
    irrigation s'appliquent, pas les moulins).
  - **Laine** : au bourg, chaque éleveur donne aussi 0,25 fibre/j.
  - **Atelier de tissage** (40 bois, 30 pierre, 5 fer) : 4 vêtements/j, une
    fibre chacun.
  - Fibres (200) et vêtements (150) en stock.
- **Recherches du bourg** :
  | Recherche | Prérequis | Points | Effet |
  |---|---|---|---|
  | Méthode expérimentale | — | 6 000 | **Laboratoire** (40 bois, 60 pierre, 15 fer, 10 outils) : recherche ×5 pour 400 habitants |
  | Coke | Métallurgie du fer | 20 000 | Les forges brûlent du charbon au lieu du bois et fabriquent 50 % d'outils en plus |
  | Moulin à eau | Moulin à vent | 30 000 | **Moulin à eau** (au bord d'une rivière ; 50 bois, 40 pierre, 10 fer) : agriculture +30 % (le meilleur moulin compte), gâchis ÷2, coupe du bois et forges +20 %, 8 kW sans dépendre du vent |
- Les bâtiments peuvent coûter des outils (laboratoire). Statistiques :
  charbon, fibres et vêtements, part des vêtements remplacés.
- **Jalons** : Gueules noires (premier charbon), Bien vêtus (tous les
  vêtements remplacés), Savants (laboratoire). **Tutoriel** : étape « Vers le
  bourg ».
- Reste pour le bourg (partie 2) : routes, marché, machine à vapeur, train,
  éclaireurs à cheval.

### Recherche (avancée de V6)
- **Points de recherche** : 1 par habitant et par jour, de 50 % à 100 % selon
  la satisfaction ; une recherche à la fois ; sans recherche en cours, les
  points sont mis de côté (10 jours de points au plus) et versés à la
  suivante.
- **Panneau Recherche** (`R` ou bouton du bandeau) : points par jour,
  recherche en cours, recherches du palier avec coût, avancement et effet.
- **Irrigation** (hameau, 500 points) : champs à 3 tuiles ou moins d'une
  rivière, d'un lac ou d'un puits (village) : rendement +30 % (indiqué dans la
  fiche de la tuile).

### V5 : exploration
- **Expédition** (menu, section Territoire) : 1 à 5 habitants actifs quittent
  le travail avec des vivres pris au grenier (1 par explorateur et par jour),
  partent du centre du village en ligne droite vers la tuile cliquée (inconnue
  comprise) et reviennent. Une expédition à la fois au palier 1.
- **Marche** : 4 tuiles/j en plaine et prairie, 3 en désert et toundra, 2 en
  forêt et colline, 1,5 sur la glace, 1 en montagne et aux gués ; lacs et mer
  infranchissables (arrêt devant l'eau).
- **Vue** : rayon de 3 tuiles ; les tuiles vues sont annexées au territoire.
- **Demi-tour** à la cible, devant l'eau ou quand il ne reste que les vivres
  du retour ; les vivres restants reviennent au grenier.
- **Annexion automatique** : pas d'outil d'annexion, l'expédition intègre au
  territoire tout ce qu'elle voit (sans limite de surface).
- Trajet prévu, position et rayon de vue de l'expédition sur la carte ;
  explorateurs dans le bandeau et le panneau Main-d'œuvre.
