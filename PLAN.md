# Plan – Jeu de gestion « Énergie »

## 1. Concept
Vous dirigez une compagnie énergétique sur une carte en grille. Vous exploitez des ressources (bois, charbon, uranium, vent, soleil, puis fusion), les transformez en électricité et alimentez des villes dont la demande croît. La recherche fait progresser la compagnie du bois jusqu'aux renouvelables, au stockage et à la fusion — en équilibrant **rentabilité**, **fiabilité du réseau** et **pollution**.

**Boucle principale** : explorer la carte → construire des extracteurs → transformer en électricité → vendre aux villes → gagner argent + points de recherche → débloquer des technologies → construire mieux.

## 2. Ressources
| Ressource | Source | Usage |
|---|---|---|
| Argent | Vente d'électricité, contrats | Construction, entretien |
| Bois | Bûcheron (forêt) | Centrale biomasse, construction |
| Charbon | Mine (gisement) | Centrale thermique |
| Uranium → combustible | Mine puis usine d'enrichissement | Centrale nucléaire |
| Deutérium | Usine d'extraction (côte/mer) | Combustible de fusion |
| Lithium | Mine de lithium (gisement rare, désert/montagne) | Production de tritium |
| Tritium | Couverture tritigène du réacteur | Combustible de fusion |
| Électricité (MW) | Centrales | Demande des villes, bâtiments |
| Recherche (RP) | Laboratoires, tokamak | Arbre technologique |
| Pollution / CO₂ | Bois, charbon | Mécontentement, taxe carbone |
| Déchets nucléaires | Centrale nucléaire | À stocker, sinon risque |

## 3. Carte
- **Grille de tuiles** (ex. 64×64), générée de façon procédurale avec une graine (seed).
- **Terrains** : plaine, forêt, colline, montagne, rivière, lac, côte/mer, désert.
- **Attributs par tuile** : gisement (charbon / uranium / lithium, quantité finie), vent (0–1, fort sur côtes et crêtes), ensoleillement (0–1, fort en désert), accès à l'eau.
- **Villes** : consommation croissante dans le temps, doivent être reliées au réseau.
- Plus tard : brouillard de guerre et prospection pour révéler les gisements.

## 4. Bâtiments
| Bâtiment | Contrainte de placement | Entrée → Sortie | Particularités |
|---|---|---|---|
| Bûcheron | Adjacent à une forêt | → bois | Épuise la forêt |
| Pépinière | Forêt / plaine | → régénère la forêt | Durabilité |
| Centrale biomasse | Libre | bois → élec. | Pollution faible |
| Mine de charbon | Sur gisement | → charbon | Gisement fini |
| Centrale à charbon | Près de l'eau | charbon → élec. (forte) | Pollution forte |
| Mine d'uranium | Sur gisement | → minerai | |
| Usine d'enrichissement | Libre | minerai → combustible | |
| Centrale nucléaire | Près de l'eau, grande emprise | combustible → élec. (très forte) | Déchets, risque d'incident |
| Éolienne / parc offshore | Vent, côte ou mer | → élec. variable | Dépend de la météo |
| Panneau / ferme solaire | Ensoleillement | → élec. variable | Nulle la nuit |
| Batterie / STEP | STEP : dénivelé + eau | Stocke et restitue l'élec. | Lisse l'intermittence |
| Usine d'extraction de deutérium | Côte | eau de mer → deutérium | Gros consommateur d'électricité |
| Mine de lithium | Gisement de lithium | → lithium | Gisement rare |
| Tokamak expérimental | Grande emprise (4×4) | Électricité importante → RP élevés | Consomme du courant, débloque la fusion commerciale après N heures de fonctionnement |
| Réacteur de fusion | Très grande emprise (5×5) | deutérium + tritium (+ lithium) → élec. massive | Pas de CO₂, très peu de déchets, coût énorme, montée en puissance lente |
| Ligne HT / transformateur | — | Transporte l'élec. | Pertes selon la distance |
| Route | Tuiles libres | Support des camions | Coût par tuile, plus cher en colline, pont sur rivière |
| Dépôt de camions | Relié à une route | Héberge et envoie les camions | Nombre de camions limité par dépôt |
| Voie ferrée + gare | Tech Rail | Support des trains | Gros volume, coût élevé, gare = point de chargement |
| Port / quai | Côte | Barges, desserte offshore | Ère 5 (offshore) |
| Entrepôt | Relié à une route | Tampon de stockage intermédiaire | Lisse les flux entre extracteurs et centrales |
| Laboratoire, site de déchets | — | RP, déchets | |

