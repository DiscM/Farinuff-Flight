# Additional Features Plan: The Return Signal

Status: implementation-ready proposal

Scope: story, world map, front-end/menu revision, and the minimum supporting architecture

Baseline: Farinuff Flight 0.5.0 on Godot 4.6.3

Planning date: 2026-09-10

## Executive decision

Build the next release around one connected experience: **The Return Signal Expedition**. The existing Wave-20 run remains the mechanical spine. A world map divides it into four five-wave sectors, short story beats explain why each milestone matters, and a shared front-end shell turns the current title, Hangar, Launch Bay, Flight School, and Settings overlays into one navigable command deck.

The world map is not a level-select screen and does not permit skipping waves. It is a route-planning and story surface before launch and at the Wave 5, 10, and 15 safe boundaries. The live run remains resident during those interludes, so this plan does not require serializing enemies, projectiles, timers, or a partially built player craft.

This preserves the game's strongest qualities:

- fast, readable arcade combat;
- a single authored Wave-20 climax followed by optional Endless play;
- run-scoped ship transformation and challenge modifiers;
- the Swallowtail/butterfly identity, pixel-planets backdrop, neon cabinet UI, and CRT presentation;
- the existing `GameManager`, `MetaProgression`, `SaveManager`, `SignalBus`, and native 3D scene flow.

## Product goals

1. Give the Wave-20 Expedition a clear beginning, escalation, climax, and reason to replay.
2. Let the player understand where they are, what threat is next, and what route choice means before entering combat.
3. Make all non-combat screens feel like one product instead of a collection of differently styled overlays.
4. Add the features through narrow interfaces so campaign rules, presentation, and combat do not become entangled.
5. Keep a complete Expedition playable in one sitting and keep story presentation skippable.

## Non-goals for this milestone

- Mid-wave checkpoints or restoring an active run after quitting.
- Multiple save slots or a profile picker.
- Branch-exclusive bosses, biomes, enemy models, or voiced dialogue.
- A free-roaming overworld or direct ship control on the map.
- Replacing the Wave-20 Expedition with mission-by-mission scene loads.
- Rebalancing the existing Hangar economy except where playtests reveal a route-related exploit.
- Rewriting the in-combat HUD in the first slice.

## Current baseline and constraints

| Concern | Current implementation | Planning consequence |
| --- | --- | --- |
| Entry point | `project.godot` launches `res://ui/main_menu.tscn` | Keep this path during migration; turn its root into the front-end shell rather than changing the boot contract immediately. |
| Run | `res://scenes/native_3d_run.tscn` and `native_3d_run.gd` own encounters and modal rewards | Keep the scene resident while sector/story/map interludes are shown. |
| Run state | `autoloads/game_manager.gd` owns waves, lives, score, upgrades, and the Wave-20 victory transition | Campaign state must not be folded into `GameManager`; it has a different lifecycle and persistence policy. |
| Persistent progression | `autoloads/meta_progression.gd` owns salvage, Hangar purchases, loadout, and lifetime statistics | Route discovery and viewed story beats are separate from the economy and should not become shop catalog keys. |
| Persistence | `autoloads/save_manager.gd` writes a versioned atomic JSON save and backup | Campaign additions require a schema version bump and a v2-to-v3 default migration. |
| Events | `autoloads/signal_bus.gd` carries combat and wave events | Reuse the existing wave/boss events as inputs, but keep campaign-specific state transitions on the campaign module itself. |
| Front end | `ui/main_menu.gd` owns four child overlays; several UI scripts build their controls and styles in code | Migrate toward declarative scenes plus one shared Theme resource. Do not do a one-shot rewrite. |
| Visual language | `ui/neon_ui.gd`, `ui/main_menu.tscn`, `design/mockups/`, PixelPlanets, and the native fleet style establish cyan/yellow/green/magenta over deep navy | Treat these as the style source; the map should look like a relay chart from the same cabinet, not a generic galaxy UI. |
| Audio language | `design/audio_direction.md` defines “The Return Signal” motif and state changes | Story, map selection, sector departure, and discovery cues should reuse that motif instead of creating a second musical identity. |

`GAME_DESIGN.md` still opens by describing a procedural 2D game even though the production runtime is native top-down 3D. Treat `README.md`, `CONTEXT.md`, the 3D migration ADRs/checklist, and the actual project settings as authoritative while this plan is implemented; refresh the stale design overview once the new campaign contract is approved.

