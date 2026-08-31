# Core Loop and State Machine

Status: canonical flow contract

## High-level flow

```text
Boot
  -> Title
  -> Flight School [first launch only]
  -> Launch Bay
  -> Active Run
       -> Wave Combat
       -> Boss Encounter [every fifth wave]
       -> Stat Allocation [after fifth-wave clear]
       -> Elite Choice [elite milestones]
       -> Wave Combat
       -> Expedition Complete [after Wave 20]
            -> Endless Run
            -> Hangar / Title
       -> Try Again [when lives reach zero and stock remains]
       -> Game Over [when the run is finalized]
  -> Hangar / Settings
```

## State definitions

| State | Entry condition | Simulation | Allowed player actions | Exit condition |
|---|---|---|---|---|
| `boot` | Application starts | Not running | None | Initialization complete |
| `title` | Boot or return from a run | Not running | Launch, Hangar, Settings, Flight School | Player selects a destination |
| `flight_school` | First launch or replay request | Not running | Advance, skip, replay | Completed or skipped |
| `launch_bay` | Start Run selected | Not running | Select ship, modifiers, supplies | Launch confirmed or back |
| `active_run` | Loadout launched | Running | Move, aim, shoot, boost, pause | Pause, milestone, defeat, victory |
| `pause` | Pause action | Frozen | Resume, restart, settings, main menu | Resume or destination selected |
| `boss_encounter` | Boss wave begins | Running | All run actions | Boss defeated or run defeat |
| `stat_allocation` | Fifth-wave milestone cleared | Frozen | Spend allocation points | All points spent or confirmed |
| `elite_choice` | Elite milestone cleared | Frozen | Choose one available upgrade | Choice confirmed |
| `try_again` | Lives reach zero with stock | Frozen | Spend stock or decline | Restarted or game over |
| `expedition_complete` | Wave-20 boss defeated | Frozen/resumable | Continue Endless or return | Chosen destination |
| `game_over` | Final defeat or run exit | Not running | Review results, continue | Return to Hangar/title |
| `hangar` | Opened from title or result | Not running | Purchase, equip, review | Back or Launch |
| `settings` | Opened from title or pause | Depends on parent | Change supported settings | Back |

## Transition rules

- Only `active_run` and `boss_encounter` advance simulation time.
- Pausing freezes movement, cooldowns, timers, projectiles, hazards, and review harnesses.
- A modal decision may not consume the input that opened it.
- Stat allocation and elite choice must be idempotent: confirming twice cannot apply a reward twice.
- Finalizing a run must be idempotent: salvage, lifetime statistics, and milestone rewards are banked once.
- Restarting a run creates fresh run state and clears all run-scoped upgrades, timers, projectiles, hazards, and caches.
- Returning to the title clears active combat objects and restores the title presentation profile.

## Run event sequence

```text
run_started
  -> wave_started
  -> enemy_spawned / projectile_fired / power_up_spawned
  -> enemy_killed / xp_orb_collected / power_up_collected
  -> wave_cleared
  -> boss_spawned [when applicable]
  -> boss_died
  -> allocation_triggered and/or elite_upgrade_triggered
  -> next wave_started
  -> expedition_completed OR player_hit until game_over
  -> run_finalized
```

## Stable event names

Implementations may use signals, delegates, events, messages, or callbacks, but these meanings should remain stable:

`run_started`, `run_paused`, `run_resumed`, `wave_started`, `wave_cleared`, `boss_spawned`, `boss_died`, `enemy_killed`, `player_hit`, `projectile_reflected`, `xp_orb_collected`, `power_up_collected`, `allocation_triggered`, `elite_upgrade_triggered`, `expedition_completed`, `game_over`, and `run_finalized`.
