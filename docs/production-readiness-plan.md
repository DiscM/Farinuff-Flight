# Farinuff Flight — production and storefront plan

**Review date:** September 14, 2026

**Reviewed baseline:** `bbc6e821`, Godot 4.6.3, application version 0.5.0

**Status:** Proposed production plan. Implementation, purchases, account changes, and publication are separate work.

## 1. Recommendation

Move into a focused production phase built around a **polished opening Expedition, followed by a complete and dependable 1.0 release**. The game already has substantial content and a recognizable identity. The next investment should make its best moments easy to understand, satisfying to play, consistent in presentation, and reliable on the machines customers will use.

The strongest sales promise is:

> Pilot a transforming butterfly craft through a ruined orbital frontier. Boost into enemy fire, turn it back on your attackers, and build a ship that can bring the Return Signal home.

Put **boost reflection, visible ship transformation, and the journey to Wave 20** at the center of development and marketing.

### Working assumptions

- A paid, single-purchase **Steam release for Windows** is the primary target. Treat Linux and Steam Deck as additional validation targets; advertise support only after testing. A native macOS release needs its own export, signing, and hardware work.
- One primary developer owns integration and release, with selective help for visual design, key art, audio, and external QA. Budget and availability remain unspecified.
- Retain the approved **Neon Cabinet + Void Frontier** direction, native 3D craft, and pixel planets. Carry this existing art direction through the entire product.
- Target a finished 1.0 with the current Wave-20 Expedition, three hulls, existing route choices, five boss identities including the Endless reveal, and 13 native upgrades. Refine this content before increasing its size.
- The Steam account, App ID, existing page, Cloud configuration, and commercial asset permissions have not been inspected. Their status needs confirmation during the first milestone.
- Plan provisionally around **12–20 full-time weeks**, including iteration and a bug-fix reserve. This is a low-confidence production allowance, not an estimate established by this audit. Re-estimate after the first two weeks using actual task completion and playtest findings. Part-time work and contractor lead times extend the calendar.

## 2. What is already built, and what needs proof

| Area | Evidence in the current project | Production implication |
| --- | --- | --- |
| Combat and content | Native 3D runtime, three hulls, 13 upgrades, five boss variants, enemy generations, pooled effects and hazards | Preserve the foundation; prioritize encounter quality, balance, and full-run verification. |
| Campaign | Expedition, route encounters, story presentation, Archives, practice, and Wave-20/Endless flow are implemented | Earlier documents describe some of this as proposed. Reconcile documentation with current behavior before creating new work. |
| Visual identity | Approved Neon Cabinet, Void Frontier, and combat-motion passes, with editable model sources | Establish one production art standard and inspect every player-facing surface against it. |
| Interface consistency | Themes use `SystemFont`; Hangar and loadout still display catalog emoji/glyph icons; upgrade previews already show actual craft | Bundle licensed fonts and author a coherent icon set. Preserve the useful live ship previews. |
| Combat readability | In the live review, the player moved partly behind the opaque top HUD. A bright planet also overlapped the boss presentation | Resolve HUD occlusion and backdrop salience before judging a polished combat slice. |
| Audio | A detailed audio direction exists; current runtime uses a looping ambient bed, pooled sampler SFX, and synthesized menu cues | Produce and mix the intended score and high-value combat cues. Current SFX route to Master; add independent SFX control. Listening quality was not assessed in this audit. |
| Player settings | Remapping, gamepad bindings, aim deadzone, menu text scale, reduced flashing, reduced menu motion, and story frequency exist | Test the complete player journey on physical devices. Extend gaps such as HUD scaling and graphics/performance options. |
| Persistence | Version-6 saves, migration, backup recovery, and future-version preservation exist. Settings and progression share one JSON file | Retain these protections. Separate machine-specific settings before configuring Cloud. Active-run continuation after process exit is intentionally absent. |
| Automated checks | CI runs 13 smoke scenes and file contracts. Frontend navigation, Expedition progression, menu boot, Neon Cabinet, and background-drift scenes exist outside that runner list | Assess and update those tests, normalize their completion markers, and add useful coverage to CI. Existing files are not automatically current or passing. |
| Packaging | Windows and Linux export presets exist; the tracked workflow tests sources but does not build release artifacts | Add reproducible exports and test the exported packages on clean target machines. |
| Asset provenance | `THIRD_PARTY_NOTICES.md` records unresolved checks for SunGraphica and selected Shapeforms audio. The repository also contains generated-art records | Resolve the shipping asset inventory, permissions, credits, and applicable storefront disclosures before release. |