### Prerequisite inconsistency to resolve

The production boss selection in `entities/enemies/boss_enemy_3d.gd` currently derives its variant from `(wave / 5) - 1`. That produces Assault Commander at Wave 5, Iron Bulwark at Wave 10, Tempest at Wave 15, and **Void Harbinger at Wave 20**. The README, Flight School, victory screen, signal comments, palette reference, and `GameManager.FINAL_EXPEDITION_WAVE` all describe **Tempest Core** as the Wave-20 finale. The developer override also maps both Harbinger and Core to Wave 20.

Before story data is authored, make the production mapping explicit:

- Wave 5: Assault Commander (`assault`, variant 0)
- Wave 10: Iron Bulwark (`bulwark`, variant 1)
- Wave 15: Tempest (`tempest`, variant 2)
- Wave 20: Tempest Core (`core`, variant 4)
- Wave 25: Void Harbinger (`harbinger`, variant 3), establishing the first Endless revelation

Later Endless milestones may rotate all command hulls, but the four Expedition milestones must not depend on array arithmetic.

There is also a production encounter wiring gap relevant to the proposed bomber-heavy routes: `BomberEnemy3D.configure_hazard_manager()` is called by `scenes/bomber_enemy_3d_review.gd`, but `systems/native_encounter_director.gd::spawn_enemy()` does not call it. As a result, Generation II-IV production bombers can reach `_try_drop_mine()` with no hazard manager and silently skip their mine/plasma behavior. Fix and cover that injection before route balance relies on bomber hazards.

## Target player journey

```text
Boot
  -> Command Deck
       -> Expedition Map
            -> Launch Bay / loadout confirmation
                 -> Sector 1 (Waves 1-5)
                 -> rewards -> debrief -> route choice
                 -> Sector 2 (Waves 6-10)
                 -> elite reward -> stat reward -> debrief -> route choice
                 -> Sector 3 (Waves 11-15)
                 -> rewards -> debrief -> final-route confirmation
                 -> Sector 4 (Waves 16-20)
                 -> Expedition victory
                      -> return to Command Deck
                      -> continue into Endless (Wave 21+)
```

The player can still open the Hangar, Flight School, and Settings before launch. During a run, Pause exposes Resume, Settings, Restart Expedition, and Abandon Expedition. “Restart” and “Abandon” must use confirmation dialogs because both discard the current in-memory build.

## Story plan

### Premise

The player is the unnamed pilot of the Swallowtail, stranded beyond the last charted relay after a routine recovery flight becomes a one-way jump. A repeating distress handshake—the Return Signal—offers the only possible route home. An old shipboard navigation intelligence called **MOTH** can trace it, but every relay on the path is guarded by a self-rewriting **Custodian Fleet**. The fleet's four generations are not a natural escalation: each relay learns from the player's previous fights and rebuilds its defenders.

The ship's boost-reflection field supplies the central metaphor and the plot's key. The player survives by returning hostile projectiles; the signal survives by returning through the relay network. At the Tempest Core, MOTH discovers that the distress handshake contains the Swallowtail's own transponder signature. Breaking the Core opens the route home but reveals the signal continuing past its source, which gives the existing Endless choice a narrative purpose.

### Tone and themes

- Lonely but determined, not grimdark.
- Short military/technical language during action; warmer, stranger language at safe boundaries.
- Home as a direction the player repeatedly chooses, not a location promised by exposition.
- Reflection, adaptation, migration, and metamorphosis link the combat mechanic, enemy generations, and butterfly craft.
- Ambiguity is reserved for the signal's origin. Objectives and gameplay consequences remain explicit.

### Cast and factions

| Name | Function | Presentation rule |
| --- | --- | --- |
| The Pilot | Player-projected protagonist | No authored face, gender, or spoken dialogue. Choices are expressed through routes and loadouts. |
| MOTH | Navigation/telemetry intelligence aboard the Swallowtail | One or two concise lines at safe boundaries; never chatters over dense combat. Text-first in the initial release. |
| The Return Signal | Repeating distress handshake and mystery | Communicated through waveform graphics, six-note motif transformations, and recovered fragments rather than a speaking character. |
| Custodian Fleet | Automated quarantine force | Its Standard, Augmented, Warform, and Apex generations are the story's visible escalation. Bosses are command functions, not unrelated villains. |

### Campaign beats

