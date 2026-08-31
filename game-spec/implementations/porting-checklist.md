# Porting Checklist

Status: reusable checklist

## Before implementation

- [ ] Choose the target engine, renderer, platform, and presentation format.
- [ ] Copy the portable specification revision into the port profile.
- [ ] Identify any rules the target cannot reproduce directly.
- [ ] Define the design-unit, camera, and Combat Space mapping.
- [ ] Map portable actions to every supported input device.
- [ ] Choose the target data, asset, UI, audio, save, and test technologies.
- [ ] Set performance and minimum-hardware budgets.

## Simulation parity

- [ ] Implement run state and state transitions before presentation polish.
- [ ] Implement explicit seedable randomness.
- [ ] Implement movement, aim, fire, boost, reflection, damage, waves, rewards, and finalization.
- [ ] Ensure pause, restart, Try Again, and finalization are idempotent.
- [ ] Map all portable content IDs one-to-one.
- [ ] Run the core acceptance scenarios against the simulation without rendering.

## Presentation parity

- [ ] Adapt art direction without losing role-readable silhouettes.
- [ ] Adapt visual feedback for the target format and resolution.
- [ ] Preserve audio event intent and priority.
- [ ] Verify UI flows, focus states, prompts, and accessibility settings.
- [ ] Verify gameplay Hitboxes remain independent from visual assets.

## Data and persistence

- [ ] Import or convert every catalog entry.
- [ ] Validate ranges, units, missing values, and duplicate IDs.
- [ ] Implement versioned save data and recovery behavior.
- [ ] Test interrupted writes, malformed data, and future-version data.

## Validation and release

- [ ] Complete manual playthrough from first launch to Wave 20.
- [ ] Complete an Endless soak test.
- [ ] Test controller-only navigation and reduced-effects settings.
- [ ] Compare reference scenarios, frame pacing, memory, and object/pool growth.
- [ ] Record intentional differences and their reason.
- [ ] Produce a clean, versioned target export and inspect included assets.
