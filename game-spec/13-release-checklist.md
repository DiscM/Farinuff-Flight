# Release Checklist

Status: reusable release gate

## Product and content

- [ ] Product name, description, icon, and version are final.
- [ ] The first-launch experience teaches the core promise.
- [ ] Expedition, Wave-20 climax, Game Over, and Endless/Hangar routes are complete.
- [ ] All shipped enemies, bosses, upgrades, Power-Ups, ships, and modifiers have approved content data.
- [ ] Player-facing strings are localization-ready.

## Technical build

- [ ] Build is produced from a known clean commit or reproducible build input.
- [ ] Engine/runtime version and export configuration are recorded.
- [ ] Warnings in first-party code are reviewed.
- [ ] Required assets are loaded without first-use combat hitching.
- [ ] No development-only scenes, debug menus, test harnesses, source packs, or unused dependencies ship unintentionally.
- [ ] Supported resolutions, input devices, and platforms have been tested.

## Persistence and recovery

- [ ] Save schema version is current.
- [ ] Fresh, existing, legacy, malformed, interrupted, and future-version saves are tested.
- [ ] Backup recovery works.
- [ ] Purchases, milestone rewards, consumables, and run finalization cannot double-apply.
- [ ] Platform-specific save location and cloud-sync behavior are documented, if applicable.

## Accessibility and usability

- [ ] Controller-only navigation works.
- [ ] Input prompts follow the active device.
- [ ] Music and SFX can be adjusted separately.
- [ ] Reduced flashing, shake, CRT/distortion, and other effects are honored.
- [ ] Threats and warnings remain understandable without color alone.
- [ ] Text is readable at the minimum supported viewport.

## Performance and stability

- [ ] Cold start, run transition, and first encounter are profiled.
- [ ] Fully upgraded combat load is profiled.
- [ ] Long-session soak test is complete.
- [ ] Memory, frame time, active-object count, pool growth, and crash logs are reviewed.
- [ ] No known orphan, leak, unbounded pool, or runaway audio-voice issue remains.

## Legal and distribution

- [ ] Every shipped asset has recorded source, author, license, and modification status.
- [ ] Third-party notices are complete.
- [ ] Store screenshots, trailer, capsule art, and descriptions match the shipped build.
- [ ] Installer/archive contents are inspected.
- [ ] Fresh-install and upgrade-install paths are tested.
- [ ] Release artifacts are checksumed or otherwise identified.
- [ ] Changelog and known-issues notes are published.
