const std = @import("std");
const testing = std.testing;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const C = @cImport({
    @cInclude("vbyte.h");
});

/// vbyte compress u32 or u64 data. if sorted, use `initial_value` for delta
/// compression. `inital_value` is only used when `sorted` is true.
pub fn compress(comptime T: type, values: std.ArrayList(T), comptime sorted: bool, out: *std.ArrayList(u8), initial_value: T) !void {
    var size_bytes: usize = 0;
    if (T == u64) {
        if (sorted) {
            const exp_size_bytes = C.vbyte_compressed_size_sorted64(&values.items[0], values.items.len, initial_value);
            try out.*.resize(@intCast(usize, exp_size_bytes));
            size_bytes = C.vbyte_compress_sorted64(&values.items[0], &out.items[0], initial_value, values.items.len);
        } else {
            const exp_size_bytes = C.vbyte_compressed_size_unsorted64(&values.items[0], values.items.len);
            try out.resize(@intCast(usize, exp_size_bytes));
            size_bytes = C.vbyte_compress_unsorted64(&values.items[0], &out.items[0], values.items.len);
        }
    } else if (T == u32) {
        if (sorted) {
            const exp_size_bytes = C.vbyte_compressed_size_sorted32(&values.items[0], values.items.len, initial_value);
            try out.*.resize(@intCast(usize, exp_size_bytes));
            size_bytes = C.vbyte_compress_sorted32(&values.items[0], &out.items[0], initial_value, values.items.len);
        } else {
            const exp_size_bytes = C.vbyte_compressed_size_unsorted32(&values.items[0], values.items.len);
            try out.resize(@intCast(usize, exp_size_bytes));
            size_bytes = C.vbyte_compress_unsorted32(&values.items[0], &out.items[0], values.items.len);
        }
    } else {
        @compileError("only u64 and u32 supported to compress");
    }
    try out.resize(size_bytes / @sizeOf(T));
}

//extern size_t
//vbyte_uncompress_sorted64(const uint8_t *in, uint64_t *out, uint64_t previous,
//               size_t length);
//extern size_t
//vbyte_uncompress_unsorted64(const uint8_t *in, uint64_t *out, size_t length);

const VByteError = error{
    UnexpectedNumberOfBytes,
};

/// out must be the correct size.
pub fn decompress(comptime T: type, compressed: [*]u8, comptime sorted: bool, out: *std.ArrayList(T), initial_value: T) !void {
    var dec_bytes: usize = 0;
    if (T == u64) {
        if (sorted) {
            dec_bytes = C.vbyte_uncompress_sorted64(compressed, &out.items[0], initial_value, out.items.len);
        } else {
            dec_bytes = C.vbyte_uncompress_unsorted64(compressed, &out.items[0], out.items.len);
        }
    } else if (T == u32) {
        if (sorted) {
            dec_bytes = C.vbyte_uncompress_sorted32(compressed, &out.items[0], initial_value, out.items.len);
        } else {
            dec_bytes = C.vbyte_uncompress_unsorted32(compressed, &out.items[0], out.items.len);
        }
    } else {
        @compileError("only u64 and u32 supported to compress");
    }
    // NOTE it's not actually bytes as indicated in the header.
    if (dec_bytes != out.items.len) {
        if (!sorted and dec_bytes == out.items.len * 4) {
            return;
        }
        try stderr.print("dec_bytes: {d}, len:{d}\n", .{ dec_bytes, out.items.len });
        return VByteError.UnexpectedNumberOfBytes;
    }
}

test "basic compression round trip" {
    // TODO
    //vbyte_select_sorted64(const uint8_t *in, size_t size, uint64_t previous,
    //vbyte_select_unsorted64(const uint8_t *in, size_t size, size_t index);
    //vbyte_search_unsorted64(const uint8_t *in, size_t length, uint64_t value);
    //vbyte_search_lower_bound_sorted64(const uint8_t *in, size_t length,
    //vbyte_append_sorted64(uint8_t *end, uint64_t previous, uint64_t value);
    //vbyte_append_unsorted64(uint8_t *end, uint64_t value);
    const sorted = false;
    const T = u64;
    const allocator = std.testing.allocator;

    var values = std.ArrayList(T).init(allocator);
    var compressed = std.ArrayList(u8).init(allocator);
    defer values.deinit();
    defer compressed.deinit();
    values.resize(10001) catch {};
    var i: T = 1;
    values.items[0] = 14566576;
    while (i < values.items.len) {
        values.items[i] = values.items[i - 1] + 2;
        i += 1;
    }

    var out = std.ArrayList(T).init(allocator);
    defer out.deinit();
    out.resize(values.items.len) catch {};

    try compress(T, values, sorted, &compressed, values.items[0]);
    try stdout.print("compressed size bytes:{d} uncompressed size bytes: {d} ratio: {d}\n", .{ compressed.items.len, values.items.len * @sizeOf(T), (values.items.len * @sizeOf(T)) / compressed.items.len });

    try decompress(T, compressed.items.ptr, sorted, &out, values.items[0]);

    try std.testing.expect(std.mem.eql(T, out.items, values.items));
}
