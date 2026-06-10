# 02 — Vulkan and the vulkan_stack adapter

*The rendering sub-library: what Vulkan is, the chain of objects you must build
before you can draw, and the four pieces (`vk`, `volk`, `VMA`, `shaderc`) the
adapter bundles so they never drift apart.*

The platform adapter (file 01) gave you a window. To put *pixels* in it with the
GPU, this framework uses **Vulkan**, wrapped by the **vulkan_stack adapter**. This
is the most conceptually dense layer in the whole project — take it slowly.

---

## What Vulkan is — and why it's "explicit"

> "[Vulkan](https://www.vulkan.org/) is a low-level, **explicit** cross-platform
> GPU API from Khronos. 'Explicit' means *you* manage almost everything OpenGL
> hid: memory allocation, synchronization, command recording, and which functions
> even exist (loaded by extension/version). That's more code, but it's predictable
> and multi-threadable — the right base for an engine."
> — [vulkan adapter, `docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md)

That word **explicit** is the key to understanding why every later doc exists. In
older APIs the driver guessed what you wanted; in Vulkan *you* state it. That is
exactly why a framework like zGameLib is worth having: it makes one reasonable set
of those decisions for you (in `Gpu`, `Swapchain`, `FrameRing`) while leaving every
raw handle reachable for when you need to decide differently.

---

## Two ideas that underpin everything

The cheat sheet distills Vulkan to two core ideas. Internalize these and the rest
is detail.

**Idea 1 — function dispatch is *loaded*, not *linked*.**

> "You start with one bootstrap pointer (`vkGetInstanceProcAddr`), load
> *instance-level* functions from it, then *device-level* functions from the
> device. Device-level dispatch skips an indirection (faster on hot paths).
> vulkan-zig models this as `BaseWrapper` → `InstanceWrapper` → `DeviceWrapper`;
> volk's job is just to provide the bootstrap pointer."
> — [vulkan adapter, `docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md)

In a normal C library you call `printf` and the linker wires it up. Vulkan isn't
like that — you ask the driver, at runtime, "give me a pointer to this function",
because *which* functions exist depends on your GPU, driver version, and the
extensions you enabled. That's what `volk` is for (below).

**Idea 2 — objects form a strict hierarchy, destroyed inside-out.**

> "Instance → PhysicalDevice → Device → (everything else). Children must be
> destroyed before parents."
> — [vulkan adapter, `docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md)

This is why the bring-up order (file 04) is rigid, and why teardown happens in
reverse.

---

## The shape of a Vulkan frame

The cheat sheet draws the full object chain, top to bottom, as:

```
load loader (vkGetInstanceProcAddr)         // volk / dynamic load
  └─ Instance  (+ extensions: VK_KHR_surface + platform)
       └─ pick PhysicalDevice (GPU) + a queue family
            └─ Device  (+ swapchain extension) + Queues
                 ├─ Surface (from a window) → Swapchain (images to present)
                 ├─ allocate memory (VMA) → Buffers / Images
                 ├─ compile GLSL → SPIR-V (shaderc) → ShaderModule → Pipeline
                 └─ per frame: record CommandBuffer → submit → present
                      synchronized with Fences + Semaphores
```

Read that as a checklist for the rest of these docs:
- **Loader → Instance → PhysicalDevice → Device → Queue** is file 04 (`Gpu`).
- **Surface (from a window)** is file 03 (the bridge).
- **Swapchain** is file 05.
- **record → submit → present, with Fences + Semaphores** is file 06 (`FrameRing`).

The vocabulary in one table (from the same cheat sheet):

| Concept | What it is |
| --- | --- |
| **Loader / dispatch** | resolving `vkXxx` function pointers at runtime |
| **Instance** | the Vulkan context; enables instance extensions/layers |
| **Physical device** | a GPU; query its queue families, memory heaps, limits |
| **Device + queues** | the logical device you actually use; queues submit work |
| **Surface (WSI)** | a handle to a window's drawable area |
| **Swapchain** | the ring of images you present to the surface |
| **Memory / resources** | heaps & types; buffers/images bound to allocations |
| **Shaders** | SPIR-V modules; GLSL is compiled to SPIR-V |
| **Commands** | recorded into command buffers, submitted to a queue |
| **Sync** | fences (GPU→CPU), semaphores (GPU→GPU), barriers |

---

## Why a *stack*, bundled — version coherence

The vulkan_stack adapter doesn't wrap one library; it bundles **four**, pinned to
move together. Bumping any one alone breaks the others:

> "VMA's headers, vulkan-zig's `vk.xml`, and shaderc's SPIR-V target must move as a
> **set** or you get cryptic mismatches."
> — [vulkan adapter, `docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md)

