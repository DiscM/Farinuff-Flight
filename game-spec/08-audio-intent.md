# Audio Intent and Event Contract

Status: portable audio direction

## One-sentence brief

Farinuff Flight should sound like a small, overdriven spacecraft finding a signal in a hostile CRT universe: every important cue launches, scrapes against danger, and returns with more energy.

## Core motif: The Return Signal

Use one interval-and-rhythm cell across music and high-value cues so launch, contact, deflection, evolution, and victory feel related.

- Tonal center: D minor with Dorian color reserved for breakthroughs and victory
- First-pass tempo: 120 BPM
- Core cell: `D4 – A4 – Bb4 – A4 | F4 – D4`
- Signature gesture: the `A–Bb–A` semitone scrape
- Wave-20 resolution: replace `Bb` with `B` in the final statement

## Music states

| State | Treatment |
|---|---|
| Menu / Hangar | Soft filtered motif statement every several bars |
| Normal flight | Sparse pluck/arpeggio fragments with space for combat SFX |
| Boss | Stretched motif with added danger layer |
| Evolution | Gated/glitched motif in a changed register |
| Wave-20 victory | Dorian resolution and dedicated reward tail |
| Game over | Inverted contour resolving into a brief drone |

Keep music and SFX independently controllable. Common hit markers must not repeatedly duck the music; high-value cues may receive brief priority ducking.

## Sound-event schema

Every important cue should have a stable event ID and the following fields:

```yaml
id: COMBAT.DEFLECT.HEAVY
trigger: projectile_reflected_while_boosting
intent: confirm_that_danger_became_offense
motif_fragment: RETURN_SCRAPE
layers: [transient, body, tail]
bus: SFX
cooldown_ms: 60
max_voices: 3
priority: high
visual_partner: boost_reflection_flash
reduced_flashing_safe: true
status: candidate
```

## Required high-value events

`PLAYER.BOOST.START`, `COMBAT.DEFLECT.NORMAL`, `COMBAT.DEFLECT.HEAVY`, `PLAYER.DAMAGE`, `PLAYER.POWERUP`, `RUN.XP.ORB`, `WAVE.START`, `BOSS.SPAWN`, `BOSS.DEATH`, `RUN.EVOLUTION`, `RUN.VICTORY`, and `RUN.GAME_OVER`.

## Sound design language

Important one-shots use three conceptual layers:

1. **Transient** — the exact-frame read
2. **Body** — material or object identity
3. **Tail** — space, exhaust, distortion, or reward texture

Use digital/UI tones for state changes, metallic ricochets for reflection, spacecraft/mechanical layers for the Player Craft, glassy energy for XP and upgrades, and low asymmetric noise for bosses and Void states.

## Audio acceptance test

With the screen partially obscured, a player should still distinguish boost, deflection, damage, boss arrival, evolution, and victory. The deflection cue should feel related to the menu motif without reusing the same recording.
