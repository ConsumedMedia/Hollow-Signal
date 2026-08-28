# Milestone 2 combat contract

This is the current one-versus-one increment, not the complete demo rules. All game code uses typed GDScript with native Godot features.

## Ownership and flow

`Player button / enemy choice → ActionCommand → CombatRules + CombatState + RNG → ordered CombatEvents → screen text and shapes`

| File/object | Owns or does |
|---|---|
| `content/actor_definition.gd`, `content/actors/*.tres` | Authored ID, display name, maximum health, and damage range. No current health. |
| `content/content_catalogue.gd` | Explicit preloads for the two definitions; no directory scanning. |
| `combat/actor_state.gd` | Unique battle ID, team, reference to a definition, and independent current health. |
| `combat/combat_state.gd` | Participants, current actor, round number, monotonic turn number, outcome. |
| `combat/action_command.gd` | Actor/action/targets and expected turn number. Copies the supplied target list. |
| `combat/combat_event.gd` | Value snapshots needed to display the resolved result. No live actor references. |
| `combat/combat_rules.gd` | Validation, health changes, random damage, next actor, and terminal outcome. No nodes or presentation dependencies. |
| `scripts/battle_controller.gd` | Owns this battle and its RNG, accepts player input, selects a legal enemy action, and schedules the enemy's short pause. |
| `scripts/battle_screen.gd` | Displays events and state, enables/disables buttons, forwards requests. Never rolls damage or changes health. |

Loaded definitions may be shared. Runtime code reads them but never mutates them; each actor instance starts with its own health copied from `max_health`. This is an ownership convention, not a language-enforced immutable type. Tests resolve damage between two actors sharing one definition and check both instance isolation and unchanged content.

## Public rules interfaces

- `create_battle(crew_definition, enemy_definition) -> CombatState`: creates `crew_1` and `enemy_1` at full health. Invalid definitions return null.
- `get_legal_actions(state, actor_id) -> Array[ActionCommand]`: read-only query; returns validated Attack and Wait commands for the current conscious actor, otherwise an empty array.
- `validate_action(state, command) -> String`: empty string means valid; otherwise a readable rejection reason. No mutation.
- `resolve_action(state, command, rng) -> Array[CombatEvent]`: revalidates before any change; invalid commands or missing RNG return no events and leave state and RNG untouched. Valid commands resolve immediately and return the events in order.

These interfaces operate on valid battle states created by the rules. They are not a general validator for arbitrary saved/corrupted state; save validation belongs to milestone 8.

The command's expected turn number must equal the current turn. An accepted action increments it once, so replaying that command is rejected even after the same actor becomes active again. The controller also locks player submissions during resolution and the enemy response. A new input on a later player turn is a new action, not a duplicate.

## Current rules and order

1. Crew acts first. Each side gets one action, alternating crew → enemy → crew. The round starts at 1 and increments after the enemy action if combat continues.
2. Attack requires one conscious opposing target and always hits. It rolls one integer in the authored inclusive damage range. Applied damage is the lesser of the roll and remaining health; health stops at zero. No accuracy, dodge, crit, healing, or damage multipliers.
3. Wait requires no targets. It consumes the turn, changes no health, and consumes no random value.
4. Attack emits `damage` with actual HP lost and health after the hit. A lethal hit then emits `defeated`. Wait emits `wait`.
5. Check outcome: no conscious crew means defeat; otherwise no conscious enemy means victory. Defeat takes priority if both sides are absent. At a terminal outcome, clear the active actor and emit `battle_ended`; no further turn is granted. Otherwise select the opponent and emit `turn_started` with the round number.

At zero HP an actor is defeated for this test. It cannot act or be attacked again. Its record remains available to show final health; there is no rank system or corpse mechanic. Downed/revival/permanent death are deferred to milestone 5.

The enemy chooses an Attack returned by the same legal-actions query; if unavailable, it chooses a returned Wait. Enemy archetypes and richer behaviour are milestone 4. The controller uses explicit player-input, resolving, enemy-turn, and finished phases. Event display is immediate; animations and a presentation phase are not added yet.

## Randomness and restart

The controller seeds one `RandomNumberGenerator` with 1729 by default. Only the rules consume it, and only accepted Attacks roll. Timing, labels, drawing, and Wait consume no gameplay randomness. Restart stops the pending Timer, creates fresh state, and resets that same seed. Leaving the scene frees the controller and Timer; returning starts fresh, not from a checkpoint.

Identical initial definitions, seed, commands, and pinned engine produce identical events and results. The tests compare complete transcripts, final state, and RNG state across 64 seeds. Do not promise replay compatibility across engine upgrades: Godot documents that the RNG implementation may change. [Godot RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)

With the shipped values and seed 1729, three player Attacks win in round 3 (crew 20 HP, enemy 0); six player Waits lose in round 6 (crew 0, enemy 20). Changing content changes these expectations.

## Verification and scope

Run `tests/run_tests.gd`, not the suite directly. It installs a native `Logger` before dynamically loading the suite and fails on assertions or engine/script errors. Negative self-tests prove both failure paths return exit 1. The error hook protects its counter with a Mutex and never logs inside the hook. [Godot Logger](https://docs.godotengine.org/en/stable/classes/class_logger.html)

See README.md for commands and manual steps; PROGRESS.md records actual results. No ranks, Move, Speed initiative, class skills, statuses, strain, power, roster, rewards, persistence, sound, or animation system are included in this milestone.
