# Research: a cohesive Farinuff Flight

Researched September 21, 2026. This is a design guideline grounded in primary developer material, not a claim that copying successful games causes commercial success. The sources describe production decisions, implementation examples, and developer judgments; none supplies a controlled causal test of what makes an indie game popular. Farinuff-specific rules and thresholds below are our hypotheses to validate.

## Design promise

**Fly into danger, turn enemy fire into momentum, and bring a distinctive expedition home.**

The existing boost/reflection mechanic is the clearest candidate for the game's identity. Shooting, enemy tells, milestone builds, routes, salvage, presentation, and the Wave-20 ending should make that promise easier to understand and more interesting to execute. Prefer a small number of mutually reinforcing systems over unrelated additions.

## What the sources actually establish

### 1. Constraints can create cohesion

Matthew Davis's *Into the Breach Design Postmortem* lists readability, limited menus, low numbers, short experiences, and interesting choices among Subset's constraints. It describes showing enemy intentions, restricting weapon designs to fit understandable UI, and rebuilding the strategy layer around clear rewards. These are first-person design lessons, not universally optimal rules. [Slides, especially 7, 13, 30–36, 42–44](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).

**Application:** upgrades and routes must disclose their combat consequence before confirmation. The player should understand both what an enemy is about to do and what opportunity their build creates.

### 2. Balance means useful roles, followed by iteration

