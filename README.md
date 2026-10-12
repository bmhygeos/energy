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
  été ×0,9) ; elle croît de 12 %/an si la ville est bien alimentée, 2 % sinon.
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
  une pénalité de 1 €/MWh non livré ; le surplus est perdu.
- **Consignes** : les centrales à combustible ne produisent que ce que
  demandent leurs villes (+5 % de marge, pertes comprises), au prorata du
  combustible en stock ; éolien et solaire passent d'abord. Une centrale sans
  ligne est à l'arrêt (pastille jaune), sans demande elle est en veille et ne
  brûle rien.
- **Vente** : 3 €/MWh livré. Le bandeau affiche l'énergie livrée / demandée
  (en rouge en cas de délestage) et les ventes de la veille ; le calque
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
  (Camions), centrale à charbon, éolienne (Éolien), ferme solaire (Solaire PV).
- **Bonus** : Vapeur −15 % de combustible, Mines +10 % d'extraction,
  Sylviculture ×2 repousse, Lignes HT et Transformateurs −40 % de pertes
  chacun, Dispatching et Smart grid −50 % de pénalités, Camions +10 % de
  vitesse, Physique nucléaire et des plasmas : recherche +10 % / +20 %…
- Les technologies marquées « contenu à venir » (nucléaire, offshore,
  stockage, fusion…) font partie de l'arbre mais leurs bâtiments arriveront
  aux étapes M5b, M6, M7 et M6b.
