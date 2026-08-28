# Hollow Signal — Progress

## Status — 2026-08-28

The user reported "all is working" for milestone 1 and requested milestone 2. Milestone 2 is implemented: a complete one-versus-one Attack/Wait battle with seeded damage, independent health, legal-command validation, automatic enemy responses, victory/defeat, and restart. Import, native rules/integration checks, and rendered checks passed. The milestone 2 user playtest is pending. No formation, classes, campaign, roster, saving, audio, or later systems were added.

Existing scenes, navigation, artwork, documents, Git history, and the Desktop Godot 4.7.1 executable were preserved. The initial Git diff contained only Godot-editor normalization of `project.godot` (expanded input events, default-value/header/order changes). Those user changes were retained; this milestone updates the project version to `0.2.0-milestone-2`.

## Completed milestones

- Milestone 1: complete; user reported success on 2026-08-28. This is general user acceptance, not a claim that every individual manual step was reported separately.
- Milestone 2: implementation and automated/rendered verification complete; user acceptance pending.
- Milestones 3–13: not started or authorized.

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

- No known project-code defect found by current checks.
- Milestone 2 user playtest pending: physical Attack/Wait/restart/navigation, editor F5/F6/F8 workflow, and readability on the user's display/DPI settings. Exact steps and expected results are in README.md. Milestone 1 has general user acceptance, without a separate report for every manual check.
- Initial imports have occasionally exited 1 without printed errors; the final milestone 2 import passed. Report any recurrence with the log rather than assuming success.
- Only this machine's NVIDIA Compatibility renderer was exercised. No Windows export or other hardware testing; exports belong to milestone 13.
- This simple battle is not a balance test for the later tactical game. Fixed crew-first order, no ranks, and defeat at zero HP are intentional interim M2 rules. No classes, statuses, downed/permanent death, strain, power, saving, audio, or future milestone behaviour is implemented or tested.
- Replay expectations apply to unchanged content, commands, seed, and the pinned engine. Cross-version replay compatibility and save/load are not claimed.

## Next steps

1. User opens the pinned editor and follows README.md's milestone 2 playtest: win, lose, replay, repeated input, pending-response cancellation, and target resolutions.
2. Fix any reported issue and update verification before another milestone.
3. Start milestone 3 only when requested. Extend the existing rules with ranks, Speed initiative, and Move; preserve definition/state separation and the test suite.