Anthony Giovannetti's *Slay the Spire: Metrics Driven Design and Balance* states a goal that each card have a place while avoiding excessively distorting options. It combines playtester feedback, metrics, frequent iteration, and player skill stratification, and cautions that data alone is not a conclusion. [Mega Crit's slides, especially 6, 9–15, 20](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

**Application:** reflection, precision, and coverage builds need different useful situations. A frequently selected upgrade may be comprehensible, available early, or popular among experts; selection rate alone does not prove excessive power. Preserve offered alternatives and profile state when collecting observations.

### 3. Repetition can retain meaning

Supergiant's *Hades FAQ* describes a combination of variable builds, persistent progression, story continuity, and adjustable challenge. It explicitly describes player expression and replayability as goals, and accessibility to a wider range of skill as another goal. This is the developer's account and product description, not independent proof of the contribution of each component. [Official FAQ, sections on roguelikes, difficulty, and story](https://www.supergiantgames.com/blog/hades-faq/).

**Application:** a failed flight should leave understandable knowledge and clearly settled salvage; a successful flight should have an unmistakable conclusion. Route and build variation should change decisions without requiring a mandatory permanent-stat grind.

### 4. Forgiveness can be a precise implementation choice

Celeste's official changelog documents corner correction fixes, a 0.1-second Quick Restart input buffer, and an explosion-boost grace period. These establish concrete shipped examples of input accommodation; they do not justify blindly transferring the same timing constants to another game. [Official changelog, version 1.3.3.7 and adjacent entries](https://www.celestegame.com/changelog.html).

**Application:** retain the existing short boost buffer and chain forgiveness, then verify their boundaries. A fresh early press should help; stale input after menus or death must not trigger an unintended dash. Evaluate timing by perceived control, not maximum generosity.

### 5. Intensity benefits from contrast

Michael Booth's *Replayable Cooperative Game Design: Left 4 Dead* describes a pacing director that alternates threat buildup and relaxation, while separating boss encounters from adaptive pacing. This is an older large-studio supporting example, not an indie-specific formula or a reason to copy its multiplayer timings. [Valve's slides, especially 34–40](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf).

**Application:** a twenty-wave expedition should have identifiable preparation, pressure, climax, and recovery. Do not increase every difficulty variable simultaneously. Keep boss rewards and route choices safe to read; avoid spending recovery time while the game is paused.

### 6. Visual style should serve recognition

Valve's *Illustrative Rendering in Team Fortress 2* describes distinct silhouettes, deliberately restrained environmental detail, and shading that makes characters readable under varied lighting. Its authors explicitly connect art and technical decisions to gameplay goals. It is a technical production paper, not a comparative preference study. [Mitchell, Francke, and Eng, 2007, sections 3–4](https://cdn.fastly.steamstatic.com/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf).

**Application:** distinguish hostile bullets, reflected fire, pickups, and effects through shape, motion, and value as well as color. Let background detail recede. Inspect actual combat at 720p; a beautiful close-up of a ship does not establish useful recognition at gameplay scale.

### 7. Feedback is a craft tool, not a substitute for rules

Martin Jonasson and Petri Purho's *Juice It or Lose It* is a live demonstration of feedback additions to a simple game. The reviewed primary source is its official GDC session description; it establishes the demonstration's intent, not a verified list of individual techniques or a quantified enjoyment result. [GDC session](https://www.gdcvault.com/play/1016789/Juice-It-or-Lose).

**Application:** give a reflection, a kill, a hurt event, and a milestone distinct feedback priorities. Effects should confirm what happened without obscuring the next threat. Avoid treating additional shake or particles as evidence of refinement.

## Testable rules for implementation

These are project-specific acceptance proposals, not numerical recommendations from the sources.

| Rule | Concrete check | What would disprove it |
| --- | --- | --- |
| Make reflection the signature skill. | Opening play introduces a readable projectile opportunity; HUD explains boost readiness and successful chain state; record first intentional reflection. | New players reach the first boss without knowing boost reflects fire. |
| Communicate the next objective. | During ordinary combat, display progress toward the current wave goal and the next milestone; distinguish a boss fight from collection. | Players keep collecting or waiting because they cannot explain how the encounter ends. |
| Give upgrades useful identities. | Cards state trigger and payoff. Each build has a documented encounter where it helps and a tradeoff against another offered option. | One choice is always superior, misleading, or unusable when offered. |
| Preserve readable danger. | Review attacks at gameplay camera distance, 720p, reduced effects, and during a developed build; identify tell, collision moment, and escape route. | Damage precedes a visible cue, or essential information depends on decorative flashing. |
| Create a deliberate run arc. | Record active time and damage by wave; ensure boss boundaries provide real recovery; inspect late-sector overlap. | A transition immediately overwhelms the player or a long lull has no purpose. |
| Let loss teach and retain value. | Defeat states show meaningful run results, earned salvage, and a clear retry action; reopening preserves settled rewards exactly once. | Players cannot tell what they gained, or retry/quit duplicates or loses rewards. |
| Resolve the expedition. | Wave 20 ends combat, presents the completion result, and offers unambiguous Return Home/Endless consequences. | Victory feels like another intermission, or the player cannot predict what each option retains. |
| Validate accessibility as part of polish. | Essential cues survive reduced motion/flashing; keyboard/controller focus reaches all choices at 720p and larger text. | Presentation settings erase required combat information or trap navigation. |
| Measure the experience, not just contracts. | Natural runs retain failures, route/build offers, profile state, duration, reward sources, and player explanation of deaths. | Assisted invulnerable journeys or one good run are used to claim general balance. |

## Recommended order

1. Audit the first five waves and the combat HUD against the design promise. Improve reflection teaching and objective clarity before adding mechanics.
2. Refine milestone and route choice presentation so each decision names a useful consequence. Keep choices tied to existing combat roles.
3. Strengthen completion and defeat presentation so a run has an emotional and mechanical endpoint. Preserve settlement invariants.
4. Measure base-profile and developed-profile runs separately. Tune enemy overlap, progression speed, and the economy from those observations.

## Evidence still needed

The existing `docs/expedition-playtest.md` explicitly distinguishes assisted engineering journeys from natural play and leaves build viability, economy pacing, and encounter readability open. `docs/gameplay-refinement.md` establishes an earlier input/pacing/UI pass but likewise does not establish player completion times or perceived difficulty. Those limitations should remain visible after this work.

A useful formative test recruits unfamiliar players and asks them to explain the core action, current objective, reason for a build choice, and cause of a death in their own words. Record failures as well as clears. Small sessions can discover severe misunderstandings; they cannot establish a population-wide enjoyment or retention rate. No amount of green smoke output proves that this game is well liked.
