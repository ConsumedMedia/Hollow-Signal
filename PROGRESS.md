# Hollow Signal — Progress

## Status — 2026-08-28

Milestone 3 was requested after the GitHub upload and is implemented. Four actors per side now use rank-limited attacks, adjacent Move, universal Wait, and Speed plus seeded d6 initiative. Formation is separate from the round queue; defeated actors are removed, ranks close up, and dead queue entries are skipped. Import and native rules/integration/rendered checks passed. User acceptance of milestone 3 is pending.

The worktree was clean at `4224ee1` before editing. Existing history, setup/navigation, shapes, engine, native test runner, and authored/runtime separation were retained. No dependencies or assets were installed. Godot remains **4.7.2 Standard / Compatibility**, project version `0.3.0-milestone-3`. No milestone 4 or later systems were started.

## Completed milestones

- Milestone 1: complete; user reported success on 2026-08-28. This is general user acceptance, not a claim that every individual manual step was reported separately.
- Milestone 2: implementation and automated/rendered verification complete; user authorized moving to milestone 3, without separately reporting every manual check.
- Milestone 3: implementation and automated/rendered verification complete; user playtest pending.
- Milestones 4–13: not started or authorized.

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

- No known code defect found by current checks. The test attacks and balance are placeholders, not the final class abilities.
- Milestone 3 physical keyboard/mouse input, editor F5/F6/F8 workflow, and display/DPI readability still need the user's README.md playtest. Automated GUI input and native screenshots are not a substitute for that.
- Only this machine's NVIDIA Compatibility renderer was exercised. No Windows export or other hardware testing; exports remain milestone 13.
- Earlier milestone imports occasionally exited 1 without printed errors. Both milestone 3 imports passed; report any future recurrence with its log.
- No classes/statuses, downed/permanent death, strain/power, campaign, saving, audio, or later systems are implemented or tested. Zero HP currently removes the actor from this test only.
- Determinism requires the same content, seed, commands, and pinned engine. Cross-version replay/save compatibility is not claimed.
- Current milestone 3 changes are local until a further GitHub push is requested.

## Next steps

1. Follow README.md's milestone 3 playtest, starting with C3 swapping with C2 to cross the front/rear boundary.
2. Check rank-based targeting, initiative, removal, victory/defeat, restart, and both target resolutions; report any errors before another system.
3. Start milestone 4 only when requested, using the existing ability Resources and rules as the foundation for class skills and enemy behaviours.
