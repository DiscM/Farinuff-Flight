# Forward+ for Native 3D

**Status**: accepted

The native 3D runtime will target Godot's Forward+ renderer because the project is moving toward polished desktop 3D craft, lighting, and effects. Forward+ provides the rendering ceiling needed for clustered lights, richer shadows, advanced reflections and indirect lighting, volumetric effects, and higher-precision HDR presentation; the decision assumes modern desktop hardware rather than Web, older hardware, or mobile-first deployment.

## Considered Options

- Keep GL Compatibility, preserving the widest hardware and Web support but limiting advanced 3D rendering features.
- Use Mobile, retaining RenderingDevice features with a lower feature/performance target than Forward+.

## Consequences

Forward+ increases hardware, driver, and desktop OS requirements, excludes Web as a primary target, and may require scene, lighting, environment, material, and shader retuning. The 2D backdrop and HUD remain valid, but final 3D assets and materials must be validated against Forward+ before the native 3D runtime is considered complete.

## Migration Sequence

The renderer change is the first implementation checkpoint: preserve the current 2D baseline, switch to Forward+, run the existing 2D smoke tests and manual baseline check, resolve renderer-related regressions, and only then build the native 3D vertical slice. No 3D asset or material is considered final while it has only been evaluated under Compatibility.

## Native 3D Output Resolution

The native 3D validation and final combat layers will render directly at the active game backbuffer or viewport resolution rather than through the reduced-resolution ship `SubViewport` used by the transitional presentation layer. Low-poly and pixel/voxel styling remain deliberate art direction choices, but low-resolution upscaling is not the native 3D output strategy. The transitional proxy is excluded from the native 3D validation scene and is removed once no longer referenced.

## Stylized Shading

Native-resolution output will preserve the project's stylized hard-surface and voxel-inspired shading direction through palette-banded lighting, controlled face contrast, emissive cores and engines, and deliberate edge accents. Forward+ is being adopted to improve the quality ceiling for that style, not to require a realistic PBR art direction.

## Initial Anti-aliasing

The first native 3D pass will use 2× or 4× MSAA as the baseline edge treatment. TAA and FSR2 remain disabled during the initial art and gameplay validation because temporal accumulation and reconstruction can soften crisp hard-surface silhouettes or introduce temporal artifacts in fine neon effects. They may be evaluated later as profiling and visual review warrant.

## 2D Asset Resolution Audit

Retained 2D presentation layers will receive an explicit resolution audit. Procedural and drawn backdrop elements will render at native resolution; unintentionally enlarged raster assets will be re-rendered or replaced; intentionally pixel-art assets will declare their pixel scale and filtering rather than inheriting a global low-resolution or nearest-neighbor assumption.

## Performance Target

The native 3D runtime must sustain 60 FPS at 1920x1080 on the intended modern desktop baseline during the heaviest enemy wave and boss attack. Validation must include active projectile and collision-shape counts, local-light count, draw calls, frame time, and the absence of visible hitches from pool growth or hot-path allocations after pools are warmed.
