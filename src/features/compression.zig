const std = @import("std");

pub const Compression = struct {
    pub const Algorithm = enum {
        none,
        gzip,
        deflate,
    };

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Compression {
        return .{ .allocator = allocator };
    }

    fn compressWith(self: *Compression, comptime pkg: type, data: []const u8) ![]u8 {
        var compressed = std.ArrayList(u8).init(self.allocator);
        var compressor = try pkg.compressor(compressed.writer(), .{});
        _ = try compressor.write(data);
        try compressor.finish();
        return compressed.toOwnedSlice();
    }

    pub fn compress(self: *Compression, data: []const u8, algorithm: Algorithm) ![]u8 {
        switch (algorithm) {
            .none => return self.allocator.dupe(u8, data),
            .gzip => return self.compressWith(std.compress.gzip, data),
            .deflate => return self.compressWith(std.compress.flate, data),
        }
    }

    fn decompressWith(self: *Compression, comptime pkg: type, data: []const u8) ![]u8 {
        var decompressed = std.ArrayList(u8).init(self.allocator);
        var fbs = std.io.fixedBufferStream(data);
        _ = try pkg.decompress(fbs.reader(), decompressed.writer());
        return decompressed.toOwnedSlice();
    }

    pub fn decompress(self: *Compression, data: []const u8, algorithm: Algorithm) ![]u8 {
        switch (algorithm) {
            .none => return self.allocator.dupe(u8, data),
            .gzip => return self.decompressWith(std.compress.gzip, data),
            .deflate => return self.decompressWith(std.compress.flate, data),
        }
    }
};
