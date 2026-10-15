# Energy

Jeu de gestion énergétique (Godot 4.7, GDScript) — voir [PLAN.md](PLAN.md).

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
| Démolir | `X` ou bouton « Démolir », puis clic sur un bâtiment (rembourse 25 % du coût, 75 % pour un chantier) |
| Arbre technologique | `T` ou bouton « Recherche » du bandeau ; Échap pour fermer |
| Statistiques et jalons | `G` ou bouton « Stats » du bandeau ; Échap pour fermer |
| Tutoriel | `H` pour l'afficher ou le masquer (affiché au lancement) |
| Calque d'information | `O` (relief, vent, soleil, eau, gisements, réseau) ou boutons en bas à droite ; les gisements ne sont visibles qu'après la technologie Prospection |
| Nouvelle carte | champ « Graine » + Générer, ou Aléatoire |

## Production (M3)

- **Bûcheron** : coupe le bois des forêts à 2 tuiles (les plus proches d'abord) ;
  une forêt vidée redevient plaine. **Pépinière** : fait repousser les forêts à
  2 tuiles et en plante une nouvelle par jour.
- **Mine de charbon** : vide le gisement sous elle et autour (1 tuile).
- **Centrales** biomasse / charbon : brûlent le combustible reçu ; puissance
  proportionnelle au combustible disponible. Éolienne et ferme solaire : puissance
  × vent / ensoleillement de la tuile.
- Chaque bâtiment a un tampon d'entrée et de sortie : sortie pleine → arrêt
  (pastille orange), entrée vide → arrêt (pastille rouge), ressource épuisée →
  pastille grise. Détails (stocks, fournisseurs, ressource restante) dans le
  panneau d'information ; puissance totale dans le bandeau.
- Débits de départ : bûcheron 0,3 t/h, mine 0,6 t/h ; centrale biomasse
  0,6 t/h de bois → 8 MW, centrale à charbon 1,2 t/h → 40 MW.

## Transport routier (M3b)

- **Routes** : outil « Route » puis glisser sur la carte (tracé en L). 50 €/tuile,
  75 € en forêt (défrichée), 100 € en colline, pont de 400 € sur rivière ; mer,
  lac et montagne infranchissables. Entretien 1 €/tuile/jour. Démolition
  (`X`) d'une tuile de route sans remboursement.
- **Dépôt de véhicules** (relié à une route, 6 places, livré avec deux
  charrettes) : **indispensable**, sans lui rien ne circule. Sélectionnez-le
  pour acheter ou revendre (50 %) des charrettes (12 t, 1 tuile/h) et des
  camions (30 t, 1,2 tuile/h). Un véhicule en mission peut être vendu : vide,
  il abandonne sa mission, chargé il livre d'abord, puis il est vendu à son
  retour au dépôt ; sa place est libérée tout de suite (remplacement de la
  flotte, par exemple charrettes → camions). Deux charrettes suffisent pour deux bûcherons
  et une centrale biomasse à une dizaine de tuiles.
- **Dispatcher** : chaque heure, les consommateurs les moins remplis sont servis
  en premier par la source joignable la plus proche ayant une charge correcte
  (80 % du véhicule ou du besoin), ou par une source presque pleine. Le
  véhicule libre le plus proche va charger, livre, puis rentre au dépôt ou
  enchaîne une autre mission. Coût d'usage par tuile parcourue.
- Le panneau d'information indique sous « Transport » pourquoi les
  marchandises d'un bâtiment ne circulent pas (pas de route, pas de client ou
  de fournisseur joignable, pas de dépôt, véhicules tous occupés).
- **Entrepôt** (relié à une route, 200 t toutes marchandises) : reçoit le
  surplus des producteurs dont la sortie dépasse 50 % sans client, et
  approvisionne ensuite les consommateurs.
- Un bâtiment qui échange des marchandises sans route affiche une pastille bleue.
- Couper une route recalcule les trajets ; une mission impossible est annulée
  (chargement perdu) et le véhicule rentre.

## Réseau électrique et villes (M4)

- **Villes** (5 sur une carte 64×64) : demande de base de 3 à 10 MW, modulée
  par l'heure (creux la nuit, pic à 19 h : ×1,3) et la saison (hiver ×1,25,
  été ×0,9) ; elle croît de 25 %/an si la ville est bien alimentée, 2 % sinon.
  Une ville ne se démolit pas. Commencez par une petite ville : une centrale
  biomasse (8 MW) ne suffit pas pour les grandes.
