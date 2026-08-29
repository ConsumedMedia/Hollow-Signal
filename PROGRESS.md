# Hollow Signal — Progress

## Status — 2026-08-29

Milestone 7 is implemented locally and automatically verified. It adds the persistent in-memory hub and complete prepare/deploy/return loop without disk saving. User acceptance and a Git checkpoint are pending. Milestones 8–13 remain unauthorized.

### Milestone 7 — implementation and actual verification

Added `CampaignService` as the small application-level owner of one in-memory `CampaignState`. New Game creates eight distinct crew records (two per class), while authored actor/module/item Resources remain immutable. The hub supports four-person selection and rank ordering, free recruits and full health restoration, paid strain recovery and supplies, six collectible modules with one owner/equipment slot, and one campaign-wide health upgrade.

Expeditions now use the selected roster records. Boss extraction returns full cargo; room or player-turn combat retreat is guaranteed and returns half salvage/data with integer rounding down; defeat returns no cargo and permanently removes the deployed party from selection. Rewards clear with the active expedition and cannot apply twice. Free recruitment allows rebuilding after losing all four crew. Equipment modifiers are copied into runtime actors and resolved by `CombatRules`, not UI scripts. No disk saving, boss narrative, procedural content, audio or unrelated dependencies were added.

Commands actually ran from `C:\Users\CRS-Workstation\Game Dev` with `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-import-final-2.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-rules-final-3.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-smoke-final-3.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-render-final-3.log' -- --capture
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-negative-assert-3.log' -- --self-test-failure
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-negative-script-3.log' -- --self-test-script-error
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/main_menu.tscn --quit-after 5 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-start-main.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/hub.tscn --quit-after 5 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m7-start-hub.log'
git diff --check
```

Results: final import exit 0; **314 rules checks, 0 failures, 0 engine errors**; **527 headless scene checks, 0 failures**; **754 rendered Compatibility checks, 0 failures**; standalone main-menu and hub starts exit 0. Intentional assertion run: 315 checks / 1 intended failure / exit 1. Intentional in-memory script-error run: 314 checks / 0 assertion failures / 1 engine error / exit 1. Initial scene testing exposed a malformed generated hub script and a 10-pixel hub overflow; both were fixed before final runs. No broken script was retained.

Rendered checks used OpenGL 3.3, NVIDIA driver 591.86 and an RTX 3080. Visually reviewed the new hub at 1280×720 and 1920×1080: eight callsigns, party ranks, HP/strain, module effect, management controls, focus and navigation are visible without clipping. Automated GUI tests cover roster/module/deploy/retreat/return. Physical mouse/keyboard use, a full natural player-controlled successful expedition, tactical economy balance, app-restart persistence, export and other hardware remain untested. App-restart persistence is intentionally milestone 8.

### GitHub checkpoint and verified upload — 2026-08-28

Reviewed `git status --short --branch`, `git remote -v`, `git log -4 --oneline`, `git diff --stat`, `git diff --numstat` and `git ls-files --others --exclude-standard`. The intended submission includes the existing M5/M6 implementation, room Resource/focus fixes, regression tests and documentation. Remote is `https://github.com/ConsumedMedia/Hollow-Signal.git`; before submission both main references were at `f6ad903`. No gameplay was edited for this upload; the passing engine runs below remain the verification evidence.

`git check-ignore .tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe .godot/editor/project_metadata.cfg .artifacts/m6-room-fix-rules.log` returned all three paths, exit 0: engine binaries, generated cache and test artifacts are excluded. Authored `.uid` files were retained. Git reports an unreadable optional user-level ignore file; repository ignore rules still apply.

Executed upload checks:

- `git add -- COMBAT_RULES.md EXPLORATION_RULES.md PROGRESS.md PROJECT_PLAN.md README.md project.godot combat content exploration scenes scripts tests`: exit 0; 62 intended source/test/document files staged, no engine/cache/artifacts.
- `git diff --check` and `git diff --cached --check`: passed, no whitespace errors. Unstaged and untracked source listings were empty after staging.
- `git commit -m "Implement milestones 5 and 6 with verified ship exploration"`: exit 0, implementation checkpoint `b5074db`.
- `git push origin main`: exit 0, remote advanced `f6ad903..b5074db`.
- `git ls-remote origin refs/heads/main` and `git rev-parse HEAD`: both returned `b5074dbc595d72b0de7bb859c4e45ae9243a3ad8`, confirming the GitHub upload.
- `git status --short --branch`: clean `main...origin/main` after upload. This subsequent documentation-only update records that receipt; no gameplay changed and engine tests were not rerun for documentation edits.

### Room Resource parse error fix — current verification

Cause: receiving.tres, junction.tres, containment.tres and signal_core.tres declared the ActorDefinition external script after an embedded resource. Moved those four declarations before all embedded resources. The ship errors were cascading dependency failures; no room content or combat balance changed. The existing test runner now checks all eight room files before loading the catalogue and rejects a synthetic late-declaration regression.

Scene checks also found lost keyboard focus after natural corridor arrival. Arrival now focuses the first available room action. Existing scene assertions cover this at both target resolutions. No dependencies or assets were added.

