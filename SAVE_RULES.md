# Hollow Signal — Save contract

Milestone 8 uses one versioned JSON campaign checkpoint and one known-good backup under `user://`. `SaveCodec` converts only game records and authored content IDs; nodes, animations, timers, particles, and audio state are never serialized.

## Files and replacement

- Main: `user://hollow_signal_save.json`
- Temporary write: `user://hollow_signal_save.tmp`
- Backup: `user://hollow_signal_save.backup.json`

Before replacing the main file, the service encodes the campaign, decodes that data into fresh records, writes the temporary file, reads it back, and validates it again. A valid existing main file becomes the backup. A corrupt or unsupported main file is not overwritten by autosave. Confirming **New Game** is the explicit replacement path.

## Checkpoints

The game checkpoints at the hub, after hub mutations, deployment, room arrival, resolved room choices and cargo decisions, battle entry, battle resolution, and expedition return. Mid-corridor presentation is not saved; the preceding room-boundary checkpoint remains valid.

At battle entry, the unresolved room ID and its exact decimal seed are saved before the battle scene exists. Loading that checkpoint constructs fresh campaign and expedition records, then starts the encounter from its entry health, strain, power, formation, cargo, and seed. Actions or animations that happened after entry are intentionally replayed by the player.

## Validation and recovery

Version 1 validates known actor, item, module and room IDs; unique crew/party/equipment ownership; health, death, strain and upgrade consistency; currency; expedition formation and locations; room visited/resolved flags; cargo limits; outcomes; and integer seeds. The live `CampaignService.state` is replaced only after a complete decode succeeds.

The main menu disables **Load Campaign** for damaged or unsupported data. If the known-good backup validates, **Recover Known-Good Backup** appears. Unsupported versions are reported and remain untouched unless the player explicitly confirms New Game.
