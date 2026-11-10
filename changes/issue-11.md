### issue-11 Move the platform adapter and zClip pins to their main branches

- `libs/zig-cpp-platform-stack-adapter`: `2a7309f` → `a2f649f`, which implements the input context stack and the application data and cache directories and adds the native folder picker.
- `libs/zClip`: `6be766c` → `fe9c8ad`, which only adds an issue.
- No zGameLib code changes.
- Checked in a Zig 0.17.0 container: `zig build test` (20 of 20 tests) and `zig build examples` pass.