The earlier approval-service block was resolved for these authorized runs. Commands below actually ran in PowerShell from `C:\Users\CRS-Workstation\Game Dev`, using Godot **4.7.2.stable.official.ed1daf0bf Standard**, Compatibility:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-import.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-rules.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-render.log' -- --capture
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-negative.log' -- --self-test-failure
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-negative-script.log' -- --self-test-script-error
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-smoke-final.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-render-final.log' -- --capture
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/expedition.tscn --quit-after 10 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-room-fix-start.log'
git diff --check
```

| Check | Observed result |
|---|---|
| Import | Exit 0; no project errors |
| Rules | 287 checks, 0 failures, engine errors 0, exit 0; includes full main-route simulation, M5 zero-damage regression and eight-room declaration preflight |
| Initial headless scenes | 517 checks, 2 failures, exit 1: corridor-arrival focus at both sizes; subsequently fixed |
| Initial rendered scenes | 744 checks, 6 failures, exit 1: same two focus failures plus four window/capture dimension assertions; dimension assertions passed on repeat without a layout change, cause unconfirmed |
| Negative assertion self-test | 288 checks, 1 intentional failure; exit 1 as required |
| Negative script self-test | 287 checks, 0 assertion failures, 1 intentional in-memory script error; exit 1 as required |
| Final headless scenes | 517 checks, 0 failures, no engine errors, exit 0 |
| Final rendered scenes | 744 checks, 0 failures, no engine errors, exit 0 |
| Direct expedition scene start | Exit 0; no loading errors; not a physical editor F6 test |
| Whitespace | `git diff --check` passed |

Rendering used this machine's NVIDIA RTX 3080 / OpenGL Compatibility. Reviewed airlock, hazard and overflow screenshots across the target sizes; visible text and controls fit. Overflow screenshots use a controlled fixture; complete-route rules simulation is separate evidence. Native GUI inputs are simulated, not physical desktop clicks. Manual controls, editor workflow, display/DPI readability, enjoyment/balance, other hardware and Windows export remain untested for M6.

**Exact error retest:** use the pinned 4.7.2 editor, press F8 to stop the old game, wait for its filesystem rescan, and clear old Output/Debugger messages. Press F5 → New Game → Explore Ship. Expected: airlock/map loads with 100 power and no Resource parse errors. Select Receiving and let the corridor finish: power is 95, Engage is available and keyboard-focused. Engage, win, then Return to room: wounds/strain/power persist and the room resolves once. Full acceptance steps remain in README; report any new error before proceeding.

The initial M5/M6 records below preserve what was and was not run at that time. Their pending/blocked wording is historical and superseded by the results above.

### GitHub upload completed before milestone 5

- `git add -- PROGRESS.md PROJECT_PLAN.md` and `git commit -m "Record milestone 4 playtest acceptance"`: exit 0, commit `f6ad903`.
- `git push origin main`: exit 0, remote main advanced `4224ee1..f6ad903`.
- `git ls-remote origin refs/heads/main`: exit 0, confirmed `f6ad9033154fedf66ba96a4defabbfb1b63d00a6`.
- Milestones 3–4 and acceptance notes are uploaded. Milestone 5 changes are uncommitted and not pushed; preserve them while implementing milestone 6.

### Historical milestone 5 implementation and verification

Implemented downed/revival/permanent death, all-crew-loss defeat, victory recovery to 1 HP, persistent CrewState/ExpeditionState records, Shaken hysteresis and modifiers, shared power, Overcharge, a next-battle test corridor and a labelled vulnerability drill. Balance thresholds are Resources; mutable state and combat rules remain independent of presentation. No dependencies or assets were added.

Commands ran in PowerShell from `C:\Users\CRS-Workstation\Game Dev`. The executable was `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`; `--version` returned `4.7.2.stable.official.ed1daf0bf`. All log paths below are under `C:/Users/CRS-Workstation/Game Dev/.artifacts/`.

| Arguments after the executable | Observed result |
|---|---|
| `--headless --path . --import --log-file .../m5-import.log` | Latest import exit 0, no reported project errors. |
| `--headless --path . --script res://tests/run_tests.gd --log-file .../m5-rules.log` | Last executed run: 233 checks, 0 failures, 0 engine errors, exit 0. A subsequently added zero-damage test has not run. |
| `--headless --path . --script res://tests/setup_smoke.gd --log-file .../m5-smoke.log` | Original 360-check suite passed. Expanded run had 460 checks, 2 failures from a duplicate-next-battle UI bug; fixed afterward and verified in rendered run. Final headless rerun not executed. |
| `--path . --script res://tests/setup_smoke.gd --log-file .../m5-render.log -- --capture` | 662 checks, 0 failures, exit 0, NVIDIA OpenGL Compatibility. 67 screenshots saved; reviewed downed targets, charged preview, combined statuses and defeat at target sizes. |
| `--headless --path . --script res://.artifacts/m5_find_seed.gd` | Exit 0; seed 20 makes the Medic first in the downed-C1 drill. This ignored helper was only used to choose test data. |

Intermediate failures were addressed: the old DOT-source-death test now applies a second hit because the first downs crew; a new fixture needed typed-array assignment; skipping a downed slot also advances the stale-input token. A duplicate Next battle signal changed the view token after the next battle began, preventing subsequent input. The screen now checks victory before changing that token; the 662-check rendered run includes the regression.

After the rendered run, the UI gained explicit Overcharge ON/OFF text, terminal help was clarified, and the suite gained a natural drill-opening check plus a zero-damage check. Latest import passed, but final rules/headless reruns and both intentional failure modes were denied BEFORE execution by the approval service (usage-limit error). No new negative-check result, final rendered result or local commit is claimed. Do not bypass that rejection; resume checks only with the required authorization/service availability. Physical editor/mouse/DPI and balance playtests are still unreported. No Windows export was tested.

### Historical milestone 6 implementation — initial verification gap

Added the authored connected eight-room graph (three combat rooms, salvage, hazard, safe room, entry and single-rank boss placeholder), short horizontal corridor presentation with a skip path, room visited/resolved records, inventory with twelve slots and stacking, power cells, inspection choices and explicit overflow confirmation.

The exploration scene owns one ExpeditionState and embeds the existing battle scene with that same state. Combat test/reset controls are hidden in expedition mode. Return to room is terminal-only, preserves wounds/strain/Shaken/deaths/power, and awards room loot once. Battle records snapshot the encounter room so stale results cannot resolve another room. No campaign hub, recruitment, retreat payout, equipment, disk saves, procedural generation, platforming, final boss mechanics, narrative or audio was added.

The existing rules and smoke suites were extended for connectivity, optional-branch independence, full main-route simulation, repeated travel/arrival, stale battle results, cells, overflow, hazard/rest choices, corridor skip/natural completion and embedded combat at both target resolutions. **These M6 tests have not executed.** The smoke suite watchdog is now 120 seconds to allow the additional scene scenarios; this is not a tool sleep.

