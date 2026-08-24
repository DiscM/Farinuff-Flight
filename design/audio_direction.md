# Farinuff Flight Audio Direction

## One-sentence brief

Farinuff Flight should sound like a small, overdriven spacecraft finding a signal in a hostile CRT universe: every important cue launches, scrapes against danger, and returns with more energy.

## Core music motif: “The Return Signal”

Use one interval-and-rhythm cell across the score and the most important gameplay cues. The player should learn the motif without being asked to listen for it.

- Tonal center: D minor, with Dorian colour (B natural) reserved for breakthroughs and victory.
- Tempo: 120 BPM for the first music pass; gameplay layers can be written to work from 112–128 BPM.
- Meter: 4/4.
- Core cell: `D4 – A4 – Bb4 – A4 | F4 – D4`.
- Durations: eighth, eighth, eighth, eighth, quarter, quarter.
- Interval identity: `1 – 5 – b6 – 5 – b3 – 1`.
- Meaning: launch, contact, deflection, return, drift, home.

The `A–Bb–A` semitone scrape is the signature. It should appear in music as a short synth or bell gesture and in sound effects as a pitch or spectral movement, never as a literal copy of the same recording.

### Motif transformations

| Moment | Musical treatment | Player meaning |
| --- | --- | --- |
| Menu / Hangar | Soft FM bell, low-pass filtered, one statement every 8 bars | A signal waiting to be answered |
| Normal flight | Pluck or arpeggio fragment; leave space for combat SFX | Forward motion without anxiety |
| Boost start | Rising `D–A` fragment with a short noise lift | Launch |
| Projectile deflect | `A–Bb–A` as a metallic, high-passed triplet or bend | Contact and reversal |
| Combo milestone | Add the next motif note or octave, never a full fanfare per kill | Skill is accumulating |
| Power-up | Bright `D–F–A` answer with a short stereo bloom | Temporary capability |
| Wave 5 / 10 / 15 boss | Stretch the cell into long bass notes; keep the scrape in the warning cue | The same threat is becoming larger |
| Evolution | Play the cell through a gated/glitched layer; change only the colour and register | The world has crossed a boundary |
| Wave 20 victory | Replace `Bb` with `B` in the final statement: `D–A–B–A`; add the third above | The signal resolves |
| Game over | Invert the contour and let the final D fall away into the drone | Return failed |

The boss and victory cues should feel like transformations of the same idea rather than unrelated themes. Avoid introducing a second “hero theme” until this motif is working in the menu, deflect, boss, and victory moments.

## Music layer format

Write music as independent stems or loopable layers, all aligned to the same bar length and tempo grid.

| Layer | Role | Normal state | Escalation rule |
| --- | --- | --- | --- |
| `MUS_DRONE` | Sub/engine bed | Always present during a run | Add saturation and a slow filter opening at boss entry |
| `MUS_PULSE` | Movement and fire-rate pulse | Sparse eighth-note pulse | Increase density only at wave milestones |
| `MUS_MOTIF` | The Return Signal | One statement every 4–8 bars | Move up an octave or add the Dorian B at major rewards |
| `MUS_DANGER` | Threat pressure | Off in normal flight | Add on boss, elite, or late-wave states; do not loop a riser |
| `MUS_VOID` | Corrupted-space colour | Off | Use for Gen III/IV and the Tempest Core; noise and ring modulation, not a new melody |
| `MUS_RESOLVE` | Victory/reward tail | One-shot | Resolve to Dorian colour, then return to the menu/run state |

Keep at least 6 dB of headroom in the music mix. The score should duck briefly for `BOSS_TELEGRAPH`, `PLAYER_HIT`, `DEFLECT_HEAVY`, and `VICTORY`, but common hit markers should never duck the music.

## Sound design language

Use three layers for important one-shots:

1. **Transient** — the exact-frame read: click, snap, attack, or impact.
2. **Body** — the object’s identity: thruster, metal, energy, hull, or void.
3. **Tail** — the world around it: exhaust, ring, distortion, reverb, or sub drop.

The game’s palette should be:

- clean digital/UI beeps for readable state changes;
- short metallic ricochets for boost reflection;
- filtered spacecraft/mechanical layers for the player ship;
- glassy energy tones for XP, shields, and upgrades;
- low, asymmetric sub and noise for bosses and the Void;
- restrained CRT/static texture for evolution and high-tier corruption.

Avoid using pitch alone to communicate threat level. Important cues need a distinct transient, duration, and visual counterpart as well.

## Event-sheet format

Every new cue gets one record in the following format. This is intentionally small enough to maintain in a spreadsheet, a markdown table, or a future data resource.

```yaml
id: COMBAT.DEFLECT.HEAVY
trigger: projectile_deflected_while_boosting
intent: confirm that the player turned danger into offense
motif_fragment: RETURN_SCRAPE # NONE, LAUNCH, RETURN_SCRAPE, RESOLVE
layers:
  transient: metal_snap_02
  body: ricochet_energy_01
  tail: short_stereo_ring_01
bus: SFX # target buses: Master, Music, SFX, UI
volume_db: -10.0
pitch_range: [0.96, 1.08]
random_start_ms: 8
cooldown_ms: 60
max_voices: 3
priority: high # low, normal, high, critical
duck_music_db: 0.0
variation_count: 3
visual_partner: boost_reflection_flash
reduced_flashing_safe: true
status: existing # existing, candidate, to_record, to_mix
```