Chaque bâtiment a : un coût, un temps de construction, un coût d'entretien, une production, une taille, une technologie requise et une durée de vie.

## 5. Arbre technologique (par ères)
```
Ère 1 – Bois        : Bûcheronnage → Biomasse → Sylviculture
Ère 2 – Charbon     : Prospection → Mines → Vapeur → Centrale charbon → Rail
Ère 3 – Réseau      : Lignes HT → Transformateurs → Dispatching
Ère 4 – Atome       : Physique nucléaire → Enrichissement → Réacteur → Gestion des déchets
Ère 5 – Renouvelable: Éolien → Solaire PV → Offshore → Solaire thermique
Ère 6 – Avancé      : Batteries → STEP → Smart grid → Filtres CO₂
Ère 7 – Fusion      : voir ci-dessous
```

### Ère 7 – Fusion
```
  Physique des plasmas (requiert : Réacteur [Ère 4] + Smart grid [Ère 6])
        │
        ├─► Supraconducteurs HTS ──► Tokamak expérimental
        │                                   │
        ├─► Extraction du deutérium ────────┤
        │   (eau de mer)                    │
        └─► Couverture tritigène ───────────┤
            (lithium → tritium)             ▼
                                   Réacteur de fusion commercial
                                            │
                                            ▼
                                   Fusion avancée (+rendement, −coûts)
```

- L'arbre est un **graphe de prérequis**, pas une liste linéaire ; des branches croisées sont possibles (ex. Smart grid ← Dispatching + Batteries).
- Le coût s'exprime en RP. Une technologie débloque des bâtiments ou donne des bonus (+10 % de rendement, −20 % de pollution, etc.).

### Mécaniques propres à la fusion
- **Phase expérimentale** : le tokamak est un puits d'énergie et d'argent ; il faut un réseau solide pour l'alimenter (récompense le travail fait en Ère 6).
- **Incident de confinement** : arrêt du plasma, redémarrage long mais sans catastrophe (contrairement au nucléaire classique).
- **Victoire « Ère de la fusion »** : plus de 50 % de la production issue de la fusion avec une pollution sous un seuil.

