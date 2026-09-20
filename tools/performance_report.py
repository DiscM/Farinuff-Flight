"""Validate benchmark completion and summarize raw, explicitly scoped metrics."""

import math

STAGES = ("late_generation", "boss_assault", "boss_bulwark", "boss_tempest",
          "boss_core", "boss_harbinger", "endless")


def percentile(values: list[float], fraction: float) -> float:
    """Nearest-rank percentile; retain outliers, including shader hitches."""
    if not values or not 0 < fraction <= 1:
        raise ValueError("Percentile requires samples and a fraction in (0, 1]")
    return sorted(values)[math.ceil(len(values) * fraction) - 1]


def summarize(events: list[dict], rss: list[dict]) -> dict:
    """Reject incomplete/malformed telemetry instead of printing a partial pass."""
    try:
        return _summarize(events, rss)
    except (KeyError, TypeError, IndexError, OverflowError) as error:
        raise ValueError("Malformed benchmark telemetry: " + str(error)) from error


def _summarize(events: list[dict], rss: list[dict]) -> dict:
    if not events or events[0].get("kind") != "metadata":
        raise ValueError("Missing initial benchmark metadata")
    if any(e.get("version") != 1 for e in events):
        raise ValueError("Unsupported telemetry version")
    if any(e.get("kind") == "failure" for e in events):
        raise ValueError("Benchmark reported a workload failure")
    if events[-1].get("kind") != "complete" or sum(e.get("kind") == "complete" for e in events) != 1:
        raise ValueError("Incomplete benchmark; partial samples are not a pass")
    metadata = events[0]["payload"]
    cycles_value = metadata["config"]["cycles"]
    if isinstance(cycles_value, bool) or cycles_value != int(cycles_value) or not 1 <= cycles_value <= 20:
        raise ValueError("Invalid cycle count")
    cycles = int(cycles_value)  # Godot's JSON reader represents numbers as floats.
    expected = [(c, name) for c in range(cycles) for name in STAGES]
    if sum(e["kind"] == "metadata" for e in events) != 1 or metadata["scenario"] != "candidate-pressure-v1":
        raise ValueError("Unexpected scenario or duplicate metadata")
    if events[-1]["payload"]["cycles"] != cycles:
        raise ValueError("Completed cycle count differs from configuration")
    stages = [e["payload"] for e in events if e["kind"] == "stage"]
    if [(s["cycle"], s["name"]) for s in stages] != expected:
        raise ValueError("Missing, duplicate, or reordered workload stages")
    warmups = [e["payload"] for e in events if e["kind"] == "warmup"]
    if [(s["cycle"], s["name"]) for s in warmups] != expected:
        raise ValueError("Missing warmup evidence")
    transitions = [e["payload"] for e in events if e["kind"] == "transition"]
    if [(s["cycle"], s["name"]) for s in transitions] != [(c, name) for c in range(cycles) for name in ("menu", "launch", "retry")]:
        raise ValueError("Missing menu/launch/retry evidence")
    cleanups = [e["payload"] for e in events if e["kind"] == "cleanup"]
    if [c["cycle"] for c in cleanups] != list(range(cycles)):
        raise ValueError("Missing cleanup/cycle evidence")
    result = []
    for stage in stages:
        values = stage["frame_intervals_ms"]
        if len(values) < 2 or any(isinstance(v, bool) or not isinstance(v, (float, int)) or not math.isfinite(v) or v <= 0 for v in values):
            raise ValueError("Invalid wall-clock frame samples")
        duration = metadata["config"]["endless_seconds" if stage["name"] == "endless" else "seconds"]
        if not math.isfinite(duration) or duration <= 0 or not math.isfinite(stage["simulation_seconds"]) or stage["simulation_seconds"] + 1e-6 < duration or not stage["counters"]:
            raise ValueError("Workload did not complete its configured simulation duration")
        if stage["name"].startswith("boss_") and stage["boss_phase"] != 2:
            raise ValueError("Boss workload did not exercise its third phase")
        counters = stage["counters"]
        player_shots = counters[-1]["projectiles"]["player"]["shots_fired"] - counters[0]["projectiles"]["player"]["shots_fired"]
        enemy_shots = counters[-1]["projectiles"]["enemy"]["shots_fired"] - counters[0]["projectiles"]["enemy"]["shots_fired"]
        if player_shots <= 0:
            raise ValueError("Player fire workload is missing")
        if max(c["enemies"] for c in counters) < (1 if stage["name"].startswith("boss_") else 10) or max(c["hazards"]["total_active"] for c in counters) < 2:
            raise ValueError("Enemy or simultaneous hazard workload is missing")
        if duration >= 10 and enemy_shots <= 0:
            raise ValueError("Enemy ordnance did not run during the full workload window")
        if stage["name"].startswith("boss_") and duration >= 10 and (not stage["boss_attacks"] or not stage["boss_selection_seed"]):
            raise ValueError("Seeded boss attack evidence is missing")
        times = []
        elapsed = 0.0
        for interval in values:
            elapsed += interval
            if interval > 50:
                times.append(elapsed)
        repeated = any(b - a <= 30000 for a, b in zip(times, times[1:]))
        p95 = percentile(values, .95)
        result.append({
            "cycle": stage["cycle"], "name": stage["name"], "frames": len(values),
            "wall_seconds": sum(values) / 1000, "simulation_seconds": stage["simulation_seconds"],
            "mean_fps": len(values) * 1000 / sum(values), "p50_ms": percentile(values, .5),
            "p95_ms": p95, "p99_ms": percentile(values, .99), "max_ms": max(values),
            "hitches_over_50_ms": len(times), "repeated_hitches_within_30s": repeated,
            "meets_frame_targets": p95 <= 1000 / 60 and not repeated,
            "peak_projectiles": max(c["projectiles"]["active"] for c in counters),
            "peak_enemies": max(c["enemies"] for c in counters),
            "peak_hazards": max(c["hazards"]["total_active"] for c in counters),
            "player_shots": player_shots, "enemy_shots": enemy_shots,
            "unfocused_frames": stage.get("unfocused_frames", 0),
            "boss_attacks": stage.get("boss_attacks", []), "boss_selection_seed": stage.get("boss_selection_seed"),
            "pool_growth": max(c["projectiles"]["pool_growth_after_warmup"] + c["hazards"]["pool_growth_after_warmup"] + c["effects"]["pool_growth_after_warmup"] for c in counters),
        })
    available_rss = [x["rss_bytes"] for x in rss if x["rss_bytes"] is not None]
    memory = {}
    for field in ("nodes", "objects", "resources", "orphan_nodes", "static_bytes", "renderer_bytes"):
        values = [c["state"][field] for c in cleanups]
        memory[field] = {"by_cycle": values, "last_minus_first": values[-1] - values[0] if cycles > 1 and all(v is not None for v in values) else None}
    cleanup_rss = [e.get("process_rss_bytes") for e in events if e["kind"] == "cleanup"]
    memory["process_rss_bytes"] = {"by_cycle": cleanup_rss, "last_minus_first": cleanup_rss[-1] - cleanup_rss[0] if cycles > 1 and all(v is not None for v in cleanup_rss) else None}
    return {
        "schema": 1, "metadata": metadata, "stages": result,
        "transitions": transitions,
        "full_protocol_duration": cycles >= 3 and metadata["config"]["seconds"] >= 10 and metadata["config"]["warmup_seconds"] >= 2 and metadata["config"]["endless_seconds"] >= 60,
        "cleanup": memory, "rss_peak_bytes": max(available_rss) if available_rss else None,
        "classification": "headless_functional_check" if metadata["display"] == "headless" else ("background_rendered_diagnostic" if metadata["config"].get("allow_background", False) else ("source_debug_measurement" if metadata["debug_build"] else "release_runtime_measurement")),
        "target_windows_measured": metadata["os"] == "Windows" and not metadata["debug_build"] and metadata["display"] != "headless" and not metadata["config"].get("allow_background", False) and not any(s["unfocused_frames"] for s in result),
        "acceptance": "pending target-hardware review; frame comparisons alone do not establish minimum specification",
    }


