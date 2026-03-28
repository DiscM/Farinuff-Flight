---
name: Godot Game Development & Design
description: A comprehensive guide to understanding Godot 4, GDScript 2.0, game development patterns, and core game design principles.
---

# Godot Game Development & Game Design Framework

This document serves as an internalized skill set to better understand, architect, and implement games in Godot 4. It covers engine specifics, software architecture patterns suited for game development, and high-level design philosophy.

## 1. Godot 4 Engine Concepts

### Node & Scene System
- **Nodes** are the smallest building blocks (e.g., `Sprite2D`, `CollisionShape2D`, `Timer`).
- **Scenes** are trees of nodes that can be saved, instantiated, and nested. A scene is essentially a reusable prefab.
- **Rule of Thumb**: "Call down, signal up." A parent node can directly call methods on its children, but children should emit signals to communicate with their parents.

### GDScript 2.0 Standards
- **Static Typing**: Always try to use static typing (`var speed: float = 300.0`, `func take_damage(amount: int) -> void:`) for better performance, auto-completion, and error catching.
- **Callables & Signals**: Instead of passing string names for functions, Godot 4 uses `Callable`. Signals are objects. You connect them via `button.pressed.connect(_on_button_pressed)`.
- **Await**: Replaces the old `yield`. Use `await get_tree().create_timer(1.0).timeout` to easily pause execution without blocking the main thread.
- **@export**: Use `@export` to expose variables to the Godot Inspector, making tweaking values easy for designers without touching code.

## 2. Game Architecture Patterns (Godot Context)

### Composition over Inheritance
- Instead of creating a massive `Enemy.gd` class and deriving `FlyingEnemy`, `GroundEnemy`, etc., use **Components**. 
- Create a `HealthComponent` node, a `HitboxComponent` node, and a `HurtboxComponent` node. An enemy scene is just a composition of these reusable nodes.

### Autoloads (Singletons)
- Godot allows defining scripts/scenes that exist globally (`GameManager`, `SignalBus`).
- **Signal Bus Pattern**: Instead of tightly coupling UI to a specific player instance, have the player emit an event to the `SignalBus` (`SignalBus.player_health_changed.emit(new_health)`), and let the UI listen to the `SignalBus`.

### State Machines
- For characters or bosses with multiple distinct states (Idle, Run, Jump, Attack), implement a Finite State Machine (FSM). This avoids massive, nested `if-elif-else` blocks in `_process`.

### Object Pooling
- In a game like a Space Shooter, creating (`instantiate()`) and destroying (`queue_free()`) bullets or enemies rapidly can cause memory fragmentation and lag. 
- Use object pooling: instantiate a set number of bullets at start-up, hide them, and recycle them as needed rather than destroying them.

## 3. Game Design Fundamentals

### The Core Loop
- The primary set of actions the player performs repeatedly. If the core loop isn't fun, no amount of polish will save the game. Validate the core loop as early as possible with a barebones prototype.

### Game Feel ("Juice")
- The tactile sensation of interacting with the game. 
- **Techniques to implement**: Screen shake, hit-stop (briefly pausing the game on a heavy impact), particle systems, tweening for smooth scaling/movement, and multi-layered sound effects.

### Readability and Affordance
- A player should be able to look at a screenshot and immediately know what is dangerous, what is interactive, and where the player character is.
- Use color theory, silhouettes, and contrast to guide the player's eye.

### Pacing and The Flow Channel
- Difficulty should ramp up gradually but dynamically. A good game has "peaks and valleys" in pacing—moments of high tension followed by periods of rest to let the player recover.
- Keep the player in the "Flow" state: the sweet spot between anxiety (too hard) and boredom (too easy).

## 4. Godot Shaders

Shaders in Godot run directly on the GPU, achieving immense performance for per-pixel calculations that are impossible on the CPU.
- **CanvasItem Shaders**: specifically for 2D. 
  - The `fragment()` function executes for every single visible pixel to determine its final color and transparency.
  - The `vertex()` function executes for the bounding box corners of the sprite, letting you stretch, squash, or twist the mesh.
- **Shader Materials**: You create a `ShaderMaterial` and write your `.gdshader` code inside it, then attach the material to any node (like a Sprite2D or ColorRect).
- **Uniforms (Parameters)**: GDScript and Shaders communicate via uniforms: `uniform float flash_amount: hint_range(0.0, 1.0);`. GDScript updates them directly: `$Sprite2D.material.set_shader_parameter("flash_amount", 1.0)`.
- **Common 2D Heuristics**: 
  - *Scrolling Textures*: Adding `TIME * speed` to the UV coordinates to pan the image indefinitely.
  - *Dissolve Effects*: Comparing UVs against a Noise Texture and `discard`ing pixels below a threshold.
  - *Hit Flashes*: Blending the pixel's color toward pure white based on a uniform float.

## 5. Current Project Context: "Space Shooter"
- **Physics Layers**: The project has clearly defined routing (`player`, `enemies`, `player_bullets`, `enemy_bullets`, `powerups`). This allows efficient collision filtering using collision masks.
- **Architecture**: The project currently implements a `SignalBus` and a `GameManager` autoload, indicating a scalable event-driven architecture that perfectly aligns with best practices.

## 6. Official Godot 4 Documentation References
When solving unexpected API errors, verifying strict GDScript 2.0 syntax, or seeking best practices for Godot 4.x features, the following official documentation endpoints should be explicitly searched or referenced:
- **Godot 4.x Stable Documentation**: [https://docs.godotengine.org/en/stable/](https://docs.godotengine.org/en/stable/)
- **GDScript 2.0 Reference**: [https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)
- **Godot Shading Language**: [https://docs.godotengine.org/en/stable/tutorials/shaders/index.html](https://docs.godotengine.org/en/stable/tutorials/shaders/index.html)
- **Node & Class API Index**: [https://docs.godotengine.org/en/stable/classes/index.html](https://docs.godotengine.org/en/stable/classes/index.html)

## 7. Parallax Effects (Godot 4.3+)

Parallax creates an illusion of depth by moving background layers at different speeds relative to the camera.

### Parallax2D (Modern Standard)
In Godot 4.3, `Parallax2D` replaced the older `ParallaxBackground` system. It is a `Node2D` that can be placed anywhere in the tree.
- **Scroll Scale**: Determines the layer's speed. `0.2` makes it move 20% of camera speed (looks far away), while `1.5` makes it move faster than the foreground (looks very close).
- **Repeat Size**: Enables infinite scrolling. Set this to the width/height of your texture to have the engine handle seamless tiling.
- **Autoscroll**: A built-in property for constant movement (e.g., a scrolling star field) without manual scripting.

### ParallaxBackground / ParallaxLayer (Legacy)
Required for projects before Godot 4.3.
- `ParallaxBackground` is a specialized `CanvasLayer`.
- `ParallaxLayer` contains the `motion_scale` and `motion_mirroring` properties.
- **Conversion**: In Godot 4.3+, you can right-click a `ParallaxBackground` in the Scene dock and select "Convert to Parallax2D" for an automatic migration.
