# Dear ImGui in zGameLib (optional `zimgui`)

**Status:** Planned (Phase 1 Q3 2026)  
**Policy:** Optional sibling adapter — **not** a core dependency of zGameLib.

---

## Why optional

zGameLib is Tier 1 — a raw-first foundation. Many consumers (minimal Vulkan demos, headless
tools, alternate engines) never draw immediate-mode UI. Dear ImGui is therefore gated behind
a build flag, matching `zaudio`, `zassets`, and other opt-in adapters.

| Consumer | ImGui requirement | In-game UI |
|----------|-------------------|------------|
| Standalone zGameLib game | Optional | 2D batcher (planned) |
| Nexus-engine shipped game | Optional (debug overlay only) | `RenderingServer` + batcher — **not ImGui** |
| **Crucible (Tier 3 editor)** | **Required** — immediate-mode tool UI | N/A (edits scene, does not draw HUD) |

Nexus-engine documents engine vs editor usage in
[`Nexus-engine/docs/theory/06-ui-and-localization.md`](../../Nexus-engine/docs/theory/06-ui-and-localization.md).

---

## Build flag

```sh
zig build -DimGui=true
zig build imgui-demo -DimGui=true   # planned Phase 2 example
```

| Flag | Default | Effect |
|------|---------|--------|
| `-DimGui` | `false` | When `true`, build `zimgui` and export `zgame.zimgui` from `root.zig` |

When `false`:

- No Dear ImGui C++ sources compiled.
- No link against `imgui` / `imgui_impl_sdl3` / `imgui_impl_vulkan`.
- `@import("zimgui")` fails at compile time (intentional — no silent stubs).

---

## Module layout (planned)

```ascii
src/
  zimgui/
    root.zig           // public Context, init, newFrame, render
    backend_sdl3.zig   // event → ImGuiIO
    backend_vulkan.zig // draw lists → command buffer
```

Re-export path:

```zig
// root.zig (when -DimGui=true)
pub const zimgui = @import("zimgui/root.zig");
```

Dependencies: `platform` (SDL3 window + events), `Gpu` + `FrameRing` (Vulkan queue, render pass compatibility).

---

## Initialization (pseudocode)

```zig
const zgame = @import("zgame");
const zimgui = @import("zimgui");

pub fn main() !void {
    var platform = try zgame.platform.init(.{ .title = "imgui-demo", .width = 1280, .height = 720 });
    defer platform.deinit();

    var gpu = try zgame.Gpu.init(&platform, .{});
    defer gpu.deinit();

    var ctx = try zimgui.init(.{
        .allocator = std.heap.page_allocator,
        .window = platform.nativeWindow(),
        .gpu = &gpu,
        .swapchain_format = gpu.swapchainFormat(),
    });
    defer ctx.deinit();

    while (!platform.shouldClose()) {
        while (platform.pollEvent()) |ev| {
            zimgui.processEvent(&ctx, ev);
            if (ev == .quit) break;
        }

        const dt = platform.deltaTime();
        zimgui.newFrame(&ctx, .{ .delta_time = dt, .display_size = platform.drawableSize() });

        if (zimgui.begin("Hello")) {
            zimgui.text("zGameLib + ImGui", .{});
        }
        zimgui.end();

        try gpu.beginFrame();
        // ... optional 3D/2D scene pass ...
        try zimgui.render(&ctx, gpu.currentCommandBuffer(), gpu.currentRenderPass());
        try gpu.endFrame();
    }
}
```

---

## Vulkan rendering notes

1. **Render pass compatibility** — ImGui backend uses the same color format as the swapchain
   (or an offscreen target Crucible uses for viewport compositing).
2. **Load op** — ImGui pass assumes color attachment is already written (scene first).
3. **Font atlas** — uploaded once via staging buffer; invalidation on DPI scale change (SDL3
   `window_pixel_size` / display scale events).
4. **Frame ring** — vertex/index buffers per in-flight frame slot; align with `FrameRing` fence
   semantics.
5. **No GL backend** — Vulkan only, consistent with zGameLib graphics policy.

---

## Integration with Tier 2 / Tier 3

```ascii
zGameLib (-DimGui=true)
  zimgui ──────────────────────────────┐
                                       │
Nexus-engine                           │
  debug-ui example (optional) ─────────┤
  NexusApp does NOT require zimgui     │
                                       │
Crucible (separate repo)               │
  all editor panels ───────────────────┘
  hard-depends on zgame.zimgui
```

Crucible should **not** fork ImGui backends — it uses `zgame.zimgui` so Vulkan/SDL3 fixes
land once in Tier 1.

---

## Licensing

Dear ImGui is MIT. When `-DimGui=true`, `NOTICE` must list ImGui. Default builds omit it.

---

## Roadmap cross-links

- zGameLib Phase 1: `-DimGui` wrapper — [`ROADMAP.md`](ROADMAP.md)
- Nexus v0.8.0 `debug-ui` — optional overlay
- Nexus v1.1.0+ Crucible — required ImGui
- Theory — [Nexus 06-ui-and-localization](../../Nexus-engine/docs/theory/06-ui-and-localization.md)

---

**Summary:** Dear ImGui is a **tooling adapter**, enabled with `-DimGui`, consumed heavily by
Crucible and optionally by debug examples — never implied by a default `zig build`.