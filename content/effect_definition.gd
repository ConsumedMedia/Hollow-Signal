class_name EffectDefinition
extends Resource
## Ordered secondary effects, after an ability's optional direct damage.

enum Kind { HEAL, STRAIN, STATUS, DISPLACE }

@export var kind: Kind = Kind.HEAL
@export var amount: int = 0
@export var status: StatusDefinition
@export var on_actor: bool = false


func is_valid() -> bool:
	match kind:
		Kind.HEAL:
			return amount > 0
		Kind.STRAIN:
			return amount != 0
		Kind.STATUS:
			return status != null and status.is_valid()
		Kind.DISPLACE:
			return absi(amount) in [1, 2, 3]
	return false
