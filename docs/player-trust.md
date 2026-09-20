# Player trust: storage, settings, and interruptions

Slice 07 engineering record, September 19, 2026. Source:
[production readiness plan, section 5](production-readiness-plan.md#5-production-engineering-and-player-trust).
The local changes and fault checks are implemented. M3 still requires release
package, physical-device, and hardware acceptance.

## Storage contract

| File in the Godot user directory | Schema | Contents |
| --- | --- | --- |
| `save_data.json` | 7 | Wallet, unlocks, loadout, consumables, records, lifetime stats, onboarding, and durable campaign discoveries/endings |
| `local_settings.json` | 1 | All audio, video, accessibility, story, and input preferences, including remapped bindings |

Each file has its own `.bak` and `.tmp`. The shared store flushes a temporary
file, retains the last valid committed file as backup, then promotes the new
file. An interrupted temporary file is never treated as committed state.
Recovering a damaged primary from backup and then saving preserves that good
backup. A newer schema in either primary or backup prevents that store from
overwriting it; a compatible backup may still be read.

Versions 1–6 continue to load. When no local preferences file exists, legacy
settings and bindings migrate first. If that write fails, the old progress
file remains intact and both settings and progress are reported as unsaved.
Established local preferences win over copied legacy progress. Once migration
is complete, preferences and progression save independently: an incompatible
settings backup cannot block compatible progression, and read-only progression
cannot block local preference changes.

Storage failures produce a persistent notice naming the affected store.
An OS close request during a run confirms that the run cannot resume, settles
earned rewards once, and saves before exiting. A failed final save keeps the
application open with **Retry Save** selected, or an explicit **Quit Without
Saving** action. Retrying writes the settled state without awarding it again.
Force termination cannot show this dialog; atomic file replacement protects
the previous committed state rather than guaranteeing unsaved rewards.

The new schema is not writable by the previous schema-6 build. Keep the newer
file when rolling back; the compatible backup is a recovery option, not a merge
of rewards earned in different versions. Automated rollback checks exercise the
version guard with real fixture files, not two exported Steam releases.

## Options and interruption behavior

| Option | Behavior |
| --- | --- |
| Low / Medium / High graphics | Low uses 75% 3D resolution with MSAA off; Medium uses native 3D resolution and 2× MSAA; High retains native resolution and 4× MSAA. UI and combat geometry are unchanged. |
| Frame limit | Unlimited, 30, 60, 120, 144, or 240 FPS; applied immediately |
| VSync | Independent on/off preference; actual pacing still depends on the display/platform |
| Combat HUD size | 100%, 115%, or 130%, independently from menu text; scales the combat header, power-up chips, boost information, and boss dock |
| Toggle fire | Optional press-to-start/press-to-stop shooting; hold-to-fire remains the default |

The existing volume, right-stick deadzone, rebinding, larger menu text, reduced
flashing/motion, shake/distortion, and hold-to-confirm controls remain available.
The hosted settings page keeps Close visible at 720p with 130% menu text.

Focus loss or disconnection of the active controller pauses active flight.
Interruptions during loading are remembered; interruptions while a reward is
closing lead to an explicit pause before combat resumes. Regaining focus does
not automatically resume. Fire latches clear on pause, rebinding, and switching between keyboard and
controller; firing and boost require a released button before a new press can act.
An unrelated controller disconnect does not interrupt flight.

Quit confirmation coordinates with reward completion and the Try Again timer.
Rewards may finish their closing animation, but cannot restart combat behind
the modal. The continuation countdown is suspended, and deferred end screens
wait until cancellation before mounting or taking keyboard focus.

## Cloud and session decision

**Keep Steam Cloud disabled for this implementation.** The split establishes a
storage boundary; it does not implement Cloud synchronization or account-aware
profiles. No Steam configuration or account was changed.

Before enabling Cloud, use only durable progress as the candidate synchronized
data. Keep `local_settings.json`, its backups, temporary files, logs, and device
configuration local. Decide backup/version-conflict handling explicitly before
selecting the final Cloud file rules. Test two machines, offline edits followed
by reconnection, conflicting progress, and two Steam accounts on a shared PC.
Current Godot user-directory storage alone does not provide Steam-account
separation. The release owner must accept that behavior before Cloud ships.

Runs remain memory-only. Session-length evidence from natural playtests must
precede a suspend/checkpoint decision. Demo-to-full policy and migration remain
with slice 09; this slice does not invent a separate demo namespace or import
progress without that product decision.

## Evidence and remaining acceptance

Godot `4.6.3.stable.official.7d41c59c4`, macOS, Apple A18 Pro, Metal Forward+.
Save-writing scenes use disposable profiles and restore both storage families.
No new smoke scenes or CI scene entries were added.

- Existing autoload checks exercise schema-6 migration, local settings priority,
  independent stores, corrupt primary recovery, interrupted writes, newer
  primary/backup protection, failed migration, retry, and malformed preferences.
- Existing audio/settings checks drive the actual controls and reopen preferences.
- Existing combat readability checks cover toggle/hold fire, held-button
  carryover, active/unrelated controller loss, startup/focus pause, cancelled
  close requests, failed final saves, retry without duplicate rewards, and
  persisted settlement.
- Existing Expedition journeys cover reward/quit/focus/controller overlap,
  deferred end-screen focus, countdown suspension, and successful continuation,
  alongside the 24 assisted hull/route/build journeys.
- HUD geometry and staged GPU captures cover 1280×720, 1920×1080, 1280×800,
  and 1920×810 with 130% HUD and all four power-up chips. Bounds are unchanged
  when HUD size changes at a fixed aspect ratio. This does not establish fair
  spawning or aiming across different aspect ratios.
- A live native run encountered an injected final-save failure, stayed open,
  retried successfully, exited, and reopened with score **12,345**, salvage
  **103**, one recorded run, 130% HUD, and no storage warning. Score/wave were
  staged, and god mode was enabled; this is a persistence check, not a natural run.
- [Capture index](../design/production-player-trust/README.md) records the staged
  setup. The [implementation ledger](production-implementation.md) records final
  suite results and reviews.

Still required for M3: the exported Windows launch/retry/reward/quit/reopen
journey; old/new exported-package update and rollback; a complete keyboard-only
run and physical-controller run, reconnect/device switching and latency checks;
aspect-ratio spawn/aim fairness; low-color-discrimination and long-string
readability; reviewed language declarations and string externalization; and
performance/memory evidence on target hardware. Proton/Deck and Cloud remain
unclaimed. Existing teardown diagnostics remain for slice 08 investigation;
the live Metal exit also logged particle-shader/texture cleanup diagnostics.
