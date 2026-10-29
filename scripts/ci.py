#!/usr/bin/env python3
"""CI pipeline for zGameLib — cross-platform equivalent of ci.sh.

Usage:
  python scripts/ci.py              # fmt + build all (examples + tests skeleton)
  python scripts/ci.py decoupling   # nm: platform-only binary pulls none of our vulkan stack
  python scripts/ci.py integration  # cross-lib test-integration (xvfb on headless Linux)
  python scripts/ci.py tdd          # full behavioral suite (test-tdd, xvfb on headless Linux)
  python scripts/ci.py sync-validation  # run depth-cube under Khronos synchronization validation
"""

import os
import re
import shutil
import subprocess
import sys
from enum import StrEnum
from pathlib import Path

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = Path(PROJECT_ROOT) / "scripts"

# ── exit codes ──────────────────────────────────────────────────────────────
EXIT_FAILURE = 1
EXIT_USAGE = 2

# ── platform enum ───────────────────────────────────────────────────────────

class Platform(StrEnum):
    LINUX = "linux"
    MACOS = "darwin"
    WINDOWS = "win32"


# ── command enum ────────────────────────────────────────────────────────────

class Command(StrEnum):
    CHECK = "check"
    DECOUPLING = "decoupling"
    INTEGRATION = "integration"
    TDD = "tdd"
    SYNC_VALIDATION = "sync-validation"


# ── zig build-step enum ─────────────────────────────────────────────────────

class ZigStep(StrEnum):
    EVENT_LOGGER = "event-logger"
    CLEAR_COLOR = "clear-color"
    CLEAR_COLOR_2 = "clear-color-2"
    TEST_INTEGRATION = "test-integration"
    TEST_TDD = "test-tdd"
    RUN_DEPTH_CUBE = "run-depth-cube"


# ── tool / subcommand arg enum ──────────────────────────────────────────────

class CmdArg(StrEnum):
    ZIG = "zig"
    BUILD = "build"
    FMT = "fmt"
    FMT_CHECK = "--check"
    NM = "nm"
    XVFB_RUN = "xvfb-run"


# ── helpers ─────────────────────────────────────────────────────────────────

def run(cmd, **kwargs):
    print(f"== {' '.join(cmd)} ==")
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True, **kwargs)


def ensure_display_deps():
    """Install display dependencies if missing (Linux headless CI).

    Delegates to `scripts/install_display_deps.py` which handles
    cross-platform detection and package-manager invocation.
    """
    if sys.platform != Platform.LINUX:
        return
    if os.environ.get("DISPLAY"):
        return  # native display server already available
    if shutil.which("xvfb-run") and shutil.which("vulkaninfo"):
        return  # already installed
    install_script = SCRIPTS / "install_display_deps.py"
    subprocess.run([sys.executable, str(install_script)], check=True)


def need_xvfb():
    return (
        sys.platform == Platform.LINUX
        and not os.environ.get("DISPLAY")
        and shutil.which("xvfb-run") is not None
    )


def cmd_check():
    print("== zig fmt --check ==")
    subprocess.run(
        [CmdArg.ZIG, CmdArg.FMT, CmdArg.FMT_CHECK, "build.zig", "build.zig.zon", "examples"],
        cwd=PROJECT_ROOT,
        check=True,
    )

    print("== zig build (framework + compile-check all examples) ==")
    run([CmdArg.ZIG, CmdArg.BUILD, ZigStep.EVENT_LOGGER, ZigStep.CLEAR_COLOR, ZigStep.CLEAR_COLOR_2])


def cmd_decoupling():
    print("== zig build event-logger (framework + platform-only consumer) ==")
    run([CmdArg.ZIG, CmdArg.BUILD, ZigStep.EVENT_LOGGER])

    if sys.platform != Platform.LINUX:
        print(f"nm decoupling check skipped on {sys.platform}")
        return

    bin_path = os.path.join(PROJECT_ROOT, "zig-out", "bin", ZigStep.EVENT_LOGGER)
    if not os.path.isfile(bin_path):
        print(f"::error::event-logger binary not found at {bin_path}")
        sys.exit(EXIT_FAILURE)

    print("== nm: event-logger (platform-only) pulls none of our vulkan stack ==")
    result = subprocess.run(
        [CmdArg.NM, bin_path], capture_output=True, text=True, cwd=PROJECT_ROOT
    )
    leaked = re.findall(
        r"vk\.[A-Za-z]|volk[A-Z]|[Vv]ma[A-Z]|shaderc_[a-z]", result.stdout
    )
    if leaked:
        print("::error::our vulkan stack (vulkan-zig/volk/VMA) leaked into the platform-only binary")
        for sym in sorted(set(leaked)):
            print(f"  {sym}")
        sys.exit(EXIT_FAILURE)
    print("clean — no vulkan-stack symbols in event-logger (SDL3's own vk loader is expected & ignored)")