### Checks performed for this plan

- Started `ui/main_menu.tscn`, launched `scenes/native_3d_run.tscn`, inspected the menu and early combat, and staged the Assault Commander with the existing development controls.
- Viewed the actual 1920 × 1080 render on macOS, Apple A18 Pro, Metal Forward+.
- Disabled save writes in memory before launching a run. Enabled invulnerability for visual inspection and stopped the game afterward. This was an inspection session, not a balance playthrough.
- `python3 tools/check_native_transition.py`: **pass**, 340 source/resources, 11 generated GLBs, 13 upgrade modules.
- `python3 tests/check_native_completion.py`: **pass**, 375 file-only assertions. Earlier reports of five failing string checks do not describe this baseline.
- Two live performance snapshots reported 80 and 82 FPS. These samples do not establish minimum specifications, sustained performance, or late-run performance.
- No GDScript runtime errors appeared in the captured session. Compiler warnings and the deliberately enabled save-protection warning were present.

**Not established:** full campaign completion, all boss phases, fresh-player comprehension, audio mix quality, physical controller usability, save migration across exported versions, Windows/Linux performance, export contents, or storefront readiness. The full 13-scene runtime suite was not rerun for this planning task.

## 3. Make the design look professionally finished

### A. Establish one shipping art standard

Consolidate the approved decisions in [Neon Cabinet](../design/neon-cabinet/README.md), [Void Frontier](../design/void-frontier/README.md), [combat motion](../design/combat-motion/README.md), and [audio direction](../design/audio_direction.md) into a short production reference.

It should specify:

- Shape language: swept butterfly wings, rigid articulated armor, clipped UI corners, broken orbital architecture.
- Materials: readable blue-gray player hulls, restrained cyan energy, class-readable enemy armor, violet corruption, warm rewards.
- Typography: one bundled display family and one highly legible body family, with licensed redistribution and required glyph coverage. Use a fixed scale for title, section, button, body, and supporting text.
- Icons: a consistent family for hulls, upgrades, currencies, modifiers, and controls, readable at their actual HUD/menu size. Replace OS-dependent emoji where visible.
- UI states: normal, hover, keyboard/controller focus, selected, unavailable, locked, and committed. Differentiate selection from purchase/installation.
- Motion and effects: anticipation, release, and recovery for attacks; short contact feedback; stronger effects reserved for major events; explicit reduced-flashing variants.

**Deliverable:** a compact art reference, reusable theme/icon assets, and an eight-shot approval set captured in-engine: title, loadout, Hangar, ordinary combat, crowded combat, boss warning, upgrade selection, and victory/results. Capture at 1280 × 720 and 1920 × 1080, with the compact-layout checks repeated at the supported larger text size.

### B. Fix visual hierarchy in combat

The player's immediate problem must remain the clearest thing on screen.

1. **Protect the player and threats from HUD occlusion.** Compare a smaller/repositioned header, occlusion-aware fading, and a deliberately reserved safe region. Evaluate normal and expanded boss arenas, resizing, and aim projection before choosing. Do not silently alter hitboxes to solve a layout problem.
2. **Reduce scenery competition.** Keep the pixel planets, but tune their placement, saturation, exposure, and contrast relative to bullets and bosses. Review the brightest planet variant behind the most demanding encounter.
3. **Communicate projectile rules with more than color.** Preserve the taught meaning of cyan non-deflectable shots; strengthen their diamond shape, outline, motion, and warning cue so they remain distinct from friendly cyan energy.
4. **Keep boss navigation local and understandable.** Offscreen attacks need directional warning and enough time to react before entering view. Test whether the new 2.2× arenas improve maneuvering or create excessive searching. Arena size should follow playtest results.
5. **Preserve the existing bounded effect pools.** Favor readable silhouettes, timing, and sound over additional particles. Test full builds with reduced flashing enabled.

