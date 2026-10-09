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
| Sélectionner une tuile / un bâtiment | clic gauche (re-clic ou Échap pour désélectionner) |
| Construire | bouton du menu « Construction » puis clic sur la carte (le fantôme est vert si le placement est valide, sinon le motif s'affiche en bas) ; Échap ou re-clic sur le bouton pour quitter |
| Démolir | `X` ou bouton « Démolir », puis clic sur un bâtiment (rembourse 25 % du coût, 75 % pour un chantier) |
| Calque d'information | `O` (relief, vent, soleil, eau, gisements) ou boutons en bas à droite |
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
- **Dépôt de véhicules** (relié à une route, 6 places, livré avec une
  charrette) : sélectionnez-le pour acheter ou revendre (50 %) des charrettes
  (5 t, lente) et des camions (15 t, plus rapides).
- **Dispatcher** : chaque heure, les consommateurs les moins remplis sont servis
  en premier par la source joignable la plus proche ; on attend une charge
  correcte (60 % du camion ou du besoin) sauf si la source est presque pleine.
  Le véhicule libre le plus proche va charger, livre, puis rentre au dépôt ou
  enchaîne une autre mission. Coût d'usage par tuile parcourue.
- **Entrepôt** (relié à une route, 200 t toutes marchandises) : reçoit le
  surplus des producteurs dont la sortie dépasse 50 % sans client, et
  approvisionne ensuite les consommateurs.
- Un bâtiment qui échange des marchandises sans route affiche une pastille bleue.
- Couper une route recalcule les trajets ; une mission impossible est annulée
  (chargement perdu) et le véhicule rentre.