#### Actual M6 checks

- Read-only PowerShell scan of `content`, `scenes`, `ui`: **154 referenced resource paths exist**, all declared `load_steps` equal external/subresource counts plus one, and **4 scene node-parent trees** have no missing parent or duplicate path. Exit **0**.
- `git diff --check`: exit **0**.
- `git status --short --branch`: local main still tracks remote main at `f6ad903`; M5/M6 changes are uncommitted, including new content, runtime, scene and documentation files.
- No M6 Godot import, automated GDScript execution, graphical run, screenshot or manual playtest was performed. The preceding engine approval rejection was not bypassed or retried. The successful M5 counts above are historical and do NOT validate the current M6 checkout.

The read-only static scan executed was:

```powershell
$projectRoot = (Get-Location).Path
$sourceFiles = Get-ChildItem content,scenes,ui -Recurse -File | Where-Object { $_.Extension -in '.tres','.tscn' }
$issues = @()
$referenceCount = 0
$sceneCount = 0
foreach ($sourceFile in $sourceFiles) {
  $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName)
  foreach ($reference in [regex]::Matches($sourceText, 'path="res://([^"]+)"')) {
    $referenceCount++
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $reference.Groups[1].Value))) { $issues += $sourceFile.Name + ': missing ' + $reference.Groups[1].Value }
  }
  $steps = [regex]::Match($sourceText, 'load_steps=(\d+)')
  $expected = 1 + [regex]::Matches($sourceText, '\[(?:ext_resource|sub_resource) ').Count
  if ($steps.Success -and [int]$steps.Groups[1].Value -ne $expected) { $issues += $sourceFile.Name + ': load_steps mismatch' }
  if ($sourceFile.Extension -eq '.tscn') {
    $sceneCount++
    $nodePaths = @('.')
    foreach ($node in [regex]::Matches($sourceText, '\[node name="([^"]+)"[^\]]*\]')) {
      $parent = [regex]::Match($node.Value, 'parent="([^"]+)"')
      if (-not $parent.Success) { continue }
      $parentPath = $parent.Groups[1].Value
      if ($parentPath -notin $nodePaths) { $issues += $sourceFile.Name + ': missing parent ' + $parentPath }
      $nodePath = if ($parentPath -eq '.') { $node.Groups[1].Value } else { $parentPath + '/' + $node.Groups[1].Value }
      if ($nodePath -in $nodePaths) { $issues += $sourceFile.Name + ': duplicate node ' + $nodePath }
      $nodePaths += $nodePath
    }
  }
}
if ($issues.Count -gt 0) { $issues; exit 1 }
Write-Output "STATIC PASS: $referenceCount resource paths; load_steps counts; $sceneCount scene node-parent trees. This does not compile GDScript or import Godot Resources."
git diff --check
```

#### Commands pending at initial implementation (superseded above)

Run from the workspace after the required engine-run authorization/service is available:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-import.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-rules.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m6-render.log' -- --capture
```

Then run both negative runner self-tests documented in README, inspect actual screenshots, fix failures and repeat affected checks. No passing count is predicted. Exact manual steps and expected results are in README's milestone 6 section; they are expectations, not observations. Graphical readability, scene integration, compilation, content import and complete-route balance all remain unverified. Preserve the uncommitted work; create a checkpoint only after verification.

## Historical milestone 4 status — 2026-08-28

Milestone 4 is implemented after the user authorized the next milestone following the Close strike diagnostic. The battle now has Breacher, Technician, Ranger and Medic skills, five enemy archetypes across two patrols, healing/use limits, battle-local strain, protection, Exposed, Scorch and forced movement. Final import, native rules/integration/rendering checks passed. On 2026-08-28 the user reported that everything seemed to work: general playtest acceptance, without enumerating individual manual checks.

Milestone 4 began at local commit `73c4eee`, with four uncommitted files from the earlier diagnostic (README, plan, progress and the smoke test). Preserved that work, history, navigation, original shapes, engine, native test runner and authored/runtime separation. No dependencies or assets were installed. Godot remains **4.7.2 Standard / Compatibility**, project version `0.4.0-milestone-4`. No milestone 5 or later systems were started.

## Completed milestones

- Milestone 1: complete; user reported success on 2026-08-28. This is general user acceptance, not a claim that every individual manual step was reported separately.
- Milestone 2: implementation and automated/rendered verification complete; user authorized moving to milestone 3, without separately reporting every manual check.
- Milestone 3: implementation and automated/rendered verification complete; user authorized proceeding to milestone 4 after the diagnostic. The earlier reported symptom was not reproduced or confirmed fixed.
- Milestone 4: implementation and automated/rendered verification complete; user reported general playtest success on 2026-08-28.
- Milestone 5: implemented locally; current combined rules/headless/rendered suites pass. User requested milestone 6 without reporting an M5 playtest; acceptance remains unreported.
- Milestone 6: implementation and automated verification complete; user reported general playtest success after the room parse/focus fixes and requested GitHub submission. Individual acceptance checks were not separately enumerated.
- Milestone 7: implemented locally; automated and rendered verification complete. User acceptance and checkpoint pending.
- Milestones 8–13: not started or authorized.

## Milestone 4 — Actual verification

### Implemented scope

- Four authored classes, exactly three skills each, plus universal Move/Wait. Five enemy archetypes across Boarding and Signal patrols. Only four enemies occupy a battle.
- Ordered effects after direct damage: healing, strain change, status and forced movement. Protected mitigates direct damage; Exposed enables the Ranger bonus; Scorch is the only DOT. Duration, stacking, rounding and resolution order are specified in COMBAT_RULES.md.
- ActorState owns independent health, strain, use counts and StatusState objects. Resources hold values and descriptions only. Healing uses reset on fresh battle/restart/switch, and separate Medics do not share them.
- Strain is battle-local to exercise the required Medic/strain enemy skills; persistence, Shaken, downed/death and power remain M5.
- EnemyPolicy scores only shared legal commands. AI preference bonuses live in balance data. Forced movement preserves the round queue; lethal DOT is resolved before input and skips the removed actor.
- Class-driven UI exposes the acting class, three skills, support targets, use counts, visible disabled reasons, modified target HP-loss ranges, strain/status counters and two patrols. Original shapes and native UI retained; no asset/dependency purchases, downloads or generation.
- Prior diagnostic work was preserved. M3 fixtures and button-click regressions remain in the existing suites, alongside the new class tests. No test framework or extra test file was added.

### Commands and results

All commands below ran from `C:\Users\CRS-Workstation\Game Dev` in PowerShell, using the existing explicit 4.7.2 executable. Available Git, rg, shell, patching and native image inspection tools were used; no sub-agents or external apps were needed for M4.

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-import.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-rules.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-render.log' -- --capture
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/battle_test.tscn --quit-after 10 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-start-battle.log'
```

