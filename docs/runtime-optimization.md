# Runtime optimization validation

Run preparation is measured with `tests/run_warmup_benchmark.tscn`. The scene
uses the production encounter preparation and combat pools, disables rewards
and supply consumption, and exits as soon as gameplay is ready. It prints
elapsed preparation time, process frames, node count, and static memory.

```sh
"$GODOT_PATH" --headless --max-fps 60 --path . res://tests/run_warmup_benchmark.tscn
"$GODOT_PATH" --max-fps 60 --path . res://tests/run_warmup_benchmark.tscn
```

The timer starts in `_ready()`: it includes pool and encounter preparation,
but excludes process startup, scene loading, and initial scene instantiation.
Headless results do not measure shader compilation or rendered frame rate.
Static memory is Godot's allocator measurement, not process RSS or GPU memory.

Baseline on 2026-09-06, Godot 4.6.3, Apple A18 Pro, 60 FPS cap:

| Mode | Preparation | Frames | Nodes | Static bytes |
| --- | ---: | ---: | ---: | ---: |
| Headless baseline | 3940.38 ms | 235 | 7151 | 101565885 |
| Forward+ Metal baseline | 4038.86 ms | 235 | 7151 | 98845050 |
| Headless optimized | 370.42 ms | 22 | 7152 | 101843328 |
| Forward+ Metal optimized | 1113.36 ms | 29 | 7152 | 98519114 |

The rendered preparation measurement improved by 72.4%. The additional node
is the resource cache autoload. Memory measurements vary between runs; these
results do not establish a reduction in total process or GPU memory.

## Changes

- Pool warmup yields after approximately 4 ms of synchronous work instead of
  sleeping a frame after every 4–8 objects. An individual instantiation or
  render can exceed that budget. Visual warmup and final deferred-return
  synchronization remain in place.
- The menu begins loading the run while players browse or choose a loadout.
  A two-entry allowlist retains the menu and run PackedScenes across retries.
  Only resources are retained: each run still gets a fresh gameplay tree.
- Projectile and pickup checkout removal uses an index map and swap removal.
  Homing and radius effects reuse an enemy registry; projectile radius clears
  use manager-owned checkouts instead of new SceneTree group arrays.
- The object pool caps idle retention per scene and globally, skips nodes
  queued for deletion, and removes stale weak references under pressure.
  Effect/hazard preparation uses stable snapshots across deferred returns.

## Regression coverage

`native_completion_smoke.tscn` covers gameplay, native upgrades, projectile
reuse, registry cleanup, and all five boss variants. `pooling_smoke.tscn`
checks idle-parent teardown and stale references. Existing autoload and VFX
smoke tests and both Python resource-contract checks remain applicable.
`resource_cache_smoke.tscn` verifies paused background loading, request
deduplication, fresh run instances, and the two-resource retention limit.
These smoke scenes and the preparation benchmark are included in CI.

These are individual local runs, not hardware-wide performance guarantees.
Baseline shutdown reports two shader allocations left alive; the rendered
baseline also reports texture cleanup warnings. Track these separately from
gameplay regressions.
