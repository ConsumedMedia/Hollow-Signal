# Hollow Signal — Project Plan

## Specification and scope

The user supplied the full plan on 2026-08-27 and then authorized milestone 1. On 2026-08-28 the user reported "all is working" and requested milestone 2. Operational requirements are recorded in [SPECIFICATION.md](SPECIFICATION.md); the original user-supplied plan remains authoritative. Embedded example prompts are not authorization to start every milestone. Milestone 3 followed the GitHub upload. After the Close strike diagnostic, the user said "ok move on to the next milestone", authorizing milestone 4. Milestones 5–13 have not been requested.

## Required approach

- Use Godot 4.7.2 Standard, typed GDScript, the Compatibility renderer, and native Godot features.
- Preserve existing work and implement only the requested milestone, as the smallest complete increment.
- Keep authored content Resources separate from mutable runtime state.
- Keep combat rules independent from scenes, animation, and sound.
- Use original content; never use extracted Darkest Dungeon assets.
- Add no unrelated systems or dependencies.
- Explain changes in plain English for a beginner.

## Milestone workflow

1. Read the specification and confirm the requested milestone's scope.
2. Inspect relevant existing files and available tools before editing.
3. Implement the smallest complete increment within that scope.
4. Run available Godot import and automated checks; record exact commands and observed results.
5. Clearly identify checks that could not be run and anything not tested.
6. Give exact Godot playtest steps and expected results for the implemented milestone.
7. Update this plan and PROGRESS.md with completed milestones, verified checks, known issues, and next steps. File creation alone does not prove a milestone works.

## Current next steps

