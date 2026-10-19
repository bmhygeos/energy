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
| Explorée | Visible (terrain, ressources), assombrie | Non : peut être annexée |
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
- **Annexion** : une tuile explorée qui touche le territoire peut y être
  intégrée contre un coût (nourriture et bois au début, puis argent ou
  influence). La surface annexable est limitée par la population (ex. 6 tuiles
  par habitant) : le territoire suit les besoins de la ville.
- Les paliers (section 7) améliorent l'exploration : plus d'explorateurs, vivres
  pour des expéditions plus longues, éclaireurs à cheval, bateaux, cartographes.

### La planète (à terme)
Le monde est une **planète**, pour pouvoir un jour la montrer en globe avec ses
**satellites** en orbite (dernier palier : observation, météo, communications).
Pour ne pas avoir à tout refaire plus tard, dès la V1 :
- **Projection** : grille en longitude / latitude (équirectangulaire, ex.
  1024×512 tuiles) qui **boucle d'est en ouest** ; les pôles sont les bords nord et
  sud. On garde des tuiles carrées, donc la vue isométrique actuelle.
- **Génération** : bruit 3D échantillonné sur la sphère (position de la tuile
  convertie en point 3D), donc sans raccord visible et cohérent avec le globe ;
  le **climat dépend de la latitude** (glace aux pôles, déserts et forêts
  tropicales près de l'équateur, saisons plus marquées aux latitudes moyennes).
- **Génération à la demande** par blocs (ex. 32×32) : seuls les blocs explorés
  sont créés et gardés en mémoire, la graine suffit à recréer le reste.
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
  | Bois | 0,2 / habitant / jour, ×2 en hiver | Chauffage et entretien des maisons |
- **Stocks** centralisés (grenier, réserve de bois) au centre du village, de
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
  moderne ; les paliers suivants ajoutent leurs sources (charbon, électricité…).
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
| Agriculture | Plaine, berges (fertilité > 0) | 2 | Nourriture, **saisonnière** : semis au printemps, récolte en été et à l'automne, rien en hiver | Gros rendement, mais il faut stocker pour l'hiver ; la fertilité baisse si on cultive sans repos (jachère plus tard) |
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
| 1 – Hameau | 20 au départ | Nourriture, bois | Agriculture, élevage, coupe du bois ; maisons, grenier | Explorateurs à pied, 1 expédition |
| 2 – Village | 100 | Pierre (maisons en dur), eau | Carrière, puits ; pêche (côte, lac) ; écurie (hippotraction), atelier (inventions) | 3 expéditions, plus de vivres, chevaux de bât |
| 3 – Bourg | 400 | Outils, vêtements | Mine de fer, forge, champ de lin/laine (élevage) ; routes, marché | Éclaireurs à cheval |
| 4 – Ville | 1 500 | Biens variés, santé, ordre | Artisans, commerce avec l'extérieur (argent), impôts | Bateaux, cartographes |
| 5 – Cité-État | 5 000 | Éducation, culture, énergie | Recherche, puis industrie (où la v1 peut revenir : énergie, réseau) | Puis ère spatiale : satellites, vue globe |

Les paliers 2 à 5 sont **indicatifs** : seul le palier 1 est détaillé ici, les
suivants seront précisés après avoir joué le premier.

### Palier 2 : hippotraction et inventions
**Hippotraction** : l'**écurie** (bois, pierre) loge des chevaux de trait,
élevés à partir de l'élevage (une part de sa production devient des chevaux, que
l'écurie plafonne). Chaque cheval mange du fourrage (ex. 3 unités de nourriture
par jour) et sert à deux choses :
- **Portée** : les chevaux sont attelés automatiquement aux zones les plus
  éloignées ; une tuile desservie par un attelage voit sa pénalité de distance
  commencer à 12 tuiles au lieu de 6, et réduite de moitié (−1,5 % par tuile).
  Le territoire exploitable s'élargit avant les routes du palier 3.
- **Quantité transportée** : une charrette rapporte autant que 4 porteurs, ce
  qui libère des habitants pour d'autres activités. Une expédition peut emmener
  des chevaux de bât qui portent 4 fois plus de vivres qu'un homme, donc va plus
  loin.