| Sector | Waves and boss | Narrative job | Required beats |
| --- | --- | --- | --- |
| **The Far Reach** | Waves 1-5; Assault Commander | Establish isolation, MOTH, and the signal. The Fleet treats the Swallowtail as salvage until the first successful reflection. | Launch briefing; first-return bark after a multi-reflect chain; Commander dossier; Wave-5 debrief revealing the first intact relay coordinate. |
| **The Broken Perimeter** | Waves 6-10; Iron Bulwark | Show that the Fleet is deliberately sealing the route. Gen II adaptation makes the enemy feel observant. | Route-specific arrival line; Gen II transition; Bulwark warning; Wave-10 recovered fragment naming the network's quarantine protocol. |
| **Tempest Reach** | Waves 11-15; Tempest | Turn the mystery inward. MOTH recognizes the pilot's transponder cadence inside the signal. Gen III is a prediction engine built from the player's combat record. | Route-specific anomaly; Gen III transition; Tempest dossier; Wave-15 reveal and explicit final-route objective. |
| **The Quiet Core** | Waves 16-20; Tempest Core | Resolve the finite Expedition without explaining away the wider mystery. Gen IV is the last defensive rewrite. | Core approach briefing; Gen IV transition; Core phase callouts; clear reveal; choice to go home or follow the continuing signal. |
| **The Void Reach** | Wave 21 onward; Void Harbinger first appears at Wave 25 | Give Endless a distinct fictional state rather than “more waves.” | One opt-in Endless briefing, Harbinger discovery, then sparse procedural/variant barks only. |

### Delivery channels and pacing budgets

| Channel | When | Budget | Input behavior |
| --- | --- | --- | --- |
| Sector briefing | Map before a sector begins | 45-70 words plus threat tags | Confirm advances; Cancel returns to the selected node. Hold-to-skip is not required. |
| Safe-boundary debrief | After rewards at Waves 5, 10, and 15 | 25-50 words | Confirm/Cancel closes; “Skip story” closes immediately. |
| Combat bark | Wave start, boss warning, first discovery only | One line, at most 42 characters and about 3 seconds | Never captures input or pauses the tree. Suppress repeat barks. |
| Recovered fragment | Optional map/codex panel | 80-140 words | Never blocks launch. Unread marker clears only after the panel opens. |
| Victory reveal | Wave-20 victory screen | 60-90 words before the existing Endless/menu choice | Both choices remain visible without scrolling at 1280x720. |

Story must never interrupt the player while enemies or hostile projectiles are active. Every blocking beat is skippable, repeat play does not replay already-seen prose by default, and the Settings screen includes Story Frequency: Full / Brief / Off. “Off” preserves objective labels and boss warnings.

## World map plan

### Map role

The map is a stylized relay chart, not a literal star simulation. Four vertical bands show the Expedition sectors from left to right. Routes are traces on a damaged CRT plot; selecting a node opens a dossier with its threat mix, wave range, boss, story status, and active loadout effects.

An Expedition always begins at The Far Reach and ends at The Quiet Core. The player makes a route choice for Sector 2 and Sector 3; those choices change regular-enemy weighting and story fragments while preserving the same boss milestones and total run length. The final route is fixed so the Tempest Core remains authored and legible.

### Initial topology

```text
Haven Relay
    |
The Far Reach (W1-5)
    |\
    | +-- Ghost Lanes ------+
    +---- Iron Wake --------+  (W6-10 -> Iron Bulwark)
                             |\
                             | +-- Echo Field -------+
                             +---- Tempest Veil -----+  (W11-15 -> Tempest)
                                                     |
                                               The Quiet Core
                                               (W16-20 -> Core)
```

The branch labels are route profiles inside the same five-wave sector, not separate campaigns. Both choices must be balanced to equivalent expected difficulty and salvage in the MVP.

### Route profiles

| Route | Threat preview | MVP gameplay effect | Story flavor |
| --- | --- | --- | --- |
| Iron Wake | Armor, mines, broad denial | Increase tank/bomber weighting; reduce fast/sniper weighting. No HP multiplier. | Wrecked quarantine carriers and a direct Custodian warning. |
| Ghost Lanes | Speed, range, crossfire | Increase fast/sniper weighting; reduce tank/bomber weighting. No spawn-rate multiplier. | Silent relays repeat pieces of older distress calls. |
| Tempest Veil | Mobility, mines, unstable space | Increase fast/bomber weighting and choose one existing hazard-capable encounter package. | The signal is strongest inside electrical interference. |
| Echo Field | Formation pressure, prediction | Increase basic/sniper weighting and favor coordinated telegraphs. | MOTH finds the Swallowtail's cadence in archived combat telemetry. |

