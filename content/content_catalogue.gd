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


static func crew_party() -> Array[ActorDefinition]:
	return [BREACHER, TECHNICIAN, RANGER, MEDIC]


static func enemy_party(signal_patrol: bool = false) -> Array[ActorDefinition]:
	return [MAULER, BULWARK, CHORISTER if signal_patrol else TUGGER, NEEDLE]