## 6. Systèmes de simulation
- **Tick fixe** (1 tick = 1 heure de jeu, 10 ticks/s à ×1, cf. section 7), indépendant du rendu ; vitesses pause / ×1 / ×2 / ×4.
- **Cycle jour/nuit et saisons** : agissent sur le solaire, le vent et la demande (pic de consommation en hiver).
- **Transport physique des matières** (voir section 6bis).
- **Réseau électrique** : réseaux connectés calculés comme composantes d'un graphe ; équilibre production / demande ; déficit → délestage (blackout) et pénalité ; surplus → stockage ou perte.
- **Économie** : prix du MWh selon le marché, contrats de fourniture, taxe carbone, subventions aux renouvelables.
- **Pollution** : carte de diffusion ; fait baisser la satisfaction des villes et peut déclencher des réglementations.
- **Événements** : tempête (éoliennes à l'arrêt), sécheresse (refroidissement des centrales), incident nucléaire, incident de confinement (fusion), épuisement d'un gisement, choc sur le prix du charbon.

## 6bis. Logistique et transport physique
Les matières (bois, charbon, minerai, combustible, deutérium, lithium, tritium, déchets) **circulent réellement** sur la carte ; l'électricité, elle, passe par les lignes HT.

**Stocks locaux** : chaque bâtiment possède un tampon d'entrée et un tampon de sortie (capacité limitée). Sortie pleine → production stoppée ; entrée vide → bâtiment à l'arrêt. Un bâtiment non relié à une route affiche une icône d'alerte.

**Véhicules** :
| Véhicule | Réseau | Capacité | Vitesse | Débloqué par |
|---|---|---|---|---|
| Charrette | Route | Faible | Lente | Départ |
| Camion | Route | Moyenne | Moyenne | Ère 2 |
| Camion blindé | Route | Faible | Moyenne | Ère 4 (combustible nucléaire, tritium, déchets) |
| Train | Rail | Élevée | Rapide | Ère 2 (Rail) |
| Barge | Eau | Élevée | Lente | Ère 5 (Offshore) |

**Fonctionnement** :
- **Graphe de transport** : routes et rails convertis en graphe (`AStar2D`), mis à jour à chaque construction / démolition ; recherche de chemin pour chaque trajet.
- **Dispatcher** : à chaque tick, crée des missions *source (sortie disponible) → destination (entrée en manque)*, priorisées par urgence et distance ; un véhicule libre du dépôt le plus proche prend la mission.
- **Cycle d'un véhicule** : dépôt → source (chargement) → destination (déchargement) → retour ou mission suivante. Le véhicule est visible et animé sur la carte isométrique (tri en Y).
- **Coûts** : entretien par véhicule + coût au kilomètre → incite à rapprocher mines et centrales ou à investir dans le rail.
- **Routes logistiques manuelles** (optionnel) : le joueur peut fixer une ligne dédiée (ex. mine A → centrale B) ou des priorités.
- **Plus tard** : congestion routière, usure des routes, accidents de matières dangereuses.

**Performance** : la simulation logistique reste abstraite (positions le long du chemin, pas de physique) ; seuls les véhicules à l'écran sont rendus.

## 7. Mode de jeu et rythme
**Première version : bac à sable uniquement**, partie d'environ **1 heure** (à vitesse ×1) pour parcourir tout l'arbre, du bois à la fusion.

- **Pas de victoire imposée** : objectifs facultatifs affichés comme jalons (premier MW, première ville alimentée à 100 %, 50 % de renouvelable, « Ère de la fusion »…). La partie continue librement après la fusion.
- **Défaite possible** (désactivable au lancement) : faillite prolongée, ou mécontentement maximal (perte de la licence).
- **Options de lancement** : graine de carte, taille de carte, argent de départ, difficulté (demande, prix, fréquence des événements).

**Échelle de temps** : 1 tick = 1 heure de jeu ; à ×1, 10 ticks/s → 1 jour ≈ 2,4 s. Année de jeu = 4 saisons de 30 jours ≈ 4,8 min réelles → une partie d'1 h ≈ 12 ans de jeu (les saisons restent perceptibles).

**Rythme cible** (à ×1, joueur moyen ; sert de référence à l'équilibrage des coûts en RP et en argent) :
| Ère | Atteinte vers |
|---|---|
| 1 – Bois | 0 min |
| 2 – Charbon | 5 min |
| 3 – Réseau | 12 min |
| 4 – Atome | 20 min |
| 5 – Renouvelable | 30 min |
| 6 – Avancé | 40 min |
| 7 – Fusion (réacteur commercial) | 50–60 min |

**Plus tard** : mode scénario (alimenter X villes, Y % de renouvelable avant l'année Z, etc.).

## 8. Architecture technique
**Plateforme** : application native avec **Godot 4** (export Windows / Linux / macOS), scripts en **GDScript** (typé statiquement).

- **Carte** : **vue isométrique** — `TileSet` en forme *Isometric* (layout *Diamond Down*, tuiles 2:1, ex. 128×64 px), `TileMapLayer` avec tri en Y (`y_sort_enabled`) pour que les bâtiments hauts se superposent correctement ; bâtiments multi-tuiles (2×2, 4×4, 5×5) ancrés sur leur tuile avant-bas ; conversion écran ↔ grille via `local_to_map` / `map_to_local` pour le placement et la sélection ; overlays (vent, soleil, pollution, réseau) dans des calques séparés.
- **Interface** : nœuds `Control` (HUD, panneaux, menu de construction, arbre tech via `GraphEdit`).
- **Données** : définitions de bâtiments, technologies et terrains en ressources Godot (`.tres`, classes `BuildingDef`, `TechDef`, `TerrainDef`) — équilibrage sans toucher au code.
- **Simulation** : autoloads indépendants du rendu, tick fixe via un `Timer` / accumulateur dans `_process`.

```
project.godot
autoload/      GameClock (tick, vitesses), GameState, EventBus (signaux), Rng (seedée)
data/
  buildings/   *.tres  (BuildingDef)
  techs/       *.tres  (TechDef)
  terrains/    *.tres  (TerrainDef)
scripts/
  defs/        building_def.gd, tech_def.gd, terrain_def.gd
  world/       génération de carte, tuiles, gisements
  sim/         production, logistique, réseau électrique, économie, pollution
  tech/        arbre tech, recherche
scenes/
  main.tscn    scène principale
  world/       carte, caméra (déplacement, zoom), bâtiments
  ui/          HUD, panneaux, menu construction, arbre tech, graphiques
save/          sérialisation (JSON dans user://)
tests/         tests unitaires de la simulation (GUT)
```

Principes :
- Simulation **pure et séparée du rendu** (classes GDScript sans dépendance aux nœuds de scène) → testable et déterministe.
- Communication simulation → rendu/UI par **signaux** (EventBus).
- Équilibrage **entièrement dans les ressources de données**.

## 9. Étapes de développement
| # | Étape | Livrable |
|---|---|---|
| M0 | Mise en place | Projet Godot 4, autoloads, boucle de jeu à tick fixe, caméra (déplacement, zoom) |
| M1 | Carte | Grille isométrique, génération procédurale, terrains, attributs, overlays, sélection de tuile à la souris |
| M2 | Construction | Placement avec contraintes, coûts, démolition |
| M3 | Production | Extracteurs, tampons d'entrée/sortie, chaînes bois/charbon → électricité |
| M3b | Transport routier | Routes, dépôts, charrettes/camions, graphe + pathfinding, dispatcher, entrepôts |
| M4 | Réseau et villes | Lignes, graphe du réseau, demande, vente, blackout |
| M5 | Arbre tech | Laboratoires, RP, interface de l'arbre, déblocages |
| M5b | Rail | Voies ferrées, gares, trains |
| M6 | Nucléaire et renouvelables | Uranium, déchets, camions blindés, météo, jour/nuit, stockage, ports et barges |
| M7 | Économie et pollution | Marché, taxe carbone, satisfaction, événements |
| M6b | Fusion | Deutérium, lithium/tritium, tokamak, réacteur de fusion, victoire fusion (après M7) |
| M8 | Interface et équilibrage | Graphiques de production, info-bulles, tutoriel, jalons du bac à sable, équilibrage sur le rythme cible d'1 h |
| M9 | Persistance et finitions | Sauvegarde/chargement, options de lancement, sons |
| M10 | (plus tard) Scénarios | Mode scénario avec objectifs et conditions de victoire |

**Version jouable minimale** à la fin de M4 : bois et charbon transportés par camion → électricité → vente à une ville.

## 10. Questions ouvertes
~~Plateforme~~ : **tranché → application native Godot 4 (GDScript)**.
~~Style graphique~~ : **tranché → 2D isométrique**.
~~Transport~~ : **tranché → transport physique des matières (routes, camions, trains, barges)**.
~~Durée / mode~~ : **tranché → bac à sable, partie d'environ 1 h**.

Aucune question bloquante restante — prêt pour M0.