The existing Hangar challenge modifiers remain run-wide and stack independently. Route profiles do not change the salvage multiplier in the MVP. If route-specific risk rewards are added later, they apply only to the next sector, are itemized separately, and are capped so they cannot make one narrative path economically mandatory.

### Node states

Every node has one of five states, each communicated by shape, label, and color:

- **Locked**: visible silhouette, lock glyph, no dossier details.
- **Reachable**: cyan outline and solid connection from the cleared node.
- **Selected**: yellow double outline, animated reticle unless Reduced Flashing is enabled.
- **Cleared**: green check and a stable, non-pulsing connection.
- **Discovered**: magenta archive marker for a route seen in a prior run but not currently reachable.

The selected state is separate from keyboard/controller focus. Focus has a white high-contrast frame so the player can tell what will activate even when a different route is selected.

### Progress and replay rules

- Route choices reset at the start of each Expedition.
- `discovered_node_ids`, `seen_story_beat_ids`, total Expedition clears, and the latest completed ending are persistent.
- A run that ends early records discovered nodes and seen beats, but it does not unlock sector skipping.
- The map shows all discovered branches on later runs and marks unread fragments.
- The first clear unlocks the Void Reach/Endless legend on the map. It does not add a separate “start at Wave 21” option.
- Abandoning during a map interlude uses the normal end-of-run finalization exactly once.

## Revamped menu UI

### Information architecture

The new `MainMenu` becomes a front-end shell with a stable status rail and page slot. The top-level pages are:

1. **Command Deck** — title treatment, current objective, primary Expedition action, latest discovery, and build/version status.
2. **Expedition Map** — route graph and selected-node dossier.
3. **Launch Bay** — hull, challenge modifiers, supplies, and final launch summary.
4. **Hangar** — systems, blueprints, hulls, modifiers, and field supplies with filters instead of one long list.
5. **Flight School** — the existing five lessons, restyled inside the shell.
6. **Settings** — Audio, Display, Controls, Accessibility, and Story tabs.
7. **Archives** — discovered story fragments, boss dossiers, and ending record; introduced after the map/story vertical slice.
8. **Credits / Quit** — compact utility actions on desktop, not primary cards.

Do not add a Profile page while the save remains single-slot, and do not show Continue Expedition while active-run restoration is unsupported.

### Layout system

- **Top status rail:** salvage balance, selected hull, best wave, and current objective. Each value has a text label; icons are supplementary.
- **Left navigation rail:** 220-260 logical pixels at 1280x720. Current page uses a filled marker; focus uses a separate high-contrast outline.
- **Content canvas:** responsive container for the map, Hangar grid, school pages, or settings groups.
- **Right context drawer:** 300-360 logical pixels for node dossiers, item descriptions, cost/ownership, or loadout summary. It collapses below content on narrow aspect ratios.
- **Footer prompt bar:** device-aware Accept / Back / Details / Tab prompts and build number.

At 16:9 the map and dossier are side by side. Between 4:3 and 16:10, the left rail narrows and the dossier overlays the right edge. Below 960 logical pixels wide, navigation becomes a top tab row and details open as a full-width modal. The implementation continues to use Godot containers and anchors; fixed pixel offsets are limited to minimum sizes and gutters.

### Visual language

- Preserve deep navy negative space and the current neon roles: cyan = navigable/system, yellow = primary/selected, green = complete/safe, magenta = anomaly/story, red-orange = danger.
- Reuse the main-menu pixel planet, native Swallowtail preview, relay-waveform graphics, and the approved cabinet/dock mockups in `design/mockups/` and `mockups/`.
- Use the butterfly geometry as a map cursor and departure marker without turning the map into character art.
- Consolidate repeated `StyleBoxFlat` construction and per-screen color constants into `res://ui/themes/farinuff_frontend_theme.tres`. Keep `NeonUI` only for genuinely dynamic controls that cannot be authored in scenes.
- Decorative CRT/distortion layers sit behind or outside critical text. Settings continue to disable both immediately.
- Use motion to clarify hierarchy: 160-240 ms page transitions, one route-trace reveal on first discovery, and a short ship departure. Reduced Flashing replaces pulses/glitches with opacity-free outlines and cuts nonessential animation.

