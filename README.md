# Hollow Signal

Milestone 6 is implemented: an authored eight-room ship, short corridor transitions, once-only room events, a twelve-slot inventory, power cells and embedded battles sharing expedition state. **Godot import, 287 rules checks, 517 headless scene checks and 744 rendered scene checks pass after the room Resource fix.** The user reported general playtest success; individual manual checks were not separately reported. Exact commands, results and limitations are in PROGRESS.md.

New Game opens the placeholder hub; **Explore Ship** starts a fresh in-memory expedition. The separate **Battle Test** remains available. No persistent roster, campaign rewards, retreat mechanic or disk saving yet. Ending a test or closing the app abandons its state; hub persistence and saves arrive in milestones 7–8.

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

## Exact milestone 6 playtest

Use **Godot 4.7.2 Standard**. Import and automated checks now pass; the following physical playtest remains yours to verify. For the reported Resource error, stop the old game with F8, wait for the editor's filesystem rescan and clear old Output/Debugger messages before F5. Stop on any new error and send its exact message.

1. Open the pinned editor, press **F8**, then **F5 → New Game → Explore Ship**. Expected: Airlock is HERE, eight rooms are visible, four healthy crew are listed, power is **100**, and two power cells occupy one of **12 slots**.
2. Click **Receiving**. Expected: a short horizontal corridor animation, **95 power**, all travel locked during the transition. **Skip corridor animation** should arrive once without another cost. Unconnected rooms cannot be chosen.
3. Click **Engage patrol**. Expected: the existing battle interface appears with the expedition crew and power; the isolated test's Fresh expedition, patrol switch and drill buttons are hidden. Win using the class skills. **Return to room** is enabled only after the outcome. Expected on return: wounds, strain, Shaken, deaths and power match the resolved fight, the room is CLEARED, and its loot is added once.
4. Travel back to **Airlock**, then back to **Receiving**. Expected: each corridor costs 5, but the cleared fight and loot do not regenerate. At power **50+** entry adds 0 strain, **25–49** adds 2, and **below 25** adds 5, calculated after the travel cost. Zero power does not force defeat.
5. In any room outside combat, click the **Power cell** stack, then **Use selected power cell**. Expected: restore **25**, capped at 100, consume one cell. At full power it is disabled. Cells cannot be used during a corridor or a fight.
6. Clear **Junction**, then take the optional **Salvage bay** branch. Click **Collect cache**. Expected: the hold fills to twelve slots and HOLD FULL lists the remaining cargo; nothing silently vanishes, and travel locks. Select a stored stack → **Discard selected stack…**, review the quantity and confirm to free space for incoming cargo. Alternatively **Leave incoming cargo…** explicitly discards the pending quantity. Cancel must change nothing. Resolve all pending cargo before travelling.
7. Continue to **Pressure breach**. **Search / +12 strain** gives its cargo once and adds 12 strain to every surviving crew member. **Seal / no loot** instead resolves it without strain or loot. Revisit: neither option may regenerate the event. A separate fresh expedition is needed to try the other choice.
8. Backtrack to **Junction → Safe room**. **Rest once** restores **12 HP** and reduces **30 strain**, with normal caps; it never revives dead crew. Repeated visits give no second rest. Continue through **Containment → Signal core**, winning each encounter. Expected: the single Relay Bulwark boss placeholder can be cleared and the summary says **BOSS PLACEHOLDER CLEARED**. No final narrative/reward campaign is implemented yet.
9. In a separate fresh expedition, Wait through a fight to lose. Expected: all deployed crew are lost; returning displays EXPEDITION FAILED and further travel/items are disabled. **End test / abandon to hub** is an explicit test reset path, not the milestone 7 retreat/reward system.
10. Repeat at **1280×720** and **1920×1080**. Check room links, room choices, all twelve inventory slots, overflow text, confirmation dialog, battle Return to room, and keyboard focus. **ESC** abandons only when outside battle/corridor/overflow; **F11** remains fullscreen. No campaign data is saved.

The main route is **Airlock → Receiving → Junction → Safe room → Containment → Signal core**. The optional branch is **Junction → Salvage bay → Pressure breach**. Room Resources live in `res://content/rooms/`, with the explicit graph in `res://content/ship.tres`. See EXPLORATION_RULES.md for ownership and transaction rules.

