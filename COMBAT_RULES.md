# Milestone 5 combat contract

Four classes, twelve class abilities, five enemy archetypes, shared effects, crew downing/death, persistent strain, Shaken and shared power. M6 adds the room graph and inventory around these rules; see EXPLORATION_RULES.md. There is no roster hub, retreat payout, campaign or disk save system yet. Current M6 integration passes native and rendered checks; see PROGRESS.md for results and remaining physical acceptance checks.

## Ownership and flow

`Player / EnemyPolicy → ActionCommand → CombatRules + CombatState + RNG → ordered CombatEvents → interface`

- Authored Resources: ActorDefinition (HP, Speed, skills), AbilityDefinition (ranks, target team, damage, uses, conditional multiplier, description and ordered effects), EffectDefinition (healing, strain, status or displacement), StatusDefinition (kind, duration, magnitude), CombatBalance (strain cap and AI preference bonuses). The catalogue explicitly preloads every class and enemy; Resources explicitly reference skills and statuses.
- CrewState records a unique individual: ID, definition reference, health, strain, Shaken and permanent death. ExpeditionState owns these records, retained formation, power, failed flag and an active-battle guard. The controller owns this minimal in-memory expedition until the test scene closes or an explicit fresh reset is requested.
- ActorState owns battle copies of health, strain, Shaken and death, plus per-ability use counts and StatusState instances. Rules synchronize persistent crew records after resolution and record death before removing an actor. New battles copy survivors' persistent values and reset only temporary statuses/use counters. Shared Resources never receive runtime counters.
- CombatState holds actors, formation arrays, round order, initiative, turn token, outcome and a read-only reference to balance data. Stable IDs C1–C4/E1–E4 follow actors, not ranks.
- CombatEvent contains value snapshots, including ability/status names, health/strain/power changes, status duration and ranks. Downed, revived, died, recovered, shaken and shaken_cleared are separate events. DOT attribution survives its source's removal.
- The controller owns the RNG and pacing Timer. The screen reads state and events only. Rules, effects and enemy preferences have no scene, animation or sound dependencies.

M3 test actor/skill Resources remain solely as regression fixtures. They are not the playable class kits.

## Authored class abilities

Rank arrays run from the front (1) outward. “All” means occupied ranks 1–4. All skills take one target and spend one action. Move and Wait are additional universal actions.

| Class (HP / Speed) | Ability | Actor ranks | Target | Default effect |
|---|---|---|---|---|
| Breacher (34 / 5) | Close strike | 1–2 | Enemy 1–2 | 6–8 damage |
| Breacher | Brace | 1–2 | Another ally, all | Protected for 2 target turn starts |
| Breacher | Ram | 1–2 | Enemy 1–2 | 4–6 damage, then push back 1 |
| Ranger (28 / 6) | Covering shot | 3–4 | Enemy all | 6–8 damage |
| Ranger | Exploit signal | 2–4 | Enemy all | 5–7; x1.5 if Exposed |
| Ranger | Fallback shot | 1–3 | Enemy all | 4–6, then move self back 1 |
| Technician (26 / 7) | Cutting beam | 2–3 | Enemy 1–3 | 4–6, then Scorch |
| Technician | Expose | 2–4 | Enemy all | Exposed for 2 target turn starts |
| Technician | Tractor pull | 2–4 | Enemy 2–4 | Pull forward 1 |
| Medic (24 / 4) | Needle dart | 2–4 | Enemy all | 3–4 damage |
| Medic | Field patch | 3–4 | Ally all, including self | Heal 8; 2 uses per actor per battle |
| Medic | Steady voice | 2–4 | Ally all, including self | Reduce strain by 20 |

Field patch rejects full-health targets and never exceeds maximum HP. Steady voice rejects targets at zero strain. Invalid commands spend neither action, use, power nor randomness. A shared Medic definition does not imply shared uses. Healing revives downed crew but never resurrects dead crew. Enemies are removed at zero HP.

The party begins C1 Breacher / C2 Technician / C3 Ranger / C4 Medic. Thus the class order differs from the order of rows above.

## Status timing and stacking

| Status / card code | Effect | Default duration |
|---|---|---|
| Protected / P | Reduce incoming direct damage by 50%; no redirection or protection chains | 2 recipient turn starts |
| Exposed / X | Marker enabling Exploit signal's bonus; ordinary attacks are unchanged | 2 recipient turn starts |
| Scorch / D | 2 damage before the recipient chooses an action; ignores Protected and Exposed | 2 ticks at recipient turn starts |

A freshly applied status has remaining = 2. At the recipient's next turn start, Scorch ticks first (if present), then every remaining status decrements to 1. At the following turn start, Scorch ticks again, then statuses reach zero and expire **before input**. A duration-1 ordinary status therefore expires at the next recipient turn start. Nothing decrements merely because the caster ended an action.

There is at most one status of each kind per actor. Reapplication **replaces** the old instance, strength and source with the new authored definition and resets the countdown; it does not sum damage, duration or protection. Different kinds coexist. Moving does not tick statuses. A status remains after its source dies. Scorch can down conscious crew or kill already-downed crew. Downed actors retain scheduled turn-start slots for DOT/expiry but cannot choose actions. Removed actors need no expiry events.

