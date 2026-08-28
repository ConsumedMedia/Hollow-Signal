# Milestone 3 combat contract

This is the current four-position increment. The two shared prototype attacks are not the four class kits. No status, strain, power, permanent loss, or persistent campaign state is included.

## Ownership and flow

`Player selection / enemy choice → ActionCommand → CombatRules + CombatState + RNG → ordered CombatEvents → text and shapes`

| Object/file | Responsibility |
|---|---|
| `content/actor_definition.gd`, `content/actors/*.tres` | Authored ID, display name, maximum health, Speed, and ability references. |
| `content/ability_definition.gd`, `content/abilities/*.tres` | Authored ability ID, name, usable actor ranks, target ranks, and inclusive damage range. |
| `content/content_catalogue.gd` | Explicit actor preloads; actors explicitly reference their ability Resources. No directory scanning. |
| `combat/actor_state.gd` | Battle ID, team, shared definition, independent current health. C1/E1 labels are derived from the ID, not rank. |
| `combat/combat_state.gd` | Living actors, ordered rank ID lists, round ID queue/cursor, rolled initiative, current actor, round/action counters, outcome. |
| `combat/action_command.gd` | Actor/action/target IDs and expected turn number; owns a copy of the target array. |
| `combat/combat_event.gd` | Snapshots for presentation: names/IDs, HP loss, remaining HP, ranks, round, outcome. Names remain available after actor removal. |
| `combat/combat_rules.gd` | Validation, initiative, damage, swaps, removal, rank compaction, turn advancement, outcomes. No scene dependency. |
| `scripts/battle_controller.gd` | Owns state/RNG, accepts commands, chooses legal enemy attacks, and coordinates input locks and the enemy Timer. |
| `scripts/battle_screen.gd` | Shows acting actor/order, rank cards, legal targets and disabled reasons; submits choices; never rolls damage or mutates state. |
| `scripts/placeholder_stage.gd` | Draws shapes from copied rank ID arrays and the active ID; no rule evaluation. |

Loaded Resources are shared templates and runtime code never mutates them. Damage now belongs to ability definitions rather than actor definitions. Health, ranks, initiative, and outcomes are runtime data. A no-ability actor definition is allowed because universal Wait must still work. Authored ability rank lists must be nonempty, unique, and between 1 and 4; IDs cannot use the reserved Move/Wait names.

## Public interfaces

- `create_battle(crew: Array[ActorDefinition], enemy: Array[ActorDefinition], rng) -> CombatState`: arrays are rank 1 outward, maximum four per side. Creates independent instances and rolls round 1 initiative. Invalid content/missing RNG returns null before any RNG consumption. An empty side produces a terminal result without rolling.
- `get_legal_actions(state, actor_id) -> Array[ActionCommand]`: read-only, active conscious actor only. Returns each legal attack/target pair, each adjacent swap, and Wait. Terminal state returns none.
- `ability_reason(state, actor_id, ability_id) -> String`: read-only availability by current rank/occupied targets, even when it is not that actor's turn. This lets a swap's effect be inspected immediately; it does not authorize acting out of turn.
- `validate_action(state, command) -> String`: empty means valid, otherwise readable reason. No mutation.
- `resolve_action(state, command, rng) -> Array[CombatEvent]`: validates before any mutation or random roll. Invalid commands or missing RNG produce no events and leave state, definitions, formation, order, and RNG untouched.

The interfaces expect internally valid combat state; they do not replace the later save-data validator. A successful action increments `turn_number` once. A command with an old or future expected turn is rejected, including when the same actor becomes active in a later round.

## Formation and attacks

Rank 1 is closest to the opposition. Crew renders left to right as 4–3–2–1; enemy as 1–2–3–4. The rank arrays store stable actor IDs, always from rank 1 outward. Rank is derived from array position; there is no second mutable rank field that can disagree.

| Action | Actor ranks | Target ranks | Crew / enemy damage |
|---|---|---|---|
| Close strike (`strike`) | 1, 2 | Opponent 1, 2 | 6–8 / 4–6 |
| Covering shot (`shot`) | 3, 4 | Opponent 1, 2, 3, 4 | 6–8 / 4–6 |
| Move (`move`) | Any | Adjacent conscious ally | None |
| Wait (`wait`) | Any | No target | None |