- **Lignes HT** : outil « Ligne HT » puis glisser (tracé en L). 40 €/tuile,
  120 € sur rivière ou montagne, mer et lac interdits ; entretien
  1 €/tuile/jour. Elles peuvent longer ou croiser les routes. Un bâtiment ou
  une ville est raccordé si une ligne borde son emprise ; un bâtiment touché
  par deux lignes les relie en un seul réseau.
- **Équilibre, chaque heure, par réseau** : pertes de 0,2 % par tuile de ligne
  (25 % max.) ; les villes sont servies de la plus petite à la plus grande,
  celles qui ne peuvent l'être entièrement sont **délestées** (coupure) avec
  une pénalité de 5 €/MWh non livré ; le surplus charge les batteries et
  STEP du réseau, sinon il est perdu.
- **Consignes** : les centrales à combustible ne produisent que ce que
  demandent leurs villes (+5 % de marge, pertes comprises), au prorata du
  combustible en stock ; éolien et solaire passent d'abord (leur production
  de l'heure suivante est prévue avec la météo). Une centrale sans
  ligne est à l'arrêt (pastille jaune), sans demande elle est en veille et ne
  brûle rien.
- **Vente** : au prix du marché (10 €/MWh en moyenne, voir M7). Le bandeau
  affiche l'énergie livrée / demandée (en rouge en cas de délestage) et le
  bilan de la veille ; le calque
  « Réseau » colore lignes, villes et centrales selon leur état.

## Recherche (M5)

- **Laboratoire** (6 000 €) : 1 RP/h, à condition d'être raccordé au réseau
  électrique et alimenté (1 MW, servi avant les villes et non vendu).
- **Arbre technologique** (`T`) : 31 technologies sur 7 ères, du bois à la
  fusion. Cliquer une technologie la met en recherche, précédée de ses
  prérequis manquants ; re-cliquer la retire (avec ce qui en dépend). Les
  points produits sans recherche en cours sont mis en réserve.
- **Au départ** : Bûcheronnage et Biomasse (bûcheron, centrale biomasse),
  plus routes, lignes, dépôt, entrepôt et laboratoire. Le reste est verrouillé
  (grisé dans le menu) : pépinière (Sylviculture), mine (Mines), camion
  (Camions), centrale à charbon, éolienne (Éolien), ferme solaire (Solaire PV),
  voie ferrée, gare et train (Rail), mine d'uranium (Physique nucléaire),
  usine d'enrichissement et camion blindé (Enrichissement), centrale
  nucléaire et site de déchets (Réacteur), port, barge et éolienne offshore
  (Offshore),
  centrale solaire thermique (Solaire thermique), batteries (Batteries),
  STEP (STEP).
- **Bonus** : Vapeur −15 % de combustible, Mines +10 % d'extraction,
  Sylviculture ×2 repousse, Lignes HT et Transformateurs −40 % de pertes
  chacun, Dispatching et Smart grid −50 % de pénalités, Camions +10 % de
  vitesse, Physique nucléaire et des plasmas : recherche +10 % / +20 %,
  Gestion des déchets −50 % de déchets nucléaires, Filtres CO₂ −50 % de
  pollution des centrales à combustible…
- Les technologies marquées « contenu à venir » (fusion) font partie de
  l'arbre mais leurs bâtiments arriveront à l'étape M6b.

## Rail (M5b)

- **Technologie Rail** (ère 2, 1 800 RP, après Centrale à charbon) : débloque
  la voie ferrée, la gare de marchandises et le train.
- **Voies ferrées** : outil « Voie ferrée » puis glisser (tracé en L).
  150 €/tuile, 200 € en forêt (défrichée), 300 € en colline, pont de 1 200 €
  sur rivière ; mer, lac et montagne infranchissables. Entretien
  2 €/tuile/jour. Une voie peut croiser une route (passage à niveau).
  Démolition (`X`) sans remboursement ; sur un passage à niveau, la voie part
  avant la route.
- **Gare de marchandises** (20 000 €, 2×2, reliée à une route **et** à une
  voie, 300 t toutes marchandises, 2 trains) : sélectionnez-la pour acheter ou
  revendre des **trains** (120 t, 3 tuiles/h, 20 000 €, entretien 120 €/j,
  4 €/tuile).
