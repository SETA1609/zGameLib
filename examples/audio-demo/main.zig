const std = @import("std");

/// Audio-demo — rung 4 (planned).
///
/// Adds zaudio (audio playback) to the stack. This example is a STUB —
/// the zaudio library does not exist yet.
///
/// When complete, it will:
///   1. Initialise zaudio with the selected backend (miniaudio).
///   2. Load and play a WAV file.
///   3. Show a minimal window with playback controls.
///
/// Libraries compiled:
///   - platform (windowing + input)
///   - zaudio (audio — miniaudio backend)
///
/// Libraries NOT compiled (pay-for-what-you-use):
///   - vulkan_stack ❌ (no rendering needed for audio demo)
///   - zClip ❌ (no animation)
///
/// This demonstrates the modular architecture: an audio-only tool
/// compiles no GPU code whatsoever.
pub fn main() !void {
    // TODO: platform.init(.{}) if a window is desired
    // TODO: var audio = try zaudio.init(.{});
    // TODO: const sound = try audio.loadWav("assets/demo.wav");
    // TODO: try audio.play(sound);
    // TODO: Wait for playback to finish or ESC to quit.

    std.debug.print("audio-demo: stub — zaudio lib does not exist yet\n", .{});
}
