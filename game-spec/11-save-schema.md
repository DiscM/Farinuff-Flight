# Save and Persistence Specification

Status: reference persistence contract

## Persistence policy

The current design persists durable progression and settings, not an in-progress combat run. A future implementation may add run resume only through an explicit design decision and schema revision.

## Portable payload

The following is the conceptual schema. A target may serialize it as JSON, binary, a platform save object, or another format.

```yaml
version: 2
high_score: integer >= 0
salvage: integer >= 0
unlock_levels: map<string, integer >= 0>
selected_ship: string content_id
active_modifiers: list<string content_id>
consumable_stocks: integer 0..3
consumable_powerup: boolean
claimed_milestones: list<integer wave>
stat_total_runs: integer >= 0
stat_total_kills: integer >= 0
stat_best_wave: integer >= 0
has_seen_flight_school: boolean
settings:
  master_volume: number 0..1
  music_volume: number 0..1
  screen_shake: boolean
  crt_effect: boolean
  screen_distortion: boolean
  alt_controls: boolean
  fullscreen: boolean
  reduced_flashing: boolean
```

## Invariants

- Unknown content IDs are ignored or sanitized to a safe default.
- Negative currency, statistics, and stockpiles are clamped to valid values.
- Duplicate active modifiers and claimed milestones are removed.
- The default ship remains selectable even when a save is damaged.
- Settings are accepted only when their type and range are valid.
- A purchase, milestone claim, or consumable consumption is committed once.
- Save failure never reports success to the player.

## Write protocol

1. Validate and serialize the complete current payload.
2. Write to a temporary file or transaction.
3. Flush and close the temporary payload.
4. Rotate the previous valid payload to a backup.
5. Promote the complete temporary payload to the live location.
6. Restore the backup if promotion fails.

The target platform may use a different API, but it must provide equivalent crash-safety and recovery behavior.

## Read protocol

1. Read and parse the live payload.
2. Reject malformed or unsupported future versions without overwriting them.
3. If the live payload is invalid, try the last-known-good backup.
4. Apply migrations in ascending order.
5. Validate types, ranges, IDs, and duplicates.
6. Use safe defaults only for fields that remain unavailable.

## Migration record

Every schema change should add a record here:

| From | To | Change | Migration | Test |
|---:|---:|---|---|---|
| 1 / missing | 2 | Added first-run Flight School flag and additive progression fields | Fill defaults; convert legacy purchased-unlock list to level-1 map | Malformed, legacy, and future-version fixtures |

Future migrations must not silently discard a player's valid progress.