**Acceptance:** target players can identify their craft, an incoming threat, and the boost state quickly during actual movement. Essential attacks remain readable against every backdrop and beneath all active HUD/reward notices. Record failures from playtests; a clean still image alone is insufficient.

### C. Finish the frontend and brand

- Retain the strong yellow launch action. Reduce equal-weight cyan borders and duplicated information so the launch choice and ship carry the screen.
- Create a deliberate Farinuff Flight wordmark, wing/ship mark, and application icon. The existing title is styled system text, and `icon.svg` depicts an older, generic ship silhouette.
- Give Hangar purchases a clear benefit, cost, owned level, and resulting change. Explain locked content without making the page feel like a catalog of unavailable features.
- Make pause, settings, reward, confirmation, defeat, and victory screens use the same spacing and hierarchy. Replace development-oriented failure copy such as “See the debugger” with a useful player-facing recovery path and an accessible log location.
- Package editable source files and exports with naming, revision, and license information. A model's folder being named `mockups` is not by itself evidence that its visible quality is unfinished.

### D. Complete the sound identity

Use the existing Return Signal motif as the brief for a small, cohesive score: menu, normal flight, boss pressure, late Expedition, victory, and defeat. Start with reusable layers and transitions rather than commissioning a large soundtrack.

Prioritize reflection, damage, boost readiness, unreflectable danger, boss windup, armor break, module installation, and victory. Separate Master, Music, SFX, and UI controls; ensure warnings survive a crowded mix. Test headphones and ordinary speakers at low volume, and ensure important information has a visual counterpart. Resolve the exact sampler permissions or replace the affected cues before final mixing.

## 4. Make the first run prove the game's value

### The opening slice

The first production milestone should contain the title-to-flight journey, an understandable reflection opportunity, the first boss, an upgrade installation, and a short encounter that lets the player feel the new build.

Use the existing interactive practice as the basis for a brief, skippable teaching sequence. Initial targets to test are:

- Movement, aiming, and fire understood in the opening minute.
- An intentional reflection within roughly 90 seconds, with a cue that makes its offensive effect obvious.
- A meaningful visible build change within roughly three minutes. Choices currently occur after Waves 5, 10, and 15; measure time to Wave 5 before changing this structure. If the first reward is too late, prototype a limited starter choice or retune the opening pacing.
- One clear instruction at a time. Explain wave progress and life restoration separately, using the existing orb economy.
- A quick, understandable retry, with the source of damage and the next achievable goal clear.

These are proposed design targets, not measured completion times or industry benchmarks.

### Build identity and progression

Use the existing upgrade catalog to test three understandable playstyles:

| Playstyle | Existing ingredients | What the player should feel |
| --- | --- | --- |
| Aggressive reflection | Boost/chains, afterburners, survival and shield tools | Deliberately enter a volley, reverse pressure, escape cleanly. |
| Precision fire | Homing, piercing, twin cannons, overclock | Pick targets and cut through dangerous lanes. |
| Escort and coverage | Drone, orbitals, spread/rear fire, magnet | Control nearby space and collect efficiently while moving. |

These are organizing hypotheses, not assertions that all three are equally viable today. Test actual interactions and opportunity costs. If reflection lacks a meaningful build payoff, prototype one focused synergy before expanding the catalog.

Balance new profiles and fully unlocked profiles separately. A fresh ship should have a credible skill-based path to an Expedition clear. Permanent upgrades should not be required to repair an intentionally weak starting experience. Measure first useful purchase, salvage per minute, losses by source, upgrade selection frequency, boss duration, and repeated attempts.

### Boss identity and encounter rhythm

