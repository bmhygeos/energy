# Plan v2 – Gouverneur d'une cité-État

> La v1 (compagnie d'électricité, du bois à la fusion) est figée au tag `v1.0`.
> Ce plan la remplace : on garde le moteur (carte isométrique, tick, interface,
> statistiques), on change le jeu.

## 1. Concept
Le joueur incarne le **gouverneur d'une cité-État**. Tout commence par un hameau
sur un petit territoire d'une planète inconnue ; en grandissant, la ville a de
nouveaux besoins, ses expéditions explorent le monde, le territoire s'agrandit
et de nouvelles activités deviennent possibles.

Le gouverneur ne construit pas chaque bâtiment de production : il **trace des
zones** (agriculture, élevage, coupe du bois…) et **les habitants s'y répartissent**
pour travailler. Son rôle est d'arbitrer : où produire, combien de bras pour
chaque activité, comment passer l'hiver, quand s'étendre.

**Boucle principale** : tracer des zones → les habitants y travaillent →
production stockée → besoins satisfaits → la population croît → nouveaux besoins
→ exploration et annexion de terres → nouvelles zones et ressources.

## 2. Ce qui change par rapport à la v1
| Conservé (adapté) | Retiré | Nouveau |
|---|---|---|
| Carte isométrique, génération par graine, terrains | Électricité, réseau HT, centrales | Zones peintes sur la carte |
| Tick horaire, saisons, météo | Compagnie, ventes aux villes, marché de l'électricité | Population, besoins, travailleurs |
| HUD, info-bulles, fenêtre de statistiques, graphiques, jalons, tutoriel | Arbre des ères énergétiques (bois → fusion) | Répartition automatique de la main-d'œuvre |
| Bâtiments (pour les bâtiments de ville : grenier, maisons…) | Véhicules au démarrage (repris plus tard) | Exploration, territoire qui s'agrandit, planète |
| Logistique et routes (paliers suivants) | | Paliers d'évolution de la ville |

## 3. Carte, exploration et planète
### États d'une tuile
| État | Affichage | Jouable |
|---|---|---|
| Inconnue | Noire | Non |
| Explorée | Visible (terrain, ressources), assombrie | Non (les expéditions annexent directement) |
| Territoire | Normale | Oui : zones et bâtiments |

- **Départ** : environ 12×12 tuiles de territoire autour du centre du village,
  avec forêt, plaine et un point d'eau garantis ; tout le reste est inconnu.
- Les terrains donnent leur sens aux zones : **fertilité** (plaine, berges),
  **pâturage** (prairie, collines), **forêt** (densité, repousse).

### Exploration
La carte ne s'agrandit que par l'**exploration** :
- Le joueur lance une **expédition** depuis la frontière vers une tuile cible ou
  une direction. Elle mobilise des habitants actifs (retirés du travail) et
  emporte des vivres prélevés sur le grenier.
- L'expédition avance sur la carte (lente en forêt et en colline, impossible sur
  l'eau au début), révèle les tuiles dans son rayon de vue, puis revient ; sans
  vivres, elle rentre plus tôt. Plus tard : risques (pertes, rencontres).
- **Annexion automatique** : les tuiles révélées par une expédition sont
  intégrées au territoire, sans coût ni outil dédié.
- Les paliers (section 7) améliorent l'exploration : plus d'explorateurs, vivres
  pour des expéditions plus longues, éclaireurs à cheval, bateaux, cartographes.

### La planète (à terme)
Le monde est une **planète**, pour pouvoir un jour la montrer en globe avec ses
**satellites** en orbite (dernier palier : le premier satellite révèle toute la
planète, section 7).
Pour ne pas avoir à tout refaire plus tard, dès la V1 :
- **Projection** : grille en longitude / latitude (équirectangulaire, ex.
  1024×512 tuiles) qui **boucle d'est en ouest** ; les pôles sont les bords nord et
  sud. On garde des tuiles carrées, donc la vue isométrique actuelle.
- **Génération** : bruit 3D échantillonné sur la sphère (position de la tuile
  convertie en point 3D), donc sans raccord visible et cohérent avec le globe ;
  le **climat dépend de la latitude** (glace aux pôles, déserts et forêts
  tropicales près de l'équateur, saisons plus marquées aux latitudes moyennes).
- **Génération à la demande** par blocs (ex. 32×32) : seuls les blocs explorés
  sont créés et gardés en mémoire, la graine suffit à recréer le reste. Quand le
  satellite révèle la planète, les blocs restent générés à la demande (à
  l'affichage) ; seul l'état « explorée » est stocké, sous forme compacte.
- **Vue globe** (plus tard) : scène 3D séparée (sphère texturée à partir de la
  carte connue, zones inconnues en noir), satellites et orbites ; on bascule
  entre la vue locale isométrique et le globe.

## 4. Population et besoins
- **Habitants** : nombre total, dont une part **active** (ex. 60 %) qui
  travaille ; le reste (enfants, anciens) consomme sans produire.
- **Besoins du hameau** (palier 1) :
  | Besoin | Consommation | Remarque |
  |---|---|---|
  | Nourriture | 1 unité / habitant / jour | Ressource unique : champs et élevage produisent la même |
  | Bois | 0,2 / habitant / jour, ×0,5 en été, ×2 en hiver | Chauffage et entretien des maisons |
- **Stocks** centralisés (grenier, camp d'abattage) au centre du village, de
  capacité limitée ; la nourriture se gâte un peu (ex. −1 % par jour au-delà de la
  moitié du grenier).
- **Croissance** : si les besoins sont couverts et qu'il reste du logement, la
  population croît (naissances, arrivants) ; pénurie → mécontentement, puis départs
  et, en cas de famine, déclin rapide.
- **Satisfaction** (0–100 %) : couverture des besoins sur les derniers jours ;
  elle module la croissance et, plus tard, l'impôt et les événements.
- **Logement** : les maisons (bâtiment simple, coût en bois) fixent la population
  maximale.

### Puissance de la cité
Un **compteur de puissance** dans le HUD affiche la puissance produite par la
cité et la **puissance par habitant**, l'indicateur de développement qui suit
toute la partie (fidèle au nom « Energy ») :
- Chaque ressource produite est convertie en énergie selon son contenu
  énergétique, puis ramenée à une puissance moyenne (W) :
  | Ressource | Équivalent | Repère |
  |---|---|---|
  | Nourriture | 1 unité = 2 500 kcal ≈ 10,5 MJ | 1 unité / jour ≈ 120 W |
  | Bois | 1 unité = 10 kg de bois sec ≈ 150 MJ | 0,2 unité / jour ≈ 350 W |
- Ordre de grandeur attendu : environ 0,5 kW par habitant pour un hameau
  agricole, quelques kW avec l'artisanat et l'industrie, 10 kW et plus à l'ère
  moderne ; les paliers suivants ajoutent leurs sources (charbon, pétrole,
  électricité, nucléaire : section 7).
- La production agricole étant saisonnière, le compteur affiche une **moyenne
  glissante** (30 jours, ou annuelle au choix) plutôt que la valeur instantanée ;
  l'info-bulle détaille la part de chaque ressource.
- Les deux valeurs sont enregistrées dans `Statistics` pour leurs graphiques et
  peuvent servir de conditions de jalons.

## 5. Zones
Le joueur **peint des zones** à la souris (rectangle ou pinceau), comme les routes
en v1, et peut les effacer. Une tuile porte au plus une zone.

| Zone | Terrain valide | Travailleurs par tuile | Production | Particularités |
|---|---|---|---|---|
| Agriculture | Plaine, berges (fertilité > 0) | 2 | Nourriture, **saisonnière** : récoltes du printemps à l'automne, rien en hiver | Gros rendement, mais il faut stocker pour l'hiver ; la fertilité baisse si on cultive sans repos (assolement au palier 2) |
| Élevage | Prairie, plaine, collines | 1 | Nourriture **régulière** toute l'année, plus faible par tuile | Lisse l'hiver ; demande beaucoup de surface |
| Coupe du bois | Forêt | 1 | Bois | La densité de la forêt baisse ; une tuile coupée à blanc devient plaine et repousse lentement si la zone est retirée |

- **Rendement d'une tuile** = travailleurs affectés × rendement de base ×
  qualité du terrain × facteur de saison × (1 − pénalité de distance).
- **Distance** : plus une zone est loin du centre du village, plus les habitants
  perdent de temps en trajet (ex. −3 % par tuile au-delà de 6) ; ce sera la porte
  d'entrée vers les routes, les hameaux secondaires et la logistique.
- **Visualisation** : couleur de zone en surimpression (calque comme les overlays
  v1), petites silhouettes de travailleurs sur les tuiles occupées, champs qui
  changent d'aspect selon la saison (labour, blé vert, blé mûr, chaume).

## 6. Répartition des habitants
Les habitants actifs sont **répartis automatiquement** entre les zones tracées :

1. Chaque type de zone offre des **places** (somme des tuiles × travailleurs par tuile).
2. Le joueur règle une **priorité** par type de zone (curseurs 0–5, ou
   « automatique »).
3. Les actifs sont distribués au prorata *priorité × places*, sans dépasser les
   places ; l'excédent éventuel est redistribué aux autres zones, puis devient
   **chômeurs** (signalés dans le HUD).
4. Dans une zone, les travailleurs vont d'abord aux **meilleures tuiles**
   (rendement × proximité).
5. **Mode automatique** : la priorité suit les stocks (grenier sous 20 jours de
   réserve → agriculture et élevage d'abord ; réserve de bois basse avant l'hiver →
   coupe du bois).

La réaffectation n'est pas instantanée (ex. 1 jour pour changer de zone) pour
éviter les oscillations. Un panneau « Main-d'œuvre » montre places, affectés,
chômeurs et production prévue par activité.

## 7. Paliers de la ville
L'évolution remplace les ères de la v1 : chaque palier se débloque par la
population **et** une condition de besoins satisfaits ; il ajoute des besoins,
des zones ou des bâtiments et améliore l'exploration.

| Palier | Population | Nouveaux besoins | Nouvelles zones et bâtiments | Exploration |
|---|---|---|---|---|
| 1 – Hameau | 20 au départ | Nourriture, bois | Agriculture, élevage, coupe du bois ; maisons, grenier ; recherche : **irrigation** | Explorateurs à pied, 1 expédition |
| 2 – Village | 100 | Pierre (maisons en dur), eau, outils (scies, charrues) | Carrière, puits ; pêche (côte, lac) ; écurie (hippotraction), atelier (recherche ×2) ; mine de fer, forge (outils) | 3 expéditions, plus de vivres, chevaux de bât, prospection du fer |
| 3 – Bourg | 400 | Vêtements | Champ de lin/laine (élevage) ; routes, marché ; laboratoire (recherche ×5), moulin à eau ; **charbon** : mine, chauffage, machine à vapeur ; **train** : voies ferrées, gares | Éclaireurs à cheval, prospection du charbon |
| 4 – Ville | 1 500 | Biens variés, santé, ordre, éclairage | Artisans, commerce avec l'extérieur (argent), impôts ; université (recherche ×10) ; **pétrole** : puits, raffinerie, moteurs ; **cuivre** : mine, lignes électriques ; premières centrales électriques et **barrage hydroélectrique**, réseau (repris de la v1) ; **camions** : routes carrossables, dépôts | Bateaux, cartographes, prospection du pétrole et du cuivre |
| 5 – Cité-État | 5 000 | Éducation, culture, électricité | Industrie ; **électronique**, informatique : **centre informatique** (recherche ×20), puis IA : **datacenter** (×100) ; **nucléaire** : mine d'uranium, centrale nucléaire ; **éolienne**, **photovoltaïque** ; **lithium** : mine, batteries, véhicules électriques | Prospection de l'uranium et du lithium ; recherche de la fusée → base de lancement → premier satellite : toute la planète révélée, vue globe |

Les paliers 2 à 5 sont **indicatifs** : seul le palier 1 est détaillé ici, les
suivants seront précisés après avoir joué le premier.

### Recherche
Toutes les inventions et découvertes, du collier d'attelage au satellite, se
débloquent par la **recherche**, une seule à la fois, choisie par le joueur dans
l'arbre :
- **Points de recherche** : la ville en produit **par habitant** (ex. 1 point
  par habitant et par jour), modulés par la satisfaction ; une ville qui grandit
  cherche plus vite.
- **Multiplicateurs** : des bâtiments de recherche multiplient ces points. Le
  multiplicateur qui s'applique est celui du meilleur bâtiment ; chaque bâtiment
  couvre un nombre d'habitants, au-delà duquel les habitants non couverts
  comptent au multiplicateur inférieur (il faut en construire d'autres quand la
  ville grandit).

  | Bâtiment | Palier | Débloqué par | Multiplicateur | Couvre | Particularité |
  |---|---|---|---|---|---|
  | — | 1 – Hameau | — | ×1 | — | Recherche sans bâtiment : irrigation |
  | Atelier | 2 – Village | Palier atteint | ×2 | 100 habitants | Coût en bois et pierre |
  | Laboratoire | 3 – Bourg | Recherche | ×5 | 400 habitants | Demande des outils |
  | Université | 4 – Ville | Recherche | ×10 | 1 000 habitants | Entretien en argent (impôts) ; prépare le besoin « éducation » du palier 5 |
  | Centre informatique | 5 – Cité-État | Recherche de l'informatique (après l'électronique) | ×20 | 2 000 habitants | Consomme de l'électricité |
  | Datacenter | 5 – Cité-État | Recherche de l'IA (après l'informatique) | ×100 | 10 000 habitants | Gros consommateur d'électricité ; refroidissement par l'eau (rivière, lac, côte), moins coûteux aux latitudes froides |

- **Coût** : chaque recherche coûte des points (croissants avec le palier, pour
  garder une durée de quelques minutes de jeu) et parfois des ressources (ex. la
  fusée). Gisements et mines sont disponibles dès leur palier, mais le fer, le
  cuivre, le pétrole, l'uranium et le lithium ne se transforment qu'après la
  recherche de leurs propriétés (section « Énergies »).
- L'électricité consommée par le centre informatique et le datacenter pèse sur le réseau : la
  recherche rapide demande une production d'énergie à la hauteur.

### Palier 1 : irrigation
Seule recherche du hameau, sans bâtiment de recherche : **irrigation** (500
points, environ 25 jours pour 20 habitants). Les champs à 3 tuiles ou moins
d'une rivière, d'un lac ou d'un puits rendent 30 % de plus ; la mer ne
compte pas (eau salée). Un hameau sans eau douce en profite dès ses premiers
puits, au village (ou en annexant vers une rivière ou un lac).

### Palier 2 : pierre, eau et pêche (réalisé en V6, partie 1)
- **Pierre** : matériau de construction (maisons en pierre, puits, atelier),
  extrait par la zone Carrière sur collines et montagnes ; chaque carte place
  une colline à pierre (au moins 4 tuiles) à 4 tuiles du centre du village au
  plus.
- **Eau** : chaque puits sert un nombre d'habitants (30) ; sans eau, la
  satisfaction baisse (jusqu'à −30 %) et la croissance s'arrête.
- **Pêche** : zone sur rivières, lacs et côte, nourriture toute l'année.
- **Atelier** : recherche ×2 pour 100 habitants.

### Palier 2 : inventions, fer et outils (réalisé en V6, partie 3)
- **Prospection** : le territoire est prospecté au passage d'un palier ; les
  expéditions prospectent ce qu'elles voient à partir du village. Un gisement
  n'apparaît qu'à son palier.
- **Mine de fer** (zone sur gisement prospecté, qui s'épuise) et **forge**
  (fer et bois → outils, après la métallurgie du fer).
- **Outils** : 1 par bûcheron ou laboureur équipé tous les 60 jours ; sans
  outils, scie et charrue sans effet et satisfaction réduite (−15 % au plus).
- Coûts des inventions : 1 500 à 3 000 points (une dizaine de jours chacune
  pour un village de 100 habitants avec un atelier).

### Maisons et greniers améliorables (un niveau par palier)
Le camp d'abattage (réserve de bois du hameau, 300) devient une **scierie** au
village (600, coupe du bois +20 %).
Les maisons s'améliorent sur place, logements gardés pendant les travaux :
maison (5 habitants, hameau) → maison en pierre (10, village) → maison
bourgeoise (16, bourg) → immeuble (30, ville) → tour d'habitation (60,
cité-État).

Le grenier s'améliore sur place à chaque palier, sans cesser de servir pendant
les travaux : grenier (600, hameau) → grenier en pierre (1 200, village) →
grand grenier (4 000, bourg) → entrepôt (7 000, ville) → silo (12 000,
cité-État). Les niveaux supérieurs coûtent de la pierre puis du fer.

### Palier 2 : hippotraction et inventions
**Hippotraction** (réalisée en V6, partie 2) : l'**écurie** (bois, pierre)
loge 6 chevaux de trait, nés des troupeaux des pâturages (un poulain par jour
pour 100 tuiles de pâturage), que l'écurie plafonne. Chaque cheval mange du
fourrage (3 unités de nourriture par jour) et dépérit sans lui ; il sert à
deux choses :
- **Portée** : les chevaux sont attelés automatiquement aux zones les plus
  éloignées ; une tuile desservie par un attelage voit sa pénalité de distance
  commencer à 12 tuiles au lieu de 6, et réduite de moitié (−1,5 % par tuile).
  Le territoire exploitable s'élargit avant les routes du palier 3.
- **Quantité transportée** : une expédition peut emmener des chevaux de bât
  qui portent 4 fois plus de vivres qu'un homme, donc va plus loin. Pour les
  zones, la charrette est comprise dans la portée (moins de temps perdu en
  trajets, donc plus de production par travailleur).

Le panneau « Main-d'œuvre » affiche aussi les chevaux (disponibles, attelés,
fourrage consommé). Leur travail s'ajoute au compteur de puissance (environ
700 W par cheval au travail).

**Inventions** : premières recherches, accélérées par l'**atelier** (×2). Chaque
invention débloquée améliore durablement la production :

| Invention | Prérequis | Effet |
|---|---|---|
| Collier d'attelage | Écurie | Chevaux plus efficaces : charge et portée +50 % |
| Charrue | Collier d'attelage, outils | Outil forgé (soc en fer) : agriculture +30 % sur les tuiles desservies par un attelage, +10 % ailleurs (araire tirée à la main) |
| Engrenage | — | Transmission mécanique : treuils à la carrière et au puits (pierre et eau +15 %) ; prérequis des moulins |
| Moulin à vent | Pierre, engrenage | Bâtiment : moud le grain, avec agriculture +20 % et nourriture qui se gâte moitié moins vite ; sa puissance mécanique compte dans le compteur |
| Pompe à eau | Engrenage | Puits : +50 % d'habitants servis |
| Assolement | Charrue | Rotation des cultures : la fertilité ne baisse plus sur les champs cultivés, agriculture +15 % |
| Métallurgie du fer | — | Forge : transforme le fer (mine de fer, disponible dès le palier) en **outils** ; prépare les rails du palier 3 |
| Outils | Métallurgie du fer | La forge fabrique la **scie** : coupe du bois +40 %, maisons −25 % de bois ; prérequis de la charrue |

**Besoin « outils »** : les outils sont la **scie** et la **charrue**. Ils
s'usent : la coupe du bois consomme des scies et l'agriculture des charrues
(ex. 1 outil par travailleur tous les 60 jours), que la forge produit à partir
du fer. Sans outils en stock, le bonus de la scie ou de la charrue disparaît sur
les tuiles concernées, et la satisfaction baisse comme pour les autres besoins.

Au palier 3, le **moulin à eau** (prérequis : moulin à vent, tuile en bord de
rivière) prend le relais : il moud plus que le moulin à vent, sans dépendre du
vent, et entraîne aussi la scierie et la forge voisines (coupe du bois et
outils +20 %) ; sa puissance compte dans le compteur.

### Énergies des paliers 3 à 5
Chaque palier découvre une nouvelle source d'énergie, qui fait grimper le
compteur de puissance par habitant :

| Palier | Découverte | Extraction | Usages |
|---|---|---|---|
| 3 – Bourg | Charbon | Mine sur un gisement (zone, comme la carrière) | Chauffage (remplace une part du bois), forge plus productive (coke), machine à vapeur (pompe, scierie, locomotive) |
| 4 – Ville | Pétrole | Puits et raffinerie | Lampes (besoin « éclairage »), moteurs (tracteurs, camions), premières centrales électriques au charbon et au fioul |
| 4 – Ville | Cuivre | Mine sur un gisement | Lignes électriques et réseau : sans cuivre, pas d'électricité |
| 4 – Ville | Hydroélectricité | Barrage sur une rivière encaissée (relief, débit) | Électricité sans combustible ; production qui suit la pluie et les saisons (météo v1) ; noie les tuiles en amont |
| 5 – Cité-État | Électronique | Usine (cuivre, puis silicium) | Prérequis du photovoltaïque, de la fusée et du satellite ; pilotage du réseau |
| 5 – Cité-État | Nucléaire | Mine d'uranium, enrichissement | Centrale nucléaire sur le réseau électrique ; base de l'ère spatiale |
| 5 – Cité-État | Éolien | Éoliennes (crêtes, côtes) | Électricité qui suit le vent (météo v1) |
| 5 – Cité-État | Photovoltaïque | Champs solaires (électronique) | Électricité de jour, meilleure près de l'équateur (latitude) |
| 5 – Cité-État | Lithium | Mine sur un gisement (salars, roches) | Batteries : stockent le surplus éolien et solaire pour la nuit et les jours sans vent ; véhicules électriques |

- **Gisements** : générés avec la carte dès V1 (dans la graine, comme les
  autres données de terrain) mais **invisibles** au départ. Toutes les
  ressources deviennent **prospectables dès leur palier**, et leurs **mines**
  (ou puits) sont disponibles dès ce palier : une expédition de prospection
  révèle les gisements des tuiles qu'elle voit et les annexe : la mine peut
  s'y construire.
- **Recherche des propriétés** : pour le fer, le cuivre, le pétrole, l'uranium
  et le lithium, une recherche est nécessaire pour savoir les **transformer et
  les utiliser** ; avant, le minerai extrait s'accumule sans usage (le charbon
  s'utilise directement) :

  | Ressource | Palier | Recherche | Ce qu'elle débloque |
  |---|---|---|---|
  | Fer | 2 – Village | Métallurgie du fer | Forge, outils, puis rails au palier 3 |
  | Pétrole | 4 – Ville | Raffinage du pétrole | Raffinerie (carburants, fioul, lampes, moteurs) |
  | Cuivre | 4 – Ville | Conductivité du cuivre | Lignes électriques, réseau |
  | Uranium | 5 – Cité-État | Radioactivité | Enrichissement, centrale nucléaire |
  | Lithium | 5 – Cité-État | Électrochimie du lithium | Batteries, véhicules électriques |

- **Équivalents** pour le compteur : 1 unité de charbon = 10 kg ≈ 290 MJ,
  1 unité de pétrole = 10 kg ≈ 420 MJ ; l'électricité (centrales) est comptée
  directement par sa production en MW.
- **Contreparties** : pollution et santé (reprise du module `Pollution` de la
  v1), épuisement des gisements, incidents nucléaires (événements v1) ;
  l'hydraulique, l'éolien et le solaire ne polluent pas mais sont variables et
  demandent de la place.
- L'électricité reprend le moteur de la v1 (`PowerGrid`, centrales, lignes),
  mis de côté au départ (section 10).

### Transport : portée et quantité transportée
Chaque palier apporte un mode de transport qui repousse la **portée** (distance
au-delà de laquelle la pénalité de trajet commence, section 5) et augmente la
**quantité transportée** (ce qu'un transport rapporte, en « porteurs »
équivalents, donc moins d'habitants perdus en trajets) :

| Palier | Mode | Infrastructure | Énergie | Portée | Pénalité au-delà | Quantité (porteurs) |
|---|---|---|---|---|---|---|
| 1 – Hameau | À pied | — | Nourriture | 6 tuiles | −3 % / tuile | 1 |
| 2 – Village | Charrette (hippotraction) | Écurie | Fourrage | 12 tuiles | −1,5 % / tuile | 4 |
| 3 – Bourg | Train | Voies ferrées, gares | Charbon | 6 tuiles autour de chaque gare | −1 % / tuile entre gares | 100 par convoi |
| 4 – Ville | Camion | Routes, dépôts | Pétrole | 30 tuiles par la route | −0,5 % / tuile | 20 par camion |
| 5 – Cité-État | Véhicule électrique | Routes, bornes de recharge | Électricité (batteries au lithium) | Comme le camion | Comme le camion | Comme le camion |

- **Train** : la distance d'une zone se compte depuis la **gare la plus proche**
  reliée au centre, plus une faible pénalité selon la longueur de voie ; une
  ligne ouvre donc des bassins d'exploitation lointains (mines, forêts), mais
  seulement autour des gares. Gros volumes, coût fixe élevé, consomme du charbon.
- **Camion** : plus souple, dessert toute zone reliée par la route, avec une
  capacité par véhicule plus faible ; consomme du pétrole. Les deux se
  complètent : le train pour les gros flux, le camion pour la desserte fine.
- **Véhicule électrique** : remplace progressivement le camion ; même portée et
  même capacité, mais il roule à l'électricité (pas de pétrole, pas de
  pollution locale) et ajoute une demande sur le réseau.
- Les chiffres sont des valeurs de départ, à équilibrer. Le train et les camions
  reprennent `RailNetwork`, `RoadNetwork`, `Vehicle` et `Logistics` de la v1 ;
  leur énergie (charbon, pétrole) compte dans le compteur de puissance.

### Palier 5 : la fusée et le premier satellite
- **Recherche de la fusée** : projet de recherche long,
  qui demande l'électronique, de l'électricité, du métal et du pétrole (carburant) ; il débloque la **base
  de lancement spatiale**, grand bâtiment sur une tuile du territoire (de
  préférence proche de l'équateur, où le lancement coûte moins de carburant).
- **Premier satellite** : son lancement (coût important en carburant et en
  matériaux, risque d'échec) fait passer **toutes les tuiles inconnues de la
  planète à l'état « explorée »**, gisements cachés compris. L'expansion ne
  dépend plus de l'exploration à pied, mais l'annexion reste contiguë au
  territoire et limitée par la population.
- Le lancement débloque la **vue globe** (planète entière, satellite en orbite)
  et ouvre l'ère spatiale (satellites suivants : météo prévue, communications).

## 8. Économie et gouvernance (à partir du palier 3–4)
- **Argent** : impôts (selon population et satisfaction), commerce des surplus.
- **Décrets** du gouverneur : rationnement, corvée (plus de travailleurs, moins de
  satisfaction), fêtes (satisfaction contre stocks).
- **Événements** (adaptés de la v1) : hiver rude, sécheresse (récoltes −50 %),
  épizootie (élevage), incendie de forêt, arrivée de migrants.

## 9. Mode de jeu et rythme
- **Bac à sable** comme en v1, avec jalons ; défaite possible (ville abandonnée)
  désactivable.
- **Échelle de temps** : tick d'1 h conservé ; l'année doit rester assez courte
  pour que l'hiver revienne souvent (cycle stocker / consommer).
- **Rythme cible** (à préciser) : palier 2 vers 10 min, palier 3 vers 25 min,
  palier 5 vers 1 h 30.

## 10. Architecture
On repart du code v1 sur la même base Godot 4 / GDScript typé.

| Module v1 | Devenir |
|---|---|
| `scripts/world/` (génération, terrains) | Réécrit pour la planète : bruit sur la sphère, latitude, blocs générés à la demande ; ajout fertilité, pâturage, densité de forêt |
| `GameClock`, `GameDate`, `Weather` | Conservés |
| `Statistics`, `Milestones`, `Chart`, fenêtre de statistiques, tutoriel | Conservés, contenus réécrits |
| `BuildingDef` / `Building` / `BuildingDb` | Conservés pour les bâtiments de ville |
| `Logistics`, `RoadNetwork`, `RailNetwork`, véhicules | Mis de côté, repris aux paliers 3 (train) et 4 (camions) |
| `PowerGrid`, centrales (dont éolien, solaire, batteries et mine de lithium de la v1), `Pollution` | Mis de côté, repris aux paliers 4–5 ; barrage hydroélectrique à créer |
| `Economy` (électricité), `Research` (ères), `Events` | Retirés ou réécrits |

Nouveaux modules (pure donnée, comme en v1) :
```
scripts/sim/
  territory.gd     état des tuiles (inconnue, explorée, territoire), annexion
  exploration.gd   expéditions : trajet, vivres, révélation des tuiles, retour
  zone_map.gd      zone par tuile, peinture / effacement, validité du terrain
  zone_def.gd      (defs/) type de zone : terrain, travailleurs/tuile, production, saisons
  population.gd    habitants, actifs, besoins, croissance, satisfaction
  labor.gd         répartition des actifs entre zones (section 6)
  stockpile.gd     stocks de la cité, capacité, pertes
  city_tier.gd     paliers et conditions de passage
  draft_animals.gd chevaux : élevage, fourrage, attelage aux zones (palier 2)
  research.gd      (réécrit) points par habitant, multiplicateurs (atelier, laboratoire, université, centre informatique, datacenter), arbre, modificateurs de production
data/zones/        agriculture.tres, pasture.tres, forestry.tres
data/research/     une définition par recherche (harness, plough, saw, windmill…), prérequis, coût, effets
```
Interface : outil « Zones » (peinture), panneau « Main-d'œuvre », HUD
(habitants, actifs, chômeurs, nourriture et bois en jours de réserve,
puissance totale et par habitant), outil « Expédition » (choix de la cible,
effectif, vivres).

## 11. Étapes de développement
| # | Étape | Livrable |
|---|---|---|
| V0 | Nettoyage | Branche `v2`, retrait de l'électricité et de la compagnie, carte et interface conservées |
| V1 | Planète et territoire | Grille longitude / latitude qui boucle, génération par blocs sur la sphère, climat selon la latitude, états des tuiles, fertilité / pâturage / forêt, gisements cachés (charbon, pétrole, cuivre, uranium, lithium) |
| V2 | Zones | Peinture et effacement des trois zones, calque de zones |
| V3 | Population et main-d'œuvre | Habitants, besoins nourriture et bois, répartition automatique, priorités, panneau |
| V4 | Production et saisons | Rendements, récoltes saisonnières, stocks, gâchis, repousse de la forêt, croissance et famine, compteur de puissance |
| V5 | Exploration | Expéditions (effectif, vivres, trajet, révélation), annexion des tuiles explorées |
| V6 | Palier 2 | Pierre, eau, pêche, expéditions améliorées, écurie et hippotraction, points de recherche, atelier et inventions (collier, charrue, assolement, métallurgie du fer et forge, outils, engrenage, moulin à vent), mine de fer |
| V7 | Interface et équilibrage | Statistiques, jalons, tutoriel réécrits, rythme des paliers 1–2 (outil `simulate_pacing`, points de recherche mis de côté plafonnés) |
| V8+ | Paliers 3 à 5 | Routes et logistique, artisanat, impôts, décrets ; charbon et train (palier 3), pétrole, cuivre, camions, électricité et barrages (palier 4), électronique, nucléaire, éolien, photovoltaïque, lithium, batteries et véhicules électriques (palier 5) |
| V∞ | Ère spatiale | Recherche de la fusée, base de lancement, premier satellite qui révèle la planète, vue globe 3D, orbites |

**Version jouable minimale** à la fin de V4 : un hameau qui doit passer ses
premiers hivers grâce à ses champs, son élevage et sa coupe de bois.

## 12. Questions ouvertes
~~Nom du jeu~~ : **tranché → on garde « Energy »** (nom du jeu, du dépôt et de l'exécutable).

~~Dépôt~~ : **tranché → même dépôt, branche `v2`** (la v1 reste sur `main` et au tag `v1.0`).

~~Nourriture~~ : **tranché → une seule ressource « nourriture »** (champs et élevage produisent la même).

~~Agrandissement~~ : **tranché → par l'exploration** (expéditions puis annexion) ; à terme la carte est une planète (section 3).

1. **Fin de partie** : le nucléaire arrive au palier 5 ; l'objectif final
   est-il la fusion (comme en v1), l'ère spatiale, un seuil de puissance par
   habitant, ou un autre objectif de cité-État ?
