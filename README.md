# Hollow Signal

Milestone 4: command a Breacher, Technician, Ranger and Medic, with three abilities each, against two test patrols covering five enemy archetypes. Healing, protection, Exposed, Scorch, strain changes and forced movement use shared rules. **There is no roster, expedition, permanent loss, persistent strain, Shaken, power or saving yet.** New Game still opens the placeholder hub.

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

## Exact milestone 4 playtest

Use **Godot 4.7.2 Standard** from the path above. Stop any old running game with **F8**, then press **F5 → Battle Test**. Leave the seed at **1729** and use unchanged content.

The four starting ranks are **C1 Breacher, C2 Technician, C3 Ranger, C4 Medic** (rank 1 outward). Rank 1 is closest to the opposition; the crew's front is on the right. Buttons belong only to the **ACTING actor/class in the top line**. Selecting a skill does not spend an action; clicking a legal **TARGET** does. Move uses an adjacent **SWAP** card. Wait acts immediately.

### First round: exact opening

Start a fresh **Boarding patrol** (the default). Do not insert other actions between these steps; enemy turns happen automatically.

1. **C3 Ranger / rank 3:** choose **Covering shot → Rank 4 / E4 Needle Turret**. E4 loses 6–8 HP.
2. **C2 Technician / rank 2:** choose **Cutting beam → Rank 1 / E1 Hull Mauler**. E1 takes 4–6 damage and gains Scorch. Its first Scorch tick happens before its immediately following action, so the card should then show **D1**, with 2 additional HP lost.
3. After E1 acts, **C1 Breacher / rank 1:** choose **Brace → C4 Medic**. The Medic gets **P2** (Protected). The Needle Turret then attacks the rear crew.
4. **C4 Medic / rank 4:** choose **Field patch → C3 Ranger**, who was injured by the turret. The Ranger returns to full health; Field patch has **1 use left** on the Medic's next turn.

This opening is exercised with simulated GUI clicks and natural initiative in the native smoke test. Your physical editor/mouse check is still required.

### Remaining acceptance checks

| Check | Exact action and expected result |
|---|---|
| Twelve skills | On each class's turn inspect its three buttons. Names and abilities differ by class; disabled reasons appear below the buttons. The full ability/rank table is in COMBAT_RULES.md. |
| Close strike | Restart; Wait for C3, then Wait for C2. After E1 acts, C1 Breacher has Close strike. Select it, then enemy rank 1 or 2. A Ranger at the front still has Ranger skills, not Breacher skills. |
| Fallback shot | Restart; on C3's opening turn choose Fallback shot → E4. C3 moves from rank 3 to 4, and C4 moves to rank 3. C3 has spent its turn; C4 retains its own turn. |
| Tractor pull | Restart; C3 Wait. C2 selects Tractor pull → E4. E4 moves from rank 4 to 3; E3 shifts to rank 4. E1 cannot be selected because it is already at the front. |
| Ram | Restart; C3 Wait, C2 Wait. After E1 acts, C1 selects Ram → E1. Damage resolves first, then surviving E1 moves from rank 1 to 2. |
| Expose / Exploit | On the Technician's turn, Expose an enemy. Before that enemy's second following turn start, select the Ranger's Exploit signal. The target HP-loss preview shows 7–10 against an unprotected Exposed enemy (capped by remaining HP), versus its base 5–7. Exposed is not consumed by the attack. |
| Status timing | Watch P, X and D counters on affected actors. P = Protected, X = Exposed, D = Scorch. Counters decrease at that actor's turn start; Scorch deals 2 first. They expire at zero. Reapplying refreshes to 2, never adds stacks. Hover a card for full status names. |
| Healing limit | Use Field patch twice on injured allies during one battle. A third use is disabled with “No uses left this battle.” Full-health targets cannot waste a use. Restart, injure someone again, and the Medic has 2 uses. |
| Strain enemy / relief | Click **Boarding patrol / switch** to restart as **Signal patrol**. E3 becomes Signal Echo. Wait until it raises crew strain; on the Medic's turn choose Steady voice → an ally with Str above zero. Str decreases by up to 20. It has no Shaken or persistence yet. |
| Enemy roles | Boarding patrol: Mauler hits front, Bulwark protects another enemy, Tow Drone pulls rear crew forward, Needle Turret attacks rear crew. Signal patrol replaces only the Tow Drone with a strain attacker. Displaced enemies can use a weak fallback attack instead of choosing illegal targets. |
| Victory / defeat | Fight using legal attacks, use Move to recover useful ranks, and heal injured crew. Both patrols can be won. Restart and Wait on every crew turn to lose; outcome is terminal and Restart restores everyone. Zero HP still removes an actor immediately in M4. |
| Repeated input / restart | Double-click a target: one action resolves. Restart or switch patrol during an enemy delay: the old response must not damage the new battle. |
| Keyboard / layout | Tab or arrows move focus; Enter activates the focused skill/card. Repeat at both sizes below. Read the three ability reasons, selected description, target damage, HP/strain/statuses, log and outcome. |

