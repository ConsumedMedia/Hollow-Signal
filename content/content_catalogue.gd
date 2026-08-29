class_name ContentCatalogue
extends RefCounted
## Explicit references work outside the editor too; no directory scanning.

const TEST_CREW: ActorDefinition = preload("res://content/actors/test_salvager.tres")
const TEST_ENEMY: ActorDefinition = preload("res://content/actors/test_sentry.tres")

const BREACHER: ActorDefinition = preload("res://content/actors/breacher.tres")
const TECHNICIAN: ActorDefinition = preload("res://content/actors/technician.tres")
const RANGER: ActorDefinition = preload("res://content/actors/ranger.tres")
const MEDIC: ActorDefinition = preload("res://content/actors/medic.tres")
const MAULER: ActorDefinition = preload("res://content/actors/mauler.tres")
const BULWARK: ActorDefinition = preload("res://content/actors/bulwark.tres")
const TUGGER: ActorDefinition = preload("res://content/actors/tugger.tres")
const NEEDLE: ActorDefinition = preload("res://content/actors/needle.tres")
const CHORISTER: ActorDefinition = preload("res://content/actors/chorister.tres")
const SHIP: ShipDefinition = preload("res://content/ship.tres")
const POWER_CELL: ItemDefinition = preload("res://content/items/power_cell.tres")
const MODULES: Array[ModuleDefinition] = [
	preload("res://content/modules/reinforced_plating.tres"),
	preload("res://content/modules/servo_rig.tres"),
	preload("res://content/modules/cutting_edge.tres"),
	preload("res://content/modules/med_injector.tres"),
	preload("res://content/modules/calming_relay.tres"),
	preload("res://content/modules/reserve_capacitor.tres")]


static func crew_party() -> Array[ActorDefinition]:
	return [BREACHER, TECHNICIAN, RANGER, MEDIC]


static func enemy_party(signal_patrol: bool = false) -> Array[ActorDefinition]:
	return [MAULER, BULWARK, CHORISTER if signal_patrol else TUGGER, NEEDLE]


static func get_module(module_id: StringName) -> ModuleDefinition:
	for module: ModuleDefinition in MODULES:
		if module.id == module_id:
			return module
	return null
