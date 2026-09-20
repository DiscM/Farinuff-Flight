# Player trust review captures

September 19, 2026; Godot 4.6.3 on macOS, Apple A18 Pro, Metal Forward+.
These are in-engine engineering references from a disposable profile, not
art approval, physical-device acceptance, or exported Windows evidence.
Existing local copy edits are visible in captures and remain separate from this
slice's implementation commit.

| Capture | Setup |
| --- | --- |
| [Display options](captures/settings-display-options-720-large.png) | 1280×720, 130% menu text; graphics, frame limit, VSync, and pinned Close |
| [Independent HUD size](captures/settings-access-hud-720-large.png) | 1280×720, 130% menu text and combat HUD; options scrolled to HUD size |
| [Controls](captures/settings-controls-720-large.png) | 1280×720, 130% menu text; toggle fire, deadzone, and remapping entry |
| [720p HUD](captures/hud-720-130.png) | 1280×720, HUD 130% |
| [1080p HUD](captures/hud-1080-130.png) | 1920×1080, HUD 130% |
| [16:10 HUD](captures/hud-16-10-130.png) | 1280×800, HUD 130% |
| [Ultrawide HUD](captures/hud-ultrawide-130.png) | 1920×810, HUD 130% |
| [Quit confirmation](captures/quit-confirmation-720-large.png) | 1280×720, 130% menu text; active native run |
| [Failed final save](captures/quit-save-failure-720-large.png) | Directory at the temporary progress path forces a write failure; Retry Save has focus |
| [Newer save notice](captures/newer-save-warning-720.png) | Injected schema-999 progress triggers the persistent read-only warning |

HUD captures use god mode, paused encounter scheduling, scripted power-ups and
a synthetic Tempest Core HUD warning. There is no live boss behind that warning.
Reduced flashing and menu motion are enabled. The quit check stages the score
and wave, verifies the error UI, removes the write obstruction, then retries
and reopens the game. Temporary files/profile are removed after validation.

See [storage and acceptance protocol](../../docs/player-trust.md). Images stay
outside the runtime asset import graph through `.gdignore`.