### Input, focus, and accessibility contract

- All flows work with mouse, keyboard, and controller without changing devices.
- `ui_accept` activates, `ui_cancel` goes back one level, directional inputs traverse explicit focus neighbors, and shoulder buttons change tabs.
- Opening a page focuses its primary safe action. Closing a modal restores the exact invoking control, not merely the first button.
- Hover may move focus only when the latest input device is a mouse; controller focus must not jump because a stationary cursor overlaps a control.
- Destructive actions require confirmation and default focus to Cancel.
- No status is color-only. Locks, selection, completion, unread content, affordability, and modifier activation each have text or glyph redundancy.
- Target minimum sizes at 1280x720: 16 px body copy, 14 px metadata, 44x44 controls, and a clearly visible 2 px focus outline. Existing smaller text can remain in the combat HUD until its later accessibility pass.
- Long text wraps without horizontal scrolling. Every interactive Control has an accessibility name/description where Godot exposes one.
- Settings add UI Scale (100/115/130%), Story Frequency, and Hold-to-confirm for destructive actions. Existing Reduced Flashing, fullscreen, audio, CRT, distortion, and alternative controls remain intact.

### Audio contract

Add stable events to the event sheet from `design/audio_direction.md`:

- `UI.NAV.MOVE`: quiet digital tick, aggressively rate-limited.
- `UI.NAV.CONFIRM`: short `D-A` launch fragment.
- `UI.NAV.CANCEL`: descending neutral click.
- `MAP.NODE.DISCOVER`: filtered Return Signal cell.
- `MAP.ROUTE.SELECT`: `A-Bb-A` return scrape without combat metal.
- `MAP.SECTOR.DEPART`: one-bar transition aligned to the gameplay music grid.
- `STORY.FRAGMENT.OPEN`: low-volume waveform lock cue.

Map/menu cues use the UI bus once that bus exists; they must not share the high-frequency combat voice pool.

## Technical architecture

### Module seams

| Module | Responsibility hidden behind its interface | Callers |
| --- | --- | --- |
| `ExpeditionManager` (new autoload) | Loads and validates campaign data, owns the current route, derives reachability, records discovery/story flags, produces sector transitions, and serializes durable campaign state. | Front-end shell, world map, run interlude coordinator, SaveManager. |
| `CampaignCatalog` (new in-process module) | Resolves stable IDs to definitions and validates graph/boss/story references. It has no mutable state. | ExpeditionManager and validation tests only. |
| `FrontendShell` (scene-owned module) | Page stack, modal stack, transition animation, input-device prompts, and focus restoration. | Top-level page controls. |
| `RunInterludeCoordinator` (scene-owned module) | Converts a milestone transition into one ordered queue of reward, story, and map overlays; owns pause/resume semantics. | `native_3d_run.gd`. |
| `StoryPresenter` (reusable Control) | Renders a beat, applies Story Frequency, records viewed state, and returns one completion result. | Front-end shell and run interlude coordinator. |
| `CommsTicker` (HUD-owned Control) | Priority queue and duplicate suppression for short, non-modal combat barks. It never owns campaign state or focus. | Run controller and campaign event binding. |
| `SectorEncounterProfile` (Resource) | Authored archetype weights and optional encounter tags for one route. | `native_encounter_director.gd` and `threat_director.gd`. |

`ExpeditionManager` should be a deep module with a small interface. Proposed public surface:

```gdscript
func start_new_expedition() -> CampaignSnapshot
func choose_route(node_id: StringName) -> RouteSelection
func record_milestone(cleared_wave: int) -> CampaignTransition
func get_snapshot() -> CampaignSnapshot
func abandon_expedition() -> CampaignTransition
```

Callers should not manipulate arrays of reachable nodes, seen beat IDs, or save dictionaries. Those invariants live inside the module and are tested through this interface.

`FrontendShell` likewise needs only:

```gdscript
func show_page(page_id: StringName, payload: Dictionary = {}) -> void
func show_modal(scene: PackedScene, payload: Dictionary = {}) -> void
func back() -> bool
```

Focus history, modal exclusivity, animations, and page lifetime remain implementation details.

### Proposed file layout