The README puts the same point as the library's reason to exist:

> "VMA's headers embed specific Vulkan-1.x signatures, vulkan-zig's bindings come
> from a specific `vk.xml` snapshot, and shaderc emits SPIR-V for a specific Vulkan
> version. Bumping any one in isolation breaks the others. One `build.zig.zon`
> pins all four so a version bump moves them **as a set** — that atomic coherence
> is the reason they live in one library."
> — [vulkan adapter README](../../libs/zig-cpp-vulkan-stack-adapter/README.md)

The four pieces, and what each is for:

### `vk` — the typed Vulkan API (vulkan-zig)

The actual Vulkan calls, as idiomatic Zig. It's [vulkan-zig](https://github.com/Snektron/vulkan-zig),
re-exported unchanged. vulkan-zig describes itself as:

> "A Vulkan binding generator for Zig. … vulkan-zig attempts to provide a better
> experience to programming Vulkan applications in Zig, by providing features such
> as integration of vulkan errors with Zig's error system, function pointer
> loading, renaming fields to standard Zig style, better bitfield handling, turning
> out parameters into return values, slices for buffer parameters and more."
> — [vulkan-zig README](https://github.com/Snektron/vulkan-zig)

Practically: instead of C's "fill a struct, call a function, check an `int` result
code", you get typed structs, Zig error unions, and the three dispatch wrappers
(`vk.BaseWrapper`, `vk.InstanceWrapper`, `vk.DeviceWrapper`) that *are* "idea 1"
above. You will use `vk.*` constantly — it's the raw layer everything else sits on.

### `volk` — the loader

`volk` does "idea 1": it opens the Vulkan driver and gives you that first bootstrap
pointer. In this stack it's reimplemented in pure Zig:

> "`volk` — Vulkan loader, implemented in **pure Zig** (`std.DynLib` dynamically
> opens `libvulkan` and resolves `vkGetInstanceProcAddr`). `getInstanceProcAddr()`
> then feeds vulkan-zig's `vk.BaseWrapper`/`InstanceWrapper`/`DeviceWrapper`, which
> own the typed dispatch — so the binary doesn't hard-link `libvulkan`."
> — [vulkan adapter README](../../libs/zig-cpp-vulkan-stack-adapter/README.md)

You'll touch `volk` exactly once, at the very top of bring-up: `volk.loadBase()`
then hand `volk.getInstanceProcAddr()` to `vk.BaseWrapper.load`. After that, `vk`'s
wrappers carry the dispatch.

### `VMA` — the GPU memory allocator

Vulkan makes you allocate GPU memory by hand, and doing it well is genuinely hard.
VMA (the Vulkan Memory Allocator, from AMD/GPUOpen) does it for you. Its README is
blunt about the problem:

> "Memory allocation and resource (buffer and image) creation in Vulkan is
> difficult (comparing to older graphics APIs, like D3D11 or OpenGL) for several
> reasons: It requires a lot of boilerplate code … There is additional level of
> indirection: `VkDeviceMemory` is allocated separately from creating
> `VkBuffer`/`VkImage` and they must be bound together. … It is recommended to
> allocate bigger chunks of memory and assign parts of them to particular
> resources."
> — [Vulkan Memory Allocator README](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator)

