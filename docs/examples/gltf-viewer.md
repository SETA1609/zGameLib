# glTF-viewer — design

> Rung A2 of the [animation track](ladder.md#animation-track-zclip). Loads a glTF 2.0 file with skeletal animation and renders the skinned mesh through the raw `zclip.skeletal` path. Proves the cgltf→bone-hierarchy→joint-palette pipeline end-to-end.

## What it does

Initialises the platform + Vulkan stack, loads a glTF file containing a skinned mesh + animation clip, builds the bone hierarchy from `zclip.skeletal`, uploads joint palettes to a GPU buffer, and renders the mesh with per-vertex skinning. The animation plays on loop; keys switch between available clips in the glTF file.

## What building it forces into existence

| Lib | Milestone | Pieces used |
| --- | --- | --- |
| platform | v0.6.0 | window + event pump + `now()` |
| vulkan | v0.3.0 (VMA) | device + VMA + depth attachment + uniform buffer (MVP) + storage buffer (joint palette) |
| zClip | **v0.7.0** | `zclip.skeletal.Skeleton` (bone hierarchy from cgltf), `zclip.skeletal.Clip` (channel-based animation from glTF), joint-palette baking per frame |
| this repo | — | `shared/surface.zig`, `shared/swapchain.zig`, `shared/gpu.zig`, `shared/frame.zig` |

## Frame loop

**Setup**
1. `platform.init(.{})`; `platform.Window.create(.{ .renderer = .vulkan })`.
2. `Gpu.init(window)` → instance + surface + device + VMA.
3. Load glTF via cgltf (wrapped by zClip): mesh data (positions, joints, weights) + skeleton + clips.
4. Build `zclip.skeletal.Skeleton` — bone hierarchy, inverse bind matrices.
5. Upload mesh to GPU (vertex buffer with `POSITION` + `JOINTS_0` + `WEIGHTS_0`; index buffer).
6. Create depth attachment + MVP uniform buffer + joint-palette storage buffer.
7. Create graphics pipeline (skinning vertex shader + simple fragment shader).

**Loop** (until close / ESC)
8. `platform.pollAllEvents()`; handle resize, clip-switch keys.
9. Calculate dt; advance active clip: `clip.advance(dt)`.
10. `skeleton.bakeJointPalette(clip.phase)` → array of 4×3 matrices (joint palette).
11. Upload palette to storage buffer.
12. Update MVP uniform (orbit camera rotates slowly).
13. Record command buffer: depth clear → bind pipeline → bind VB/IB → bind descriptor sets (MVP + palette) → draw indexed → present.

**Teardown**: destroy GPU resources → `Gpu.deinit()` → `window.destroy()` → `platform.deinit()`.

## Done when

- Window opens with a skinned mesh animating (e.g. the DamagedHelmet or a simple rigged figure).
- Multiple glTF animation clips switch via keyboard; each plays at the correct speed.
- The joint palette updates per frame and skinning is visibly correct (no broken vertices).
- Orbit camera rotates around the model; depth-testing works.
- Resizing recreates the swapchain; ESC quits.

## Build

```sh
zig build gltf-viewer
```

## zClip surface exercised

| zClip API | How it's used |
| --------- | ------------- |
| `zclip.skeletal.Skeleton.init` | Build bone hierarchy from cgltf data |
| `zclip.skeletal.Clip.init` | Extract animation channels from glTF |
| `Clip.advance(dt)` | Step skeletal animation |
| `Skeleton.bakeJointPalette(phase)` | Compute per-frame joint transforms |
| `Skeleton.joint_count` | Size the palette storage buffer |
