# Hollow Signal — Demo Specification

## Source and authority

Recorded from the user's full plan supplied on 2026-08-27. This is an operational transcription of its game, architecture, production, and release requirements, not a new design or independent verification of its research links. The original user-supplied plan is authoritative if a discrepancy is found. Milestone scopes and acceptance checks are recorded in PROJECT_PLAN.md.

The plan's embedded milestone prompts are a sequence to request individually, not permission to implement the entire game. Current authorization and progress are tracked in PROJECT_PLAN.md and PROGRESS.md.

## Direction and scope

Working title: **Hollow Signal**, a placeholder that has not been cleared for commercial use. A salvage crew investigates a derelict research vessel, recovers material, discovers the source of a repeating transmission, and tries to extract before injuries, strain, and power loss overwhelm it.

Core loop: prepare crew → choose equipment → explore ship → fight or investigate → decide whether to continue → extract → recover and upgrade.

Target: a Windows PC demo, followed by a larger game; one beginner developer; no fixed deadline or required paid plugins. A successful expedition should take approximately 20–30 minutes, plus a short introduction and hub visit. Schedule estimates follow the first three milestones and one finished character's actual art workload.

Borrow broad principles of formation tactics, vulnerable characters, expedition pressure, and illustrated theatrical presentation. Create original characters, environments, UI art, dialogue, audio, story, and balancing. Never extract Darkest Dungeon assets or reproduce its branding. Use illustrated 2D depth rather than 3D models, cameras, or environments.

| Area | Fixed demo scope |
|---|---|
| Party and roster | Four active crew; eight starting individuals, two per class |
| Classes | Breacher, Ranger, Technician, Medic |
| Abilities | Three per class, plus universal Move and Wait |
| Enemies | Five regular archetypes and one boss |
| Environment | One derelict research vessel |
| Layout | One authored eight-room layout |
| Encounters | Combat, salvage, hazard, safe room, boss |
| Hub | Recruitment, recovery, equipment upgrades |
| Inventory | Twelve slots, simple stacking |
| Equipment | Six collectible modules; one equipped per crew member |
| Persistence | One campaign slot with a backup |
| Presentation | Original portraits, combat poses, layered environments, sound |
| Completion | Defeat the boss and extract; campaign remains replayable |

Excluded: multiplayer, crafting trees, ship piloting, true 3D, procedural layouts, mod support, full voice acting, complex relationships, live AI, and unnecessary expansion mechanics. Placeholder visuals come first; AI-assisted art and manual cleanup follow later. Do not generate or purchase assets without a request.

## Technical baseline

- Godot **4.7.2 Standard**, pinned for the demo; typed GDScript; Compatibility renderer; native Godot features; no required third-party plugins.
- 1920×1080 design resolution with proportional scaling and letterboxing; interface usable at both 1280×720 and 1920×1080.
- Mouse and keyboard. No OpenAI API integration in the shipped game.
- Preserve existing files and Git history. Git checkpoints follow verified milestones.
- Locate and verify the executable rather than assuming installation or PATH availability. The initial local version check returned 4.7.1; milestone 1 subsequently obtained and verified the pinned 4.7.2 Standard build. See PROGRESS.md for commands and results.

## Combat

### Formation, turns, and commands

- Each side has four positions; rank 1 is nearest the opposition. Each actor occupies one position, including the boss.
- Abilities define usable actor ranks and valid target ranks.
- Every conscious actor receives one action per round.
- Initiative is Speed plus a seeded integer roll from 1–6; stable actor ID breaks ties.
- Valid attacks hit automatically. Damage uses a displayed minimum–maximum range. No separate accuracy, dodge, or critical hits.
- Move swaps with an adjacent ally and consumes the action. Wait is always available.
- Dead actors are removed and remaining ranks close up; no corpses initially.
- Enemy AI selects only legal actions and targets through the same checks as player commands.
- Retreat is guaranteed on a player turn, ends the expedition, and forfeits half its salvage.

### Classes and effects

| Class | Role | Three abilities |
|---|---|---|
| Breacher | Front-line damage and protection | Close-range strike; protect an ally; knock an enemy backward |
| Ranger | Reach and precision | Rear-rank shot; stronger attack against an exposed target; attack while moving backward |
| Technician | Position control and support | Cutting beam; expose an enemy; pull an enemy forward |
| Medic | Survival and strain management | Weak ranged attack; limited-use healing; reduce an ally's strain |

