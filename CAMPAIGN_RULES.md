# Milestone 7 campaign contract

`CampaignService` owns one live `CampaignState` across scene changes. `SaveService` validates versioned disk checkpoints before replacing that live state. **New Game** replaces an existing campaign only after confirmation. See `SAVE_RULES.md`.

Authored `ActorDefinition`, `ModuleDefinition`, item and ship Resources contain editable content only. `CampaignState`, `CrewState`, `ExpeditionState`, inventory stacks and room records contain mutable state. Campaign and combat rules have no scene, animation or sound dependency.

## Hub rules

- A fresh campaign has eight unique crew records: two Breachers, two Technicians, two Rangers and two Medics. Four are selected in ranks 1–4.
- Party selection requires exactly four living crew to deploy. Rank controls swap selected crew one position at a time.
- Basic recruits and full health restoration are free. Strain treatment costs 5 salvage and removes 30 strain; Shaken clears only below 50.
- Two power cells begin in stores. A cell costs 5 salvage and all stored cells transfer to the next expedition, so they cannot duplicate between deployments.
- Six authored modules cost 10 salvage each. Each can be owned once and equipped by one crew member; equipping it elsewhere moves it. A crew member holds at most one module.
- The single 30-salvage upgrade adds 2 maximum health to every current and future crew member.

## Expedition return

- Boss extraction returns all carried alloy scrap and data wafers.
- Retreat is guaranteed on a conscious player turn, or from a room while no corridor, overflow decision or battle is active. It returns half of each reward, rounded down.
- Defeat returns no cargo and permanently loses every deployed crew member. Dead records remain visible and cannot be selected.
- An expedition can be completed only once. The campaign clears its active-expedition reference before another deployment.
- Free recruitment and free health restoration ensure the player can rebuild after a total-party loss.

Modules modify runtime actor values copied from the equipped crew record: maximum health, Speed, damage, healing, strain relief or starting power. Combat still resolves those values in `CombatRules`; the UI only presents them.
