# Content Data

Status: portable reference catalogs

The files in this folder are engine-neutral seed data. A target engine may convert them into Resources, ScriptableObjects, DataAssets, JSON, tables, or another native format, but the stable IDs and player-facing meanings should remain unchanged.

## ID convention

Use uppercase, dot-separated IDs in the portable layer:

- `ENEMY.BASIC`
- `BOSS.TEMPEST_CORE`
- `POWERUP.RAPID_FIRE`
- `UPGRADE.TWIN_CANNONS`
- `META.HULL`
- `MOD.RAPID_ASSAULT`

An implementation may use another identifier syntax internally, but it must keep a mapping to the portable ID.

## Data rules

- Numbers in these files are reference tuning, not an excuse to hide formulas in code.
- Formulas and state transitions belong in `03-gameplay-rules.md` and `05-progression-and-economy.md`.
- `tuning_status: needs_extraction` means the current project has behavior but not a complete portable table yet.
- `acquisition_status: needs_confirmation` means the current project contains the mechanic, but its player-facing acquisition route still needs to be formalized.
- Display names, descriptions, colors, and role labels are content data and should not be duplicated across UI code, previews, and debug tools.
- When one mechanic has multiple acquisition routes, define its effect once and use reference entries for the alternate route.
- Asset filenames are not public IDs. Use a manifest or mapping layer when a port changes formats.

## Catalog completion checklist

- [ ] Every entry has a stable ID and display name.
- [ ] Every tunable value has a unit and a valid range.
- [ ] Every effect names its scope: momentary, run-long, or persistent.
- [ ] Every random choice has a seedable test path.
- [ ] Every entry has a visual role, audio role, and acceptance scenario where applicable.
- [ ] Any intentional port-specific deviation is recorded in the implementation profile.