Start around 20–35 crew health and 4–8 damage for ordinary attacks. All numbers belong in editable content Resources; all thresholds and multipliers belong in balance data. Healing has a per-battle use limit that resets between battles.

Use only the shared effect system needed for damage, healing, strain reduction, protection, expose, forced movement, and one damage-over-time status. Document duration, stacking, rounding, and resolution order when milestone 4 is requested; the plan does not yet specify those details.

The five regular enemy archetypes are melee attacker, rear attacker, strain attacker, protector, and displacement specialist.

### Health and permanent loss

- At zero health, crew are downed and cannot act.
- Further damage permanently kills a downed crew member.
- Healing above zero restores the crew member to action.
- If no conscious crew remain, the expedition fails and the deployed crew are lost.
- After victory, downed survivors recover to one health.

### Strain

- Range: 0–100; persists between battles.
- At 100, the crew member becomes Shaken and deals 25% less damage.
- Shaken clears only when strain falls below 50.
- Enemy abilities, hazards, and low power increase strain.
- Medic abilities, the safe room, and hub recovery reduce it.
- Distinct breakdown behaviours and rare heroic responses are deferred beyond the demo.

### Shared power

- Expeditions start at 100 power.
- Every corridor traversal costs 5 power, including backtracking.
- Entering a room adds 0 strain at 50+ power, 2 at 25–49, or 5 below 25.
- Overcharging a damaging ability costs 10 power and increases its damage by 50%.
- Overcharge cannot spend unavailable power.
- Power cells restore 25 power and can be used outside combat.
- Zero power increases pressure but does not automatically end the expedition.

## Exploration and hub

Use a connected room graph, with short side-scrolling corridor transitions for presentation and interaction. No platforming or physics-based combat. The eight authored rooms are entry airlock, three combat rooms, salvage room, hazard room, safe room, and boss room. Salvage and the hazard belong on an optional branch; a route from entry to boss must be guaranteed.

Visited events resolve once. Backtracking consumes power without regenerating loot. Track room progress, inventory, power, rewards, and inspection choices. Full inventory requires a clear keep/discard decision. Entering and leaving combat must preserve crew and expedition state.

At the hub, choose four crew and arrange their ranks, buy supplies, assign one module per crew member, and spend salvage on recovery and one upgrade tier. Provide free basic recruits and free full-health restoration so party loss cannot make the campaign unplayable. Preserve strain unless treated, preserve permanent deaths, and apply completed-expedition rewards exactly once.

## Rules and runtime architecture

Flow: player UI or enemy AI → action command → rules and game state → ordered event list → animation, sound, text, and interface.

Rules calculate damage once; presentation displays the results. Skipping animation, changing speed, or disabling effects must not change outcomes. Only rules consume gameplay randomness; particles and camera shake use separate randomness.

Use a small application root for persistent services; battle-specific objects stay inside the battle scene rather than making everything globally accessible.

| Component | Responsibility |
|---|---|
| Campaign state | Roster, currency, upgrades, completed objectives |
| Expedition state | Room graph, location, supplies, power, collected rewards |
| Combat state | Participants, ranks, round order, temporary effects |
| Combat rules | Validate and resolve actions |
| Combat controller | Advance turns and coordinate input |
| Battle presentation | Movement, poses, effects, sound, combat text |
| Content catalogue | Load classes, abilities, enemies, modules, encounters |
| Save service | Campaign checkpoints |
| Audio service | Music, ambience, effects, volume settings |

Authored custom Resources define actors, abilities, statuses, encounters, items, and modules. Do not put instance health or other mutable runtime values in shared authored definitions. Use an explicit content catalogue rather than directory scanning that has only been tested in the editor.

Runtime records:

- `CrewState`: unique ID, class ID, health, strain, equipment, progression.
- `CombatState`: actor instances, ordered ranks, round, active actor, statuses.
- `ActionCommand`: actor ID, action ID, target IDs, overcharge choice.
- `CombatEvent`: event type, source, targets, presentation values.
- `ExpeditionState`: room progress, inventory, power, rewards, random state.
- `SaveData`: version and persistent state.

Core rules interfaces: `get_legal_actions(state, actor_id)`, `validate_action(state, command)`, `resolve_action(state, command, rng)`. Invalid commands leave state unchanged.

