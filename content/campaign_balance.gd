class_name CampaignBalance
extends Resource
## Authored hub economy and upgrade values. CampaignState owns changing totals.

@export var starting_salvage: int = 20
@export var starting_cells: int = 2
@export var recovery_cost: int = 5
@export var recovery_amount: int = 30
@export var cell_cost: int = 5
@export var module_cost: int = 10
@export var upgrade_cost: int = 30
@export var upgrade_health_bonus: int = 2
@export var retreat_reward_divisor: int = 2


func is_valid() -> bool:
	return starting_salvage >= 0 and starting_cells >= 0 and recovery_cost >= 0 and recovery_amount > 0 \
		and cell_cost >= 0 and module_cost >= 0 and upgrade_cost >= 0 and upgrade_health_bonus > 0 \
		and retreat_reward_divisor > 1