Repository: [ConsumedMedia/Hollow-Signal](https://github.com/ConsumedMedia/Hollow-Signal), connected and initially pushed on 2026-08-28. Local `main` tracks `origin/main`; preserve milestone history and exclude local engine/cache/artifact files from commits.

1. User performs README.md's milestone 4 opening and remaining ability/status checks in Godot 4.7.2 at both target sizes.
2. Fix reported problems before proceeding. The earlier Close strike observation was not reproduced; its tests remain, and the user authorized continuing without supplying a screenshot. Do not claim a confirmed fix for that report.
3. Begin milestone 5 (crew vulnerability and shared power) only when explicitly requested.

## Milestone 1 — Project setup

Status: complete; import, native automated checks, and rendered screenshot review passed. User reported "all is working" on 2026-08-28. The report did not enumerate individual manual checks. See PROGRESS.md for evidence and limitations.

Locate Godot or guide obtaining the pinned version. Create project, input actions, scalable window configuration, main menu, placeholder hub, and battle test scene. Set up Git if needed, ignore rules, and run instructions without overwriting history. Use only shapes and labels. Explain scenes, nodes, scripts, and signals through this project.

Acceptance: import without errors; New Game opens hub; battle test scene runs; UI usable at 1280×720 and 1920×1080.

Delivered: Godot 4.7.2 Standard portable editor in ignored `.tools/`; three native scenes using shapes and labels; shared typed navigation and drawing scripts; authored theme; explicit UI/fullscreen input; 1920×1080 proportional canvas with default 1280×720 window; native setup smoke checks; local Git and ignore rules; beginner README. No combat or persistent game state was added.

## Milestone 2 — One functioning battle

Status: implementation and verification complete; import, 51 rules checks, 82 headless integration checks, and 123 rendered integration checks passed at its checkpoint. User authorized proceeding to milestone 3; individual milestone 2 manual checks were not separately reported.

Minimal one-versus-one battle: actor definitions and separate instances, health, seeded randomness, Attack and Wait, legal-action validation, turns, victory/defeat. Rules independent of scene, emitting presentation events. Add a native GDScript test runner with unsuccessful exit on test failure.

Acceptance: battle can be won or lost; invalid commands do not mutate state; same seed and commands reproduce outcomes; two instances of one definition do not share health.

Delivered: two editable actor Resources and an explicit catalogue; separate runtime actors, combat state, commands, and events; rules without scene dependencies; Attack/Wait, seeded damage, fixed crew/enemy turns, terminal victory/defeat; a controller and immediate event presentation with health, action locks, and same-seed restart. Native tests include 64-seed replay comparisons, shared-definition isolation, invalid/stale commands, repeated input, and cancelling pending enemy actions. Fixed turn order is temporary for M2; initiative/ranks remain M3, and downed/permanent-death rules remain M5.

## Milestone 3 — Four-position combat

Status: implemented and verified locally at its checkpoint; user authorized milestone 4 after the Close strike diagnostic. Original checks and the additional button-click regressions are retained. No claim that every manual acceptance item was separately reported.

Four positions per side, actor/target rank requirements, Speed plus seeded 1–6 initiative, stable actor-ID tie-breaking, one action per actor per round. Adjacent Move consumes an action; Wait remains available; compact ranks after removal. Show active actor, rank numbers, legal targets, and disabled-skill reasons.

Acceptance: movement immediately changes legality; dead actors never act; moving never grants another turn; awkward formations cannot softlock combat.

Delivered: four actors per side, two generic rank-limited attack Resources per side, authored Speed, canonical seeded d6 initiative with ID ties, formation arrays independent of the round queue, adjacent Move, universal Wait, immediate removal/compaction, and target cards with visible disabled reasons. Extended existing native tests rather than adding a framework. Original shape presentation retained. No classes, statuses, power, or future systems added. This milestone's checkpoint is local; uploading further commits was not requested.

## Milestone 4 — Crew classes and enemy behaviour

Status: implemented and verified locally; final import and standalone battle start passed, with 149 rules checks, 360 headless integration checks and 539 rendered integration checks. Both intentional failure modes exit 1. User acceptance playtest pending; exact evidence and limitations are in PROGRESS.md.

Four classes and twelve specified class abilities. Minimal shared effects for damage, healing, strain reduction, protection, expose, forced movement, and one damage-over-time status. Editable ability Resources. Document status duration, stacking, rounding, and resolution order. Five enemy archetypes, using the same legality checks as players.

Acceptance: distinct class roles; documented status expiry; legal enemy decisions; healing limits reset between battles.

Delivered: four class Resources with twelve skills; five original enemy archetypes across two selectable patrols; ordered healing/strain/status/displacement effects after direct damage; Protected, Exposed and one DOT (Scorch); separate runtime status/use counters; common legality and deterministic enemy preferences; class-driven buttons, support targets, adjusted damage previews and status counters. Battle-local strain exists only to exercise the Medic and strain enemy. Persistent strain, Shaken, downed/death and power remain milestone 5. No new dependencies/assets or later systems.

## Milestone 5 — Crew vulnerability and shared power

Status: not started.

Implement specified downed/death rules, persistent strain, Shaken, shared power, and Overcharge. Prominent explanations; all thresholds and multipliers in balance data.

Acceptance: healing revives downed crew; subsequent damage can kill; no conscious crew causes defeat; Shaken applies at 100 and clears below 50; no overspending power; presentation settings cannot change outcomes.

## Milestone 6 — Ship exploration

Status: not started.

Connected authored eight-room graph, short side-scrolling corridors, combat/salvage/hazard/safe/boss-placeholder rooms and optional branch. Room-state tracking, traversal power, twelve-slot inventory, power cells, inspection choices. No procedural generation or platforming.

Acceptance: boss reachable; events resolve once; no backtracking reward duplication; clear overflow keep/discard decision; crew and expedition state persist across combat transitions.

## Milestone 7 — Persistent hub and complete game loop

Status: not started.

Eight starting crew, party selection and ordering, recruitment, recovery, supplies, six modules, one upgrade tier. Success, guaranteed retreat with half-salvage loss, and expedition defeat. Permanent deaths and persistent strain; free basic recruitment and full-health restoration safeguards.

Acceptance: prepare → deploy → complete/abandon → return → recover → change party → redeploy; rewards once; dead crew never reappear; campaign playable after party loss.

## Milestone 8 — Save and load

Status: not started.

Versioned validated JSON under user://, temporary writes and backup. Save roster, equipment, upgrades, expedition, room states, inventory, power, rewards, and required randomness. Battle-entry checkpoint policy; no animation progress or arbitrary node serialization.

Acceptance: reopen restores checkpoint; mid-battle loading restarts same encounter; deaths/rewards not duplicated; corrupt-save recovery; unsupported version not silently overwritten.

## Milestone 9 — One polished visual example

Status: not started.

One polished combat/corridor example, using approved assets or retaining placeholders. Layered 2D, Parallax2D, shadows, framing, scalable HUD. Reusable character scene with idle/walk/attack/support/hurt/downed/death. Event-driven anticipation, impact, reaction, sound hooks, return.

Acceptance: no visible parallax seams; fixed HUD; readable characters; animation skip and missing-animation fallback finish without combat lock.

## Milestone 10 — Art production preparation

Status: not started.

Asset checklist/specifications for crew, enemies, portraits, ability icons, modules, environments, effects: size, facing, pivot, transparency, poses, naming, on-screen scale. Prepare generation prompts from the approved guide, cleanup checklist, and provenance register. No generation or purchases without request.

Acceptance: validate one complete character set before multiplying it. If assets are unavailable, clearly distinguish preparation from uncompleted asset validation.

## Milestone 11 — Boss and narrative

Status: not started.

Signal Warden, single rank, alternates ordinary actions and a telegraphed charged attack on a marked party rank next turn. Repositioning counters the threat using existing rules/events. Short briefing, six logs, contextual barks, extraction ending; original text, no required voice acting.

Acceptance: warning shows timing and position; movement changes threatened actor; boss can be defeated; ending and rewards once.

## Milestone 12 — Sound, accessibility, and tutorial

Status: not started.

Music/ambience/UI/combat buses; supplied licensed audio or marked placeholders. Volume, text scaling, reduced motion, shake toggle, combat speed, keyboard navigation, persistent settings, labels/icons alongside important colours. Contextual formation/abilities/strain/power/retreat tutorial.

Acceptance: new player understands first fight; no clipping; settings persist; effects can be disabled without breaking functionality; audio overlap controlled.

## Milestone 13 — Demo validation and Windows export

Status: not started.

Run all automated tests; inspect resources, signals, node paths, editor-only assumptions. Test victory, retreat, party loss, recovery, saving/loading, corrupt saves, repeated input, full inventory, low power, boss completion. Windows preset/build with matching templates when available. Report blockers, clean-machine checklist, known issues, asset credits, release notes. No new gameplay features.

Acceptance: evidence for the full demo criteria in SPECIFICATION.md, including a Windows machine without Godot and at least five external tutorial testers. Unavailable external checks remain explicitly unverified.

## Session and debugging rules

At session start, read this plan, PROGRESS.md, Git status if a repository exists, and relevant code. Summarize working versus unverified behaviour and the next unfinished milestone; continue only with the requested milestone and do not rebuild completed systems.

For a reported bug, gather expected/actual behaviour, reproduction steps, Godot error/stack trace, and any screenshot or recording. Read the cause before editing, fix only that issue, preserve architecture, add a practical regression test, and rerun affected checks.

After each milestone, the user reads the summary, playtests in Godot, checks acceptance, fixes problems before another system, and saves a Git checkpoint. Expansion and Steam preparation are deferred until the demo passes.
