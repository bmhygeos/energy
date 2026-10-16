class_name Research
extends RefCounted
## Recherche : technologies acquises, file d'attente (prérequis ajoutés
## automatiquement), points de recherche (RP) accumulés et modificateurs.
## Pure donnée.

var defs: Dictionary[StringName, TechDef] = {}
var known: Dictionary[StringName, bool] = {}
## File de recherche ; la tête reçoit les points.
var queue: Array[StringName] = []
## Points investis dans la tête de file.
var progress := 0.0
## Points accumulés sans recherche en cours, versés à la prochaine.
var bank := 0.0
## Heures de fonctionnement cumulées par type de bâtiment (conditions
## d'essai des technologies).
var operation_hours: Dictionary[StringName, int] = {}


func _init(p_defs: Array[TechDef]) -> void:
	for def in p_defs:
		defs[def.id] = def
		if def.start_known:
			known[def.id] = true


func get_def(id: StringName) -> TechDef:
	return defs.get(id)


## Vrai pour une technologie acquise ou vide (aucune exigence).
func is_known(id: StringName) -> bool:
	return id == &"" or known.has(id)


## Tous les prérequis sont acquis.
func is_available(id: StringName) -> bool:
	if is_known(id):
		return false
	for p in defs[id].prerequisites:
		if not is_known(p):
			return false
	return true


## Condition d'essai de [param id] remplie (ou absente).
func is_ready(id: StringName) -> bool:
	var def := defs[id]
	return def.requires_hours <= 0 or operation_hours.get(def.requires_building, 0) >= def.requires_hours


## Tête de file payée mais en attente de sa condition d'essai.
func is_waiting() -> bool:
	return not queue.is_empty() and progress >= defs[queue[0]].cost and not is_ready(queue[0])


func current() -> TechDef:
	return defs[queue[0]] if not queue.is_empty() else null


## Avancement de [param id] (0–1) : 1 si acquise, sinon la part investie.
func progress_of(id: StringName) -> float:
	if is_known(id):
		return 1.0
	if not queue.is_empty() and queue[0] == id:
		return progress / maxf(1.0, defs[id].cost)
	return 0.0


## Met [param id] en file, précédée de ses prérequis manquants ; renvoie les
## technologies achevées grâce aux points en banque.
func enqueue(id: StringName) -> Array[TechDef]:
	_enqueue_rec(id)
	var points := bank
	bank = 0.0
	return add_points(points)


func _enqueue_rec(id: StringName) -> void:
	if is_known(id) or id in queue:
		return
	for p in defs[id].prerequisites:
		_enqueue_rec(p)
	queue.append(id)


## Retire [param id] de la file, ainsi que les technologies qui en dépendent ;
## les points investis dans la tête retournent en banque.
func dequeue(id: StringName) -> void:
	if id not in queue:
		return
	if queue[0] == id:
		bank += progress
		progress = 0.0
	var removed: Array[StringName] = [id]
	queue.erase(id)
	var changed := true
	while changed:
		changed = false
		for q in queue.duplicate():
			for p in defs[q].prerequisites:
				if p in removed:
					removed.append(q)
					queue.erase(q)
					changed = true
					break
	if not queue.is_empty() and progress == 0.0 and bank > 0.0:
		var points := bank
		bank = 0.0
		add_points(points)


## Verse [param points] dans la file ; renvoie les technologies achevées.
func add_points(points: float) -> Array[TechDef]:
	var done: Array[TechDef] = []
	while not queue.is_empty():
		var def := defs[queue[0]]
		var need := maxf(0.0, def.cost - progress)
		if points >= need:
			if not is_ready(def.id):
				# Payée, mais en attente des heures d'essai : le reste en banque.
				progress = def.cost
				points -= need
				break
			points -= need
			progress = 0.0
			queue.pop_front()
			known[def.id] = true
			done.append(def)
		else:
			progress += points
			points = 0.0
			break
	# Technologies gratuites en tête de file.
	while not queue.is_empty() and defs[queue[0]].cost <= 0:
		var def := defs[queue.pop_front()]
		known[def.id] = true
		done.append(def)
	bank += points
	return done


## Produit des facteurs de [param key] sur les technologies acquises.
func modifier(key: StringName) -> float:
	var factor := 1.0
	for id in known:
		factor *= defs[id].modifiers.get(key, 1.0)
	return factor


## Bâtiments et véhicules débloqués par [param id] (noms).
static func unlocks_of(id: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	for def in BuildingDb.DEFS:
		if def.required_tech == id:
			names.append(def.display_name)
	for def in VehicleDb.DEFS:
		if def.required_tech == id:
			names.append(def.display_name)
	return names
