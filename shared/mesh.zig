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
        if (vertex_bytes.len == 0) return error.EmptyVertexList;
        if (indices.len == 0) return error.EmptyIndexList;
        var mesh = IndexedMesh{ .vkd = gpu.vkd, .device = gpu.device, .index_count = @intCast(indices.len) };
        errdefer mesh.destroy();
        const vertex_upload = try uploadBuffer(gpu, vertex_bytes, .{ .vertex_buffer = true });
        mesh.vertex_buffer = vertex_upload.buffer;
        mesh.vertex_memory = vertex_upload.memory;
        const index_upload = try uploadBuffer(gpu, std.mem.sliceAsBytes(indices), .{ .index_buffer = true });
        mesh.index_buffer = index_upload.buffer;
        mesh.index_memory = index_upload.memory;
        return mesh;
    }

    pub fn destroy(self: *IndexedMesh) void {
        if (self.vertex_buffer != .null) self.vkd.destroyBuffer(self.device, self.vertex_buffer, null);
        if (self.vertex_memory != .null) self.vkd.freeMemory(self.device, self.vertex_memory, null);
        if (self.index_buffer != .null) self.vkd.destroyBuffer(self.device, self.index_buffer, null);
        if (self.index_memory != .null) self.vkd.freeMemory(self.device, self.index_memory, null);
        self.* = .{ .vkd = self.vkd, .device = self.device };
    }

    /// Bind the vertex buffer at binding 0 and the index buffer, then draw every index once.
    pub fn recordDraw(self: *const IndexedMesh, command_buffer: vk.CommandBuffer) void {
        const vertex_buffer_offsets = [_]vk.DeviceSize{0};
        self.vkd.cmdBindVertexBuffers(command_buffer, 0, &.{self.vertex_buffer}, &vertex_buffer_offsets);
        self.vkd.cmdBindIndexBuffer(command_buffer, self.index_buffer, 0, index_type);
        self.vkd.cmdDrawIndexed(command_buffer, self.index_count, 1, 0, 0, 0);
    }
};

const BufferUpload = struct { buffer: vk.Buffer, memory: vk.DeviceMemory };

fn uploadBuffer(gpu: anytype, contents: []const u8, usage: vk.BufferUsageFlags) !BufferUpload {
    const vkd = gpu.vkd;
    const device = gpu.device;
    const buffer = try vkd.createBuffer(device, &.{
        .size = contents.len,
        .usage = usage,
        .sharing_mode = .exclusive,
    }, null);
    errdefer vkd.destroyBuffer(device, buffer, null);
    const memory_requirements = vkd.getBufferMemoryRequirements(device, buffer);
    const memory = try vkd.allocateMemory(device, &.{
        .allocation_size = memory_requirements.size,
        .memory_type_index = try gpu.findMemoryTypeIndex(
            memory_requirements.memory_type_bits,
            .{ .host_visible = true, .host_coherent = true },
        ),
    }, null);
    errdefer vkd.freeMemory(device, memory, null);
    try vkd.bindBufferMemory(device, buffer, memory, 0);
    const mapped_bytes: [*]u8 = @ptrCast(try vkd.mapMemory(device, memory, 0, contents.len, .{}));
    @memcpy(mapped_bytes[0..contents.len], contents);
    vkd.unmapMemory(device, memory);
    return .{ .buffer = buffer, .memory = memory };
}