def markdown(report: dict) -> str:
    meta = report["metadata"]
    rows = ["# Candidate performance measurement", "",
            f"{report['classification']} · {meta['os']} · {meta['cpu']} · {meta['gpu']} · {meta['driver']}", "",
            f"Full protocol duration: {report['full_protocol_duration']}. Settings: {meta['config']['quality']}, {meta['config']['resolution']}, VSync {meta['vsync']}, cap {meta['frame_cap']}. Power: {meta['config'].get('power_state', 'unrecorded')}.", "",
            f"Unfocused sampled frames: {sum(s['unfocused_frames'] for s in report['stages'])}. Background diagnostics are not foreground hardware acceptance measurements.", "",
            "Intervals use monotonic wall-clock time between process callbacks. They include waiting/stalls; they are not GPU execution timings.", "",
            "| Cycle | Workload | Mean FPS | p95 ms | p99 ms | Max ms | >50 ms |", "| --- | --- | ---: | ---: | ---: | ---: | ---: |"]
    for stage in report["stages"]:
        rows.append(f"| {stage['cycle'] + 1} | {stage['name']} | {stage['mean_fps']:.1f} | {stage['p95_ms']:.2f} | {stage['p99_ms']:.2f} | {stage['max_ms']:.2f} | {stage['hitches_over_50_ms']} |")
    rows += ["", "Targets: p95 ≤16.67 ms and no pair of >50 ms intervals within 30 seconds of sampled combat. Warmup and transitions are reported separately, never discarded from the raw record.", "",
             f"Process RSS peak: {report['rss_peak_bytes']} bytes. Renderer allocation counters and Godot static allocation counters are separate from RSS. Unavailable release/headless counters remain null.", "",
             "## Scene transitions", "", "| Cycle | Transition | Elapsed ms |", "| --- | --- | ---: |"]
    for transition in report["transitions"]:
        rows.append(f"| {transition['cycle'] + 1} | {transition['name']} | {transition['elapsed_ms']:.2f} |")
    rows += ["", f"External process startup timings: {report.get('external_startup_timings', {})}. These include process startup and event delivery; see raw records for each boundary.", "",
             "## Repeated-cycle cleanup", "", "| Counter | After each cycle | Last − first |", "| --- | --- | ---: |"]
    for key, value in report["cleanup"].items():
        rows.append(f"| {key} | {value['by_cycle']} | {value['last_minus_first']} |")
    rows += ["", "Repeated-cycle differences require investigation; a few stable cycles do not establish long-session memory stability.", "",
             "Runtime diagnostics (retained in runtime.log): " + str(report.get("diagnostics", [])), "", report["acceptance"], ""]
    return "\n".join(rows)