Attack requires one living opponent in an allowed rank and always hits. Roll one integer from the ability range; applied damage is capped at remaining HP. No accuracy, crit, dodge, healing, or status effects.

Move swaps the acting actor's ID with an ally exactly one rank away and consumes the acting actor's action. It does not consume the ally's action, change health, reorder the turn queue, or reroll initiative. Wait consumes the action without changing health. Neither Move nor Wait rolls damage, but either can finish a round and thereby trigger new initiative rolls.

## Initiative and action resolution

At each round start:

1. Collect conscious actors and sort IDs lexicographically, ascending.
2. Roll one inclusive d6 per actor in that canonical ID order. Score is authored Speed + roll.
3. Sort by score descending, then actor ID ascending on equal scores. Sorting itself never consumes RNG.
4. Keep this ID queue for the entire round and begin at its first actor.

The explicit ID comparison breaks every tie; it does not rely on the sorting implementation preserving equal elements. Formation changes cannot affect draw order. [Godot Array sorting](https://docs.godotengine.org/en/stable/classes/class_array.html)

For each valid action:

1. Apply damage, swap, or Wait and emit its event (`damage`, `moved`, or `wait`).
2. On lethal damage, emit `defeated`, remove the target from actors and its rank array, then emit `ranks_compacted` with the new rank IDs. Event names/values remain usable after removal.
3. Increment the turn counter. Check outcome: no conscious crew → defeat; otherwise no conscious enemies → victory. If both sides are absent, defeat wins. Emit `battle_ended` and clear the active actor for terminal results.
4. Otherwise advance the queue cursor, skipping removed or non-conscious actors. Do not insert or reorder turns after a swap or removal.
5. When the queue is exhausted, increment the round and roll the new queue, emitting `round_started`. Finally emit `turn_started`.

Defeated actors are absent from formation and future initiative. Their stale ID in the current round's snapshot is harmless because advancement skips it. There are no corpses, downed states, or revival yet; milestone 5 adds crew vulnerability.

## Controller, input, and presentation

Phases are player input → resolving → next actor's player input or enemy turn, or finished. An enemy waits 0.4 seconds, chooses the first legal attack from the shared query, and otherwise chooses its legal Wait. There is no additional gameplay randomness in AI. Enemy archetypes/advanced behaviour remain milestone 4.

The UI selects an attack or Move first, then submits the clicked legal target card; Wait submits directly. Skills show visible rank/target reasons. All command buttons lock during resolution/enemy turns and after terminal outcomes. The controller rejects more than one player action in a rendered frame, even when two crew turns are consecutive. A fresh input on a later turn is a new command, not a duplicate.

Events display immediately. The next input phase is deferred until the current submission finishes. Restart stops the enemy Timer, increments a generation token to invalidate deferred callbacks, creates new actors, and resets the seed. Leaving the scene frees its controller/Timer. Presentation does not need an animation or sound callback to complete.

## Determinism and verification

Only rules consume the controller's `RandomNumberGenerator`: initiative at round boundaries and damage on valid attacks. Timing, drawing, selection, and rejected input consume none. Same definitions, seed, commands (including target IDs/Move/Wait), and pinned engine reproduce events and results. Cross-engine-version replay compatibility is not promised. [Godot RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)

Default seed 1729 opens with C3, C1, C2, E1, C4, E4, E2, E3. Always using the available attack against enemy rank 1 wins in round 4 (C1 2 HP, others 30). Waiting on every crew turn loses in round 7. These are reproducible test cases, not final balancing.

Run `tests/run_tests.gd` for rules; its native Logger catches script errors as well as assertions. The suite compares 64-seed replays, verifies formation/initiative invariants, and exercises stranded actors. `tests/setup_smoke.gd` checks actual buttons, layouts, restart races, and complete battles. README.md has playtest steps; PROGRESS.md records actual commands/results and untested work.