Final results:

| Check | Observed result |
|---|---|
| Import | Exit 0; no project errors |
| Rules | 149 checks, 0 failures; engine errors 0; exit 0 |
| Headless integration | 360 checks, 0 failures; exit 0 |
| Rendered integration | 539 checks, 0 failures; exit 0 |
| Independent battle scene start | Exit 0; no project errors (not a physical F6 check) |

Rendering used OpenGL 3.3 / NVIDIA 591.86 / RTX 3080 / Compatibility. Integration checks the pinned version and Standard (not Mono). The renderer run produces 59 viewport PNGs: retained setup/M3 states plus all twelve class skill selections, both patrols, maximum status display and class-battle outcomes at both target sizes. Reviewed class battle, Medic heal, Expose, all-status display, Signal patrol and victory screenshots across the two sizes; text, buttons and target labels fit. Skill/status screenshot fixtures explicitly set health/strain/active turns to cover the UI; natural full battles and the README opening do not use those overrides.

Rules coverage includes 64 original seed cases and 64 class-patrol cases (32 seeds per patrol, each replayed), plus targeted support/status/movement tests. Every automated enemy decision is checked for legality. Both patrols reach victory using the documented deterministic test policy (Boarding round 7, Signal round 8, both turn token 45), and defeat when all crew Wait. These outcomes demonstrate functionality, not final balance or user acceptance.

The exact four-action README opening is also exercised through GUI clicks and natural turns: Ranger Covering shot at E4 → Technician Cutting beam at E1 → Breacher Brace on Medic → Medic Field patch on injured Ranger. All four expected actors and effects passed.

Intentional failure checks:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-negative-assert.log' -- --self-test-failure
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-negative-script.log' -- --self-test-script-error
```

Expected exit **1** confirmed for both: 150 checks / 1 intentional assertion failure; and 149 checks / 0 assertion failures / 1 intentionally injected in-memory parse error. No broken project script was written.

After correcting the simulated mouse helper, repeated the rendered suite without screenshot pauses:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-render-repeat.log'
```

Result: **362 checks, 0 failures, exit 0**, in addition to the final 539-check capture run and 360-check headless run. Clean-log searches across final import, rules, headless, rendered, repeat and standalone-start logs found no ERROR/WARNING/SCRIPT ERROR/FAIL lines (rg exit 1 means no matches). Intentional negative logs were excluded from that clean-log search. `git diff --check` and staged whitespace review passed; engine, cache, logs and screenshots were not staged.

### Intermediate findings and limitations

- Initial M4 import exited 1 without a project error in its output (`m4-import-initial.log`); final import passed. Cause remains unconfirmed, as noted for earlier intermittent imports.
- First extended rules run caught deliberately invalid test fixtures sharing nested Effect/Status Resources through arrays. Fixed the test to duplicate those nested Resources explicitly before corrupting them. No authored files were corrupted. Final suite passes and includes independent runtime health/strain/use/status checks.
- First layout run detected an 8-pixel width overflow from expanded actor cards. Reduced local card padding while retaining font size; reruns and rendered review pass.
- Review added correct source attribution to DOT death events after the originating actor has died, with a regression.
- A later rendered run caught 7 missed-click assertions; a temporary diagnostic run (`--path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m4-click-diagnostic.log' -- --diagnose-clicks`, same pinned executable) caught 8. Diagnostics showed synthetic hover becoming false between mouse down/up while the button rectangle stayed fixed and the real viewport mouse position was elsewhere. Updated the test helper to deliver motion/down/up together, with the correct button mask, before yielding frames. This retains native GUI hit testing and signals while avoiding desktop-pointer polling between synthetic gesture events. Removed the temporary diagnostics. This is a test-input correction, not a claimed fix for the user's earlier physical Close strike observation.
- Physical mouse/keyboard/editor F5/F6/F8 and actual display/DPI readability remain user checks. No desktop automation or real editor gameplay was claimed for M4. The previously observed 4.7.1 editor is not the verified engine; use README's 4.7.2 launch path.
- No export, other hardware, persistence, downed/death, Shaken, power, sound or future milestone work was tested. No claims of tactical enjoyment or final balancing.
- Git diff/whitespace review includes the intended earlier diagnostic changes. Generated engine/cache/log/screenshot files remain ignored. The local checkpoint is titled `Implement milestone 4 class abilities and shared combat effects`; use `git log` for its hash. No GitHub push is authorized by this milestone request.


## Close strike report — 2026-08-28

User reports Close strike cannot be clicked even with crew at the front. Started from clean local milestone 3 commit `73c4eee` (`main` one commit ahead of `origin/main`). Read the Resources, rules, controller, UI connections and existing tests before editing. **Failure not reproduced; report remains open pending the user's diagnostic/screenshot. No gameplay or Resource changes made.**

Subsequent update: the user authorized the next milestone without a screenshot or explicit reproduction result. M4 retains the button regressions with M3 fixtures and makes the acting class explicit. This is not evidence of a confirmed fix to the original report.

