//! An indexed mesh for the 3D path: one vertex buffer and one 16-bit index buffer.
//!
//! The vertex bytes are opaque here; the pipeline that draws the mesh defines
//! the vertex layout. Buffers live in host-visible, host-coherent memory, which
//! is simple and fine for small meshes; staging into device-local memory is a
//! later step. Transparent like the rest of zGameLib: every handle is public.

const std = @import("std");
const vulkan_stack = @import("vulkan_stack");
const vk = vulkan_stack.vk;

pub const IndexedMesh = struct {
    vkd: vk.DeviceWrapper,
    device: vk.Device,
    vertex_buffer: vk.Buffer = .null,
    vertex_memory: vk.DeviceMemory = .null,
    index_buffer: vk.Buffer = .null,
    index_memory: vk.DeviceMemory = .null,
    index_count: u32 = 0,

    pub const index_type: vk.IndexType = .uint16;

    /// Upload `vertex_bytes` and `indices`. `gpu` is a `*Gpu` (or anything with
    /// `.vkd`, `.device`, and `findMemoryTypeIndex`).
    pub fn create(gpu: anytype, vertex_bytes: []const u8, indices: []const u16) !IndexedMesh {
        _ = .{ gpu, vertex_bytes, indices };
        @panic("not implemented");
    }

    pub fn destroy(self: *IndexedMesh) void {
        _ = self;
        @panic("not implemented");
    }

    /// Bind the vertex buffer at binding 0 and the index buffer, then draw every index once.
    pub fn recordDraw(self: *const IndexedMesh, command_buffer: vk.CommandBuffer) void {
        _ = .{ self, command_buffer };
        @panic("not implemented");
    }
};
