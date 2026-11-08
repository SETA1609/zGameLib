### issue-10 Move the library pins to the merged releases

- `libs/zig-cpp-vulkan-stack-adapter`: `bf23d83` → `b321a96`, the adapter's v0.6.0 release commit, with its surface format documentation and version.
- `libs/zig-cpp-platform-stack-adapter`: `7e6630c` → `2a7309f`, its v0.7.0 release commit.
- `libs/zClip`: `a34cfe8` → `6be766c`, its v0.6.0 release commit plus the issues added after it.
- No zGameLib code changes.
- Checked in a Zig 0.17.0 container: `zig build test` and `zig build examples` pass.
