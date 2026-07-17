# Architecture Decisions — zGameLib

## 1. Comptime foundation tier

zGameLib is Tier 1 — a collection of source-level Zig modules consumed via
`b.addModule`, not a static library. This is where Zig's comptime model delivers
maximum value (Vulkan pipeline builders, platform abstractions, FrameRing).

- Consumers link individual modules: `zgame.platform`, `zgame.vk`, `zgame.Gpu`, etc.
- `zgame_platform` module exists as a decoupling check — no Vulkan symbols leak in.
- The Nexus engine static library (T2) re-exports zGameLib modules to its consumers.

Bundle rationale: [`../../../../docs/architecture-decisions.md`](../../../../docs/architecture-decisions.md)

## 2. Script encapsulation for CI

No non-trivial bash/Python inline in `.github/workflows/*.yml`. All meaningful
logic goes in `scripts/` and is called from CI.

**Already practiced in this repo:** the main CI build, decoupling check, and
display tests all call `scripts/ci.sh` rather than inlining commands.
