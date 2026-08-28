# Hollow Signal

Milestone 1: a working project shell with a main menu, placeholder hub, and independently runnable battle test. **There is no playable combat, roster, expedition, or saving yet.** New Game only opens the hub.

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

The Input Map defines `ui_accept`, `ui_cancel`, and `toggle_fullscreen`. Tab and arrow navigation use Godot's native UI actions. No future combat bindings are added yet.

## Exact milestone 1 playtest

Start with F5. If the editor embeds the running game, use its game view; use the standalone commands below when checking exact window sizes or fullscreen behaviour.

| Step | Expected result |
|---|---|
| Click **New Game** | Hub titled **Salvage operations** opens |
| Click **Open Battle Test** | Cyan crew stand-in on the left, orange enemy stand-in on the right, and a clear no-combat-yet message |
| Click **Back to Hub**, then **Main Menu** | Each button opens the named screen |
| From the menu click **Battle Test**, then **Main Menu** | Direct menu-to-battle and battle-to-menu navigation both work |
| Open battle, press Escape twice | Battle → hub → main menu |
| Press Escape once more | Menu remains open |
| Press Tab, Shift+Tab, arrows, then Enter or Space | Focus outline moves; activation follows the focused button |
| Rapidly click New Game | A single hub opens, with no error or stacked screens |
| Press F11 twice in a standalone game | Fullscreen, then back to a usable window |
| Click Quit | Game window closes |

To test **Run Current Scene**, stop with F8, double-click `res://scenes/battle_test.tscn` in Godot's FileSystem dock, and press **F6**. The battle placeholder should run directly without first opening the menu. Back to Hub and Main Menu should still work. Stop, then F5 should start at the main menu again.

### Exact resolution checks

Run one command at a time from the project folder in PowerShell. Close the game before the next command. These avoid ambiguity from the editor's embedded preview size.

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1280x720
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1920x1080
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path . --resolution 1280x900
```

At **1280×720** and **1920×1080**, visit all three screens: every button, heading, description, and footer should fit and be readable. At **1280×900**, the game should retain its proportions, with black bars above and below. Dragging the window edges should not stretch the figures or text.

The design canvas is 1920×1080; the default window is 1280×720. `canvas_items` stretch scales the interface, and `keep` preserves its aspect ratio. The minimum window is 960×540, although the acceptance targets are 720p and 1080p. See [Godot's resolution documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## Scenes, nodes, scripts, and signals

| Term | What it means in this project |
|---|---|
| Scene | A saved tree of objects. `main_menu.tscn`, `hub.tscn`, and `battle_test.tscn` each describe one screen. |
| Node | One object in that tree. A `Label` displays text, a `Button` receives input, and a `Control` supplies a UI rectangle. |
| Container | A node that arranges children. `VBoxContainer` stacks them vertically; `HBoxContainer` puts them side by side; `MarginContainer` adds padding. |
| Script | Typed GDScript that adds behaviour. `screen_navigation.gd` changes screens; `placeholder_stage.gd` only draws original geometric placeholders. |
| Signal | A notification. New Game emits `pressed`; its saved connection calls `open_screen` with the hub scene path. |
| Resource | Reusable authored data. `prototype_theme.tres` holds visual styles shared by all three screens; it holds no crew health or combat state. |

To see a signal, open `main_menu.tscn`, select the **NewGame** button, and inspect its **Signals** list. Its `pressed` connection goes to the scene's root. To change a label, select the Label node and edit its **Text** property in the Inspector.

Each screen currently manages only its navigation. There are no autoloads or persistent services yet. Combat definitions and mutable actor state will be added separately in milestone 2; drawing code will not calculate damage.

## Automated checks

The small native runner in `tests/setup_smoke.gd` checks this setup without installing a test framework. It is an integration smoke test, not a combat-rule suite. Run these commands from the project folder:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd
```

Expected: import exits 0 without project errors; smoke runner prints **55 checks, 0 failures**, exit 0. Check the output as well as the exit code: some engine/environment errors can accompany exit 0.

For real Compatibility-renderer checks and screenshots (opens a window briefly and exits):

```powershell
New-Item -ItemType Directory -Path '.artifacts' -Force | Out-Null
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd -- --capture
```

Expected: **84 checks, 0 failures**, exit 0. Screenshots go into `.artifacts/`. Filenames identify the requested window size; the 1280×900 captures contain the 1280×720 viewport, excluding the Window's black bars.

To confirm failure exit behaviour:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd -- --self-test-failure
$LASTEXITCODE
```

Expected: **56 checks, 1 failure**, exit **1**, caused only by the intentionally injected failure. Do not use that option for a normal passing run. See [Godot's command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

## Files and Git

- `SPECIFICATION.md`: supplied requirements; `PROJECT_PLAN.md`: milestone scopes; `PROGRESS.md`: actual commands, results, limitations, and next steps.
- `scenes/`: editable screen trees; `scripts/`: typed behaviour; `ui/`: authored theme; `tests/`: native setup checks.
- `.godot/`: generated cache, not source. `.tools/`: local engine. `.artifacts/`: local test output. Their contents are excluded from Git except the `.gdignore` markers that keep engine files and test output out of Godot's import scan.
- `.uid` files are kept in Git so Godot script references remain stable.
- All visible artwork is original rectangles, circles, and lines, with Godot's built-in font. No extracted assets, downloaded artwork, or audio is used.

Git is local; no remote repository has been created or pushed. After your acceptance playtest, inspect `git status` before any checkpoint. Commit intended changes only; do not commit engine binaries or caches.

**Next milestone, only when requested:** milestone 2, one functioning battle.
