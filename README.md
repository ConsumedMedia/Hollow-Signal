# Hollow Signal

Milestone 3: four Salvagers face four Faulted Sentries. Rank determines which attacks work and who they can target. Move swaps adjacent allies; Speed plus a seeded roll determines the order each round. Win, lose, and restart with the same seed. **There is no roster, expedition, permanent loss, or saving yet.** New Game still opens the placeholder hub.

## Open the project in Godot

This project uses **Godot 4.7.2 Standard**, typed GDScript, and the Compatibility renderer. Do not use the older 4.7.1 executable on the Desktop for this project.

The pinned editor is already downloaded to:

```text
C:\Users\CRS-Workstation\Game Dev\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe
```

1. Open that executable. If you see the Project Manager, click **Import**.
2. Select `C:\Users\CRS-Workstation\Game Dev\project.godot`, then import and edit it.
3. Wait for the initial scan. The renderer indicator should say **Compatibility**.
4. Press **F5** (Run Project). You should see the Hollow Signal main menu.
5. Press **F8** in the editor to stop the running game.

Alternatively, from PowerShell, open the editor directly:

```powershell
Set-Location 'C:\Users\CRS-Workstation\Game Dev'
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --editor --path .
```

The engine binaries in `.tools` are deliberately not in Git. On another computer, get **Windows Standard x86_64**, not .NET, from the [official 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/) or [official GitHub release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). Extract both executables into `.tools/godot-4.7.2/`. Keep them together: the console executable uses the main executable. No PATH change or third-party plugin is needed.

## Controls

| Input | Result |
|---|---|
| Left click | Activate a button |
| Tab / Shift+Tab | Next / previous button |
| Arrow keys | Move button focus |
| Enter / Space | Activate the focused button |
| Escape in battle test | Return to hub |
| Escape in hub | Return to main menu |
| Escape in main menu | Stay in main menu; does not quit |
| F11 | Toggle fullscreen / windowed mode |
| Quit in main menu | Close the game |

Orange outlines show keyboard focus. The first useful button is focused on every screen. Repeated navigation requests in the same frame are ignored after the first request.

The Input Map defines `ui_accept`, `ui_cancel`, and `toggle_fullscreen`. Tab and arrow navigation use Godot's native UI actions. Select an attack or Move, then click a labelled TARGET or SWAP card. Wait immediately spends the current actor's action. There are no extra combat hotkeys yet.

## Exact milestone 3 playtest

Use **Godot 4.7.2 Standard** and press **F5**, then **Battle Test** (or New Game → Open Battle Test). These exact expectations use unchanged Resources and seed **1729**.

Each card has a stable actor label (C1–C4 for crew, E1–E4 for enemies) and a separate rank. **Rank 1 is nearest the opposition:** crew ranks run 4, 3, 2, 1 from left to right; enemy ranks run 1, 2, 3, 4. IDs stay with the actor when ranks change.

| Check | Steps and expected result |
|---|---|
| Starting state | Four crew at 30 HP and four enemies at 20 HP. **C3 at rank 3 acts first**, with Covering shot selected and focused. All four enemy cards say TARGET. Close strike is disabled, with the reason printed below it. |
| Initiative and ties | Initial order is **C3:11 > C1:9 > C2:9 > E1:9 > C4:7 > E4:6 > E2:4 > E3:4**. Numbers are Speed + the d6 roll. The three actors on 9 appear in stable ID order. Only the current actor's action is accepted. |
| Adjacent Move | Click **Move / swap**, then the **Rank 2 / C2** card marked SWAP. Only C2 and C4 should be valid swap targets for C3. C3 moves to rank 2 and C2 moves to rank 3. The log says the action was spent; **C1 acts next**, not C3 again. |
| Movement changes skills | Click **Wait** for C1. **C2 now acts from rank 3**: Covering shot is available and Close strike is disabled. C2 still gets its original turn despite being swapped. C3 is no longer in this round's remaining queue. |
| Front/rear targeting | Restart. Use C3's selected Covering shot on any TARGET. C1 acts next at rank 1: Close strike becomes selected and only enemy ranks **1–2** are TARGETs; enemy ranks 3–4 cannot be attacked with that skill. |
| Removal and compaction | Restart. On each crew turn, use the available attack against the enemy currently at rank 1. Once E1 reaches zero, its shape/card disappears; E2 becomes rank 1, E3 rank 2, E4 rank 3, and rank 4 says EMPTY. E1 cannot act later. |
| Complete victory | Continue the same strategy without Move or Wait. With default data, victory occurs in **round 4**. C1 has 2/30 HP; C2–C4 have 30/30. No further combat action is accepted. |
| Complete defeat | Restart and choose **Wait on every crew turn**. The enemy acts automatically. Crew are removed as their HP reaches zero; defeat occurs in **round 7**. Restart restores all eight actors; no persistent deaths exist yet. |
| Deterministic replay | Restart and repeat the same abilities, target IDs, and swaps. Damage, initiative, ranks, and result should repeat. Different choices may change later random rolls. |
| Repeated input | Rapidly double-click a target card. The current actor's action resolves once; it cannot act twice or submit a second action while resolution is locked. A fresh click on a later crew turn is a new action. |
| Restart/leave safely | During an enemy response, click Restart or Back to Hub. The previous battle's delayed action must not damage a new battle or cause an error after leaving. |
| Keyboard and layout | Use Tab/Shift+Tab or arrows to focus an enabled skill, then a TARGET/SWAP card; activate with Enter/Space. Check health, rank, remaining order, reasons, and outcomes at both resolutions below. |