| Boss | Design question to validate |
| --- | --- |
| Assault Commander | Can the player read the locked charge, bait it, and recognize the punish window? |
| Iron Bulwark | Can players identify which pod to destroy and understand how that opens safer lanes? |
| Tempest | Are rotating openings and reflection-based crossings readable at normal speed? |
| Tempest Core | Are stopped/released projectiles and the interruptible attack clearly distinguishable under arena pressure? |
| Void Harbinger | Can players bait an echo, predict the returning path, and recognize this as an Endless escalation? |

Use the new arena-pressure patterns only where they reinforce these identities. Check overlapping attack timing, nearest safe routes, minimum warning time from the actual camera position, and phase cleanup. The latest arena entries in the gameplay plan explicitly lack validation; existing tests cannot substitute for representative play.

Author pressure and recovery across each sector: introduce a threat, combine it with a known threat, offer a brief recovery/reward, then test mastery. Use existing route profiles, objectives, and scenery kits to distinguish sectors before adding more systems.

Make the Wave-20 ending feel complete through a short payoff, music resolution, run/build summary, and a clear Hangar-or-Endless decision. Preserve the current separation between Expedition completion and optional Endless play.

## 5. Production engineering and player trust

### Release pipeline

- Pin the engine, matching export templates, and any platform integration versions. Build Windows release artifacts from a clean checkout in CI; add other declared platforms after their targets are accepted.
- Extend the existing runner with useful frontend/progression/presentation coverage. Several older scenes use different success messages; align them with the runner's required completion marker and update stale expectations. Use disposable user-data directories for all save-writing tests.
- Test the **exported package**: launch, start, pause, retry, rewards, quit, reopen, retained progression, and shutdown. Retain build version, commit, checksums, and logs with each artifact.
- Inspect exported contents. Existing exclusions enumerate some older mockup folders and do not constitute a complete release manifest. Check newer review folders, raw source art/audio, development bridge files, and unnecessary assets. Follow runtime dependencies before excluding anything: some approved hulls are sourced from `assets/models/ships/`.
- Preserve the existing release-mode guard on Dev Tools and verify it in a release export. Confirm the MCP bridge is absent and debug-only entry points cannot affect shipping score/progression.
- Rehearse an update and rollback with compatible saves before launch. Keep a known-good release available and assign one owner to promotion of a build.

### Saves, Cloud, and session length

Preserve current migration, backup, and future-version protections. Add regression coverage for interrupted writes, backup recovery followed by another save, demo-to-full migration, and updating/rolling back between supported releases.