Explicit phases: round start → turn start → choose action → resolve → present → check outcome → next actor.

- Damage-over-time resolves before an actor chooses an action.
- Dead and downed actors cannot act; rank changes do not grant another turn.
- Disable action buttons during resolution and presentation. Repeated clicks cannot submit duplicate actions.
- Missing animation falls back to immediate event presentation.
- Victory, defeat, and retreat are terminal outcomes. Simultaneous elimination is defeat.

Build these components only in their requested milestones, not all during setup.

## Saving

Save at the hub, room boundaries, battle entry, and after battle resolution. Loading during battle restarts it from its entry checkpoint with the same initial state and seed; explain this in the interface. Do not save animation progress or arbitrary scene nodes.

Use versioned JSON under `user://`, a temporary-file write before replacing the main save, and a known-good backup. Validate data before replacing live state. Provide a clear recovery message for damaged or incompatible saves; do not silently overwrite unsupported versions. Use unique IDs and resolved flags to prevent duplicated rewards or deaths. Serialize seeds and random states without losing integer precision. Godot `FileAccess` and JSON support still require custom conversion and validation.

## Visual presentation and asset production

### Layered 2D depth

Use `Node2D`, `Sprite2D`, `Camera2D`, `Parallax2D`, `AnimationPlayer`, and `Control`; keep the interface in an independent `CanvasLayer`.

| Layer | Treatment |
|---|---|
| Distant hull and space | Slow movement, low contrast |
| Machinery and architecture | Moderate movement, restrained detail |
| Floor and characters | Readable primary action plane |
| Foreground cables and beams | Faster movement, dark framing |
| Fog and particles | Sparse atmosphere |
| Interface | Fixed independently of the environment |

Start distant, middle, and foreground parallax multipliers around 0.15, 0.4, and 1.15, then tune by playtesting. Use overlap, silhouettes, environmental framing, painted light and shadow, restrained camera motion, grounding shadows, and strong attack/reaction poses. Verify tutorial controls against the pinned editor rather than assuming old steps still apply.

### Animation

Prototype with complete placeholder sprites, movement, tint changes, and pose swaps. Polish later with layered cutouts for idle/walk and separate attack/reaction illustrations. Finish one crew member and one enemy before producing the remaining cast.

Each character needs portrait, idle, walk, attack, support, hurt, downed, and death. An ordinary attack presents anticipation, decisive pose, impact sound and flash, damage text, reaction, and return. Keep ordinary actions brief and reserve longer emphasis for major events. Include animation skip, speed options, missing-animation fallback, and sound hooks without locking combat.

### Visual guide and provenance

Dark navy and charcoal foundations, bone-white equipment markings, rust-orange salvage technology, restrained cyan instruments, heavy shadow shapes, readable silhouettes, and minimal face/hand detail. No text baked into character or environment images.

Generate concepts only when requested, approve a consistent reference, and derive variations from that reference. Independent generated frames should not be assumed to form consistent animation. The example Breacher concept is an original full-body salvage worker with a compact industrial pressure suit, asymmetric shoulder protection, mechanical cutting weapon, distinctive enclosed helmet, three-quarter side view facing right, separated limbs, grounded stance, and uncropped equipment on transparency. It is a concept reference, not a finished animation sheet.

Asset specifications must cover size, facing, pivot, transparency, poses, naming, and intended on-screen scale for crew, enemies, portraits, ability icons, modules, environments, and effects. Final image sizes and pivots are set during cleanup.

Manually check actual transparency, consistent proportions/equipment/facing/lighting, clean silhouettes and edges, enough joint overlap, no accidental cropping, and no text, logos, or unwanted symbols. Maintain a register of source, generation tool or creator, applicable terms, edits, and usage. Validate one complete character set before multiplying it. Retain placeholders when approved assets are unavailable.

## Boss and narrative

The Signal Warden occupies one rank. It alternates ordinary actions with a charged attack, clearly telegraphed against a marked party rank on its next turn. Moving changes who is threatened. Use existing rules and events, not a second combat engine.

Include a short mission briefing, six discoverable logs, contextual crew barks, and an extraction ending. Use original text with no required voice acting. Boss defeat, ending, and rewards must complete correctly and occur once.

## Usability, audio, and tutorial

