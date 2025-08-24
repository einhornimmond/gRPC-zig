const std = @import("std");
const net = std.net;
const http2 = struct {
    pub const connection = @import("http2/connection.zig");
    pub const frame = @import("http2/frame.zig");
    pub const stream = @import("http2/stream.zig");
};

pub const TransportError = error{
    ConnectionClosed,
    InvalidHeader,
    PayloadTooLarge,
    CompressionNotSupported,
    Http2Error,
};

pub const Transport = struct {
    stream: net.Stream,
    read_buf: []u8,
    write_buf: []u8,
    allocator: std.mem.Allocator,
    http2_conn: ?http2.connection.Connection,

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !Transport {
        var transport = Transport{
            .stream = stream,
            .read_buf = try allocator.alloc(u8, 1024 * 64),
            .write_buf = try allocator.alloc(u8, 1024 * 64),
            .allocator = allocator,
            .http2_conn = null,
        };

        // Initialize HTTP/2 connection
        transport.http2_conn = try http2.connection.Connection.init(allocator);
        try transport.setupHttp2();

        return transport;
    }

    pub fn deinit(self: *Transport) void {
        if (self.http2_conn) |*conn| {
            conn.deinit();
        }
        self.allocator.free(self.read_buf);
        self.allocator.free(self.write_buf);
        self.stream.close();
    }

    fn setupHttp2(self: *Transport) !void {
        // Send HTTP/2 connection preface
        _ = try self.stream.write(http2.connection.Connection.PREFACE);

        // Send initial SETTINGS frame
        var settings_frame = try http2.frame.Frame.init(self.allocator);
        defer settings_frame.deinit(self.allocator);

        settings_frame.type = .SETTINGS;
        settings_frame.flags = 0;
        settings_frame.stream_id = 0;
        // Add your settings here

        var writer = std.io.bufferedWriter(self.stream.writer());
        try settings_frame.encode(writer.writer());
        try writer.flush();
    }

    pub fn readMessage(self: *Transport) ![]const u8 {
        var frame_reader = std.io.bufferedReader(self.stream.reader());
        var frame = try http2.frame.Frame.decode(frame_reader.reader(), self.allocator);
        defer frame.deinit(self.allocator);

        if (frame.type == .DATA) {
            return try self.allocator.dupe(u8, frame.payload);
        }

        return TransportError.Http2Error;
    }

    pub fn writeMessage(self: *Transport, message: []const u8) !void {
        var data_frame = try http2.frame.Frame.init(self.allocator);
        defer data_frame.deinit(self.allocator);

        data_frame.type = .DATA;
        data_frame.flags = http2.frame.FrameFlags.END_STREAM;
        data_frame.stream_id = 1; // Use appropriate stream ID
        data_frame.payload = message;
        data_frame.length = @intCast(message.len);

        var writer = std.io.bufferedWriter(self.stream.writer());
        try data_frame.encode(writer.writer());
        try writer.flush();
    }
};
