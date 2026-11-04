class_name Treasury
extends RefCounted
## Trésor de la cité (à partir du bourg) : pièces, impôts journaliers selon
## le taux, la population et la satisfaction, et commerce au marché (achat et
## vente au prix courant, dans la limite du volume que les marchés traitent
## par jour ; vente automatique des surplus). Pure donnée.

const TAX_NAMES: PackedStringArray = ["Aucun", "Faible", "Normal", "Élevé"]
## Pièces par habitant et par jour, à pleine satisfaction.
const TAX_PER_INHABITANT: PackedFloat32Array = [0.0, 0.05, 0.1, 0.2]
## Satisfaction du jour multipliée par ce facteur selon le taux.
const TAX_MOOD: PackedFloat32Array = [1.0, 1.0, 0.95, 0.85]
## Les impôts rentrent de TAX_MIN_SATISFACTION_FACTOR à 100 % selon la
## satisfaction.
const TAX_MIN_SATISFACTION_FACTOR := 0.5
const DEFAULT_TAX := 1
## Prix de vente d'une unité, en pièces (Stockpile.Good) ; à l'achat,
## BUY_MARKUP fois plus.
const PRICES: PackedFloat32Array = [1.0, 1.0, 2.0, 4.0, 8.0, 3.0, 6.0, 1.0, 5.0]
const BUY_MARKUP := 1.5
## Surplus vendus automatiquement : ce qui dépasse cette part de la capacité.
const AUTO_SELL_RATIO := 0.75
## Lot des boutons d'achat et de vente.
const LOT := 10.0

var money := 0.0
var tax_level := DEFAULT_TAX
## Unités que les marchés achètent et vendent par jour (0 : pas de marché).
var trade_capacity := 0.0
var traded_today := 0.0
## Marchandises dont les surplus sont vendus chaque jour.
var auto_sell: Array[bool] = []
## Mouvements du jour : impôts, ventes, achats (pièces).
var taxes_today := 0.0
var sales_today := 0.0
var purchases_today := 0.0


func _init() -> void:
	auto_sell.resize(Stockpile.COUNT)
	auto_sell.fill(false)


static func sell_price(good: int) -> float:
	return PRICES[good]


static func buy_price(good: int) -> float:
	return PRICES[good] * BUY_MARKUP


## Impôts du jour pour [param count] habitants à [param satisfaction] (0–1).
func taxes_for(count: int, satisfaction: float) -> float:
	var factor := lerpf(TAX_MIN_SATISFACTION_FACTOR, 1.0, clampf(satisfaction, 0.0, 1.0))
	return count * TAX_PER_INHABITANT[tax_level] * factor


## Encaisse les impôts du jour ; renvoie le montant.
func collect_taxes(count: int, satisfaction: float) -> float:
	var amount := taxes_for(count, satisfaction)
	money += amount
	taxes_today += amount
	return amount


## Facteur de satisfaction du taux d'imposition.
func mood() -> float:
	return TAX_MOOD[tax_level]


## Unités encore échangeables aujourd'hui.
func trade_left() -> float:
	return maxf(0.0, trade_capacity - traded_today)


## Achète jusqu'à [param qty] de [param good] (pièces, volume du jour et
## place en stock) ; renvoie la quantité achetée.
func buy(stock: Stockpile, good: int, qty: float) -> float:
	var room := maxf(0.0, stock.capacity[good] - stock.amount[good])
	var n := minf(minf(qty, trade_left()), minf(room, money / buy_price(good)))
	if n <= 0.0:
		return 0.0
	stock.add(good, n)
	money -= n * buy_price(good)
	purchases_today += n * buy_price(good)
	traded_today += n
	return n


## Vend jusqu'à [param qty] de [param good] (stock et volume du jour) ;
## renvoie la quantité vendue.
func sell(stock: Stockpile, good: int, qty: float) -> float:
	var n := minf(minf(qty, trade_left()), stock.amount[good])
	if n <= 0.0:
		return 0.0
	stock.take(good, n)
	money += n * sell_price(good)
	sales_today += n * sell_price(good)
	traded_today += n
	return n


## Vend les surplus des marchandises cochées (au-delà de AUTO_SELL_RATIO de
## la capacité) ; renvoie les pièces gagnées.
func sell_surplus(stock: Stockpile) -> float:
	var before := money
	for good in Stockpile.COUNT:
		if auto_sell[good]:
			sell(stock, good, stock.amount[good] - stock.capacity[good] * AUTO_SELL_RATIO)
	return money - before


## Remet à zéro le volume et les mouvements du jour (après les statistiques).
func reset_day() -> void:
	traded_today = 0.0
	taxes_today = 0.0
	sales_today = 0.0
	purchases_today = 0.0