and describes itself simply as:

> "Easy to integrate Vulkan memory allocation library."
> — [Vulkan Memory Allocator README](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator)

The adapter exposes it as idiomatic Zig (`vk_stack.vma.createBuffer(...)` etc.)
behind a `noexcept` C++ bridge. You don't need it for the first rungs (clearing the
screen needs no buffers), but the moment you upload a vertex you'll reach for it.

### `shaderc` — GLSL → SPIR-V

The GPU doesn't run human-readable shader source; it runs **SPIR-V**, a binary
intermediate format. `shaderc` (from Google) compiles GLSL into it:

> "A collection of tools, libraries and tests for shader compilation."
> — [Shaderc README](https://github.com/google/shaderc)

In this stack it's **opt-in** under the `-Dshaderc` build flag — because you have a
choice. Compile shaders at runtime (handy while iterating) *or* precompile them to
`.spv` files and `@embedFile` them (zero runtime dependency). The adapter exposes a
boolean so your code can branch:

> "Without it, `compile` traps; branch on `available` to choose runtime compilation
> vs. embedded SPIR-V."
> — [vulkan adapter, `docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md)

### Plus: per-OS surface creators

Not a bundled library but part of the adapter's own surface: `createX11Surface`,
`createWaylandSurface`, `createWin32Surface`, `createAndroidSurface`. Each turns a
**raw OS handle** into a `vk.SurfaceKHR` — and takes no windowing import. That's the
GPU-side half of the surface bridge (file 03).

---

## A few gotchas worth knowing now

From the cheat sheet, the ones that bite beginners:

- **`VkResult` is a return value, not an exception.** In raw C you check a result
  code; vulkan-zig converts these into Zig error sets for you, so you `try` and
  `catch` like normal Zig.
- **Surface extensions must be enabled on the instance** — which is precisely why
  file 04 feeds `platform.requiredVulkanInstanceExtensions()` into instance
  creation. Forget it and surface creation fails later with a confusing error.
- **Validation layers are your friend.** Develop with `VK_LAYER_KHRONOS_validation`
  on; it catches API misuse that would otherwise be a silent crash or a black
  screen.

---

## Where this sits in zGameLib

The framework re-exports the whole stack, so you reach each piece by name:

```zig
const vk        = zgame.vk;        // vulkan-zig's typed Vulkan API
const volk      = zgame.volk;      // the loader
const vma       = zgame.vma;       // the GPU allocator
const shaderc   = zgame.shaderc;   // GLSL → SPIR-V (opt-in -Dshaderc)
```

— exactly as listed in [`src/root.zig`](../../src/root.zig). The next four docs are
the framework helpers that assemble these raw pieces into the conventional path so
you don't have to spell it out by hand every time.

---

## Bibliography

- **vulkan_stack adapter** (this framework's rendering lib) —
  [`README.md`](../../libs/zig-cpp-vulkan-stack-adapter/README.md),
  [`docs/api.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/api.md),
  [`docs/vulkan-cheat-sheet.md`](../../libs/zig-cpp-vulkan-stack-adapter/docs/vulkan-cheat-sheet.md).
- **Khronos Vulkan** — homepage <https://www.vulkan.org/>; specification
  <https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html>; tutorial
  <https://docs.vulkan.org/tutorial/latest/index.html>; guide
  <https://docs.vulkan.org/guide/latest/index.html>.
- **vulkan-zig** — <https://github.com/Snektron/vulkan-zig>
- **volk** — <https://github.com/zeux/volk>
- **Vulkan Memory Allocator (VMA)** — <https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator>
  · docs <https://gpuopen-librariesandsdks.github.io/VulkanMemoryAllocator/html/>
- **shaderc** — <https://github.com/google/shaderc>

Quoted excerpts are © The Khronos Group, © AMD/GPUOpen, © Google, © the vulkan-zig
author, and © this project's authors, used here for teaching/commentary; consult
the live sources for authoritative wording.
