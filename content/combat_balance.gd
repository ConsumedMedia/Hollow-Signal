class_name CombatBalance
extends Resource
## Only battle-local strain in M4. Shaken/power thresholds arrive in M5.

@export_range(1, 1000) var strain_max: int = 100
@export_range(0, 1000) var ai_protection_bonus: int = 100
@export_range(0, 1000) var ai_status_bonus: int = 5
@export_range(0, 1000) var ai_movement_bonus: int = 8