## Exact milestone 5 playtest

Use the pinned **Godot 4.7.2 Standard** editor above. Press **F8** to stop an old run, then **F5 → Battle Test**. To run the scene directly, open `res://scenes/battle_test.tscn` and press **F6**. Repeat the checks at **1280×720** and **1920×1080** using the resolution commands below.

### Revival and Overcharge drill

1. Click **Vulnerability drill**. This intentionally starts NEW test data, not a normal expedition: **seed 20**, **C4 Medic acts first**, **C1 Breacher has 0 HP / DOWNED**, **C3 Ranger has 100 strain / SHAKEN**, and **10 power** remains.
2. Select **Field patch → C1**. C1 returns to **8 HP**, DOWNED disappears and the Medic spends one of two healing uses. Overcharge is disabled while Field patch is selected.
3. The revived **C1 Breacher** gets its unused turn: choose **Wait**. Then **C2 Technician → Wait**. Let the enemy turn finish. On **C3 Ranger's turn**, select **Covering shot** and turn **Overcharge ON**. The target preview includes both Shaken and Overcharge: **6–9** damage against an unprotected, sufficiently healthy enemy instead of the Shaken-only **4–6**. Toggling alone must not spend power.
4. Click **E4 Needle Turret**. Power falls from **10 to 0**, the attack resolves once, and the next turn begins. Overcharge becomes unavailable at zero power; ordinary actions and Wait still work. Double-clicking must not spend another charge or grant another action.
5. Click **Fresh expedition**. The default seed is restored (1729 unless you changed it in the Inspector), crew are full-health with zero strain, and power is 100. This is an explicit test reset, not a resurrection of the prior crew.

### Death and strain checks

- **Death:** click Vulnerability drill again, then use Wait on each crew turn without healing C1. Further damage to C1 removes them, closes ranks and adds **C1** to the persistent **DEAD** list. Healing cannot select that missing individual. Keep waiting: when no conscious crew remain, **DEFEAT** appears, all deployed crew are listed as dead, and **Next battle** is disabled.
- **Strain relief:** restart the drill and choose **Steady voice → C3** on the opening Medic turn. Strain becomes **80**, but SHAKEN remains. Use Steady voice on C3 on subsequent Medic turns, keeping the crew alive: **60** still means Shaken; **40** clears it. At exactly **50**, Shaken remains (the automated boundary test checks this). No strain is gained simply because power is low during a turn: it is applied on entering a room.
- **Victory recovery:** if a downed ally survives until the last enemy dies while another crew member is conscious, the downed survivor recovers to **1 HP**. Dead crew stay dead. This is also covered by a controlled native rules test; it may require several attempts to arrange manually.

### Between-battle persistence

1. Click **Fresh expedition**, fight a patrol to victory using legal attacks and healing, and note the surviving crew IDs, formation, HP, strain, Shaken markers, DEAD list and power. The existing class opening below is still valid with Overcharge OFF.
2. Click **Next battle / −5 power**. A test corridor spends 5 power (clamped at zero), then the same patrol starts with the survivors' health, strain, Shaken, deaths and formation preserved. Temporary statuses clear and Field patch has **2 uses** again. A second click cannot start another battle or deduct another corridor cost.
3. Room entry uses power **after** that cost: **50+ → +0 strain; 25–49 → +2; below 25 → +5** to each surviving crew member. The header shows the current pressure tier. Power at zero does not automatically cause defeat. Spend power on Overcharge during a winning battle to exercise lower tiers on the next entry.
4. The control is unavailable during combat and after defeat. **Fresh expedition**, patrol switch, Vulnerability drill, Back to Hub, Main Menu or closing the app abandons this isolated battle-test session. Explore Ship uses a separate owned expedition; hub/save persistence comes in milestones 7–8.

Read the two rule lines at the bottom and hover the power label for thresholds. All numbers used by these rules are editable in `res://content/balance.tres`. The drill is a test aid; ordinary expeditions still start with healthy, unshaken crew and 100 power.