The UI displays short codes plus counts, a visible legend and full names on hover. Applied, expired and DOT events also appear in the rolling log.

## Damage and effect order

Direct attacks automatically hit. Roll one inclusive integer in Damage Min–Max. If the target is Exposed, apply the ability's Exposed Multiplier (1.0 for all except Exploit signal's 1.5). Multiply by 0.75 if the source is Shaken, by 1.5 if Overcharged, and by `1 - magnitude / 100` if Protected. **Floor once after multiplying all direct-damage modifiers**, then clamp at zero. HP loss is capped by current HP, but positive resolved damage to an already-downed crew member kills even though their HP loss is zero. Damage rounded to zero does not kill. Fixed DOT is not modified by Shaken/Overcharge/Exposed/Protected; it uses its own authored status magnitude.

Examples: 7 with protection → 3; Exploit's roll 7 against Exposed → 10; both together → floor(7 x 1.5 x 0.5) = 5. The interface shows base range on the ability and current per-target HP-loss ranges beneath the description. DOT has fixed authored damage; healing and strain do not roll.

For each accepted command:

1. Validate turn token, conscious active actor, rank, target/team/self restrictions, use limit and Overcharge affordability before mutation or RNG.
2. Wait emits its event. Universal Move swaps adjacent allies and emits their original ranks and new formation.
3. A class/enemy ability increments the acting instance's use counter. Overcharge spends power and emits power_spent first. Apply optional direct damage once; emit damage, then down crew or kill/remove/compact as appropriate.
4. Apply secondary effects **in Resource array order**: healing, strain, status, or displacement. An effect aimed at a removed target is skipped; an effect on a surviving caster still applies (e.g. Fallback after a killing shot).
5. Healing caps at max HP and can revive. Strain clamps to 0–100 and updates Shaken using the hysteresis below.
6. Increment the turn token, check outcome, then advance the round queue, skipping removed actors.
7. At each new actor turn, resolve Scorch and status expiry before emitting turn_started or offering commands. A lethal start-of-turn tick advances the token too, invalidating old requests.
8. No conscious crew means defeat and all deployed crew are lost, taking precedence over enemy elimination. Victory recovers downed survivors to 1 HP. Emit battle_ended, clear the active ID and release the expedition's active-battle guard. Synchronize persistent state. Rejected terminal commands cannot repeat recovery.

Only direct damage and round initiative consume gameplay RNG. Move, support, fixed effects, AI scoring, UI refresh and rejected commands consume none. A support action that finishes a round can still trigger the next initiative rolls.

## Forced movement and universal Move

Rank 1 is nearest the opposing side. Positive displacement moves backward; negative moves forward. Displacement removes the actor ID and inserts it at the destination, shifting intervening actors. Clamp destinations to currently occupied ranks; there are no gaps and no fifth rank. Forced movement never changes the initiative queue or grants extra actions.

Universal Move remains an adjacent **swap**, not an insertion; it spends the actor's action, never the ally's. The distinction matters for future effects moving multiple ranks. A damaging ability still works if its extra displacement is clamped to the same rank; the displacement event records equal start/end ranks. Pure displacement rejects a target that cannot move. Fallback can fire while alone, even with no backward space.

## Initiative and enemy choices