### Required fields

| Field | Rule |
| --- | --- |
| `id` | Stable uppercase category and event name; never rename after implementation |
| `trigger` | Gameplay signal or explicit state transition, not a vague description |
| `intent` | What the player should understand or feel |
| `motif_fragment` | Which part of the motif, if any, is present |
| `layers` | At least transient and body for high-value events; tail is optional for common hits |
| `bus` | Mix category; common combat and UI must be separable from music |
| `volume_db` | Starting point in Godot; final value is set during mix pass |
| `pitch_range` | Small variation only; do not randomize critical warning cues broadly |
| `cooldown_ms` | Protects readability and prevents voice storms |
| `max_voices` | Maximum simultaneous copies before voice stealing |
| `priority` | Determines which cues survive a full combat mix |
| `visual_partner` | Name the visual confirmation or `none` |
| `status` | Makes production state visible without changing the event ID |

### File naming

Use this pattern for rendered files:

```text
<domain>_<event>_<layer>_<material-or-character>_<variant>_<intensity>.wav
```

Examples:

```text
combat_deflect_transient_metal_01_high.wav
player_boost_body_thruster_02_medium.wav
boss_charge_tail_void_01_critical.wav
ui_upgrade_transient_digital_03_low.wav
```

Use 48 kHz WAV for source/rendered game files, keep one-shots trimmed to intentional silence, and use loop points only on files explicitly marked `_loop`.

## First-pass event sheet for the current build

These IDs map directly to the signals and methods already present in the project. The existing asset is listed as a candidate, not a final approval.

| Event ID | Current hook | Motif use | Candidate source / next treatment | Mix intent |
| --- | --- | --- | --- | --- |
| `PLAYER.BOOST.START` | `AudioManager.play_boost()` | `LAUNCH` (`D–A`) | `Thruster Ignite Oneshot_02.wav` | Quiet, short, never masks a warning |
| `COMBAT.DEFLECT.NORMAL` | `AudioManager.play_deflect()` | `RETURN_SCRAPE` (`A–Bb–A`) | `BLLTRico_Ricochet Metallic_04.wav` | One of the loudest common combat reads |
| `COMBAT.HIT.MARKER` | `AudioManager.play_hit_marker()` | None | `BLLTImpt_Hit Marker_07.wav` | Frequent and deliberately low |
| `PLAYER.DAMAGE` | `AudioManager.play_player_hit()` | Inverted fragment | `Impact Asteroid Debris Tail_03.wav` | Critical read; keep distinct from enemy hits |
| `PLAYER.POWERUP` | `AudioManager.play_powerup()` | `RESOLVE` (`D–F–A`) | `SCIEnrg_Energy Orb_05.wav` | Bright but brief |
| `PLAYER.SHIELD` | `AudioManager.play_shield()` | Held `D` plus shimmer | `SCIEnrg_Shield Activate Deactivate_02.wav` | Clear defensive state |
| `RUN.XP.ORB` | `AudioManager.play_xp_orb()` | Single motif pitch | `UIBeep_Lock On_05.wav` | Randomized pitch, heavily rate-limited |
| `WAVE.START` | `SignalBus.wave_started` | One low motif statement | New 1-bar cue | Scale intensity at waves 5, 10, 15, 20 |
| `BOSS.SPAWN` | `SignalBus.boss_spawned` | Stretched cell | `BEEPTimer_Anticipation Beeps_05.wav` plus sub/body | Must own the mix for the first warning |
| `BOSS.DEATH` | `SignalBus.boss_died` | Full cell into `RESOLVE` | Explosion/implode layers | Rewarding, not just louder |
| `RUN.EVOLUTION` | `SignalBus.evolution_transition_pending` | Gated/glitched cell | `Electric Glitch_01.wav` plus new motif render | One unmistakable generational boundary |
| `RUN.VICTORY` | `SignalBus.expedition_completed` | Dorian `B` resolution | New one-shot | Full musical payoff; no combat voice competition |
| `RUN.GAME_OVER` | `SignalBus.game_over` | Descending/inverted cell | New low tail | Short, legible, leaves room for result UI |

## Current codebase fit

The project already has a pooled `AudioManager`, a dedicated `Music` bus, a looping spacecraft ambience, rate limits, and a shared `SignalBus`. The next implementation slice should preserve those strengths:

1. Keep high-frequency SFX pooled and rate-limited.
2. Add a separate `SFX` bus before doing a serious mix; route current pooled players there while leaving `Music` independent.
3. Add one music state controller that reacts to wave, boss, evolution, victory, and game-over transitions.
4. Gate musical one-shots by state so a pause, retry, or modal popup cannot retrigger a reward cue.
5. Add boss/evolution cues before adding more ordinary combat sounds; those are the clearest current presentation gap.

## Acceptance test

The first pass is working when a player can identify these events with the screen partially obscured: boost, deflect, player damage, boss arrival, evolution, and victory. It is also working when the deflect sound can be hummed as the same four-note shape as the menu motif, even though the two recordings use different instruments.
