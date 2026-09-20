# Candidate performance protocol

Slice 08 implements a repeatable workload and evidence capture. Windows minimum
specification, long-session stability, and platform compatibility remain acceptance
work. A source/headless check establishes harness behavior; a local Mac release
runtime measurement establishes behavior on that recorded Mac configuration.

## Workload: candidate-pressure-v1

Use the defaults for the initial comparison: three identical configured cycles,
1280 × 720, High graphics, VSync off, unlimited frame cap, seed 8026, two seconds
of warmup per workload, ten sampled simulation seconds per combat stage, and
sixty sampled simulation seconds of Endless per cycle. This is a six-minute
combat protocol, plus warmup and transitions; it does not replace a long session.

Each cycle visits the real menu, initializes a native run, and exercises:

- Generation four at Wave 24 with two each of basic, fast, bomber, tank, and
  sniper enemies. The fixture replenishes that population once per simulation
  second, bypassing normal encounter budgets to sustain pressure.
- The third phase of Assault Commander, Iron Bulwark, Tempest, Tempest Core,
  and Void Harbinger, using their actual movement, attack selection and ordnance.
- Wave 55 with the same sustained generation-four workload for the longer
  Endless window. This deliberately fixes composition; natural Endless escalation
  and an uninterrupted player session remain separate checks.

The Swallowtail moves along a fixed input pattern while firing with homing,
piercing, explosive rounds, escort drones, twin cannons, elite spread and
overclock enabled. Cluster/plasma mines, seeker fragments and plasma fields are
requested every second through the normal bounded hazard manager. Invulnerability
and durable enemy/boss health keep the fixture alive; these are measurement aids,
not evidence of game balance. Boss selectors receive explicit per-boss seeds;
their committed attack IDs and simulation timestamps are retained. Physics step
count and target movement can still vary with render scheduling: compare the
recorded workload and attack sequences before interpreting a performance delta.

After combat, the real pause menu's confirmed restart path replaces the run.
Retry timing begins at that trigger and ends when replacement gameplay and
encounters are ready, followed by three settling frames. The benchmark sets
practice/no-reward flags before every new run's `_ready()`. It then frees the
replacement, waits four frames, prunes stale pooled references, drops sampler
buffers, and records cleanup. The harness stays idle until the host acknowledges
its RSS measurement, so the next menu cannot contaminate the cleanup sample.

## Capture and interpretation

Record OS/build, CPU/GPU, physical RAM, power mode, engine hash, driver, resolution,
graphics, frame cap, VSync, seed, durations, upgrades, source revision/dirty state,
PCK hash and runtime hash. The report retains raw frame samples, counters, logs,
configuration, a viewport PNG and checksums alongside its summary.

Frame intervals use a monotonic clock between complete process callbacks.
Nearest-rank p50/p95/p99, mean FPS, maximum interval and >50 ms hitch counts use
every sampled interval. No outlier clipping or shader-hitch exclusion is allowed.
Warmup has separate raw samples; initialization, restart and menu setup are timed
separately. The first partial callback interval is not a complete frame and is
not sampled. Snapshot queries run every 0.5 seconds and add observer overhead.

For the proposed 60 FPS target, compare p95 against 16.67 ms and flag any pair of
>50 ms combat intervals within 30 seconds inside a stage. This is a diagnostic
threshold, not automatic acceptance. Review shorter isolated spikes, warmup,
scene transitions, workload coverage and player-visible smoothness as well.
There are no preapproved gameplay hitch exceptions. Revisit these thresholds
with the release owner before declaring minimum hardware.