Each round, gather living IDs (including downed crew's status-tick slots) and sort lexicographically. Draw Speed + inclusive d6 in that canonical order. Sort score descending, stable actor ID ascending to break ties. Keep the resulting queue independent of rank changes; draw fresh rolls only at the next round start. Downed slots resolve DOT/expiry and skip input. Revival before an unused slot allows that slot's action; revival after the slot waits until next round. Never insert an extra turn. Universal Move may swap with a downed adjacent ally.

Two test patrols cover five archetypes without placing five enemies on screen:

| Enemy (HP / Speed) | Specialty |
|---|---|
| Hull Mauler (22 / 3) | Shear: 5–7, actor ranks 1–2 to enemy ranks 1–2 |
| Needle Turret (18 / 5) | Needle volley: 4–6, actor ranks 3–4 to enemy ranks 3–4 |
| Signal Echo (20 / 4) | Signal burst: 2–3 plus 18 strain, actor ranks 2–4 to all opponents |
| Relay Bulwark (26 / 2) | Shield relay: Protected on another ally, actor ranks 1–3 |
| Tow Drone (20 / 4) | Tow hook: 3–4 then pull 1, actor ranks 2–4 to opponent ranks 2–4 |

All have Scramble, a 3–4 damage fallback from any rank to any opponent. Boarding patrol is Mauler / Bulwark / Tow Drone / Needle Turret. Signal patrol replaces only the Tow Drone with Signal Echo.

EnemyPolicy ranks only commands returned by get_legal_actions; the controller sends its choice back through resolve_action's validation. Score starts with adjusted maximum direct damage, then adds actual possible healing/strain change, a bonus for a new status (Protected 100, other statuses 5), and 8 for effective displacement. Those bonuses are editable balance values. Existing status kinds get no reapplication bonus, so the protector attacks while allies are already protected. Wait scores -1, Move -2; ties use action ID then target ID ascending. There is no AI RNG or hidden bypass. This is a small deterministic preference policy, not advanced planning.

## Public interfaces and presentation

- `create_battle(crew, enemy, rng, expedition = null)`: max four definitions per side; validate before RNG; build independent instances. Omit the expedition for a fresh test; pass one to copy its living crew records and retained ranks. Failed/already-active expeditions are rejected. Empty sides are terminal without rolling.
- `get_legal_actions(state, actor_id)`: read-only commands for the active conscious actor. Wait always remains legal while ongoing.
- `ability_reason(state, actor_id, ability_id)`: read-only rank, use and eligible-target explanation, also usable for inactive actors. It does not authorize acting out of turn.
- `validate_action(state, command)`: empty means legal; otherwise readable reason. No mutation.
- `resolve_action(state, command, rng)`: ordered snapshots; invalid commands/null RNG return no events and leave state/content/RNG unchanged.
- `adjusted_damage(target, ability, rolled, source = null, overcharge = false)`: shared read-only modifier calculation for resolution and previews.
- `new_expedition(crew)`: create independent crew records with balance-defined starting power.
- `traverse_test_corridor(expedition)`: isolated battle-test helper; deduct 5 power with zero clamp, then apply room-entry strain. Actual M6 navigation uses ExpeditionRules.begin_travel/arrive with the same balance, separating the cost from arrival so skipping presentation cannot double-apply pressure.
- `EnemyPolicy.choose_action(state)`: read-only deterministic selection from legal commands.

These expect internally valid runtime state, not unvalidated save files. Save validation belongs to M8. Each definition remains shared and read-only; test code explicitly duplicates nested Resources when deliberately corrupting a test fixture.

All action controls lock during resolution, enemy turns and terminal outcomes. The current acting class populates three skill slots; TARGET cards can be allies or enemies. Same-frame repeats are rejected. EnemyDelay affects pacing only. Restart/switch cancels the old Timer and deferred callbacks using a generation token. Missing animation is immediate event presentation, with no animation callback dependency.

## Crew vulnerability, strain and power

- At zero health, crew are **DOWNED**, retain their rank, and cannot act. Any later positive direct or DOT damage kills them permanently in this expedition. Overkill on the initial hit does not count as another hit. Healing above zero revives; damage/status expiry still occurs before input. Enemies have no downed phase.
- No conscious crew means immediate defeat and loss of every deployed individual. Downed survivors recover to 1 HP after victory. Dead records remain in ExpeditionState even when removed from CombatState.
- Strain persists from 0–100. At 100, **SHAKEN** applies a 0.75 direct-damage multiplier. It remains at 50–99 and clears only below 50. Healing does not clear strain. Medic relief and room pressure update the same hysteresis. Temporary combat statuses do not include Shaken.
- Power begins at 100. Each test corridor costs 5, including at low power (clamp to zero). Apply room strain using the resulting power: 0 at 50+, 2 at 25–49, 5 below 25. Zero power is allowed. No passive per-turn drain or strain gain exists.
- Overcharge is an optional ActionCommand flag: crew damaging abilities only, 10 power for x1.5 direct damage. Support, Move, Wait and enemies cannot Overcharge. Choosing the toggle is read-only; accepting a command spends exactly once. UI resets the toggle on each turn or when selecting a non-damaging action.
- Thresholds, costs, multipliers and recovery HP live in `content/balance.tres`. Power cells/inventory, hazards, safe room and hub recovery are deferred to their milestones.
- **Next battle / −5 power** is a test corridor followed by the same patrol with the same test seed. It keeps individual wounds, strain, Shaken, deaths, formation and power. **Fresh expedition**, patrol switch, drill, or leaving the test scene explicitly abandons this test session. Nothing is saved to disk yet.
- **Vulnerability drill** is labelled test data: normal classes, C1 downed, C3 at Shaken threshold, exactly one Overcharge of power, seed 20 so C4 Medic acts first. It does not change normal starting balance or bypass combat rules.

## Verification scope

The rules suite retains M3 fixtures and adds all class effects, timed expiry, independent healing uses, DOT death/source attribution, forced movement and 64 class-patrol replay comparisons. Integration retains prior navigation and Close strike regressions, clicks all twelve class skills at two sizes, checks maximum status display, naturally completes both patrol outcomes, and exercises README's exact opening without state overrides.

M5 additionally tests down/revive/death, DOT on downed slots, revival before/after a queued turn, defeat priority, persistent survivors/deaths, exact Shaken/power boundaries, Overcharge rejection and repeat commands. The GUI checks click the drill and charged targets, continue to another battle, and compare full event/persistent-state results at two enemy Timer speeds. Presentation settings themselves are deferred to M12; immediate/no-animation presentation remains supported. Seeded equality requires the same engine/content/commands. Physical editor controls, DPI readability and tactical enjoyment require user playtesting; no Windows export was tested. See PROGRESS.md for current measured results.
