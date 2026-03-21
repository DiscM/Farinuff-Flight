---
name: Godot Animation Skills
description: Best practices for implementing programmatic and keyframed animations in Godot 4.
---

# Godot Animation Skills

Godot 4 provides multiple powerful ways to animate objects, nodes, and UI elements.

## 1. Tweens (Programmatic Animation)
Tweens are ideal for procedural, code-driven animations like UI pop-ups, hover effects, or dynamic enemy "breathing" behaviors.
- **Creation**: Always create tweens dynamically with `create_tween()`. Godot 4 manages them automatically and kills them when the bound node is freed.
- **Example**:
  ```gdscript
  var tw := create_tween().set_loops()
  tw.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.5).set_trans(Tween.TRANS_SINE)
  tw.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
  ```
- **Parallel and Sequential**: By default, `tween_property` calls happen sequentially. Use `tw.set_parallel(true)` to make them happen at the same time.

## 2. AnimationPlayer (Keyframed Animation)
`AnimationPlayer` is best for complex, multi-track animations (e.g., character walking, attacking, complex cutscenes).
- **Tracks**: You can animate position, rotation, scale, modulate (color/alpha), and even call methods on specific frames using a Call Method Track.
- **State Machines**: Use an `AnimationTree` with an `AnimationNodeStateMachine` to smoothly blend and transition between different `AnimationPlayer` animations.

## 3. AnimatedSprite2D (Frame-by-Frame)
Best used for traditional 2D pixel-art games where you have spritesheets.
- **Implementation**: Create a `SpriteFrames` resource, add your individual frames, and call `$AnimatedSprite2D.play("run")`.

## Summary
- Use **Tweens** for simple, dynamic math-based interpolation (like we did for the enemy squash/stretch).
- Use **AnimationPlayer** for complex, timed structures that affect multiple nodes.
- Use **AnimatedSprite2D** for classic flipbook-style 2D art.