Added mouse-input coverage to the existing `tests/setup_smoke.gd`, plus a short README diagnostic. Existing tests had exercised targets and direct selection calls, but not the complete Close strike button hit-test/selection path. New checks click disabled Strike, Wait, Move, Strike, and TARGET cards at both 1280x720 and 1920x1080; they also verify the next turn after moving forward. Buttons correctly follow the acting actor, not the location of other crew. Default C3 rank 3 can only shoot; one Wait reaches C1 rank 1 and enables Strike. Selecting Strike alone does not spend the action; clicking an enemy TARGET resolves damage.

An initial new test run failed two assertions because it expected moved C3 to remain at rank 2. Observed C1 had been defeated while waiting for C3's next turn, compacting C3 to rank 1. Corrected that test expectation to allow either front rank; no production code changed. Final runs pass.

### Actual commands and results

PowerShell, project directory:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/strike-diagnosis-baseline.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/strike-click-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/strike-import.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/strike-render.log' -- --capture
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/strike-rules.log'
```

- Unmodified baseline: 107 checks, 0 failures, exit 0.
- Extended headless integration: 137 checks, 0 failures, exit 0 (final rerun).
- Import: exit 0, no project errors.
- Rendered integration: 202 checks, 0 failures, exit 0; Compatibility on the RTX 3080. Reviewed the new `battle_strike_selected` PNG at both sizes: C1 rank 1, Strike selected, Shot disabled, only enemy ranks 1/2 targetable, text/buttons unclipped.
- Rules: 78 checks, 0 failures, no engine errors, exit 0.

Computer-use inspection found the user's open editor is **Godot 4.7.1**, opening this same project folder. This version difference is observed, not established as the cause. An attempted editor F5 interaction was interrupted by detected user input; a subsequent observation failed to identify the foreground process. Physical editor/gameplay reproduction was not completed. The verified clicks above are native Godot simulated GUI input, not physical desktop clicks. Do not claim the user's issue is fixed or that 4.7.1 is verified. Restart/Wait/Strike/TARGET steps and the pinned editor launch command are in README.md. Test/document edits remain local and uncommitted pending clarification; nothing was pushed.

## Milestone 3 — Actual verification

All commands ran from `C:\Users\CRS-Workstation\Game Dev` in PowerShell. Read the project plan, progress, rules, scene/controller, Resources, and existing tests before changing them. Git showed a clean `main...origin/main` at `4224ee1`. No applicable AGENTS.md was found; the already-located engine was invoked by explicit path, not assumed from PATH. Available shell, file editing, image inspection, and official Godot documentation were used. No external plugin or sub-agent was used.

### Implementation choices

- `AbilityDefinition` Resources hold damage and usable/target ranks. Actor definitions now reference abilities and hold Speed; current health remains in `ActorState`.
- The test contains four instances of the same crew definition and four of the same enemy definition. They have two generic attacks, not class kits: Close strike from ranks 1–2 against ranks 1–2; Covering shot from ranks 3–4 against any enemy rank.
- Rank arrays and the round queue contain stable IDs. Initiative draws occur in canonical ID order, then sort by Speed + d6 descending with ascending ID ties. Swaps do not reorder turns.
- Move costs the actor's action, leaves the ally's turn intact, and updates rank requirements immediately. Wait remains usable even without any legal attack.
- Removed actors leave no corpse. Survivors close ranks; queue advancement skips removed IDs. Downed/revival/permanent-death rules remain milestone 5.
- UI shows the acting ID/rank, remaining initiative, current HP, TARGET/SWAP labels, and visible reasons for disabled skills. Repeated-input guards also cover consecutive crew turns; restart invalidates deferred callbacks and cancels the old enemy Timer.

### Commands and final results

Engine version:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
```

Exit **0**: `4.7.2.stable.official.ed1daf0bf`. Native integration also confirms Standard (no Mono) and Compatibility.

Import and independent battle start:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-import.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/battle_test.tscn --quit-after 10 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-start-battle.log'
```

Both exit **0**, no project errors. Direct scene startup is not a physical editor F6 check.

Rules and scene integration:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-rules.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-render.log' -- --capture
```

- Rules: **78 checks, 0 failures, engine errors 0; exit 0**.
- Headless integration: **107 checks, 0 failures; exit 0**.
- Rendered integration: **166 checks, 0 failures; exit 0**. OpenGL 3.3, NVIDIA 591.86, GeForce RTX 3080, Compatibility.

Rules checks include 64-seed full replay equality, exact canonical initiative rolls/ties, one action per round, shared-definition isolation, no mutation on invalid/stale commands, actor/target rank restrictions, adjacent swaps, no extra or stolen turns, removal before a queued turn, compaction, terminal empty formations, and Wait-only progression for stranded rear-only actors. Four rounds of repeated swaps retain exactly one turn per actor. Move/Wait do not roll damage; initiative is rolled only at round boundaries.

Integration checks exercise the actual scene's action selection/target cards (including simulated GUI mouse input), disabled reasons, both sides' visible ranks, swaps across ranks 2/3, partial enemy removal, full victory/defeat, duplicate signals, initial focus, restart during resolution/enemy delay, safe navigation, and the earlier setup checks.