```text
campaign/
  campaign_definition.gd
  campaign_snapshot.gd
  campaign_transition.gd
  route_node_definition.gd
  sector_encounter_profile.gd
  story_beat_definition.gd
  data/
    return_signal_expedition.tres
    routes/*.tres
    story/*.tres
autoloads/
  expedition_manager.gd
ui/frontend/
  frontend_shell.gd
  frontend_shell.tscn
  command_deck.gd
  command_deck.tscn
  world_map_screen.gd
  world_map_screen.tscn
  launch_bay_screen.gd
  launch_bay_screen.tscn
  hangar_screen.gd
  hangar_screen.tscn
  settings_screen.gd
  settings_screen.tscn
  archives_screen.gd
  archives_screen.tscn
ui/shared/
  story_presenter.gd
  story_presenter.tscn
  comms_ticker.gd
  comms_ticker.tscn
  confirmation_dialog.tscn
ui/themes/
  farinuff_frontend_theme.tres
systems/
  campaign_catalog.gd
  run_interlude_coordinator.gd
tests/
  campaign_catalog_smoke.gd
  campaign_catalog_smoke.tscn
  expedition_progression_smoke.gd
  expedition_progression_smoke.tscn
  frontend_navigation_smoke.gd
  frontend_navigation_smoke.tscn
```

The first implementation may keep `res://ui/main_menu.tscn` as a thin wrapper that instances `frontend_shell.tscn`. That preserves the current `project.godot`, pause-menu return path, `ResourceCache` allowlist, and tests while screens move one at a time.

### Authored resource fields

`RouteNodeDefinition`:

- stable `id` and localization-ready display/description keys;
- sector index and inclusive wave range;
- map position in normalized coordinates;
- outgoing node IDs;
- `boss_variant_id` for the sector endpoint;
- encounter-profile resource;
- briefing, debrief, and optional fragment beat IDs;
- threat tags and visual accent;
- discovery and completion glyph IDs.

`StoryBeatDefinition`:

- stable `id`;
- trigger type: pre-sector, post-sector, combat bark, fragment, victory, or Endless;
- speaker ID and text key;
- optional portrait/waveform asset;
- once policy: always, first-run, first-discovery, or first-clear;
- blocking/skippable flags and auto-dismiss duration for barks;
- optional required/forbidden route tags.

`SectorEncounterProfile`:

- archetype weights for basic, fast, bomber, tank, and sniper;
- optional encounter tags understood by the director;
- optional spawn, orb, pickup, and threat-budget multipliers defaulting to `1.0`;
- validation limits so a data error cannot produce zero enemies or unsafe scaling.

Only archetype weights ship in the MVP. The other fields establish an intentional extension point and must remain at neutral defaults until separately balanced.

### Runtime event order

At a normal five-wave milestone:

1. `native_encounter_director.gd` finishes the boss and clears hostile projectiles/hazards as it does now.
2. `GameManager` banks boss salvage and advances to the next wave without allowing new spawns to resume.
3. `ExpeditionManager.record_milestone(cleared_wave)` returns one immutable `CampaignTransition` containing the cleared node, next reachable nodes, story beat IDs, and whether a route choice is required.
4. `RunInterludeCoordinator` queues overlays in this order: elite choice when eligible, stat allocation, debrief beat, world-map route choice.
5. Route confirmation calls `ExpeditionManager.choose_route()`, passes the resulting encounter profile to the encounter director, then resumes the run.
6. The existing evolution banner appears as combat resumes, not underneath a blocking overlay.

At Wave 20, the existing Expedition victory surface replaces the route-choice step. It presents the final reveal, then delegates to the existing return-to-menu or `GameManager.continue_into_endless()` paths.

Replace the current `_elite_pending` plus `_allocation_queue` coordination in `scenes/native_3d_run.gd` with the single ordered interlude queue before adding story/map overlays. Layering another boolean onto the existing pair would make signal ordering harder to reason about and test.

### Save semantics

Raise `SaveManager.SAVE_VERSION` from 2 to 3 and add a nested `campaign` object:

```json
{
  "campaign": {
    "discovered_node_ids": [],
    "seen_story_beat_ids": [],
    "expedition_clear_count": 0,
    "last_ending_id": ""
  }
}
```

Migration from v2 supplies these defaults and preserves every existing setting, unlock, statistic, and first-clear milestone. Current route, active node, in-run upgrade choices, wave, score, and entities are intentionally absent. A future active-run checkpoint feature must use a new schema and a separate design.

### Existing integration points

