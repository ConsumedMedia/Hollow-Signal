# Hollow Signal

Milestone 2: a playable battle between one Salvager and one Faulted Sentry. Attack, Wait, see damage and health, win or lose, and restart with the same random seed. **There is no roster, expedition, permanent loss, or saving yet.** New Game still opens the placeholder hub.

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

The Input Map defines `ui_accept`, `ui_cancel`, and `toggle_fullscreen`. Tab and arrow navigation use Godot's native UI actions. Attack and Wait are buttons; there are no extra combat hotkeys yet.

## Exact milestone 2 playtest

Start with F5. If the editor embeds the running game, use its game view; use the standalone commands below when checking exact window sizes or fullscreen behaviour.

| Step | Expected result |
|---|---|
| Click **New Game**, then **Open Battle Test** | Round 1, Your turn, Seed 1729. Salvager has 30/30 HP and Attack 6–8; Sentry has 20/20 HP and Attack 4–6. |
| Click **Attack Sentry** once | Sentry loses 6–8 HP. Attack/Wait lock briefly; the enemy attacks automatically, then Your turn returns. Both hits appear in the log. |
| Click Attack on each of your next two turns | With unchanged content and seed, **VICTORY** in round 3; crew 20/30 HP, enemy 0/20. Enemy is labelled DEFEATED. Attack/Wait stay disabled. |
| Click **Restart same seed**, then repeat those three Attacks | Full health returns first; the same damage sequence and final result repeat. |
| Restart, then click **Wait** on each of your turns | Wait uses your action without healing or damage. Enemy keeps attacking; **DEFEAT** in round 6, crew 0/30, enemy 20/20. Attack/Wait stay disabled. |
| Restart after defeat | Round 1, full health, and enabled actions return. No permanent loss occurs in this milestone. |
| On a fresh battle, rapidly double-click Attack | No extra action occurs during the enemy response. One enemy reply follows each accepted player action. |
| Attack, then immediately Restart during the short enemy pause | New battle starts at full health; the cancelled enemy reply does not damage the new crew. |
| Attack, then immediately click **Back to Hub** | Hub opens without an error from the departing battle. Opening Battle Test again creates a fresh battle. |
| From the menu click **Battle Test** | The battle also opens directly without visiting the hub. |
| Open battle, press Escape twice | Battle → hub → main menu. A third Escape stays in the menu. |
| Use Tab, Shift+Tab, arrows, Enter/Space | Focus moves between usable buttons; activation follows focus. Check both Attack and Wait. |
| Press F11 twice in a standalone game; use **Quit** from menu | Fullscreen, then a usable window; Quit closes it. |

To test **Run Current Scene**, stop with F8, double-click `res://scenes/battle_test.tscn` in Godot's FileSystem dock, and press **F6**. The playable battle should run directly without first opening the menu. Back to Hub and Main Menu should still work. Stop, then F5 should start at the main menu again. Watch the editor's Debugger for errors during these steps.

Damage is rolled within the displayed inclusive range, but health never drops below zero. A finishing hit may therefore report less damage than the minimum: an enemy with 5 HP can lose only 5 HP. The current test always gives the crew the first turn; Speed initiative and four positions arrive in milestone 3.

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
| Signal | A notification. Attack emits `pressed`; the screen submits a command. The controller emits `events_resolved`, and the screen displays the resulting damage text. |
| Resource | Reusable authored data. `test_salvager.tres` holds starting health and damage, while `prototype_theme.tres` holds visual styles. Neither stores the changing health of a particular actor. |

To see a signal, open `main_menu.tscn`, select the **NewGame** button, and inspect its **Signals** list. Its `pressed` connection goes to the scene's root. To change a label, select the Label node and edit its **Text** property in the Inspector.

The battle owns its controller and enemy-delay Timer; there are no autoloads or persistent services yet. The Timer pauses briefly before the enemy action, but does not calculate damage. The rule objects are `RefCounted` data/code objects, not scene nodes, so the rules can run in tests without loading a battle scene.