Negative runner checks:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-negative-assert.log' -- --self-test-failure
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m3-negative-script.log' -- --self-test-script-error
```

Expected failures confirmed: **79 checks, 1 intentional assertion failure, exit 1**; and **78 checks, 0 assertion failures, 1 intentional in-memory parse error, exit 1**. No broken script file was written.

### Visual review and observed outcomes

The final renderer run produced **19 viewport PNGs**: three screens at 1280×720, 1920×1080, and 1280×900; Move selection, swapped formation, partial enemy compaction, victory, and defeat at both acceptance sizes. The taller-window captures exclude the Window's letterbox bars, as documented in milestone 1.

Reviewed initial battle, Move selection, swapped ranks, partial removal, and terminal screenshots across the target resolutions, plus the changed hub at 720p. Rank/ID/HP labels, active actor, targets, disabled reasons, navigation, and results are readable and unclipped in the inspected captures. Initial review prompted a local disabled-button style with clearer health text and stable card dimensions, and initial keyboard focus was moved to the usable attack. Final automated checks were rerun after those changes.

Default seed 1729 starts **C3:11, C1:9, C2:9, E1:9, C4:7, E4:6, E2:4, E3:4**. Always attacking enemy rank 1 wins in **round 4 after 19 total actions**, with C1 at 2 HP and the other crew at 30. Waiting on every crew turn loses in **round 7 after 45 total actions**. E1's first removal visibly puts E2 at rank 1 and leaves rank 4 empty.

Earlier passing runs had 77 rules, 101 headless, and 154 rendered checks before the final Wait, initial-focus, and partial-compaction coverage was added. No failed product assertions or script errors were observed in this milestone's normal runs. Intentional failure logs are excluded from clean-log checks.

### Review, limitations, and checkpoint

`git diff --check` passed. The first `git diff --cached --check` caught one extra blank line at the end of each new ability Resource; those were removed, and the staged check then passed. Scanning final import, rules, smoke, render, and startup logs with `rg -n 'ERROR|WARNING|SCRIPT ERROR|FAIL:'` returned no matches (exit 1 means none). The existing native test files were extended; no new testing dependency was added. README.md and COMBAT_RULES.md now describe the current rules and exact playtests.

The milestone checkpoint is local. A further GitHub push was not requested in this turn; the last verified upload was milestone 2 and its repository documentation. No export/build, manual physical input, other hardware, or external player testing is claimed. The tests deliberately use valid queue fixtures for isolated rule cases; full replay and integration tests use actual seeded queues.

## GitHub upload — 2026-08-28

User supplied and authorized upload to `https://github.com/ConsumedMedia/Hollow-Signal.git`. The repository was empty (`ls-remote --symref` exited 0 with no refs); no remote history was overwritten. Local `main` was clean at milestone 2 commit `65091eb`. Inspected tracked files and all history object paths: only project source, documents, and ignore markers are included, not engine binaries, caches, logs, screenshots, or exports. A filename-only scan for common private-key/token patterns found no matches in HEAD; this is a limited check, not a comprehensive security audit.

Git's initial HTTPS check failed with OpenSSL `unable to get local issuer certificate (20)`. Retrying with Windows Schannel and TLS verification enabled succeeded. No certificate verification was disabled, no global configuration was changed, and no credentials were printed or stored in project files.

Actual successful setup/upload commands, run from the project folder:

```powershell
git -c http.sslBackend=schannel -c http.sslVerify=true -c credential.interactive=false ls-remote --symref 'https://github.com/ConsumedMedia/Hollow-Signal.git'
git remote add origin 'https://github.com/ConsumedMedia/Hollow-Signal.git'
git config --local http.sslBackend schannel
git config --local http.sslVerify true
$env:GIT_TERMINAL_PROMPT = '0'
git -c credential.interactive=false push -u origin main
git rev-parse HEAD
git -c credential.interactive=false ls-remote origin refs/heads/main
git status --short --branch
```

All succeeded (exit 0). Push created remote `main` and set its upstream. Local HEAD and GitHub's main ref both returned **65091eb8956c78d2bc3b5f5b57467c2f7a209adf**; status was `## main...origin/main` with no changes. This confirms the source and all three existing milestone commits reached GitHub. The following documentation commit records this upload and updates the README and project plan.

No game code changed during upload, so Godot checks were not rerun; milestone 2 results below still apply. No release executable, GitHub Actions workflow, or repository visibility/settings changes were requested or made. Next step remains the milestone 2 user playtest.

## Milestone 2 — Actual verification

Commands ran from `C:\Users\CRS-Workstation\Game Dev` in PowerShell. Godot/Git checks ran with permission as the normal Windows user. No additional engine, plugin, test framework, or dependency was installed.

### Inspection and pinned engine

Read the specification, project plan, progress, existing scenes/scripts, and Git status/diff before editing. No applicable AGENTS.md was present. Inspected available shell/file/image tools; used the known portable engine by its explicit path, not PATH. Existing commits `878c298` and `c8eab36` were retained.

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
```

Result: exit 0, `4.7.2.stable.official.ed1daf0bf`. Integration checks also confirm Standard (no Mono) and Compatibility.

### Import and independent battle start

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-import-final.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene res://scenes/battle_test.tscn --quit-after 5 --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-start-battle.log'
```

Both exited **0** without project errors. The direct launch is a startup check, not an editor F6 test. The first import attempt (`m2-import.log`) exited 1 without a printed error; it was not counted as a pass. After the typing fixes below, the final import passed.

### Rules without scenes

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-rules.log'
```

Result: **51 checks, 0 failures; engine errors 0; exit 0**. Coverage includes shared-definition health isolation, unchanged authored Resources, invalid definitions, Attack/Wait rules, turn progression, event snapshots/order, malformed/wrong-turn/dead-target commands, missing state/RNG, stale commands across rounds, overkill clamping, terminal outcomes, and complete replay equality over 64 seeds. Every tested seed supports victory by attacking and defeat by waiting. Rules tests load no scene, animation, timer, or sound.

### Test runner must fail on failures

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-negative-assert.log' -- --self-test-failure
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-negative-script.log' -- --self-test-script-error
```

Results: assertion injection **52 checks, 1 intentional failure; engine errors 0; exit 1**. Script injection **51 checks, 0 assertion failures; 1 intentional parse error; exit 1**. The latter reloads a deliberately malformed in-memory script; no malformed file remains. Both failures are expected evidence, not outstanding product defects.

