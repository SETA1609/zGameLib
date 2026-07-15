#!/usr/bin/env python3
"""Generate SPIR-V binaries for hello-triangle shaders.

Usage:
    python3 scripts/gen-spv.py examples/hello-triangle/shaders/
"""

import struct, sys, os


def write_spv(path, words):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        for w in words:
            f.write(struct.pack("<I", w))


def make_vert_spv():
    # Vertex shader: passes through vec2 position at location 0
    # layout(location = 0) in vec2 inPos;
    # void main() { gl_Position = vec4(inPos, 0.0, 1.0); }
    # Bound = 24, IDs 7-23
    return [
        0x07230203,
        0x00010000,
        0x00000000,
        0x00000018,
        0x00000000,
        0x00010011,
        0x00000001,  # OpCapability Shader
        0x0006000B,
        0x4C534C47,
        0x6474732E,
        0x3035342E,
        0x00000000,  # ExtInst
        0x0003000E,
        0x00000000,
        0x00000001,  # MemoryModel
        0x0007000F,
        0x00000000,
        0x00000012,  # EntryPoint
        0x6E69616D,
        0x00000000,
        0x00000010,
        0x00000011,
        0x00040005,
        0x00000012,
        0x6E69616D,
        0x00000000,  # OpName %main
        0x00040005,
        0x00000010,
        0x6F506E69,
        0x00000073,  # OpName %inPos
        0x00050005,
        0x00000011,
        0x505F6C67,
        0x7469736F,
        0x006E6F69,  # OpName %gl_Position
        0x00040047,
        0x00000010,
        0x0000001E,
        0x00000000,  # Decorate Location
        0x00040047,
        0x00000011,
        0x0000000B,
        0x00000000,  # Decorate BuiltIn
        0x00020013,
        0x00000007,  # OpTypeVoid %7
        0x00030021,
        0x00000008,
        0x00000007,  # OpTypeFunction %8 %7
        0x00030016,
        0x00000009,
        0x00000020,  # OpTypeFloat %9 32
        0x00040017,
        0x0000000A,
        0x00000009,
        0x00000002,  # OpTypeVector %10 %9 2
        0x00040017,
        0x0000000B,
        0x00000009,
        0x00000004,  # OpTypeVector %11 %9 4
        0x00040020,
        0x0000000C,
        0x00000001,
        0x0000000A,  # OpTypePointer Input %12 %10
        0x00040020,
        0x0000000D,
        0x00000003,
        0x0000000B,  # OpTypePointer Output %13 %11
        0x0004002B,
        0x00000009,
        0x0000000E,
        0x00000000,  # Constant %14 0.0
        0x0004002B,
        0x00000009,
        0x0000000F,
        0x3F800000,  # Constant %15 1.0
        0x0004003B,
        0x0000000C,
        0x00000010,
        0x00000001,  # Variable %16 Input %inPos
        0x0004003B,
        0x0000000D,
        0x00000011,
        0x00000003,  # Variable %17 Output %gl_Pos
        0x00040036,
        0x00000007,
        0x00000012,
        0x00000000,
        0x00000008,  # Function %main
        0x000200F8,
        0x00000013,  # Label
        0x0004003D,
        0x0000000A,
        0x00000014,
        0x00000010,  # Load %20 %inPos
        0x0005009E,
        0x00000009,
        0x00000015,
        0x00000014,
        0x00000000,  # CompositeExtract %21 %20 0
        0x0005009E,
        0x00000009,
        0x00000016,
        0x00000014,
        0x00000001,  # CompositeExtract %22 %20 1
        0x0007009D,
        0x0000000B,
        0x00000017,  # CompositeConstruct %23
        0x00000015,
        0x00000016,
        0x0000000E,
        0x0000000F,
        0x0003003E,
        0x00000011,
        0x00000017,  # Store %gl_Position %23
        0x000100FD,  # OpReturn
        0x00010038,  # OpFunctionEnd
    ]


def make_frag_spv():
    # Fragment shader: outputs solid red
    # layout(location = 0) out vec4 outColor;
    # void main() { outColor = vec4(1.0, 0.0, 0.0, 1.0); }
    # Bound = 17, IDs 6-16
    return [
        0x07230203,
        0x00010000,
        0x00000000,
        0x00000011,
        0x00000000,
        0x00010011,
        0x00000001,  # OpCapability Shader
        0x0006000B,
        0x4C534C47,
        0x6474732E,
        0x3035342E,
        0x00000000,  # ExtInst
        0x0003000E,
        0x00000000,
        0x00000001,  # MemoryModel
        0x0006000F,
        0x00000004,
        0x0000000E,
        0x6E69616D,  # EntryPoint Fragment
        0x00000000,
        0x0000000D,
        0x00030010,
        0x0000000E,
        0x00000000,  # ExecutionMode OriginUpperLeft
        0x00040005,
        0x0000000E,
        0x6E69616D,
        0x00000000,  # OpName %main
        0x00050005,
        0x0000000D,
        0x4374756F,
        0x726F6C6F,  # OpName %outColor
        0x00000000,
        0x00040047,
        0x0000000D,
        0x0000001E,
        0x00000000,  # Decorate Location
        0x00020013,
        0x00000006,  # OpTypeVoid %6
        0x00030021,
        0x00000007,
        0x00000006,  # OpTypeFunction %7 %6
        0x00030016,
        0x00000008,
        0x00000020,  # OpTypeFloat %8 32
        0x00040017,
        0x00000009,
        0x00000008,
        0x00000004,  # OpTypeVector %9 %8 4
        0x00040020,
        0x0000000A,
        0x00000003,
        0x00000009,  # OpTypePointer Output %10 %9
        0x0004002B,
        0x00000008,
        0x0000000B,
        0x3F800000,  # Constant %11 1.0
        0x0004002B,
        0x00000008,
        0x0000000C,
        0x00000000,  # Constant %12 0.0
        0x0004003B,
        0x0000000A,
        0x0000000D,
        0x00000003,  # Variable %13 Output %outColor
        0x00040036,
        0x00000006,
        0x0000000E,
        0x00000000,
        0x00000007,  # Function %main
        0x000200F8,
        0x0000000F,  # Label
        0x0007009D,
        0x00000009,
        0x00000010,  # CompositeConstruct %16
        0x0000000B,
        0x0000000C,
        0x0000000C,
        0x0000000B,
        0x0003003E,
        0x0000000D,
        0x00000010,  # Store %outColor %16
        0x000100FD,  # OpReturn
        0x00010038,  # OpFunctionEnd
    ]


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    write_spv(os.path.join(outdir, "triangle.vert.spv"), make_vert_spv())
    write_spv(os.path.join(outdir, "triangle.frag.spv"), make_frag_spv())
    print(f"Generated SPIR-V in {outdir}/")