Split durable progression from machine-specific display settings before enabling Steam Cloud. Valve explicitly advises against roaming video configuration. Test two machines, offline progression followed by reconnection, account separation on a shared PC, and conflicting local/cloud state. Cloud is a recommended product feature for this game, not a universal Steam submission requirement. [Steam Cloud documentation](https://partner.steamgames.com/doc/features/cloud)

Measure normal session length before deciding about suspend/resume. If successful Expeditions commonly require more than about 20 minutes, prioritize a **single-use checkpoint at a safe wave or interlude boundary**. Design it around consumed supplies, pending rewards, route state, and duplicate-credit prevention; it needs a schema and migration plan. If runs remain intentionally short, make abandonment consequences clear and validate that players accept them. The current lack of process-exit continuation is a documented design choice, not a newly found save defect.

### Performance and compatibility

Use the existing telemetry and pooling work to establish actual minimum hardware. Measure frame-time percentiles, stutters, process/GPU memory, startup, retry, and scene-transition latency on release builds.

Required scenarios include late-generation enemies, each boss's heaviest phase, simultaneous hazards, homing/piercing/explosive/escort combinations, repeated retries, and extended Endless. Keep a repeatable high-load scenario and a capture of its exact build/configuration.

Proposed targets: stable 60 FPS at the selected Windows minimum specification, no repeated combat hitches above 50 ms, and no unexplained monotonic memory growth across repeated identical run cycles after warmup. Define frame-time sampling and acceptable exceptions before testing. These targets are not certified by the two local snapshots.

Add simple graphics presets, frame cap/VSync, and independent HUD scale where needed. Test 720p, 1080p, 16:10, and ultrawide framing; changing aspect ratio must not create unfair spawn or aiming behavior.

### Controls, accessibility, and platform features

- Complete every screen and an entire run using keyboard only and a physical controller. Cover rebinding, disconnect/reconnect, device switching, focus restoration, held-button carryover, pause, and destructive confirmations.
- Test the largest supported text size, long strings, reduced flashing, disabled shake/distortion, and low-color-discrimination conditions. Menu text scaling does not establish HUD readability.
- Consider a toggle-fire option to reduce sustained holding. Test input latency and right-stick aiming with real players before changing movement feel.
- Externalize player-facing strings and remove text baked into art. Launch with accurately declared, reviewed languages; choose additional localization from audience demand and available QA.
- If Steam achievements are included, keep a compact set tied to mastery, discoveries, hulls, and interesting builds. Verify offline behavior and duplicate protection. Cloud and achievements should fail gracefully without breaking an offline run.
- Test the Windows build through Proton on physical Steam Deck before claiming compatibility. Controller access and readable display/UI are part of Valve's review criteria; a local Mac run or injected gamepad events cannot establish them. [Steam hardware compatibility review](https://partner.steamgames.com/doc/steamhardware/compat)

## 6. Milestones and acceptance gates

The roles below describe responsibilities; one person may hold several. Work on asset permissions and the store package can proceed alongside game polish. Public promises should follow verified content.

| Milestone | Owner | Work and dependencies | Exit evidence |
| --- | --- | --- | --- |
| **M0 — Establish the baseline** | Developer / producer | Confirm launch scope, platform, account status, asset inventory, test coverage, representative captures, and fresh-profile playtest plan | One accepted scope sheet, reproducible current build, prioritized defect list, and owners for unresolved permissions |
| **M1 — Finish the opening slice** | Developer + visual/audio design | Polish title through first boss, installation, and post-upgrade combat; settle art/typography/icons/HUD hierarchy and reflection teaching | At least eight fresh target players tested; six can reflect intentionally and explain its value without coaching; all can launch and retry; agreed visual reference captures |
| **M2 — Validate the whole game** | Developer / game design | Apply M1 standards to all sectors and bosses; balance hulls, builds, meta economy, objectives, and ending | Representative full runs on each hull and available route combination; boss-phase/readability review; no progression stalls or dominant mandatory purchase identified |
| **M3 — Produce release candidates** | Developer + QA | Export CI, package inspection, saves/Cloud decision, input/accessibility, hardware profiles, long sessions, and update/rollback | All required automated checks and release-package tests pass; known minimum spec measured; no unresolved crash, progress-loss, or completion-blocking defect |
| **M4 — Validate demo and store** | Producer + visual design / QA | Derive demo from polished content, capture actual gameplay, finish art/copy, confirm price and declarations; start store work during M1 | Store claims match the build; demo users understand reflection and experience a build change; current Steam checklists and reviews complete before public release |
| **M5 — Launch and support** | Release owner | Freeze content, choose a tested candidate, confirm external timing requirements, rehearse rollout and support | Install/update/rollback rehearsal complete, support route and known issues ready, release timing chosen from quality and audience evidence |

M1's small cohort is a usability gate, not statistical evidence of sales potential. Add another cohort after revisions. A promising slice should lead to broader full-run testing, including players unfamiliar with the genre.

### First ten working days

1. **Days 1–2: baseline and scope.** Build a clean Windows package, reconcile the current feature list, choose reference captures, inventory shipping assets, and recruit the first playtest cohort.
2. **Days 3–4: combat clarity.** Resolve the HUD-over-player case and the brightest backdrop/boss overlap. Compare changes during movement at 720p and 1080p.
3. **Days 5–6: interface finish.** Bundle the selected fonts, create a small representative icon set, and refine title/loadout/reward hierarchy. Approve the style before rolling it across every screen.
4. **Days 7–8: reflection and payoff.** Refine the existing teaching/practice flow and first reward pacing; mix a first pass of reflection, damage, and boss warning cues.
5. **Days 9–10: observe and re-plan.** Run moderated sessions without coaching, address the largest repeated confusion, and re-estimate remaining work. Carry unfinished acceptance work forward; the ten-day timebox is not automatic approval of M1.

## 7. Storefront strategy

### Steam as the main commercial target

The existing premium scope and replayable action loop make Steam a reasonable working target. Prepare a Coming Soon page once the visual direction, representative screenshots, and first polished slice are credible. Continue game validation while the page builds an audience.

A smaller itch.io release or demo remains an alternative if the chosen budget or schedule favors a limited first launch. Avoid multiplying supported releases before the main export is dependable.

### Concrete release package

- One approved key-art composition that explains the butterfly craft and reflection interaction, adapted intentionally to each format.
- A wordmark, application/community icons, and Steam library capsule, hero, and transparent logo using the current templates.
- Steam store capsules: Header **920 × 430**, Small **462 × 174**, Main **1232 × 706**, Vertical **748 × 896**. Verify templates again at export time. Base capsules should contain the game's art, title, and official subtitle; keep other marketing text in its proper store fields. [Store assets](https://partner.steamgames.com/doc/store/assets/standard), [graphical asset rules](https://partner.steamgames.com/doc/store/assets/rules)
- At least five current gameplay screenshots. Aim for six to eight that show reflection, different encounters, an actual build, a boss, and late-run play. Keep image claims representative of the shipping game. The README explicitly identifies its older screenshots as predating later completion changes. [Screenshot requirements](https://partner.steamgames.com/doc/store/assets/standard)
- A concise gameplay trailer: first seconds show boost → reflection → enemy destruction; the next sequence shows a module changing the craft and combat; then show boss identity and the Expedition destination. Test it muted. Valve recommends leading with gameplay and notes that users may decide in under ten seconds. [Trailer guidance](https://partner.steamgames.com/doc/store/trailer)
- A press kit with current screenshots, trailer, logo, short pitch, factual feature list, contact/support details, and supported platforms/languages. Prepare a small, relevant creator list for action roguelites and arcade shooters.

### Demo and audience test

Use the opening slice plus enough post-upgrade play to demonstrate transformation. Ending immediately when a new module is chosen would hide part of the game's promise. Prototype an approximately 10–15 minute demo, then adjust based on observed pace; this duration is a design hypothesis.

Maintain a defined demo/full-game save policy, preferably a tested one-way import that cannot overwrite newer full-game progression. A Steam demo has its own App ID, depot/build setup, and release checklist. [Steam demo configuration](https://partner.steamgames.com/doc/store/application/demos)

Track comprehension, time to first reflection, first boss attempts, time to build change, voluntary replays, demo completion, and attributable store interest. Obtain consent for session recording and any collected playtest data. Use local logs first; an online analytics service is not necessary to answer these questions.

The older market report's **US$7.99 and US$9.99** anchors remain price-test hypotheses. Reassess against the actual launch package and target-player reactions to its trailer and demo. This audit does not establish an optimal price or expected sales.

Choose a suitable Next Fest only after the demo passes its quality gate. Participation requires an eligible public base-game page and playable demo, and a title can join only once. Check the selected event's current registration/review dates; do not inherit the older report's October target as a commitment. [Next Fest rules](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)

### Store requirements and lead time

- Complete Steamworks onboarding, payment/banking/tax information, app configuration, pricing, and the release checklists. Steam Direct currently charges **US$100 per app**; confirm account-specific status before budgeting or paying. [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
- For a developer's first few releases, allow the **30-day period after paying the app fee**, plus a public Coming Soon page for **at least two weeks** before launch. These clocks may overlap. [Steam Direct timing](https://partner.steamgames.com/steamdirect)
- Submit store presence before build review. Both must be approved. Valve describes typical reviews of **3–5 business days** and asks developers to allow **at least seven business days** for each review, including room for corrections. Marketing preparation should begin well before these minimums. [Release process](https://partner.steamgames.com/doc/store/releasing), [review process](https://partner.steamgames.com/doc/store/review_process)
- Resolve each shipping asset's commercial permissions and notice requirements. The current third-party register identifies exact outstanding checks; retain license evidence and include applicable notices in the exported package. Replace assets whose permission cannot be established.
- Complete the Content Survey based on what actually ships. The repository includes generated-art records; audit their connection to player-consumed artwork, sound, narrative, and other content. Valve's current AI section focuses on this shipped content, rather than general development-tool efficiency. [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey)

Cloud, achievements, localization breadth, and Deck compatibility are product/platform decisions. Declare only the features and systems that have actually passed their tests.

## 8. Release decision

Separate **mandatory storefront approval** from **our internal quality bar**. Launch when both are satisfied.

| Gate | Required evidence |
| --- | --- |
| Player understanding | Fresh players can launch, reflect deliberately, understand their first upgrade, and retry without guidance. |
| Content completeness | Wave 1 through Wave 20, ending, optional Endless transition, routes, rewards, failure, and return-to-menu verified on release builds. |
| Visual/audio finish | Accepted reference captures, coherent fonts/icons/materials, readable heavy combat, and a reviewed mix at normal and reduced-effect settings. |
| Reliability | No unresolved crash, save loss, duplicate reward, or progression blocker; current automated checks pass. |
| Performance | Representative minimum-hardware frame-time results and repeated-run/long-session memory observations recorded. |
| Controls/accessibility | Physical controller and keyboard journeys pass; resizing, rebinding, text/HUD scale, reduced effects, and focus behavior accepted. |
| Distribution | Clean-machine install, offline launch, update, and rollback pass; package contents and dependencies inspected. |
| Commercial readiness | Asset permissions resolved, accurate store claims, applicable disclosures complete, required Steam reviews/timing satisfied, support contact ready. |

Reserve the final part of the schedule for defect correction, compatibility, and presentation consistency. During launch week, triage crashes and progress loss first, watch repeated usability complaints, verify hotfixes against saves, and keep public known issues concise. Reassess balance and the next content update after the initial support period.

## 9. Scope control and where to spend

Prioritize limited external spending in this order:

1. A visual designer/art director to finalize typography, icons, the wordmark, and the approval captures.
2. Key art/capsule design and a sound/music pass grounded in the game's existing briefs.
3. External usability testing and access to Windows minimum-spec hardware and a physical controller/Deck.
4. Additional localization and broader content only when the accepted launch scope and audience justify them.

Obtain quotes against these concrete deliverables before setting a cash budget. Keep roughly 20–25% of available production capacity uncommitted for revisions and release defects; this is a planning rule, not a measured cost estimate.

Defer multiplayer, additional campaigns, a large upgrade expansion, online competitive leaderboards, procedural content frameworks, console ports, and further changes of art direction. Bring them back only when a release-critical finding makes them necessary or after the first release is stable.

**Next decision:** accept or adjust the storefront/platform and team assumptions, then begin M0/M1. The immediate objective is an externally tested opening that demonstrates the final quality bar and makes the remaining schedule credible.

## Local evidence index

- [Current product overview](../README.md)
- [Historical design and additions](../GAME_DESIGN.md)
- [Gameplay implementation and outstanding validation](gameplay-improvements-plan.md)
- [Campaign and frontend plan](additional-features-plan.md)
- [Runtime optimization measurements](runtime-optimization.md)
- [Existing market research and earlier hypotheses](../PREMIUM_GAME_MARKET_RESEARCH.md)
- [Project configuration](../project.godot) and [export presets](../export_presets.cfg)
- [CI workflow](../.github/workflows/smoke_tests.yml) and [smoke runner](../tools/run_smoke_tests.py)
- [Save manager](../autoloads/save_manager.gd), [input bindings](../autoloads/input_bindings.gd), and [settings](../ui/settings_menu.gd)
- [Frontend theme](../ui/themes/farinuff_frontend_theme.tres), [heading font](../ui/themes/cabinet_heading.tres), and [HUD](../ui/hud.gd)
- [Run/reward flow](../scenes/native_3d_run.gd), [practice](../scenes/flight_practice.gd), and [encounter director](../systems/native_encounter_director.gd)
- [Audio implementation](../autoloads/audio_manager.gd) and [third-party release register](../THIRD_PARTY_NOTICES.md)

External requirements were checked against the linked official Steamworks pages on the review date. Recheck them before submission.