### Scene integration and rendering

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-smoke.log'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/m2-render.log' -- --capture
```

Headless: **82 checks, 0 failures; exit 0**. Graphical: **123 checks, 0 failures; exit 0**, using OpenGL 3.3, NVIDIA driver 591.86, NVIDIA GeForce RTX 3080, Compatibility. These totals include the earlier navigation/layout checks plus playable victory/defeat, displayed damage events, action locks, repeated same-frame submissions, restart after outcomes, restarting during a pending enemy response, deterministic first-hit replay, and leaving during a pending response. No engine errors were reported.

The rendered run saved 13 PNGs: each screen at 1280×720, 1920×1080, and 1280×900, plus victory and defeat at both target resolutions. Visually inspected all three battle states (initial/victory/defeat) at 720p and 1080p, and the updated menu/hub at 720p. Text, controls, shapes, health, and outcomes fit. At default seed 1729, captured victory is round 3 with crew 20/30 HP; captured defeat is round 6 with crew 0/30 HP and enemy 20/20 HP.

These are actual native-renderer viewport captures, not mockups. Godot input was simulated internally; physical Windows battle input and editor workflow remain user checks. The 1280×900 capture contains the 1280×720 game content, excluding the Window's letterbox bars.

### Failures found and fixed during development

- An initial `ActorState.Side` enum collided with Godot's built-in `Side` type. Renamed it to `Team` and reran compilation/tests.
- The early rules runner invoked the suite directly and could print an apparent pass/exit 0 despite script errors aborting test functions. Replaced it with `run_tests.gd`, which installs a native engine-error monitor before loading the suite. Both deliberate assertion and parse-error tests now exit 1. The early false-success output is not counted as verification.
- The first scene run failed with a typed-array mismatch in a conditional expression constructing targets (82 checks, 10 failures, exit 1). Replaced that expression with an explicitly typed array and append; reran headless and graphical checks successfully.

### Review and checkpoint

Reviewed the rules, runtime records, controller, presentation, scene connections, and tests. `git diff --check` returned 0. Clean final import/rules/integration/render logs had no `ERROR`, `WARNING`, `SCRIPT ERROR`, or `FAIL:` matches. The intentionally failing logs were excluded. The implementation checkpoint is recorded in Git; no remote/push is involved.

Current contracts and temporary M2 choices are documented in COMBAT_RULES.md. README.md contains exact commands and beginner playtest steps. Earlier milestone 1 results below remain a historical record; their pending-playtest wording predates the user's acceptance above.

## Milestone 1 — Actual verification

All commands below ran from `C:\Users\CRS-Workstation\Game Dev` in PowerShell. Shell Godot checks needed permission to use the engine's normal AppData directories. No certificate checks or security settings were disabled.

### Pinned engine

The official archive and GitHub release pages were checked. Archive download attempts with curl failed with `SEC_E_NO_CREDENTIALS`, then `CRYPT_E_NO_REVOCATION_CHECK`; PowerShell's archive retry failed with a closed transport connection. The official GitHub mirror succeeded:

```powershell
Invoke-WebRequest -Uri 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip' -OutFile '.tools\Godot_v4.7.2-stable_win64.exe.zip' -UseBasicParsing
Expand-Archive -LiteralPath '.tools\Godot_v4.7.2-stable_win64.exe.zip' -DestinationPath '.tools\godot-4.7.2'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
```

Results: download/extraction exit 0; archive 86,013,866 bytes. Version exit 0, `4.7.2.stable.official.ed1daf0bf`. Native test also confirms no Mono/.NET feature. No PATH or older-engine changes. The portable engine is intentionally excluded from Git.

### Import

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/import.log'
```

Final result: exit **0**, completed scan/editor loading, no ERROR or WARNING entries. Earlier sandboxed import returned 0 despite AppData/certificate-access errors and was not counted as a pass. The first unrestricted retry returned 1 without a printed project error; a verbose retry and the final normal retry both returned 0. No project-code change was needed between those retries. Monitor for recurrence rather than assuming the unexplained initial exit was a code failure.

### Native setup smoke checks

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/setup-smoke.log'
```

Result: **55 checks, 0 failures; exit 0**. Checks cover engine/configuration, input actions, loading every screen, layout bounds and text minimum sizes at 1280×720, 1920×1080, and 1280×900, initial focus, all navigation-button destinations, repeated same-frame requests, Escape, Enter, Tab, Shift+Tab, arrows, and simulated mouse input through Godot's GUI. These simulate input inside Godot; they do not prove physical Windows input or editor F6 handling.

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/setup-negative.log' -- --self-test-failure
```

Result: **56 checks, 1 intentional failure; exit 1**. This proves the runner reports failures to the calling process. It is not a product defect.

