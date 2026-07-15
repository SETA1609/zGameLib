# Sprint 1 — Foundation + modular ladder setup

> The first miniproject: wire the libs-first build, land both Foundation rungs
> (platform-only + platform+vulkan together), and establish the
> pay-for-what-you-use pattern that all later rungs follow.
>
> **Goal:** tag examples **v0.1.0**.
>
> **Definition of done:** `zig build clear-color` opens a window whose
> clear-colour animates (a cycling palette), recreates its swapchain on resize,
> and quits on window close with **zero validation-layer messages**; `zig build
> event-logger` runs platform-only; **both `nm` decoupling checks print
> nothing**; CI builds every example on Linux + Windows and runs the
> headless-safe ones.

Items (completed):

- [x] **S1.1** Enable the local-path deps. `build.zig.zon`: uncomment the `.platform` + `.vulkan_stack` path entries.
- [x] **S1.2** Wire the build shell. `build.zig`: pull both `b.dependency(...)`, create the `surface` module, add the example-exe helper.
- [x] **S1.3** Rung 0 — event-logger (platform only). **No `vulkan_stack` import** — this enforces pay-for-what-you-use from the start.
- [x] **S1.4** Decoupling check #1 (`scripts/ci.sh decoupling`): assert event-logger drags **none of our Vulkan stack**.
- [x] **S1.5** The surface bridge (`shared/surface.zig`).
- [x] **S1.6** Rung 1 — clear-color (platform + vulkan together).
- [ ] **S1.7** Decoupling check #2 (headless-vulkan: no windowing symbols).
- [x] **S1.8** CI (build every example on Linux + Windows; run headless-safe ones).
- [ ] **S1.9** Tag `v0.1.0`.

## Out of this sprint

- **Rung 2** (clear-color-2 + hello-triangle with Gpu/FrameRing) — v0.2.0.
- **Rung 3+** (animation, audio, assets, App) — later releases, each adding
  exactly one sibling library. See [`ROADMAP.md`](ROADMAP.md).

## Pay-for-what-you-use tracking

Each rung's build must link **only** the libraries it needs:

```
event-logger:  nm … | grep 'vk\.|volk|Vma|shaderc' → empty  ✅
clear-color:   nm … | grep 'zClip|miniaudio'        → empty  ✅
```

These checks are the project's most important CI gates.
