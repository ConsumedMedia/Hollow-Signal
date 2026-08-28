# Milestone 6 exploration contract

Godot import and native rules/headless/rendered scene checks pass after the room Resource declaration fix. The user reported general playtest success; individual physical acceptance checks were not separately reported. See PROGRESS.md for actual results and limitations.

## Ownership

- `ShipDefinition`, eight `RoomDefinition` Resources, `ItemDefinition` and `ItemDrop` hold authored content only. `ContentCatalogue.SHIP` is an explicit preload, not an editor directory scan.
- `ExpeditionState` owns the graph reference, current room, pending destination/encounter, `RoomState` records, persistent crew, shared power, inventory and pending loot. There is no global campaign state or save service.
- `InventoryState` owns up to twelve `ItemStack` records. Item definitions are shared; stack quantities are not. Scrap stacks to 5, wafers to 3, cells to 3. Cells restore 25 power outside combat only.
- `expedition.tscn` owns the expedition throughout corridor and battle presentation. It embeds the existing battle scene as a child and supplies the same expedition object before that child's `_ready`. Test reset/navigation controls are hidden during expedition combat. No combat arithmetic moved into the exploration scene.

## Travel and events

The main route is Airlock–Receiving–Junction–Safe room–Containment–Signal core. Junction–Salvage bay–Pressure breach is optional. Every link is bidirectional. Receiving, Junction and Containment are regular combat rooms; Signal core uses a single existing Relay Bulwark as a boss placeholder.

`begin_travel` validates adjacency, resolved current room, no active fight/transition/failure and no pending cargo. It deducts the balance-defined 5 power once and records the destination. `arrive` commits that destination, marks it visited and applies room-entry strain using remaining power. Duplicate begin/arrival calls do nothing. The native corridor tween and Skip button call the same arrival path; animation never consumes RNG or resolves combat.

Combat rooms lock travel until victory. `begin_encounter` reserves the room; combat receives a deterministic seed assigned when the expedition is created. `finish_encounter` requires a terminal battle from this expedition and this room. It clears the reservation and awards room loot once on victory. A stale result from a different room is rejected. Defeat preserves all permanent losses and prevents further exploration.

Salvage and hazard choices either accept or leave the event. Either choice resolves it once. Searching the hazard adds its authored 12 strain and loot; sealing it gives neither. One safe-room rest heals 12 and reduces strain by 30 for survivors, respecting health caps and Shaken hysteresis. Dead crew never recover. Backtracking consumes power without resetting events or rewards.

## Overflow decisions

Room resolution queues fresh runtime copies of authored drops, then fills matching partial stacks and empty slots. Excess remains in `pending_loot`; it is not discarded. Travel is blocked until the player explicitly decides. Confirming removal of a stored stack frees space for pending cargo. Confirming Leave incoming cargo discards only the displayed remaining item quantity. Both dialogs show exactly what will be lost; cancelling changes nothing. Using a cell outside battle can also free a slot. No thirteenth slot is created.

Resolved flags are set before the loot decision, so repeated inspection/return cannot enqueue another reward. Full-stack discard is intentional: splitting stacks and item trading are outside this milestone. Inventory items are cargo, not an implemented hub currency/equipment system.

## Scope and testing

No procedural maps, platforming, physics combat, campaign roster, retreat payout, equipment modules, save/load, final boss mechanics or ending were added. End test/ESC explicitly abandons the in-memory expedition outside locked transitions; closing the app also loses it. New Game still opens a placeholder hub.

Native rules tests cover graph connectivity, optional-branch independence, travel costs/locks, one-time rewards, overflow, cells, hazard/rest choices, combat transfer and a full main-route simulation. Native scene tests cover both target sizes, corridor skip/natural completion, embedded combat and return, and overflow confirmation. Current combined suites pass 287 rules, 517 headless scene and 744 rendered scene checks; the runner also checks all eight room declaration orders before loading the catalogue. GUI inputs and overflow fixtures are automated, not physical full-route playtesting. See PROGRESS.md for evidence.