- **Fonctionnement** : la gare sert d'entrepôt aux camions. Le surplus des
  producteurs proches y est déposé ; un train l'emmène vers la gare, joignable
  par le rail, **plus proche par la route d'un client** de cette marchandise
  (les marchandises ne font que se rapprocher de leurs clients : pas
  d'aller-retour) ; les camions de la gare d'arrivée livrent ensuite les
  consommateurs. Un train part avec au moins 60 % de sa charge, ou dès que la
  gare de départ est presque pleine.
- Typiquement : bûcherons ou mines loin des centrales, reliés à une gare par
  la route ; une seconde gare près des centrales, avec son propre dépôt de
  véhicules. Le panneau de la gare signale l'absence de voie, de route, de gare
  partenaire ou de train ; une gare sans voie affiche la pastille bleue.

## Nucléaire (M6, partie 1)

- **Mine d'uranium** (40 000 €, sur gisement d'uranium) : 0,5 t/h de minerai.
- **Usine d'enrichissement** (100 000 €, 2×2) : 0,5 t/h de minerai → 0,1 t/h
  de combustible ; raccordée au réseau et alimentée (4 MW).
- **Centrale nucléaire** (450 000 €, 3×3, près de l'eau) : 120 MW pour
  0,1 t/h de combustible, pilotée par le réseau comme les autres centrales à
  combustible. Elle produit autant de **déchets nucléaires** (moitié moins
  avec Gestion des déchets) ; stock de déchets plein → arrêt (pastille
  orange), et le réseau ne compte plus sur elle.
- **Site de stockage des déchets** (60 000 €, 2×2) : entrepose 400 t de
  déchets, définitivement ; une fois plein, en construire un autre.
- **Matières dangereuses** (combustible, déchets) : transportées seulement par
  **camion blindé** (8 t, 1,2 tuile/h, 6 000 €, à acheter au dépôt), qui ne
  transporte rien d'autre ; jamais déposées en entrepôt ni en gare. Le
  panneau d'information signale l'absence de camion blindé ou de site de
  déchets joignable.
- Incidents nucléaires : voir les événements (M7, partie 3).

## Renouvelables, météo et stockage (M6, partie 2)

- **Jour et nuit** : la lumière du jour suit l'heure et la saison (jours de
  15 h en été, 9 h en hiver) ; le monde se teinte de bleu la nuit.
- **Météo** : vent et nébulosité varient en douceur (fronts sur une journée,
  rafales sur quelques heures), propres à la graine ; hiver plus venteux, été
  plus clair. Le bandeau affiche le ciel (survol : vent, nuages, lumière).
- **Éolienne** : puissance × potentiel de la tuile × vent du moment (statut
  « pas de vent » par calme plat). **Ferme solaire**
  (10 MW, au lieu de 6) : puissance × ensoleillement de la tuile × lumière du
  jour × ciel, nulle la nuit. Le panneau d'information détaille ces facteurs.
- **Éolienne offshore** (30 000 €, Offshore) : en mer, au contact de la côte
  (une ligne la raccorde depuis la terre), à moins de 15 tuiles d'un port
  sur la même étendue d'eau ; 6 MW, vent marin fort.
- **Centrale solaire thermique** (90 000 €, 3×3, ensoleillement ≥ 70 %) :
  stocke la chaleur du jour (120 MWh) et produit 20 MW **à la demande**,
  y compris le soir et la nuit tant que le stock dure ; pilotée par le réseau
  comme une centrale à combustible.
- **Batteries** (20 000 €, 25 MWh, 10 MW, rendement 90 %) et **STEP**
  (120 000 €, 2×2, près de l'eau et à côté d'une colline ou d'une montagne,
  400 MWh, 40 MW, rendement 75 %) : raccordées au réseau, elles chargent les
  surplus et couvrent les manques avant tout délestage. Les centrales
  pilotables suivent la demande ; le stockage lisse l'intermittence des
  renouvelables. Le survol de l'électricité du bandeau donne le stock total.

## Ports et barges (M6, partie 3)

- **Voies navigables** : la mer, les lacs et les rivières, gratuites et sans
  entretien ; une étendue d'eau isolée forme son propre réseau.