Le panneau « Main-d'œuvre » affiche aussi les chevaux (disponibles, attelés,
fourrage consommé). Leur travail s'ajoute au compteur de puissance (environ
700 W par cheval au travail).

**Inventions** : l'**atelier** (bâtiment) accueille quelques habitants actifs,
affectés comme dans une zone, qui mettent au point **une invention à la fois** :
un coût en ressources plus une durée en jours de travail. Chaque invention
débloquée améliore durablement la production :

| Invention | Prérequis | Effet |
|---|---|---|
| Collier d'attelage | Écurie | Chevaux plus efficaces : charge et portée +50 % |
| Charrue | Collier d'attelage | Agriculture +30 % sur les tuiles desservies par un attelage, +10 % ailleurs (araire tirée à la main) |
| Scie | — | Coupe du bois +40 %, maisons −25 % de bois |
| Moulin à vent | Pierre | Bâtiment : moud le grain, avec agriculture +20 % et nourriture qui se gâte moitié moins vite ; sa puissance mécanique compte dans le compteur |

D'autres inventions (moulin à eau, assolement, fer) viendront avec les paliers
suivants ; l'atelier devient la recherche du palier 5.

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
| `Logistics`, `Roads`, véhicules | Mis de côté, repris au palier 3 |
| `PowerGrid`, `Economy` (électricité), `Research` (ères), `Events` | Retirés ou réécrits |

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
  inventions.gd    atelier, mise au point, modificateurs de production (palier 2)
data/zones/        agriculture.tres, pasture.tres, forestry.tres
data/inventions/   harness.tres, plough.tres, saw.tres, windmill.tres
```
Interface : outil « Zones » (peinture), panneau « Main-d'œuvre », HUD
(habitants, actifs, chômeurs, nourriture et bois en jours de réserve,
puissance totale et par habitant), outil « Expédition » (choix de la cible,
effectif, vivres).

## 11. Étapes de développement
| # | Étape | Livrable |
|---|---|---|
| V0 | Nettoyage | Branche `v2`, retrait de l'électricité et de la compagnie, carte et interface conservées |
| V1 | Planète et territoire | Grille longitude / latitude qui boucle, génération par blocs sur la sphère, climat selon la latitude, états des tuiles, fertilité / pâturage / forêt |
| V2 | Zones | Peinture et effacement des trois zones, calque de zones |
| V3 | Population et main-d'œuvre | Habitants, besoins nourriture et bois, répartition automatique, priorités, panneau |
| V4 | Production et saisons | Rendements, récoltes saisonnières, stocks, gâchis, repousse de la forêt, croissance et famine, compteur de puissance |
| V5 | Exploration | Expéditions (effectif, vivres, trajet, révélation), annexion des tuiles explorées |
| V6 | Palier 2 | Pierre, eau, pêche, expéditions améliorées, écurie et hippotraction, atelier et inventions (collier, charrue, scie, moulin à vent) |
| V7 | Interface et équilibrage | Statistiques, jalons, tutoriel réécrits, rythme des paliers 1–2 |
| V8+ | Paliers 3 à 5 | Routes et logistique, artisanat, impôts, décrets, puis énergie |
| V∞ | Ère spatiale | Vue globe 3D, satellites et orbites |

**Version jouable minimale** à la fin de V4 : un hameau qui doit passer ses
premiers hivers grâce à ses champs, son élevage et sa coupe de bois.

## 12. Questions ouvertes
~~Nom du jeu~~ : **tranché → on garde « Energy »** (nom du jeu, du dépôt et de l'exécutable).

~~Dépôt~~ : **tranché → même dépôt, branche `v2`** (la v1 reste sur `main` et au tag `v1.0`).

~~Nourriture~~ : **tranché → une seule ressource « nourriture »** (champs et élevage produisent la même).

~~Agrandissement~~ : **tranché → par l'exploration** (expéditions puis annexion) ; à terme la carte est une planète (section 3).

1. **Fin de partie** : l'énergie (reprise de la v1) comme palier final, ou un
   autre objectif de cité-État ?