def _build_with_display(step: ZigStep, extra_args=None):
    cmd = [CmdArg.ZIG, CmdArg.BUILD, step]
    if extra_args:
        cmd.extend(extra_args)
    env_merged = os.environ.copy()
    if need_xvfb():
        cmd = [CmdArg.XVFB_RUN, "-a"] + cmd
    print(f"== zig build {step} ==")
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True, env=env_merged)


def cmd_integration():
    ensure_display_deps()
    _build_with_display(ZigStep.TEST_INTEGRATION, extra_args=["-Dshaderc"])


def cmd_tdd():
    ensure_display_deps()
    _build_with_display(ZigStep.TEST_TDD)


VALIDATION_LAYER_NAME = "VK_LAYER_KHRONOS_validation"
VALIDATION_LAYER_MANIFEST_DIRECTORIES = [
    "/usr/share/vulkan/explicit_layer.d",
    "/usr/local/share/vulkan/explicit_layer.d",
    "/etc/vulkan/explicit_layer.d",
]
SYNC_VALIDATION_FRAME_COUNT = 30


def find_validation_layer_manifest():
    for directory in VALIDATION_LAYER_MANIFEST_DIRECTORIES:
        manifest = Path(directory) / "VkLayer_khronos_validation.json"
        if manifest.is_file():
            return manifest
    return None


def cmd_sync_validation():
    """Run depth-cube for a few frames with the Khronos validation layer and its
    synchronization validation on; fail on any validation error, so missing
    barriers (write-after-write, write-after-read hazards) cannot return."""
    if find_validation_layer_manifest() is None and not os.environ.get("VK_LAYER_PATH"):
        print(f"{VALIDATION_LAYER_NAME} not installed; sync validation skipped")
        return
    ensure_display_deps()
    cmd = [CmdArg.ZIG, CmdArg.BUILD, ZigStep.RUN_DEPTH_CUBE, "--", "--frames", str(SYNC_VALIDATION_FRAME_COUNT)]
    if need_xvfb():
        cmd = [CmdArg.XVFB_RUN, "-a"] + cmd
    env_merged = os.environ.copy()
    env_merged["VK_INSTANCE_LAYERS"] = VALIDATION_LAYER_NAME
    env_merged["VK_KHRONOS_VALIDATION_VALIDATE_SYNC"] = "true"
    print(f"== {' '.join(cmd)} (synchronization validation) ==")
    result = subprocess.run(cmd, cwd=PROJECT_ROOT, env=env_merged, capture_output=True, text=True)
    output = result.stdout + result.stderr
    error_ids = re.findall(r"\[ ((?:SYNC-HAZARD|VUID)-[A-Za-z0-9_-]+) \]", output)
    if result.returncode != 0 or "Validation Error" in output:
        print(output[-4000:])
        counts = {error_id: error_ids.count(error_id) for error_id in sorted(set(error_ids))}
        print(f"::error::depth-cube: exit code {result.returncode}, validation errors {counts}")
        sys.exit(EXIT_FAILURE)
    print(f"clean — depth-cube ran {SYNC_VALIDATION_FRAME_COUNT} frames with no validation errors")


DEFAULT_COMMAND = Command.CHECK

COMMANDS = {
    Command.CHECK: cmd_check,
    Command.DECOUPLING: cmd_decoupling,
    Command.INTEGRATION: cmd_integration,
    Command.TDD: cmd_tdd,
    Command.SYNC_VALIDATION: cmd_sync_validation,
}


def main():
    raw = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_COMMAND
    try:
        command = Command(raw)
    except ValueError:
        command = raw

    if command not in COMMANDS:
        print(f"unknown command: {command} (try: {' | '.join(COMMANDS)})", file=sys.stderr)
        sys.exit(EXIT_USAGE)

    os.makedirs(os.path.join(PROJECT_ROOT, ".zig-cache"), exist_ok=True)

    COMMANDS[command]()
    print(f"ok: {command}")


if __name__ == "__main__":
    main()