If a button appears wrong, capture the top actor/class/rank line, the buttons and the reason below them. The earlier Close strike report was not reproduced; its mouse-click regressions are retained using the original M3 fixtures. This does not establish the cause of the user's earlier observation.

For **F6 / Run Current Scene**, stop with F8, open `res://scenes/battle_test.tscn` in the FileSystem dock, and press F6. It should start the class battle directly. Back to Hub, Main Menu, Escape and F11 should still work.

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
| Resource | Reusable authored data. `breacher.tres` holds maximum health, Speed, and ability references; ability `.tres` files hold damage, ranks, use limits and ordered effects, while `prototype_theme.tres` holds visual styles. Neither stores the changing health of a particular actor. |

To see a signal, open `main_menu.tscn`, select the **NewGame** button, and inspect its **Signals** list. Its `pressed` connection goes to the scene's root. To change a label, select the Label node and edit its **Text** property in the Inspector.

The battle owns its controller and enemy-delay Timer; there are no autoloads or persistent services yet. The Timer pauses briefly before each enemy action, but does not calculate damage. The rule objects are `RefCounted` data/code objects, not scene nodes, so the rules can run in tests without loading a battle scene.

### Change actor values in the Inspector

1. Stop the game. Open `res://content/actors/breacher.tres` (or another class/enemy) in the FileSystem dock. Inspect **Max Health**, **Speed**, and **Abilities**. These are shared templates, not changing battle state.
2. Open `res://content/abilities/field_patch.tres`, `cutting_beam.tres` or `breach_strike.tres`. Inspect **Actor Ranks**, **Target Ranks**, **Damage Min/Max**, **Max Uses**, and expand **Effects**. Status durations/amounts are in `res://content/statuses/`; strain cap and AI preferences are in `res://content/balance.tres`. Descriptions are authored text: update them if tuning numbers.
3. For an optional experiment, record the original value, change a damage value or rank list, save, and run a new battle. The UI should use the new requirements. Restore original values afterward so tests and this walkthrough match.
4. In `battle_test.tscn`, select **BattleController** to inspect **Battle Seed** (1729). Restart resets both initiative and damage randomness to that seed.

`ContentCatalogue` explicitly preloads the actor files, which explicitly reference their attacks. Each combat actor owns its own health, battle strain, remaining statuses and use counters. Formation and initiative track stable IDs separately. See [COMBAT_RULES.md](COMBAT_RULES.md) for interfaces and resolution order.

## Automated checks

There is no test-framework dependency. `tests/run_tests.gd` runs rules without scenes; `tests/setup_smoke.gd` exercises the actual scenes, controller, navigation, and layout. Run these commands from the project folder, one at a time:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd
```

Expected: import exits 0 without project errors; rules print **149 checks, 0 failures** and **engine errors = 0**, exit 0; headless integration prints **360 checks, 0 failures**, exit 0. The rules suite compares full replay results across 64 seeds and verifies rejected commands do not change state or randomness. The integration suite checks legal target cards, swaps, rank compaction, visible disabled reasons, playable victory/defeat, repeated input across consecutive crew turns, restart cancellation, and the existing setup.

Use `run_tests.gd` as the entry point, not `combat_rules_test.gd`. The runner loads the suite after installing an engine error monitor so a script error cannot masquerade as a passing test. Check output as well as exit codes, particularly during import.

For real Compatibility-renderer checks and screenshots (opens a window briefly and exits):

```powershell
New-Item -ItemType Directory -Path '.artifacts' -Force | Out-Null
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd -- --capture
```

Expected: **539 checks, 0 failures**, exit 0. Fifty-nine screenshots go into `.artifacts/`, including every class skill, both patrols, all status counters, and outcomes at both target sizes. Controlled skill/status screenshots use test fixtures; the full patrol battles use natural turns. Filenames identify the requested window size; the 1280×900 captures contain the 1280×720 viewport, excluding the Window's black bars.

To confirm failure exit behaviour:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-failure
$LASTEXITCODE
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-script-error
$LASTEXITCODE
```

Expected: the first command prints **150 checks, 1 intentional failure**, exit **1**. The second prints **149 checks, 0 assertion failures**, then one intentionally injected parse error, **engine errors = 1**, exit **1**. Neither option should be used for a normal passing run. The malformed script exists only in memory; no broken project file is written. See [Godot's command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

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

**Next milestone, only after this playtest and when requested:** milestone 5, crew vulnerability, persistent strain, Shaken and shared power.
