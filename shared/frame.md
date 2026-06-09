# `frame.zig` — the theory behind the frames-in-flight ring

Companion to [`frame.zig`](./frame.zig). It explains the *frame lifecycle* the
`FrameRing` automates — the acquire → render → present loop, the two kinds of
synchronization it needs, why there is more than one of everything, and what
"out of date" means. The code is the "how"; this is the "why".

> **On the quotes below.** Each `>` block is a short excerpt from the official
> Khronos Vulkan specification, with a link to the source, quoted for
> commentary/teaching. The live spec is authoritative — follow the links for the
> full wording. Excerpts © The Khronos Group under its license.

---

## The frame loop in three calls

Every presented frame is the same three-act play, regardless of what you draw:

```
acquire  →  record + submit  →  present
   │              │                 │
img_avail      in_flight          done
(semaphore)     (fence)         (semaphore)
```

`FrameRing` splits this into a **begin → record → end** seam: `begin` does the
acquire + the waits and opens a command buffer; the app records whatever it
likes; `end` submits and presents. Each act is guarded by a different
synchronization primitive, and choosing the right primitive for each is the
whole subtlety.

---

## Acquire: borrowing an image from the swapchain

The swapchain owns a small set of presentable images. You don't create images
per frame — you *borrow* one with `vkAcquireNextImageKHR`, which gives you an
index and signals when the image is actually ready to be rendered into.

The signalling matters: acquire returns **immediately**, before the image is
usable. The spec is explicit that the returned index can be handed to recording
right away, but the GPU must still wait on the semaphore:

> "After acquiring the image, the application **can** use the image (e.g. for
> rendering) before the presentation engine has finished its use of it."
> — [Vulkan spec, `vkAcquireNextImageKHR`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#vkAcquireNextImageKHR)

That is why `begin` passes `img_avail` (a semaphore) to the acquire and `end`
makes the queue submit *wait* on it: the recording is queued early, but the GPU
stalls at `wait_stage` until the presentation engine is genuinely done with that
image.

---

## Two primitives, two jobs: semaphores vs fences

Vulkan deliberately separates **GPU↔GPU** ordering from **GPU↔CPU** ordering, and
gives you a different object for each. Getting this split right is the core of a
correct frame loop.

**Semaphores** order work *between queue operations on the GPU*. Nothing on the
CPU waits on them.

> "Semaphores are a synchronization primitive that can be used to insert a
> dependency between queue operations."
> — [Vulkan spec, *Semaphores*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization-semaphores)

The ring uses two per frame:
- `img_avail` — acquire signals it; the submit waits on it (don't render before
  the image is free).
- `done` — the submit signals it; present waits on it (don't present before
  rendering finished).

**Fences** report GPU completion *back to the CPU*, so the host can know a frame
is finished:

> "Fences are a synchronization primitive that can be used to insert a dependency
> from a queue to the host."
> — [Vulkan spec, *Fences*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization-fences)

The ring uses one per frame, `in_flight`. `begin` blocks on it with
`vkWaitForFences` before reusing that frame's command buffer; the submit signals
it when the GPU is done. This is the only place the CPU and GPU rendezvous.

---

## Why "frames *in flight*" — and why each gets its own everything

If the CPU recorded frame N and then blocked until the GPU finished it before
starting frame N+1, the two processors would take turns idling. Instead we let
the CPU run *ahead*: while the GPU renders frame N, the CPU records frame N+1.
That overlap is "frames in flight".

But overlap is only safe if frame N+1 doesn't touch resources frame N is still
using. So each in-flight frame needs its **own** command buffer + its **own**
sync set — which is exactly the `[max_frames]` arrays in the ring. `max_frames`
is the overlap depth (2 = double-buffered CPU/GPU); `index` cycles through them,
and `begin`'s `vkWaitForFences` guarantees we never reuse frame slot *i* until
its previous submission has fully retired.

The `in_flight` fences are created **already signalled** so the very first
`begin` on each slot doesn't deadlock waiting for a submission that never
happened.

---

## Present, and the present mode

`end` finishes with `vkQueuePresentKHR`, handing the rendered image to the
display. The companion [`swapchain.zig`](./swapchain.zig) prefers `MAILBOX` but
falls back to `FIFO`, and it can always fall back because the spec guarantees it:

> "`VK_PRESENT_MODE_FIFO_KHR` … is required to be supported."
> — [Vulkan spec, `VkPresentModeKHR`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#VkPresentModeKHR)

FIFO is the v-sync'd, tear-free queue ("first in, first out", one image per
vertical blank) — a safe default for a toy.

---

## "Out of date": when the swapchain stops matching the window

A swapchain is built for a specific surface size/state. Resize the window (or
otherwise invalidate it) and the swapchain no longer fits. Vulkan signals this
with `VK_ERROR_OUT_OF_DATE_KHR`:

> "A surface has changed in such a way that it is no longer compatible with the
> swapchain."
> — [Vulkan spec, return codes](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#fundamentals-errorcodes)

It can surface at **either** end of the frame — on acquire *or* on present — so
the ring handles both:
- `begin` catches it on `vkAcquireNextImageKHR`, recreates the swapchain, and
  returns `null` (the caller `continue`s — no frame this iteration).
- `end` catches it on `vkQueuePresentKHR` and recreates, then advances anyway.

The recreate itself lives in [`swapchain.zig`](./swapchain.zig) (it passes the
old swapchain as `oldSwapchain` so the driver can recycle resources). The ring
just owns *when* to call it. `begin` stashes the requested extent in `want` so
`end`'s recreate path has it without the app re-threading it.

---

## Why this lives in zGameLib, not the vulkan adapter

The number of frames in flight, the choice of one fence + two semaphores per
frame, and the policy of recreating-on-out-of-date are all **consumer
decisions** — the vulkan adapter exposes the raw `vk` calls and stops there.
`FrameRing` encodes one correct, conventional policy for these examples while
leaving the pool, command buffers and sync objects public, so an app that needs
a different submit shape can still reach past it. Same principle as
[`gpu.zig`](./gpu.zig) and [`swapchain.zig`](./swapchain.zig).

---

## Sources

- Khronos **Vulkan 1.3 specification** — Synchronization (semaphores, fences),
  WSI (`vkAcquireNextImageKHR`, `vkQueuePresentKHR`, `VkPresentModeKHR`), error
  codes: <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>

Quoted excerpts are © The Khronos Group, used here for teaching/commentary;
consult the live spec for authoritative wording.
