class_name CombatBalance
extends Resource
## Authored thresholds; runtime health, strain and power live elsewhere.

@export_range(1, 1000) var strain_max: int = 100
@export var shaken_threshold: int = 100
@export var shaken_clear_below: int = 50
@export var shaken_damage_multiplier: float = 0.75
@export var victory_recovery_health: int = 1
@export var power_max: int = 100
@export var starting_power: int = 100
@export var corridor_power_cost: int = 5
@export var power_safe_threshold: int = 50
@export var power_low_threshold: int = 25
@export var medium_power_strain: int = 2
@export var low_power_strain: int = 5
@export var overcharge_cost: int = 10
@export var overcharge_multiplier: float = 1.5
@export_range(0, 1000) var ai_protection_bonus: int = 100
@export_range(0, 1000) var ai_status_bonus: int = 5
@export_range(0, 1000) var ai_movement_bonus: int = 8


func is_valid() -> bool:
	return (strain_max > 0 and shaken_threshold > 0 and shaken_threshold <= strain_max
		and shaken_clear_below > 0 and shaken_clear_below <= shaken_threshold
		and shaken_damage_multiplier > 0.0 and shaken_damage_multiplier <= 1.0
		and victory_recovery_health > 0 and power_max > 0
		and starting_power >= 0 and starting_power <= power_max and corridor_power_cost >= 0
		and power_low_threshold >= 0 and power_safe_threshold > power_low_threshold
		and power_safe_threshold <= power_max and medium_power_strain >= 0 and low_power_strain >= 0
		and overcharge_cost > 0 and overcharge_multiplier >= 1.0)