### Change actor values in the Inspector

1. Stop the game. In the FileSystem dock open `res://content/actors/test_salvager.tres` or `test_sentry.tres`.
2. Inspect **Max Health**, **Damage Min**, and **Damage Max**. These are the authored starting values, not current battle health.
3. For an optional experiment, record the original value, change Max Health, save, and run a new battle. The new starting health should appear. Restore the original value afterward to match this guide and the tests.
4. To inspect the seed, open `battle_test.tscn`, select **BattleController**, and look at **Battle Seed** (1729). Restart reuses this seed; it does not randomize it.

`ContentCatalogue` explicitly preloads the two actor files. Each battle creates separate `ActorState` records that reference those shared definitions but own their own current health. See [COMBAT_RULES.md](COMBAT_RULES.md) for the interfaces and resolution order.

## Automated checks

There is no test-framework dependency. `tests/run_tests.gd` runs rules without scenes; `tests/setup_smoke.gd` exercises the actual scenes, controller, navigation, and layout. Run these commands from the project folder, one at a time:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd
```

Expected: import exits 0 without project errors; rules print **51 checks, 0 failures** and **engine errors = 0**, exit 0; headless integration prints **82 checks, 0 failures**, exit 0. The rules suite compares full replay results across 64 seeds and verifies rejected commands do not change state or randomness. The integration suite checks playable victory/defeat, repeated input, restart, pending enemy cancellation, and the existing setup.

Use `run_tests.gd` as the entry point, not `combat_rules_test.gd`. The runner loads the suite after installing an engine error monitor so a script error cannot masquerade as a passing test. Check output as well as exit codes, particularly during import.

For real Compatibility-renderer checks and screenshots (opens a window briefly and exits):

```powershell
New-Item -ItemType Directory -Path '.artifacts' -Force | Out-Null
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd -- --capture
```

Expected: **123 checks, 0 failures**, exit 0. Thirteen screenshots go into `.artifacts/`, including victory and defeat at both target sizes. Filenames identify the requested window size; the 1280×900 captures contain the 1280×720 viewport, excluding the Window's black bars.

To confirm failure exit behaviour:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-failure
$LASTEXITCODE
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-script-error
$LASTEXITCODE
```

Expected: the first command prints **52 checks, 1 intentional failure**, exit **1**. The second prints **51 checks, 0 assertion failures**, then one intentionally injected parse error, **engine errors = 1**, exit **1**. Neither option should be used for a normal passing run. The malformed script exists only in memory; no broken project file is written. See [Godot's command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

Automated inputs are simulated inside Godot. The recorded rendering checks used this machine's NVIDIA Compatibility renderer; your physical controls, editor F6 workflow, and display/DPI readability still need the manual playtest above. No Windows export or other hardware has been tested. Exact executed commands, results, and earlier failures/fixes are recorded in [PROGRESS.md](PROGRESS.md).

## Files and Git

- `SPECIFICATION.md`: supplied requirements; `PROJECT_PLAN.md`: milestone scopes; `PROGRESS.md`: actual commands, results, limitations, and next steps.
- `COMBAT_RULES.md`: current battle contract and deferred rules.
- `content/`: authored definitions and explicit catalogue; `combat/`: runtime records and scene-independent rules.
- `scenes/`: editable screen trees; `scripts/`: presentation/controllers; `ui/`: authored theme; `tests/`: native rules and integration checks.
- `.godot/`: generated cache, not source. `.tools/`: local engine. `.artifacts/`: local test output. Their contents are excluded from Git except the `.gdignore` markers that keep engine files and test output out of Godot's import scan.
- `.uid` files are kept in Git so Godot script references remain stable.
- All visible artwork is original rectangles, circles, and lines, with Godot's built-in font. No extracted assets, downloaded artwork, or audio is used.

Git is local; no remote repository has been created or pushed. After your acceptance playtest, inspect `git status` before any checkpoint. Commit intended changes only; do not commit engine binaries or caches.

**Next milestone, only after this playtest and when requested:** milestone 3, four-position combat.