- **Port** (30 000 €, 2×2, Offshore) : au bord de l'eau navigable et relié à
  une route ; 400 t toutes marchandises, 3 barges. Il fonctionne comme une
  gare : les camions y déposent le surplus des producteurs proches, une
  barge l'emmène vers le port, joignable par l'eau, le plus proche par la
  route d'un client, et les camions de l'autre rive livrent. Il dessert aussi
  les chantiers d'éoliennes offshore.
- **Barge** (12 000 €, à acheter au port) : 200 t, 1,5 tuile/h, entretien
  60 €/j, 1 €/tuile — lente mais très économique par tonne. Elle part avec
  au moins 60 % de sa charge, ou dès que le port de départ est presque plein.
- Le panneau du port signale l'absence d'eau, de route, de port partenaire
  ou de barge. Les matières dangereuses ne passent ni par les ports ni par
  les gares.

## Pollution et satisfaction (M7, partie 1)

- **Émissions** (t/h de CO₂ à plein régime, selon l'activité) : centrale à
  charbon 30, centrale biomasse 4, usine d'enrichissement et mine de charbon
  1, mine d'uranium 0,5 ; rien pour le nucléaire et les renouvelables.
  Filtres CO₂ : −50 % pour les centrales à combustible.
- **Pollution de l'air** : chaque émission se répand jusqu'à 8 tuiles
  autour du bâtiment, en décroissant avec la distance, et se dissipe de 4 %
  par heure. Calque « Pollution » (`O`) ; le panneau d'une tuile indique sa
  pollution, celui d'un bâtiment ses émissions.
- **Villes** : la qualité de l'air (moyenne de la pollution sur la ville)
  freine leur croissance (jusqu'à −8 %/an). Leur **satisfaction** suit, jour
  après jour, la part d'heures alimentées (70 %) et la qualité de l'air
  (30 %). Le survol de l'électricité du bandeau donne les émissions de
  l'heure et la satisfaction moyenne des habitants.
- Implanter les centrales thermiques loin des villes, ou passer au
  nucléaire et aux renouvelables, garde l'air pur.

## Économie (M7, partie 2)

- **Prix de marché** horaire, 10 €/MWh en moyenne : la moitié du prix suit
  le profil de la demande (nuit ≈ 7,8 €, pointe du soir ≈ 12,3 €, hors saison), l'hiver
  est plus cher, et le marché fluctue de ±15 % sur quelques jours.
- **Tarif selon la satisfaction** : une ville paie de 80 % (mécontente) à
  120 % (comblée) du prix du marché ; 100 % à mi-satisfaction.
- **Taxe carbone** sur les émissions de CO₂ : nulle la première année, puis
  1 €/t l'an 2, +1 €/t chaque année jusqu'à 5 €/t.
- **Subventions renouvelables** (éolien, solaire, solaire thermique) sur la
  part renouvelable de l'énergie vendue : 3 €/MWh l'an 1, −0,5 €/MWh par an
  jusqu'à 1 €/MWh.
- Les nouveaux taux sont annoncés au début de chaque année. Le bandeau
  affiche le **bilan** de la veille ; son survol détaille ventes,
  subventions, pénalités, taxe carbone, transport et entretien, ainsi que
  le prix, la subvention et la taxe actuels.

## Événements (M7, partie 3)

- **Tempête** (12–36 h ; environ tous les 10 jours en automne et en hiver,
  plus rare au printemps et en été) : ciel couvert, éoliennes mises en
  sécurité ; chacune a 10 % de risque d'être endommagée (2 à 4 jours de
  réparation, 5 % de son prix).
- **Sécheresse** (été, 5–12 jours, environ une par été) : les centrales
  refroidies par l'eau (charbon, nucléaire) sont limitées à 50 % de leur
  puissance ; les autres centrales prennent le relais.
- **Crise de l'énergie** (10–20 jours, environ tous les deux ans) : prix du
  marché ×1,5.
- **Grève des mineurs** (3–6 jours, environ une par an, s'il existe des mines
  de charbon) : mines de charbon à l'arrêt ; les stocks des centrales et des
  entrepôts font tampon.
- **Incident nucléaire** (environ un tous les 4 ans par réacteur en service) :
  réacteur arrêté 10 jours, réparations à 10 % de son prix, satisfaction des
  villes à moins de 20 tuiles −25 points.
- **Gisements** : une alerte prévient quand une mine n'a plus qu'environ
  30 jours d'extraction.
- Chaque événement est annoncé à son début et à sa fin. Pendant un
  événement, la météo du bandeau passe en orange et son survol liste les
  événements en cours. Le panneau d'un bâtiment arrêté donne le délai de
  reprise. Les réparations apparaissent dans le bilan du jour.

## Statistiques et jalons (M8, partie 1)

- **Fenêtre Statistiques** (`G` ou bouton « Stats ») : un point par jour,
  sur 30 jours, 1 an ou toute la partie. Le survol d'un graphique donne la
  date et les valeurs.
  - *Électricité* : production par type de centrale (aires empilées) et
    demande ; délestages.
  - *Finances* : trésorerie ; ventes, subventions, dépenses et bilan du
    jour ; prix moyen du marché.
  - *Environnement* : émissions de CO₂ ; part renouvelable et satisfaction.
  - *Villes et recherche* : population ; recherche produite.
  - Le compteur d'images par seconde a quitté le bandeau pour cette fenêtre.
- **Jalons du bac à sable** (onglet « Jalons ») : 12 objectifs facultatifs,
  vérifiés chaque fin de journée et annoncés une fois atteints : premier
  mégawatt, une ville puis toutes les villes alimentées 24 h sur 24, 100 MW
  livrés en moyenne, ère atomique, moitié verte (50 % renouvelable), zéro
  carbone, habitants comblés (80 %), millionnaire, 20 technologies,
  500 000 habitants, ère de la fusion.

## Tutoriel et info-bulles (M8, partie 2)

- **Tutoriel** en 9 étapes, affiché en haut de l'écran au lancement (`H`
  pour le masquer ou le rouvrir) : caméra et temps, bûcheron, centrale
  biomasse, dépôt et routes, première livraison, ligne vers une ville,
  recherche, statistiques, puis un résumé des mécaniques avancées. Les
  étapes d'action passent d'elles-mêmes quand elles sont accomplies ;
  « Passer » et « Précédent » permettent de naviguer.
