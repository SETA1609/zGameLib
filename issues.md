# Issues — zGameLib

Each issue is one PR, on a branch `issue-<n>-<slug>`, with its changelog entry in `changes/issue-<n>.md`. Status is `todo`, `done (#pull-request)`, or `dropped`; statuses and new issues are edited only on bookkeeping branches. See *Releases* in [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Issue 10 — Move the library pins to the merged releases

Status: review
Needs: —

The platform adapter, the Vulkan adapter, and zClip have merged their release branches. Move `libs/zig-cpp-vulkan-stack-adapter` from `bf23d83` to `b321a96` (the adapter's v0.6.0 release commit, which adds the surface format documentation and the version), `libs/zig-cpp-platform-stack-adapter` from `7e6630c` to `2a7309f` (its v0.7.0 release commit), and `libs/zClip` from `a34cfe8` to `6be766c` (its v0.6.0 release commit plus the issues added after it). No zGameLib code changes.

Done when: `zig build test` and `zig build examples` pass with the new pins.

---

## Issue 9 — Delegate the swapchain to the Vulkan adapter

Status: review
Needs: the Vulkan adapter's Issue 8 (swapchain helper), merged as `bf23d83`

The Vulkan adapter's Issue 8 implements its opt-in `vk_stack.Swapchain`: `create`, `recreate`, `deinit`, `toRaw`, `Options`, and the default policy as pure `select*` functions. `recreate` keeps the old swapchain when building the new one fails, a 0×0 surface is `SurfaceHasZeroExtent`, image usage and composite alpha are checked against the surface capabilities, and its tests run on a `VK_EXT_headless_surface` surface. `shared/swapchain.zig` has the same Vulkan calls without those fixes: its `recreate` destroys the image views before it rebuilds, so a failed rebuild leaves the swapchain unusable. Two copies of the mechanism is one too many.

Split the work: the adapter owns the mechanism (create, recreate, failure handling, capability checks, the `select*` defaults); zGameLib owns the policy (which `Options` it passes) and the timing (`FrameRing` decides when to recreate).

- Move the `libs/zig-cpp-vulkan-stack-adapter` pin to `bf23d83`, the commit that merges its Issue 8.
- Reimplement `shared/swapchain.zig` over `vk_stack.Swapchain`. The adapter's helper allocates its image and view lists, so `gpu.createSwapchain` takes an allocator: `gpu.createSwapchain(allocator, extent)`, and `Swapchain.create(allocator, vki, vkd, pdev, device, surface, extent)` replaces the struct literal plus `init`. `recreate(extent)`, `deinit()`, and the public `handle`, `format`, `extent`, `images`, `views`, and `count` fields stay (`images` and `views` become slices). zGameLib passes its policy as `framework_options` (8-bit blue-green-red-alpha pixels in the standard red-green-blue colour space, mailbox present mode else first-in-first-out, the minimum image count plus one, transfer-destination usage for clears) and holds the dispatch tables and allocator the adapter calls need. The changelog lists the API changes.
- `FrameRing.begin` and `end`: on `SurfaceHasZeroExtent` skip the frame (return null) instead of failing, so a minimized window waits for a resize.
- Rewrite `docs/theory/05-the-swapchain.md`: "Why this is framework policy, not lib API" becomes "Mechanism in the adapter, policy in the framework"; describe the kept old swapchain on failure, the zero extent, and the capability checks; quote the adapter's `docs/api.md`; update the `recreate` snippet. Update `docs/theory/06-the-frame-ring.md` for the zero-extent skip, and `README.md`, `cheat_sheet.md`, and `docs/reference.md` where they describe the swapchain.

Done when: `shared/swapchain.zig` makes no `createSwapchainKHR` or `destroySwapchainKHR` call of its own; the `check` and `decoupling` gates, `zig build test`, `zig build test-tdd` (including the `test-gpu` swapchain and `FrameRing` specs), and `zig build examples` pass; `scripts/ci.py sync-validation` gives the same result as before the change; `clear-color` and `depth-cube` keep rendering through a window resize and a minimize and restore.

## Issue 8 — Move the Vulkan adapter pin to the Win32 surface

Status: done (#17)
Needs: —

The Vulkan adapter implemented `createWin32Surface` (its #8, `a5c700f`): it calls `vkCreateWin32SurfaceKHR` instead of panicking. Move the `libs/zig-cpp-vulkan-stack-adapter` submodule from `912b245` to `a5c700f`, so the `.windows` branch of the surface bridge (docs/theory/03-the-surface-bridge.md) reaches a real surface creator. No zGameLib code changes.

Done when: the `check` and `decoupling` gates and `zig build test` pass with the new pin.

## Issue 7 — Add a cglm math adapter

Status: done (#16)
Needs: —

Add `libs/zig-c-math-stack-adapter` (interim name), a standalone Zig package shaped like the platform and Vulkan adapters (own `build.zig`, `build.zig.zon`, `LICENSE`, `README.md`, `issues.md`, `CHANGELOG.md`, tests), which builds cglm (C, MIT, pinned by commit) as a static library and wraps it as Zig types: `Vector3`, `Vector4`, `Matrix4` with multiply, transform, transpose, inverse, translation, rotation, right-handed look-at, and a Vulkan perspective (depth 0..1, y down). Inputs cglm would turn into zeros, infinities, or NaN return a `math_stack.Error` (`SingularMatrix`, `InvalidRotation`, `DegenerateLookAt`, `InvalidPerspective`), as the Vulkan and platform adapters return errors for their failures. It lives in this repository, not as a submodule, until its API settles; then it moves to its own repository like the other adapters. zGameLib imports it as a path dependency and re-exports it as `zgame.math_stack`. `shared/camera.zig` is not changed by this issue.

Done when: the adapter's `zig build test` passes with no display or GPU; zGameLib's `zig build`, `zig build test`, and the decoupling gate pass; the adapter's README states its conventions.

---

## Issue 1 — Port to Zig 0.17.0

Status: done (#12)

Zig 0.17.0 changed the build API (`Build.args` removed), `@import` (Zig sources only), and enum builtins, and the 0.17 Vulkan adapter brings vulkan-zig `master`, whose generated bindings changed (`.null` handles, pointer dispatchable handles, flags without `_bit`). Move the adapter and zClip submodules to their 0.17.0 versions, port `shared/`, tests, and examples, and move CI, the Docker image, and the docs to 0.17.0. `-Dshaderc` now needs the system shaderc library (`libshaderc-dev` or the Vulkan SDK).

Done when: the `check` and `decoupling` gates pass; `zig build test`, `zig build examples`, test-tdd, and test-integration `-Dshaderc` give the same results as on 0.16.0.

---

## Issue 2 — Start the 3D path

Status: done (#14)
Needs: Issue 1

Add a 3D render path beside the 2D one without changing the 2D API: a depth attachment, a perspective camera, and one indexed mesh drawn with dynamic rendering. Engine-neutral: no game content.

Done when: an example draws a depth-tested mesh; the 2D examples render unchanged; `depth-cube` runs with no synchronization-validation errors (`scripts/ci.py sync-validation`).

---

## Issue 5 — Order swapchain image transitions after image acquire

Status: todo
Needs: Issue 2

The examples transition the acquired swapchain image out of `UNDEFINED` with source stage `TOP_OF_PIPE`, but `FrameRing.end` waits on the image-acquire semaphore at a later stage (`TRANSFER` in `clear-color-2`). The transition is then not ordered after the wait and can run while the presentation engine still reads the image. Synchronization validation reports `SYNC-HAZARD-WRITE-AFTER-READ` on every frame: 27,368 times in 25 seconds of `clear-color-2`. Issue 2 fixed the same pattern in `depth-cube`.

Use the semaphore's wait stage as each transition's source stage, in every example and test that records one, and say in `transitionImage`'s doc comment that the source stage must chain with the acquire wait. Extend `scripts/ci.py sync-validation` to every example that renders, with a frame limit like `depth-cube`'s `--frames N`, so the check covers them all.

Done when: `scripts/ci.py sync-validation` runs `clear-color`, `clear-color-2`, and `depth-cube` with no validation errors.

---

## Issue 6 — Fix hello-triangle's validation errors

Status: todo
Needs: —

With the Khronos validation layer loaded, `hello-triangle` reports `VUID-VkGraphicsPipelineCreateInfo-pDynamicStates-04130` and `-04131` at pipeline creation and `VUID-VkRenderPassBeginInfo-framebuffer-parameter` when it begins its render pass, then aborts. Without the layer it runs. Find and fix each cause (the viewport and scissor state of a pipeline with dynamic viewport and scissor; which framebuffer is passed after the swapchain is created or recreated), and add a frame limit so the example can run in `scripts/ci.py sync-validation`.

Done when: `hello-triangle` runs under the validation layer, with synchronization validation, with no validation errors, and is part of the `sync-validation` check.

---

## Issue 4 — Design the API before the tests

Status: done (#15)

Write down the commit order every behaviour change follows: the API with stub bodies, then failing tests against it, then the implementation, which makes the tests pass without changing them or the public signatures. Each step is its own commit, and the tests commit records the failing run. Issue 2 is the first issue done this way.

Done when: `CLAUDE.md` has the workflow section.

---

## Issue 3 — Run agents in a dev container

Status: done (#13)

Run coding agents (Claude Code) on zGameLib with their own login, kept apart from the host's Claude Code account. Add `docker/agent.Dockerfile` on top of the build image (Claude Code, Node 22, uv, a user with the host's uid and gid) and `scripts/agent.sh`, which mounts a named home volume (`personal-agent-home`, shared with other repos that use the same volume name) for the Claude login and git identity. The host's `~/.claude`, `~/.gitconfig`, and SSH keys are not mounted: the agent commits, and the owner pushes from the host. When the checkout is a submodule or worktree, its git directory is mounted too.

Done when: `./scripts/agent.sh claude --version` prints the pinned version; `git status` and `zig build test` work inside the container from a standalone clone and from a submodule checkout; files it writes belong to the host user.