- `ui/main_menu.gd`: become the compatibility wrapper/front-end composition root; stop directly owning each migrated overlay.
- `ui/launch_bay.gd` and `ui/hangar_menu.gd`: retain current `MetaProgression` behavior while their control trees move into declarative screen scenes.
- `ui/settings_menu.gd`: retain immediate SaveManager application; add tabbed categories, Story Frequency, UI Scale, and hold-to-confirm.
- `ui/flight_school.gd`: reuse lesson data and persistence, then move into the shell.
- `ui/pause_menu.gd`: adopt the shared theme/confirmation dialog and rename destructive actions accurately.
- `ui/expedition_victory.gd`: host the final story beat without changing the two existing outcomes.
- `ui/hud.tscn`: host `CommsTicker` below the critical combat readouts; barks queue by priority, auto-dismiss, never pause, and respect Reduced Flashing.
- `scenes/native_3d_run.gd`: own the interlude coordinator because it already owns the run overlays and pause lifecycle.
- `systems/native_encounter_director.gd`: accept the selected `SectorEncounterProfile` and replace implicit boss variant arithmetic with stable IDs.
- `systems/threat_director.gd`: consume validated archetype weights/tags, not campaign or UI state.
- `autoloads/save_manager.gd`: persist only durable campaign fields and preserve atomic backup behavior.
- `autoloads/resource_cache.gd`: add the shell/map scenes to the bounded preload allowlist only when profiling shows a transition hitch.

## Delivery plan

### Milestone 0 — lock the content contract

Deliverables:

- Fix the Wave-20 boss identity mapping.
- Inject the production hazard manager into spawned `BomberEnemy3D` actors.
- Approve the four sector names, MOTH/Return Signal premise, route names, and ending reveal.
- Add stable IDs and validation rules before prose is spread across UI scripts.
- Document that a run cannot be resumed after process exit.

Exit criteria:

- Waves 5/10/15/20 resolve to Assault/Bulwark/Tempest/Core and Wave 25 to Harbinger.
- A later-generation bomber receives the scene-owned hazard manager and can request a bounded mine.
- README, Flight School, victory copy, boss mapping, and campaign data agree.

### Milestone 1 — front-end foundation

Deliverables:

- Shared Theme resource and reusable focus/confirmation behavior.
- FrontendShell with page and modal stacks.
- Command Deck and existing Launch Bay migrated into the shell.
- Mouse/keyboard/controller device prompts and focus restoration.

Exit criteria:

- The existing “start run” path still reaches `native_3d_run.tscn` with the selected hull/modifiers.
- Back navigation is deterministic from every migrated screen.
- No old Hangar, setting, onboarding, or save behavior regresses.

### Milestone 2 — map vertical slice

Deliverables:

- Campaign resources and validation.
- ExpeditionManager v3 persistence migration.
- Full four-sector map rendered with only The Far Reach initially reachable.
- Pre-launch Far Reach briefing, node dossier, and map-to-Launch-Bay flow.
- One route choice after Wave 5 using Iron Wake and Ghost Lanes archetype weights.

Exit criteria:

- A fresh save, migrated v2 save, and corrupt-save fallback all open the map safely.
- The selected route affects only Waves 6-9 regular-enemy weighting and leaves the Wave-10 boss intact.
- Closing or abandoning the interlude cannot unpause combat behind the map.

### Milestone 3 — complete the Expedition story

Deliverables:

- Remaining sector briefings, debriefs, fragments, and sparse combat barks.
- Wave-10 and Wave-15 route/interlude flows.
- Tempest Core reveal and story-aware victory copy.
- Archives page and discovery markers.
- Endless/Harbinger discovery beat.

Exit criteria:

- The full campaign can be played with Story Frequency Full, Brief, or Off.
- Every blocking beat occurs with zero active hostile threats and is skippable.
- Repeat runs suppress first-discovery prose while objective information remains clear.

### Milestone 4 — finish the menu revision

Deliverables:

- Hangar, Flight School, Settings, results, victory, and Pause adopt the shared theme and interaction contract.
- UI Scale, explicit focus graph, accessibility metadata, reduced-motion/flashing variants, and responsive dossier layout.
- Stable map/menu audio events using The Return Signal motif.

Exit criteria:

- All front-end and pause flows pass the device/resolution matrix below.
- No critical text sits under a distortion-only cue or requires color perception.
- The old per-screen style builders are removed only after the corresponding screen is migrated.