- **Info-bulles** : date (effet de la saison sur la demande, durée du jour,
  prochaine saison), trésorerie (bilan d'hier, entretien), boutons de calque
  (ce que montre chaque calque) ; délai d'apparition réduit à 0,3 s.

## Équilibrage (M8, partie 3)

Réglé sur le rythme cible d'une partie d'1 h à ×1 (1 min réelle = 25 jours
de jeu). `godot --headless -s res://tools/balance_report.gd` imprime le
rapport : arrivée de chaque ère pour un joueur moyen (1 laboratoire à 1 min,
2 à 3 min, 4 à 10 min, 8 à 22 min, 12 à 40 min), rentabilité des centrales
et demande des villes année par année.

- **Recherche** : rendement décroissant des laboratoires (n laboratoires
  produisent comme n^0,75 : 4 labos ≈ 2,8, 9 labos ≈ 5,2), indiqué dans le
  panneau du laboratoire. Coûts revus ère par ère : ère 2 moins chère (le
  charbon arrive vers 5 min), ères 3 à 6 plus chères (réseau ≈ 11 min,
  atome ≈ 18 min, renouvelables ≈ 28 min, stockage ≈ 38 min).
- **Demande** : les villes bien alimentées croissent de 25 %/an (au lieu de
  12 %) : ≈ 32 MW au départ, 87 MW en an 5 (le nucléaire devient utile),
  236 MW en an 9, 640 MW en fin de partie.
- **Centrales** : prix et entretien relevés au-delà de l'ère du bois pour
  qu'elles se remboursent en 10 à 45 jours de jeu à pleine demande (au lieu
  de 2 à 20) et que l'entretien pèse sur les centrales surdimensionnées :
  charbon 90 000 € (900 €/j), nucléaire 450 000 € (2 500 €/j), éolienne
  10 000 €, ferme solaire 22 000 €, offshore 30 000 €, solaire thermique
  90 000 €, batteries 20 000 €, STEP 120 000 € ; mines, usine
  d'enrichissement, site de déchets, gare et port suivent. Le bois (départ
  à 50 000 €) est inchangé, à part l'entretien de la centrale biomasse
  (150 €/j).
- **Délestage** : pénalité portée à 5 €/MWh non livré (la moitié du prix),
  pour que la fiabilité et le stockage comptent.