### Actual rendering and screenshot review

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd --log-file 'C:/Users/CRS-Workstation/Game Dev/.artifacts/setup-render.log' -- --capture
```

Result: **84 checks, 0 failures; exit 0**. Godot reported OpenGL 3.3.0, NVIDIA driver 591.86, Compatibility renderer, NVIDIA GeForce RTX 3080. The same integration checks ran with real rendering, plus window/content dimensions, nine saved viewport images, and F11 fullscreen/windowed transitions.

Inspected `main_menu`, `hub`, and `battle_test` PNGs at both 1280×720 and 1920×1080: headings, buttons, labels, focus outlines, and placeholder shapes are visible and unclipped. Screenshots are local in `.artifacts/`, not committed.

An earlier capture run reported three failures because the test incorrectly expected 1280×900 viewport images from a letterboxed window. Godot's viewport image excludes the Window's black bars. Corrected the test to check the requested window separately from the expected 1280×720 content. Rerun passed; game scaling code did not need changing. Physical black-bar presentation remains a user check.

Windows computer-use inspection did not complete: app approval timed out. No physical mouse/keyboard or editor UI success is claimed. A separate 1280×720 game window was launched successfully; its log reports Compatibility without project errors.

### Independent scene starts

Ran this loop, with each scene exiting 0 and no project errors:

```powershell
$sceneChecks = @('main_menu', 'hub', 'battle_test')
$failedScenes = 0
foreach ($sceneName in $sceneChecks) {
    & '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --scene "res://scenes/$sceneName.tscn" --quit-after 5 --log-file "C:/Users/CRS-Workstation/Game Dev/.artifacts/start-$sceneName.log"
    $sceneExitCode = $LASTEXITCODE
    [pscustomobject]@{Scene=$sceneName; ExitCode=$sceneExitCode}
    if ($sceneExitCode -ne 0) { $failedScenes += 1 }
}
if ($failedScenes -gt 0) { exit 1 }
```

### Git

`git rev-parse --show-toplevel` confirmed no existing repository before `git init -b main` created a local repository (exit 0). The rules keep `.gdignore` marker files versioned while ignoring engine binaries, caches, and test outputs, so a fresh clone preserves import exclusions. No remote or push.

The sandbox-created `.git` directory initially had a different Windows owner, causing normal-user Git commands to reject it. With permission, changed only that new directory's owner to the user's account; did not change permissions or add global `safe.directory` exceptions. Normal-user Git then worked.

Final commands and results:

```powershell
git check-ignore .godot/ .tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe .artifacts/setup-render.log
git add -- .gitattributes .gitignore .tools/.gdignore .artifacts/.gdignore README.md PROJECT_PLAN.md PROGRESS.md SPECIFICATION.md project.godot scenes scripts tests ui
git diff --cached --check
git diff --cached --stat
```

Results: exit 0; three generated paths correctly ignored; 19 source/document/marker files staged; no whitespace errors. `rg -n 'ERROR|WARNING|SCRIPT ERROR|FAIL:'` across the final import, headless smoke, rendered smoke, and three startup logs found no matches (rg exit 1 means no matches). The intentional negative-test log was correctly excluded from that clean-log check.

Created local implementation checkpoint **878c298 — Set up Hollow Signal milestone 1** with `git commit -m 'Set up Hollow Signal milestone 1'`. `git log -1 --format='%h %s'` confirmed it; `git status --short` was empty. A following documentation-only commit records this checkpoint. User acceptance playtesting is still pending; the checkpoint does not claim those checks passed.

## Historical intake checks (before implementation)

Commands ran in PowerShell from `C:\Users\CRS-Workstation\Game Dev`.

### Workspace inspection

```powershell
Get-Location; rg --files --hidden -g '!\.git/**' -g '!\.godot/**' -g '!node_modules/**' -g '!\.codex/**' -g '!\.agents/**'
```

Result: location was the expected workspace; no files returned. Exit code 1 from `rg` indicated no matches. A separate `Get-ChildItem -LiteralPath 'C:\Users\CRS-Workstation\Game Dev' -Force -ErrorAction Stop` inspection confirmed zero items, including hidden items.

No applicable AGENTS.md was found in the empty workspace or at the checked ancestor paths (`C:\Users\CRS-Workstation\AGENTS.md`, `C:\Users\AGENTS.md`, `C:\AGENTS.md`).

### Available tools

```powershell
Get-Command rg, git, powershell, godot, godot4 -ErrorAction SilentlyContinue | Select-Object Name, Source
```

Result: `rg.exe`, `git.exe`, and `powershell.exe` were found. Neither `godot` nor `godot4` was found on PATH. Tool discovery also confirmed shell execution, file editing, and image inspection are available; no dedicated Godot tool was exposed. Git availability does not imply the workspace is a repository.

A bounded search checked top-level Godot-named entries in Downloads, Desktop, Program Files, Program Files (x86), `C:\Tools`, `C:\Godot`, and Local\Programs. This was not a full-disk search.

### Engine version

```powershell
& 'C:\Users\CRS-Workstation\Desktop\Godot_v4.7.1-stable_win64.exe' --version
```

Result: exit code 0; output `4.7.1.stable.official.a13da4feb`. This does not satisfy the requested Godot 4.7.2 version.

```powershell
rg --files 'C:\Users\CRS-Workstation\Downloads\Godot_v4.7.1-stable_win64.exe' -g '*.exe'
```

Result: exit code 0; found `C:\Users\CRS-Workstation\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`. That executable was not run.

### Specification intake and documentation checks

Read the existing documents before updating them. Preserved the initial inspection results, recorded the supplied specification, and added all thirteen milestone scopes and acceptance checks. Corrected a stray transcription marker during readback.

```powershell
rg --count '^## Milestone [0-9]+ ' PROJECT_PLAN.md
rg --count '^Status: not started\.$' PROJECT_PLAN.md
rg --files --hidden
Test-Path -LiteralPath 'project.godot'
Test-Path -LiteralPath '.git'
```

Result: exit code 0; 13 milestone headings and 13 not-started statuses; exactly SPECIFICATION.md, PROJECT_PLAN.md, and PROGRESS.md listed. Both path checks returned False. These are documentation checks, not Godot import or gameplay tests. No external reference links were rechecked during specification intake.

## Known issues and untested work

- Earlier user-reported Close strike issue was not reproduced. The user authorized proceeding; retained GUI regressions pass, but no confirmed fix to the physical observation is claimed.
- Milestone 4 received general user playtest acceptance. Individual physical keyboard/mouse, editor F5/F6/F8, display/DPI readability and tactical balance checks were not separately reported; automated GUI input and native screenshots do not establish those results.
- Only this machine's NVIDIA Compatibility renderer was exercised. No Windows export or other hardware testing; exports remain milestone 13.
- The first M4 import exited 1 without a printed project error; the final import passed. The same intermittent behavior occurred during earlier milestones. Cause remains unconfirmed; keep the log if it recurs.
- M7 adds the in-memory campaign loop. Disk persistence, audio and later presentation work are not implemented. Current verification and remaining manual checks are recorded at the top of this document.
- The first M6 rendered run had four window/capture dimension assertion failures; the final repeat passed without a layout change. Cause is unconfirmed; retain logs if this recurs.
- Determinism requires the same content, seed, commands, and pinned engine. Cross-version replay/save compatibility is not claimed.
- Milestones 5–6 and the room Resource/focus fix were uploaded and verified at `b5074db`; see the submission record above. Godot binaries and verification artifacts are deliberately not uploaded.

## Next steps

1. User completes the README milestone 7 playtest; fix any reported failure before a checkpoint or further milestone.
2. After acceptance, review and upload the intended milestone 7 files only if requested.
3. Start milestone 8 only when requested. Milestones 8–13 remain out of scope.
