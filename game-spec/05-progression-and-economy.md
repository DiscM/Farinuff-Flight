# Progression and Economy

Status: reference economy contract

## Progression boundaries

| Scope | Examples | Reset when |
|---|---|---|
| Momentary | Boost, combo, active power-up, invulnerability | Effect ends or the player is hit |
| Run-long | Stat allocation, elite upgrades, current build, run salvage | Run finalizes or restarts |
| Persistent | Salvage wallet, blueprints, ships, modifiers, high score, settings | Never during ordinary play |

## Starting run values

The base lives, Try Again stocks, movement, fire interval, and orb-to-life threshold are defined in [`03-gameplay-rules.md`](03-gameplay-rules.md). The economy starts every run at a ×1.00 Salvage multiplier before challenge modifiers.

Starting values are modified by the selected ship, purchased systems, armed consumables, and challenge modifiers. The resolved starting lives are stored so Try Again can restore the same loadout-derived value.

## Milestone allocation

- Every fifth-wave clear grants 3 allocation points.
- Available stats: fire rate, health, and speed.
- Each fire-rate or speed point adds 4.5%, capped at 45% for that allocation category.
- Each health point grants one life.
- Allocation bonuses are run-scoped and separate from persistent Hangar bonuses.

## Salvage earnings

Boss rewards are paid immediately during the run:

- Regular boss: 30 salvage
- Elite boss: 60 salvage

On final run finalization:

```text
score_bonus = round(sqrt(max(score, 0) / 10) × run_salvage_multiplier)
wave_bonus = cleared_waves × 3 × run_salvage_multiplier
milestone_bonus = unclaimed_first_clear_awards
total_new_bonus = score_bonus + wave_bonus + milestone_bonus
```

First-clear awards are not multiplied:

| Wave | Award |
|---:|---:|
| 5 | 50 |
| 10 | 100 |
| 15 | 150 |
| 20 | 250 |
| 25 | 400 |
| 30 | 600 |

## Hangar catalog

### Permanent systems

| ID | Name | Cost sequence | Effect |
|---|---|---:|---|
| `META.HULL` | Hull Reinforcement | 150, 300, 600 | +1 starting life per level |
| `META.THRUSTERS` | Tuned Thrusters | 150, 300, 600 | +8% movement speed per level |
| `META.CANNONS` | Overcharged Cannons | 150, 300, 600 | +8% fire rate per level |
| `META.RESERVES` | Emergency Reserves | 200, 400 | +1 base Try Again stock per level |

### Blueprint unlocks

| ID | Cost | Adds to elite pool |
|---|---:|---|
| `META.ORBITALS` | 250 | Orbital Array |
| `META.PIERCING` | 250 | Piercing Rounds |
| `META.EXPLOSIVE` | 250 | Explosive Rounds |

### Ship variants

| ID | Cost | Profile |
|---|---:|---|
| `SHIP.SWALLOWTAIL` | Free | Balanced baseline |
| `SHIP.INTERCEPTOR` | 400 | +15% speed, +10% fire rate, −1 starting life |
| `SHIP.BULWARK` | 400 | +2 starting lives, −10% speed, −10% fire rate |

### Consumables

| ID | Cost | Rule |
|---|---:|---|
| `CONSUMABLE.RESERVE_STOCK` | 120 | +1 Try Again stock on the next run; stockpile up to 3 |
| `CONSUMABLE.DROP_POD` | 100 | Start the next run with a random non-nuke Power-Up |

### Challenge modifiers

| ID | Cost | Effect | Salvage bonus |
|---|---:|---|---:|
| `MOD.RAPID_ASSAULT` | 300 | Enemies spawn 20% faster | +20% |
| `MOD.ARMORED_FLEET` | 300 | Regular enemies have +30% HP | +30% |
| `MOD.DAMAGED_HULL` | 300 | Start with −1 life | +15% |
| `MOD.SUPPLY_BLOCKADE` | 300 | No Power-Up drops | +25% |
| `MOD.ENERGY_DROUGHT` | 300 | Waves need 50% more orbs | +25% |

All active modifier bonuses add to the run multiplier. With all five active, the reference maximum is ×1.90.

## Economy invariants

- Salvage cannot become negative.
- A purchase consumes the price exactly once.
- Locked items cannot be selected or activated by ordinary player actions.
- Consumables are consumed only at the next run start.
- First-clear milestones are claimed once and remain claimed.
- A failed or interrupted save must not erase previously committed progress.
