# Theory: The Cherno's Hazel & Hazelnut Split — The View from Tier 1

## What This Doc Is

This document is the **zGameLib counterpart** of the Nexus-engine theory document
[`10-hazel-hazelnut-split.md`](../../../docs/theory/10-hazel-hazelnut-split.md). That
doc explains what the Hazel/Hazelnut architectural split means for Tiers 2 and 3.
This one focuses on what it means for **Tier 1** — the foundation library that
both the engine and the editor consume.

Read that doc first for the full context (who The Cherno is, how his split works,
the key lessons). This doc adds the Tier‑1 perspective.

---

## The Three-Tier Picture

```
Crucible (Tier 3 — Editor)
    Links against Nexus-engine
           │
           ▼
Nexus-engine (Tier 2 — Engine Library)
    Links against zGameLib
           │
           ▼
zGameLib (Tier 1 — Foundation)     ← YOU ARE HERE
    Pure low-level reusable primitives
    No engine-specific code
```

## What This Means for zGameLib

The Hazel/Hazelnut split confirms a design direction we already committed to, but
it also sharpens a constraint that is easy to forget:

### Confirmed: zGameLib must be engine-agnostic

The Cherno's Hazel never had a clean engine-agnostic foundation layer. Its lowest
levels were tightly coupled to Hazel's own rendering model. When Hazelnut (the
editor) needed to present ImGui overlays or manage editor-specific windows, those
concerns bled into engine code.

**Our advantage:** zGameLib is *not* Hazel's foundation. It is a general-purpose
game-dev library that happens to have Nexus-engine as its first consumer. This
means:

- Crucible can (and should) link directly against zGameLib for any foundation
  concern it needs — windowing, Vulkan, swapchain, frame ring, hot-reload
  primitives — *without* going through Nexus-engine.
- ImGui integration lives in zGameLib's optional module layer, usable by both
  Nexus-engine (runtime debug UI) and Crucible (editor panels).
- zGameLib's hot-reload system (`08-hot-reload.md`) is a generic primitive; the
  engine and editor each layer their own policies on top.

### Sharpened constraint: no editor-specific code in Tier 1

Because zGameLib ships as an independent reusable library, it must never grow
editor-specific concepts — no "editor scene", no "editor viewport", no
"inspector panel". Those belong in Crucible (Tier 3). If zGameLib needs to provide
a mechanism that the editor happens to use (e.g. file watching, ImGui integration),
it must be designed as a general-purpose primitive, not an editor feature.

### Sharpened constraint: no engine-specific code in Tier 1

Similarly, zGameLib must not grow engine-specific concepts that belong in
Nexus-engine — no "SceneNode", no "ECS bridge", no "LocalizationSystem". Those
are Tier 2 concerns. The line is:

| Belongs in zGameLib (Tier 1) | Belongs in Nexus-engine (Tier 2) |
|---|---|
| Vulkan stack, swapchain, frame ring | SceneNode hierarchy, ECS bridge |
| SDL3 windowing, input, platform | Systems, update loop, fixed timestep |
| 2D batcher, texture upload | Resource manager, asset pipeline |
| ImGui integration (optional) | Editor-specific use of ImGui |
| Hot-reload primitives (file watcher, rebuild hooks) | Hot-reload policies (what to reload, when) |

## Testing the boundary: the Crux Question

When you are unsure whether a piece of code belongs in zGameLib or higher, ask:

> **"Could a non-game-engine application (a pure tool, a demoscene app, a
> visualiser) reasonably want this?"**

If yes → zGameLib.
If no → Nexus-engine or Crucible.

This is the litmus test that keeps Tier 1 clean. The Cherno's Hazel never had this
line, and his foundation layer suffered for it.

## Conclusion

The Hazel/Hazelnut split is an existence proof that separating engine from editor
is worthwhile. For zGameLib specifically, it reinforces the **raw-first / opt-in**
and **engine-agnostic** design principles. By keeping Tier 1 free of both
engine-specific and editor-specific concepts, we ensure it remains a reusable
foundation that can outlive any single consumer.

---

*Document created based on public YouTube content and GitHub repository of
The Cherno's Hazel project (as of 2026). Cross-references the Nexus-engine theory
doc [`10-hazel-hazelnut-split.md`](../../../docs/theory/10-hazel-hazelnut-split.md).*