## Verification plan

### Automated

- **Campaign catalog:** stable IDs are unique; all connections, bosses, profiles, and story beats resolve; every node is reachable from the start; no route bypasses the final node; multiplier defaults are within bounds.
- **Progression:** start, select, clear, abandon, first-clear, replay, and Endless transitions are deterministic through the `ExpeditionManager` interface.
- **Persistence:** v2 migration, v3 round-trip, corrupt primary/valid backup, unknown IDs, and future-version read-only behavior preserve existing guarantees.
- **Interlude ordering:** Wave 5 = stat -> story -> map; Wave 10 = elite -> stat -> story -> map; Wave 15 = stat -> story -> map; Wave 20 = victory. No overlay duplication and no early unpause.
- **Boss contract:** production milestone-to-variant mapping, title, and victory identity agree.
- **Frontend navigation:** every page has initial focus, every modal restores invoking focus, Cancel obeys the page stack, and unavailable/locked actions cannot activate.

### Manual matrix

| Area | Cases |
| --- | --- |
| Input | Keyboard only, mouse only, Xbox-style controller only, switching device mid-screen, controller disconnect/reconnect. |
| Resolution | 1280x720, 1920x1080, 1024x768, 1280x800, and 2560x1080; windowed and fullscreen. |
| Settings | CRT off/on, distortion off/on, Reduced Flashing off/on, UI scale 100/115/130%, Story Full/Brief/Off, master/music at zero. |
| Saves | Fresh profile, migrated v2 profile, all routes discovered, future-version read-only save, corrupted primary with valid backup. |
| Run state | Death before a milestone, try-again at a boss, abandon from map, restart from pause, clear Wave 20, continue to Wave 21, die in Endless. |
| Economy/loadout | Locked and owned hulls/modifiers, all modifiers active, supplies armed, unaffordable/maxed Hangar items, route selection with every challenge modifier. |

## Release acceptance criteria

The feature set is ready when:

1. A new player can state the objective, next boss, and meaning of the map's selected route before launching.
2. The Wave-20 fight is unambiguously Tempest Core in data, UI, runtime title, and victory copy.
3. The Expedition remains 20 waves, the in-memory build survives every sector interlude, and no map action skips combat.
4. Story can be completed, shortened, or disabled without changing mechanics or rewards.
5. Both Sector 2 routes and both Sector 3 routes are viable and show accurate threat previews.
6. All front-end actions work by mouse, keyboard, and controller, with deterministic focus restoration and confirmation for destructive actions.
7. v2 saves migrate without losing settings, salvage, unlocks, hull/modifier selections, milestones, or lifetime stats.
8. Returning to menu, retrying, abandoning, clearing, and continuing to Endless each finalize or preserve run state exactly once.
9. The menu, map, and story surfaces share one Theme, vocabulary, input prompt system, and audio language.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Story slows an arcade game | Put blocking prose only at safe boundaries, enforce word budgets, remember viewed beats, and offer Full/Brief/Off. |
| Map becomes cosmetic | Ship the first route-dependent enemy weighting in the vertical slice and show the effect in threat tags. |
| Route and challenge modifiers create opaque stacking | Keep route profiles neutral for economy/HP/spawn speed in MVP and show route effects separately from run-wide challenges. |
| Interlude overlays race existing elite/allocation popups | Replace the current boolean-plus-array logic with one ordered coordinator and test each milestone contract. |
| Menu rewrite regresses mature flows | Keep `ui/main_menu.tscn` as the boot wrapper and migrate one screen at a time behind the shell. |
| Save expansion damages buyer progress | Bump the schema, default missing campaign fields, retain atomic backup rotation, and cover migration/future-version cases before release. |
| Small neon text remains inaccessible | Establish front-end text/control minimums now; schedule the combat HUD as a separate pass. |
| Content identifiers drift from boss arrays and prose | Stable authored IDs plus catalog validation; do not derive narrative identity from array position. |

## Decisions to confirm before implementation

These are product choices, not technical blockers. The plan assumes the first option in each line:

- MOTH remains text-only for the first release; voice-over is a later production layer.
- Route choices change encounter weighting and story first; bespoke hazards/rewards arrive only after balance data.
- The pilot remains unnamed and visually undefined.
- Returning home ends and banks the run; continuing follows the signal into Endless without returning to the map between every five waves.
- Archives unlock after the first recovered fragment and remain optional.
