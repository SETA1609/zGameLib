# 06 — The frame ring: frames in flight

*The per-frame loop — acquire an image, record commands, submit, present — and the
synchronization that keeps the CPU and GPU running in parallel without stepping on
each other.*

You have a device (file 04) and a swapchain (file 05). The last piece is the
**frame loop**: the thing that runs every frame to actually put a picture on
screen. The framework's [`FrameRing`](../../shared/frame.zig) automates it.

> This is the **beginner-facing** tour. The framework also ships
> [`shared/frame.md`](../../shared/frame.md), a deeper note on the exact `vk` calls
> and the synchronization theory — read it after this.

---

## Every frame is the same three acts

> "Every presented frame is the same three-act play, regardless of what you draw:"
> — [`shared/frame.md`](../../shared/frame.md)

```
acquire  →  record + submit  →  present
   │              │                 │
img_avail      in_flight          done
(semaphore)     (fence)         (semaphore)
```

`FrameRing` splits this into a **begin → record → end** seam: `begin` does the
waiting and acquires an image and opens a command buffer; *you* record whatever you
want to draw; `end` submits and presents. In code it looks like:

```zig
while (running) {
    platform.pollAllEvents();
    // ... handle .close / .resize ...
    if (try ring.begin(&chain, extent)) |frame| {  // null = swapchain was recreated, skip
        // record into frame.cmd, targeting frame.image ...
        try ring.end(&chain, frame, wait_stage);
    }
}
```

---

## Acquire: you *borrow* an image

You don't create images each frame — you borrow one from the swapchain with
`vkAcquireNextImageKHR`. The subtle part: acquire returns *immediately*, before the
image is actually ready to render into. The spec is explicit:

> "After acquiring the image, the application **can** use the image (e.g. for
> rendering) before the presentation engine has finished its use of it."
> — [Vulkan spec, `vkAcquireNextImageKHR`](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#vkAcquireNextImageKHR)

That's why a semaphore is involved: acquire signals it when the image is *truly*
ready, and the GPU submit is told to wait on it before drawing.

---

## The core idea: two kinds of synchronization

This is the single most important concept in the frame loop. Vulkan gives you
**two different primitives** for two different jobs, and using the right one for
each is the whole game.

**Semaphores** order work between GPU operations. The CPU never waits on them:

> "Semaphores are a synchronization primitive that can be used to insert a
> dependency between queue operations."
> — [Vulkan spec, *Semaphores*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization-semaphores)

`FrameRing` uses two semaphores per frame:
- `img_avail` — acquire signals it; the submit waits on it (*don't render before the
  image is free*).
- `done` — the submit signals it; present waits on it (*don't present before
  rendering is finished*).

**Fences** report GPU completion back to the *CPU*, so the host knows a frame is
done:

> "Fences are a synchronization primitive that can be used to insert a dependency
> from a queue to the host."
> — [Vulkan spec, *Fences*](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#synchronization-fences)

`FrameRing` uses one fence per frame, `in_flight`. `begin` blocks on it
(`vkWaitForFences`) before reusing a frame's command buffer; the submit signals it
when the GPU finishes. As `frame.md` puts it, *"This is the only place the CPU and
GPU rendezvous."*

A one-line summary to memorize: **semaphores = GPU↔GPU, fences = GPU↔CPU.**

---

## Why "in flight", and why each frame owns its own everything

If the CPU recorded a frame and then sat idle until the GPU finished it before
starting the next, the two processors would take turns doing nothing. Instead, the
CPU runs *ahead*:

> "while the GPU renders frame N, the CPU records frame N+1. That overlap is 'frames
> in flight'."
> — [`shared/frame.md`](../../shared/frame.md)

But overlapping is only safe if frame N+1 doesn't touch resources frame N is still
using. So **each in-flight frame gets its own** command buffer and its own sync set:

> "each in-flight frame needs its **own** command buffer + its **own** sync set —
> which is exactly the `[max_frames]` arrays in the ring. `max_frames` is the
> overlap depth (2 = double-buffered CPU/GPU)."
> — [`shared/frame.md`](../../shared/frame.md)

That's why `FrameRing(2)` is parameterized by a count: it allocates that many of
everything. And one neat trick — the fences are created *already signalled* so the
very first `begin` on each slot doesn't deadlock waiting for a submission that never
happened.

---

## "Out of date" — handled at both ends

A resize can invalidate the swapchain (file 05), and the `OutOfDateKHR` error can
surface at *either* end of the frame — on acquire **or** on present. `FrameRing`
catches both:

> "`begin` catches it on `vkAcquireNextImageKHR`, recreates the swapchain, and
> returns `null` (the caller `continue`s — no frame this iteration). `end` catches
> it on `vkQueuePresentKHR` and recreates, then advances anyway."
> — [`shared/frame.md`](../../shared/frame.md)

This is why `begin` returns an *optional* `?Frame`: a `null` means "I had to rebuild
the swapchain, skip drawing this iteration". You just `if (try ring.begin(...)) |f|`
and the resize case handles itself.

---

## Why this is framework policy, not lib API

By now the pattern is familiar. *How many* frames in flight, *how many*
fences/semaphores, *whether* to recreate-on-out-of-date — all consumer decisions
the Vulkan lib refuses to make for you:

> "The number of frames in flight, the choice of one fence + two semaphores per
> frame, and the policy of recreating-on-out-of-date are all **consumer
> decisions** — the vulkan adapter exposes the raw `vk` calls and stops there.
> `FrameRing` encodes one correct, conventional policy … while leaving the pool,
> command buffers and sync objects public, so an app that needs a different submit
> shape can still reach past it."
> — [`shared/frame.md`](../../shared/frame.md)

---

## Where this sits in zGameLib

Re-exported as `zgame.FrameRing`, built from a `Gpu`:

```zig
var ring = try zgame.FrameRing(2).init(gpu);  // 2 frames in flight
defer ring.deinit();
```

> "The **frames-in-flight** ring + the begin/record/end frame seam. See frame.zig."
> — [`src/root.zig`](../../src/root.zig)

With `Gpu` (file 04), `Swapchain` (file 05), and `FrameRing` together, you have a
complete render loop — which is exactly what the `clear-color` example assembles.

---

## Bibliography

- **zGameLib** — [`shared/frame.zig`](../../shared/frame.zig) (the implementation),
  [`shared/frame.md`](../../shared/frame.md) (the deep "why" note),
  [`src/root.zig`](../../src/root.zig) (the re-export).
- **Khronos Vulkan specification** — Synchronization (semaphores, fences), WSI
  (`vkAcquireNextImageKHR`, `vkQueuePresentKHR`):
  <https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html>

Quoted excerpts are © The Khronos Group and © this project's authors, used here for
teaching/commentary; consult the live Vulkan spec for authoritative wording.
