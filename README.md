# Farinuff Flight 🚀

A high-octane, procedural 2D space shooter built in **Godot 4.x**. 

Fight through endless waves of increasingly difficult enemies, collect powerful upgrades, and survive intense boss encounters. Featuring retro CRT aesthetics, procedural generation, and momentum-based movement.

## Features
- **Dynamic Wave Progression:** The game progresses based on the total XP orb value you collect, incentivizing players to hunt down high-value targets.
- **RPG Upgrade System:** Collect power-ups mid-wave and allocate points for permanent ship upgrades (Orbitals, Twin Cannons, Piercing Rounds).
- **Elites & Bosses:** Face challenging Boss encounters every 5 waves, with terrifying Elite Bosses dropping massive XP rewards at wave 10.
- **Procedural Rendering:** Ships, backgrounds, and visual effects are heavily driven by code and Godot 4 Shader Materials (`.gdshader`).
- **Retro Aesthetic:** A custom-built, full-screen CRT post-processing shader provides authentic barrel distortion, RGB chromatic aberration, and scanlines.

## Controls
- **Movement:** `Arrow Keys` or `W-A-S-D`
- **Shoot:** `Spacebar` (Hold for auto-fire)
- **Pause:** `Escape`

## Development
This project is explicitly built focusing on Godot 4's modern standards:
- Extensive use of GDScript 2.0 static typing.
- Decoupled event routing through a global `SignalBus`.
- Code-driven shader injection to preserve scene modularity.

---
*Built with [Godot Engine 4](https://godotengine.org).*