Music, ambience, UI, and combat audio buses. Use licensed supplied assets or clearly marked placeholders, not arbitrary fetched copyrighted audio. Avoid uncontrolled overlap.

Add volume, text scaling, reduced motion, screen-shake toggle, combat speed, keyboard navigation, and persistent settings. Pair important colours with icons or labels. Explain formation, abilities, strain, power, and retreat through a short contextual tutorial, including prominent downed/death/strain/power/overcharge explanations. Text must not clip; disabling effects must preserve functionality.

## Demo verification and release

Native GDScript rule tests must exit unsuccessfully on failure. Use manual playtests for readability, animation, sound, and enjoyment. Record exact commands/results, known issues, untested behaviour, and exact Godot playtest steps with expected results at each milestone. Do not equate file creation with working behaviour.

Demo acceptance:

- Fresh campaign reaches the ending without editor intervention.
- All four classes offer meaningful formation decisions; continuing versus retreating is a real decision.
- Roster survives scene changes and application restarts.
- Duplicate clicks cannot duplicate actions, purchases, or rewards.
- Invalid targeting and empty formations cannot freeze combat.
- Readable at 1280×720 and 1920×1080.
- Windows export works on a machine without Godot, using matching export templates.
- Every shipped asset has a recorded source.
- At least five external testers complete the tutorial without coaching.

Release validation covers victory, retreat, party loss, recovery, save/load, corrupt-save recovery, repeated input, full inventory, low power, boss completion, broken resources, missing signals, invalid node paths, and editor-only assumptions. Supply a clean-machine Windows checklist, known issues, asset credits, and release notes. Do not add gameplay features during release validation.

Track combat length, skill usage, retreat frequency, extraction strain, and confusion with local logs and playtest notes; no online analytics service is needed.

## Deferred expansion and store preparation

Only after the demo passes: six classes, five available abilities each/four equipped; three ship sectors; fifteen regular enemy archetypes; three sector bosses and a final encounter; seeded authored-template layouts; three upgrade tiers and a larger roster; persistent traits and several breakdown behaviours; about twenty-four modules; a finite campaign objective chain; full controller support before claiming it; other platforms only after dedicated testing.

Expansion order: seeded generation retaining the authored tutorial → data validation and encounter-budget tools → extra crew abilities and traits → sectors and bosses → campaign progression and ending → controller support, balance, compatibility, release preparation. Test hundreds of map seeds for connectivity, reachable objectives, valid encounters, and guaranteed extraction access. Diseases, elaborate camping, corpses, and complex relationships remain outside the first commercial version unless playtests demonstrate a need.

Once gameplay and visuals are stable, prepare truthful screenshots/trailer, credits and asset-use records, an accurate content survey, store page, and build review. Recheck current Steam onboarding, Coming Soon lead time, release rules, and AI-content disclosure before submission or selecting a date. The user's plan cites a two-week Coming Soon requirement; it is not independently verified here. Distinguish player-facing AI-generated assets from coding assistance.

## Reference links supplied in the plan

These links are recorded as references, not claims of fresh research or hands-on playtesting. Browse relevant official documentation when implementation requires verification.

- [Godot release archive](https://godotengine.org/download/archive/)
- [Godot Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
- [Godot saving guide](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [Godot parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html)
- [Godot cutout animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html)
- [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Darkest Dungeon Steam overview](https://store.steampowered.com/app/262060/Darkest_Dungeon/)
- [Developer affliction breakdown](https://www.gamedeveloper.com/design/game-design-deep-dive-i-darkest-dungeon-s-i-affliction-system)
- [Original-game developer interview](https://www.gamedeveloper.com/audio/road-to-the-igf-red-hook-studios-i-darkest-dungeon-i-)
- [Animator portfolio](https://brx.artstation.com/projects/VAVxX)
- [Sequel announcement](https://blog.playstation.com/2024/04/18/darkest-dungeon-ii-rolls-onto-ps5-ps4-july-15/)
- [Expansion announcement](https://www.darkestdungeon.com/news/the-fire-s-edge-available-now-/)
- [Combat reference](https://darkestdungeon.wiki.gg/wiki/Dodge_%28Darkest_Dungeon%29)
- [OpenAI prompting guidance](https://learn.chatgpt.com/docs/prompting)
- [Steam Coming Soon](https://partner.steamgames.com/doc/store/coming_soon)
- [Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)
