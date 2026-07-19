# Build Step Files

Each file in this directory defines one step (or a closely related group of
steps) in the build DAG. `build.zig` imports and calls them in dependency
order, wiring the outputs of earlier steps into later ones.

## DAG

```
modules.zig  ──────┬──────→  tests.zig  ──┐
                   │                       │
                   └──────→ examples.zig ──┤
                                          │
                                          ↓
                                       dev.zig
```

| Step file | Responsibility | Output type | Consumed by |
| --- | --- | --- | --- |
| [`modules.zig`](modules.zig) | Dependency resolution, shared & framework module creation | `Modules` | tests, examples |
| [`tests.zig`](tests.zig) | Unit, integration, and GPU test targets | `TestSteps` | dev |
| [`examples.zig`](examples.zig) | Example executables (compile + run steps) | `ExampleExes` | dev |
| [`dev.zig`](dev.zig) | Composite `dev` step — builds everything + runs all tests | — | — |

## Convention

- Every file exposes a `pub fn create(...)` function that registers build
  steps and returns a struct of references for downstream steps.
- Step files import only `@import("std")` and sibling step files (via
  relative `@import`). They never import the project's own source modules.
- `build.zig` is the sole orchestrator — it does not define steps inline.
