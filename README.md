# Farinuff Flight

A premium single-purchase 2D arcade shooter built in Godot 4. Farinuff Flight centers on fast survival play, drift-heavy ship handling, boost-reflection combat, transformative run builds, and an authored Wave-20 Expedition that opens into optional Endless mastery.

![Gameplay capture](assets/readme/gameplay-capture.png)

![Elite boss fight capture 1](assets/readme/elite-boss-fight.png)

![Elite boss fight capture 2](assets/readme/elite-boss-fight-fullpower.png)

## Gameplay Mechanics

Farinuff Flight uses a taught finite Expedition followed by optional Endless play. Standard enemies spawn from the screen edges, drop XP orbs on defeat, and increase pressure as the wave count rises. XP orbs fill the wave meter, restore lives after enough collection, and advance the run toward tougher enemy mixes.

Combat uses held auto-fire with free aim support. The ship can aim with mouse movement or controller right stick input, while keyboard movement keeps the ship inside the visible playfield. Boosting adds a short high-speed dash, post-boost drift, afterimages, projectile deflection, and chain potential after multiple reflected shots.

Power-ups appear during active waves and can be collected by contact or shot pickup. Current temporary effects include bullet scale increases, rapid fire, shield, spread shot, magnet, and nuke. These stack with run upgrades to create different weapon profiles across a session.

Progression adds permanent run choices at milestone moments. Every fifth cleared wave grants stat allocation points for fire rate, health, and movement speed. Boss waves occur every 5 waves, while every 10th wave triggers an elite upgrade choice with options such as twin cannons, auto-aim, drone escort, afterburner, shield burst, magnet field, overclock, and rear gunner.

The first launch opens Flight School, a replayable five-page briefing covering movement, boost reflection, the orb/life economy, build decisions, and the Wave-20 target. Failure uses a try-again flow before final game over. Remaining try-again stocks can continue a run, clear immediate pressure, and return the ship with temporary invincibility. Final game over records score, high score, and highest wave reached.

Runs also earn salvage — a persistent currency banked from boss kills and an end-of-run bonus based on score and waves cleared. Salvage spends in the Hangar on the title screen: tiered ship systems (starting lives, speed, fire rate, extra try-again stocks), elite blueprints that add Orbital Array, Piercing Rounds, and Explosive Rounds to the elite upgrade pool, ship variants, and challenge modifiers.

Before each run, the launch bay offers a loadout choice: pick an unlocked ship variant (the balanced Swallowtail, the fast-but-fragile Interceptor, or the slow-but-tough Bulwark) and toggle any owned challenge modifiers — faster spawns, armored enemies, no power-ups, and more — each paying a percentage bonus on all salvage earned that run. The game-over screen itemizes where the run's salvage came from.

## Controls

- Movement: `WASD` or `Arrow Keys`, or gamepad left stick
- Shoot: hold `Space`, gamepad `A` / right trigger
- Boost: `Shift`, gamepad `B` / left trigger
- Pause: `Escape`
- Free aim: mouse movement or gamepad right stick
- Alt controls (Settings toggle): shoot with `Left Mouse Button`, boost with `Space`

## Tech Stack

- Engine: Godot 4.6 project format with Forward+ rendering; the verified 2D gameplay baseline remains active while native 3D migration is in progress
- Language: GDScript 2.0 with typed scripts across gameplay systems
- Architecture: scene-based composition with reusable player, enemy, bullet, power-up, HUD, menu, and popup scenes
- Global state: autoload singletons for `GameManager`, `MetaProgression`, `SignalBus`, and `SaveManager`
- Event flow: signal-driven score, combo, life, orb meter, wave, boss, allocation, elite upgrade, settings, and game-over updates
- Rendering: procedural starfield and background layers, shader-driven CRT overlay, distortion pass, screen shake, tweens, and generated visual effects
- Persistence: saved settings and high score through the save manager
- Build target: exported Windows desktop build included with the repository
