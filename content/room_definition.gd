class_name RoomDefinition
extends Resource
enum Kind { ENTRY, COMBAT, SALVAGE, HAZARD, SAFE, BOSS }
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.ENTRY
@export var links: Array[StringName] = []
@export var map_column: int = 0
@export var map_row: int = 0
@export var enemies: Array[ActorDefinition] = []
@export var loot: Array[ItemDrop] = []
@export var strain_cost: int = 0
@export var recovery_health: int = 0
@export var recovery_strain: int = 0