Counters distinguish process RSS (external resident working set), renderer
allocation bytes, and Godot static allocations. Do not add them together,
especially on unified-memory hardware. Godot's static/orphan counters are debug
only; unavailable release/headless values stay `null`. Renderer allocation bytes
are not measured GPU execution time or an independent physical VRAM reading.
Monitor-based snapshots may lag and miss short-lived peaks. [Godot Performance
reference](https://docs.godotengine.org/en/4.6/classes/class_performance.html)
documents the monitor availability and update limitations. System physical RAM
comes from [OS.get_memory_info](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-get-memory-info);
it is never substituted for process RSS.

The first cycle includes cold initialization; later cycles expose retained caches.
Investigate unexplained monotonic growth after warmup across nodes, objects,
resources, allocations and acknowledged RSS snapshots. A flat three-cycle result
does not certify a leak-free long session. Keep engine shutdown diagnostics in
the evidence; do not count a completion event as clean teardown. Runtime errors,
pauses, incomplete/reordered workloads, missing fire/hazards, timeouts and malformed
telemetry invalidate a capture. Shortened runs remain explicitly labeled pilots.

`--allow-background` is a separate diagnostic mode for a host being used during
the capture. Only this mode bypasses the run's focus-loss pause; gameplay pauses,
window close, controller interruption and runtime failures still invalidate it.
Every stage records unfocused frame counts. Background captures are labeled
`background_rendered_diagnostic` and cannot establish the Windows foreground
target even if their frame numbers look favorable. OS throttling/occlusion can
affect their timing. Use them for workload, release integration and cleanup checks.

Benchmark exports enable immediate stdout flushing, so the host receives events
before the cleanup acknowledgement deadline. Godot normally buffers release
stdout; this override is confined to the benchmark package. [Godot setting
reference](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-run-flush-stdout-on-print)

## Commands

Use the pinned engine and templates in `tools/godot_release.json`. Keep the game
window focused and unobscured, record power mode, and close competing games or
benchmarks. Each output directory must be new so earlier evidence is preserved.

```sh
python3 tools/run_performance.py --godot "$GODOT_PATH" --headless \
  --cycles 2 --seconds 1 --warmup-seconds 0.2 --endless-seconds 2 \
  --output .godot/performance-functional

python3 tools/export_release.py --godot "$GODOT_PATH" --benchmark \
  --output builds/performance-candidate

python3 tools/run_performance.py --build builds/performance-candidate \
  --output .godot/performance-windows-high-720 \
  --power-state "AC; record Windows power mode here"
```

`--allow-dirty` on the exporter is for local validation only and is recorded in
`build.json`. `--git` selects the Git executable where needed. `--quality`,
`--resolution`, `--cycles`, `--seconds`, `--warmup-seconds` and `--endless-seconds`
are explicit configuration changes, not equivalent comparison runs.

`--runtime /absolute/path/to/a/matching/release-template` can execute the same
PCK locally on another desktop OS. The runner copies the runtime and PCK into a
temporary directory under matching basenames; official release templates disable
`--main-pack`. This checks that local engine/driver, not the Windows executable.
The full engine version must match both the lock and package metadata, and a
debug template is rejected for package measurements. Retain the original template
archive's verified hash when provisioning this runtime.

Benchmark exports have a dedicated main scene, feature flag and unique private
profile. The normal Windows/Linux presets exclude `benchmarks/**`; package
inspection rejects benchmark resources unless explicitly inspecting a benchmark
build. Benchmark inspection still rejects unlisted developer helpers. Source
checks use disposable project settings and profiles; an exported benchmark keeps
its separate `farinuff-performance-*` profile, identified in its metadata.

## Target hardware acceptance

On the proposed Windows minimum machine, run the exact identified benchmark
package at the proposed shipping preset, repeat after a cold process launch,
then compare the supported presets and resolutions. Retain driver/power details,
raw samples, warmup hitches, captures, and real executable execution evidence.
Run an extended Endless session and more repeated cycles to investigate trends;
choose a wall timeout that permits the configured simulation duration on a slow
machine. Inspect the production candidate separately for cold startup, input,
natural session pacing, aspect-ratio fairness and update behavior. Neither this
stress fixture nor Mac results resolve those gates.
