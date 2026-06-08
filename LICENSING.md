# Using zGameLib under the Apache License 2.0

zGameLib is licensed under the **Apache License, Version 2.0** (see [`LICENSE`](LICENSE)).
This file explains, in practical terms, what that lets you do and the few things
you must do to stay compliant — especially if you ship a **commercial or
closed-source product**.

> Not legal advice. It summarises the license to make compliance easy; the
> authoritative terms are in [`LICENSE`](LICENSE).

## TL;DR

- ✅ **Use it in commercial and proprietary products.** You do **not** have to
  open-source your game/app. Apache-2.0 is permissive, not copyleft.
- ✅ Modify it, fork it, link it statically or dynamically, ship the result.
- ✅ You receive an explicit **patent license** from the contributors.
- 📋 In return you must **include the license, keep the notices, flag your
  changes, and carry the `NOTICE` attribution forward** (details below).
- ⚠️ zGameLib links third-party code under **other** licenses (MIT, Zlib,
  Apache-2.0). Those obligations travel with your binary too — see
  [The dependency license map](#the-dependency-license-map).

## What you may do

The Apache-2.0 grant (LICENSE §2–3) gives you a perpetual, worldwide,
royalty-free, irrevocable license to:

- reproduce, use, and run the Work;
- prepare **Derivative Works** (modify it);
- publicly display/perform, **sublicense**, and **distribute** it in source or
  binary form — including as part of a larger, proprietary product.

Plus a **patent license** (§3): contributors grant you the patent rights needed
to use their contributions. (This terminates only if you start patent litigation
claiming the Work infringes — the standard anti-troll clause.)

## What you must do (compliance checklist)

When you **distribute** anything that includes zGameLib (source or compiled into
a binary), satisfy these — they're lightweight and require **no source
disclosure**:

- [ ] **Include the license.** Ship a copy of the Apache-2.0 [`LICENSE`](LICENSE)
      with your distribution (e.g. in a `licenses/`/`third-party/` folder, an
      "About → Legal" screen, or your installer).
- [ ] **Retain notices.** Keep the copyright, patent, trademark, and attribution
      notices that appear in zGameLib's source for the parts you use (LICENSE §4c).
- [ ] **Propagate the `NOTICE`.** zGameLib ships a [`NOTICE`](NOTICE) file —
      reproduce its attribution text in your docs, a `NOTICE`/`THIRD-PARTY` file,
      or a credits/legal screen (LICENSE §4d). This is the one step people miss.
- [ ] **State your changes.** If you modified zGameLib's files, mark them as
      changed (a header line or a CHANGES note is enough) (LICENSE §4b).
- [ ] **Don't imply endorsement.** The license grants **no trademark rights**
      (§6) — you may say your product "uses zGameLib," but don't use the name/logo
      to suggest the authors endorse your product.

That's it. You keep your own source private, set your own price, and license your
own original code however you like.

## The dependency license map

zGameLib is a thin layer — it **does not vendor** the code underneath it; it
links it. Your shipped binary therefore contains these components, **each under
its own license (not Apache-2.0)**. All are permissive and all allow commercial /
proprietary use, but their attribution requirements travel with your binary:

| Component | Role | License | Commercial OK |
|---|---|---|---|
| **zGameLib** | this framework | **Apache-2.0** | ✅ |
| zig-cpp-platform-stack-adapter | windowing/input adapter | MIT | ✅ |
| zig-cpp-vulkan-stack-adapter | vulkan-stack adapter | MIT | ✅ |
| SDL3 *(via castholm/SDL)* | platform backend | Zlib | ✅ |
| vulkan-zig *(Snektron)* | typed Vulkan API | MIT | ✅ |
| Vulkan-Headers *(Khronos)* | Vulkan headers | Apache-2.0 OR MIT | ✅ |
| VulkanMemoryAllocator *(AMD)* | GPU allocator | MIT | ✅ |
| volk | Vulkan loader | MIT | ✅ |
| shaderc *(opt-in `-Dshaderc`)* | GLSL→SPIR-V | Apache-2.0 | ✅ |

**Practical consequence:** to comply you bundle the **set** of these licenses
(Apache-2.0 + MIT + Zlib), not just zGameLib's. The MIT and Zlib licenses each
require their copyright + permission notice to be included; the Apache-2.0
components follow the rules above. The full text of each ships in that
component's own source tree (its `LICENSE` file) — the easiest path is to collect
them into a single `THIRD-PARTY-LICENSES` file in your distribution.

> The table reflects the upstreams these libraries pin. License terms can change
> across versions — verify against the exact revisions your build resolves
> (`build.zig.zon` in each adapter) before a release.

## Note on GPL compatibility

Apache-2.0 is one-way compatible with **GPLv3** (you can combine zGameLib into a
GPLv3 project) but **not GPLv2** — the patent/termination terms conflict. This
only matters if a downstream consumer wants to fold zGameLib into a GPLv2
codebase; it has **no effect** on proprietary or commercial use.

## Applying the header to new source files (for contributors)

New `.zig` files in zGameLib should carry the standard header so the license is
self-evident in each file:

```zig
//! SPDX-License-Identifier: Apache-2.0
//! Copyright 2026 Sebastian Tamayo (SETA1609)
```