There are two temporary attacks for each side, not the four classes yet:

| Action | Actor ranks | Target ranks | Result |
|---|---|---|---|
| Close strike | 1–2 | Enemy 1–2 | Crew 6–8 damage; enemy 4–6 |
| Covering shot | 3–4 | Enemy 1–4 | Crew 6–8 damage; enemy 4–6 |
| Move | Any occupied rank | Adjacent ally | Swap; spend the actor's turn |
| Wait | Any occupied rank | None | Spend the actor's turn |

Both attacks hit automatically. Actual HP loss is capped at remaining health. At zero HP an actor is removed and surviving ranks close up; downed/revival rules arrive in milestone 5. Wait remains available even when an actor has no usable attack. Initiative is rerolled at each new round; swapping never rerolls it or changes the current queue.

For **F6 / Run Current Scene**, stop with F8, open `res://scenes/battle_test.tscn` in the FileSystem dock, and press F6. The battle should run directly. Back to Hub, Main Menu, Escape, and F11 should still work. Stop, then F5 starts the main menu. Watch the Debugger for errors.

### Exact resolution checks

Run one command at a time from the project folder in PowerShell. Close the game before the next command. These avoid ambiguity from the editor's embedded preview size.

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1280x720
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1920x1080
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1280x900
```

At **1280×720** and **1920×1080**, visit all three screens and finish both a victory and defeat: every button, health label, outcome, log, and footer should fit and be readable. At **1280×900**, the game should retain its proportions, with black bars above and below. Dragging the window edges should not stretch the figures or text.

The design canvas is 1920×1080; the default window is 1280×720. `canvas_items` stretch scales the interface, and `keep` preserves its aspect ratio. The minimum window is 960×540, although the acceptance targets are 720p and 1080p. See [Godot's resolution documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## Scenes, nodes, scripts, and signals

| Term | What it means in this project |
|---|---|
| Scene | A saved tree of objects. `main_menu.tscn`, `hub.tscn`, and `battle_test.tscn` each describe one screen. |
| Node | One object in that tree. A `Label` displays text, a `Button` receives input, and a `Control` supplies a UI rectangle. |
| Container | A node that arranges children. `VBoxContainer` stacks them vertically; `HBoxContainer` puts them side by side; `MarginContainer` adds padding. |
| Script | Typed GDScript that adds behaviour. `screen_navigation.gd` changes screens; `combat_rules.gd` resolves actions; `placeholder_stage.gd` only draws original geometric placeholders. |
| Signal | A notification. A target card emits `pressed`; the screen submits the selected ability and target as a command. The controller emits `events_resolved`, and the screen displays the resulting damage text. |
| Resource | Reusable authored data. `test_salvager.tres` holds starting health, Speed, and ability references; ability `.tres` files hold damage and ranks, while `prototype_theme.tres` holds visual styles. Neither stores the changing health of a particular actor. |

To see a signal, open `main_menu.tscn`, select the **NewGame** button, and inspect its **Signals** list. Its `pressed` connection goes to the scene's root. To change a label, select the Label node and edit its **Text** property in the Inspector.

The battle owns its controller and enemy-delay Timer; there are no autoloads or persistent services yet. The Timer pauses briefly before each enemy action, but does not calculate damage. The rule objects are `RefCounted` data/code objects, not scene nodes, so the rules can run in tests without loading a battle scene.

### Change actor values in the Inspector

1. Stop the game. Open `res://content/actors/test_salvager.tres` or `test_sentry.tres` in the FileSystem dock. Inspect **Max Health**, **Speed**, and **Abilities**. These are templates, not changing battle state.
2. Open `res://content/abilities/crew_strike.tres` or `crew_shot.tres`. Inspect **Actor Ranks**, **Target Ranks**, **Damage Min**, and **Damage Max**. The two `enemy_*.tres` files define enemy attacks.
3. For an optional experiment, record the original value, change a damage value or rank list, save, and run a new battle. The UI should use the new requirements. Restore original values afterward so tests and this walkthrough match.
4. In `battle_test.tscn`, select **BattleController** to inspect **Battle Seed** (1729). Restart resets both initiative and damage randomness to that seed.