## Existing class and formation playtest

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
| Strain enemy / relief | Click **Boarding patrol / switch** to restart as **Signal patrol**. E3 becomes Signal Echo. Wait until it raises crew strain; on the Medic's turn choose Steady voice → an ally with Str above zero. Str decreases by up to 20; Shaken and persistence now follow the M5 rules above. |
| Enemy roles | Boarding patrol: Mauler hits front, Bulwark protects another enemy, Tow Drone pulls rear crew forward, Needle Turret attacks rear crew. Signal patrol replaces only the Tow Drone with a strain attacker. Displaced enemies can use a weak fallback attack instead of choosing illegal targets. |
| Victory / defeat | Fight using legal attacks, use Move to recover useful ranks, and heal injured crew. Both patrols can be won. Fresh expedition then Wait on every crew turn loses. Outcomes are terminal; downed crew remain until healed or killed, and a fresh test creates new individuals. |
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

The battle owns its controller, enemy-delay Timer and in-memory ExpeditionState. There are no autoloads or campaign services yet. The Timer pauses briefly before each enemy action, but does not calculate damage. The rule objects and crew records are `RefCounted` objects, not scene nodes, so the rules can run in tests without loading a battle scene.

### Change actor values in the Inspector

1. Stop the game. Open `res://content/actors/breacher.tres` (or another class/enemy) in the FileSystem dock. Inspect **Max Health**, **Speed**, and **Abilities**. These are shared templates, not changing battle state.
2. Open `res://content/abilities/field_patch.tres`, `cutting_beam.tres` or `breach_strike.tres`. Inspect **Actor Ranks**, **Target Ranks**, **Damage Min/Max**, **Max Uses**, and expand **Effects**. Status durations/amounts are in `res://content/statuses/`; strain cap and AI preferences are in `res://content/balance.tres`. Descriptions are authored text: update them if tuning numbers.
3. For an optional experiment, record the original value, change a damage value or rank list, save, and run a new battle. The UI should use the new requirements. Restore original values afterward so tests and this walkthrough match.
4. In `battle_test.tscn`, select **BattleController** to inspect **Battle Seed** (1729). Restart resets both initiative and damage randomness to that seed.

`ContentCatalogue` explicitly preloads the actor files, which explicitly reference their attacks. Each combat actor has independent mutable values; rules copy health, strain, Shaken and death back to its CrewState record. Temporary statuses/use counters are battle-local. Formation and initiative track stable IDs separately. See [COMBAT_RULES.md](COMBAT_RULES.md) for interfaces and resolution order.

## Automated checks

There is no test-framework dependency. `tests/run_tests.gd` runs rules without scenes; `tests/setup_smoke.gd` exercises the actual scenes, controller, navigation, and layout. Run these commands from the project folder, one at a time:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/setup_smoke.gd
```

Expected: import exits 0 without project errors; both suites report **0 failures**, with **engine errors = 0** for the rules runner, and exit 0. Current measured counts and exact log paths are in PROGRESS.md. The suites retain earlier checks and add downed/revival/death, Shaken and power boundaries, persisted crew records, repeated Overcharge/next-battle input, and equal outcomes at different presentation speeds.

Use `run_tests.gd` as the entry point, not `combat_rules_test.gd`. The runner loads the suite after installing an engine error monitor so a script error cannot masquerade as a passing test. Check output as well as exit codes, particularly during import.

For real Compatibility-renderer checks and screenshots (opens a window briefly and exits):

```powershell
New-Item -ItemType Directory -Path '.artifacts' -Force | Out-Null
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/setup_smoke.gd -- --capture
```

Expected: **0 failures**, exit 0, with screenshots in `.artifacts/`, including every class skill, both patrols, downed healing targets, Overcharge, combined statuses and outcomes at both target sizes. Controlled skill/status screenshots use test fixtures; full patrol battles use natural turns. Filenames identify the requested window size; the 1280×900 captures contain the 1280×720 viewport, excluding the Window's black bars.

To confirm failure exit behaviour:

```powershell
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-failure
$LASTEXITCODE
& '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_tests.gd -- --self-test-script-error
$LASTEXITCODE
```

Expected: the first command prints **1 intentional failure**, exit **1**. The second prints **0 assertion failures**, then one intentionally injected parse error, **engine errors = 1**, exit **1**. Neither option should be used for a normal passing run. The malformed script exists only in memory; no broken project file is written. See [Godot's command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

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

**Next milestone, only after acceptance playtesting and when requested:** milestone 7, persistent hub and complete expedition return loop.