`ContentCatalogue` explicitly preloads the actor files, which explicitly reference their attacks. Each combat actor owns its own current health. Formation and initiative track stable IDs separately. See [COMBAT_RULES.md](COMBAT_RULES.md) for interfaces and resolution order.

## Automated checks

There is no test-framework dependency. `tests/run_tests.gd` runs rules without scenes; `tests/setup_smoke.gd` exercises the actual scenes, controller, navigation, and layout. Run these commands from the project folder, one at a time:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd
```

Expected: import exits 0 without project errors; rules print **78 checks, 0 failures** and **engine errors = 0**, exit 0; headless integration prints **107 checks, 0 failures**, exit 0. The rules suite compares full replay results across 64 seeds and verifies rejected commands do not change state or randomness. The integration suite checks legal target cards, swaps, rank compaction, visible disabled reasons, playable victory/defeat, repeated input across consecutive crew turns, restart cancellation, and the existing setup.

Use `run_tests.gd` as the entry point, not `combat_rules_test.gd`. The runner loads the suite after installing an engine error monitor so a script error cannot masquerade as a passing test. Check output as well as exit codes, particularly during import.

For real Compatibility-renderer checks and screenshots (opens a window briefly and exits):

```powershell
New-Item -ItemType Directory -Path '.artifacts' -Force | Out-Null
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd -- --capture
```

Expected: **166 checks, 0 failures**, exit 0. Nineteen screenshots go into `.artifacts/`, including Move selection, swapped ranks, partial enemy compaction, victory, and defeat at both target sizes. Filenames identify the requested window size; the 1280×900 captures contain the 1280×720 viewport, excluding the Window's black bars.

To confirm failure exit behaviour:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-failure
$LASTEXITCODE
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-script-error
$LASTEXITCODE
```

Expected: the first command prints **79 checks, 1 intentional failure**, exit **1**. The second prints **78 checks, 0 assertion failures**, then one intentionally injected parse error, **engine errors = 1**, exit **1**. Neither option should be used for a normal passing run. The malformed script exists only in memory; no broken project file is written. See [Godot's command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

Automated inputs are simulated inside Godot. The recorded rendering checks used this machine's NVIDIA Compatibility renderer; your physical controls, editor F6 workflow, and display/DPI readability still need the manual playtest above. No Windows export or other hardware has been tested. Exact executed commands, results, and earlier failures/fixes are recorded in [PROGRESS.md](PROGRESS.md).

## Files and Git

- `SPECIFICATION.md`: supplied requirements; `PROJECT_PLAN.md`: milestone scopes; `PROGRESS.md`: actual commands, results, limitations, and next steps.
- `COMBAT_RULES.md`: current battle contract and deferred rules.
- `content/`: authored definitions and explicit catalogue; `combat/`: runtime records and scene-independent rules.
- `scenes/`: editable screen trees; `scripts/`: presentation/controllers; `ui/`: authored theme; `tests/`: native rules and integration checks.
- `.godot/`: generated cache, not source. `.tools/`: local engine. `.artifacts/`: local test output. Their contents are excluded from Git except the `.gdignore` markers that keep engine files and test output out of Godot's import scan.
- `.uid` files are kept in Git so Godot script references remain stable.
- All visible artwork is original rectangles, circles, and lines, with Godot's built-in font. No extracted assets, downloaded artwork, or audio is used.

The GitHub repository is [ConsumedMedia/Hollow-Signal](https://github.com/ConsumedMedia/Hollow-Signal). Local `main` tracks `origin/main`; local commits reach GitHub only after a push. Godot binaries, caches, test logs, and screenshots are excluded; another computer needs the pinned engine from the setup instructions above.

After your acceptance playtest, inspect `git status`, commit intended changes, then use `git push` to upload the new commit. Saving a file alone does not upload it. Never commit credentials, engine binaries, or caches. This repository uses Windows certificate validation (`http.sslBackend=schannel`) with TLS verification enabled; no global Git settings were changed.

**Next milestone, only after this playtest and when requested:** milestone 4, crew classes and enemy behaviour.
