const std = @import("std");

pub const alphabet = @import("alphabet.zig");
pub const rngs = @import("rngs.zig");

pub const default_size: usize = 21;
pub const max_alphabet_len: usize = 256;

pub const Error = error{
    EmptyAlphabet,
    AlphabetTooLong,
};

/// Fill `out` with an ID generated from `symbols` using rejection sampling.
pub fn formatInto(random: std.Random, symbols: []const u8, out: []u8) Error!void {
    if (symbols.len == 0) return error.EmptyAlphabet;
    if (symbols.len > max_alphabet_len) return error.AlphabetTooLong;
    if (out.len == 0) return;

    const mask: u8 = @intCast(std.math.ceilPowerOfTwoAssert(usize, symbols.len) - 1);
    const step: usize = @max(@as(usize, 1), (out.len * 8) / 5);

    var random_bytes: [256]u8 = undefined;
    const chunk_len = @min(step, random_bytes.len);

    var out_index: usize = 0;
    while (out_index < out.len) {
        random.bytes(random_bytes[0..chunk_len]);

        for (random_bytes[0..chunk_len]) |byte| {
            const symbol_index: usize = @intCast(byte & mask);
            if (symbol_index < symbols.len) {
                out[out_index] = symbols[symbol_index];
                out_index += 1;
                if (out_index == out.len) return;
            }
        }
    }
}

/// Allocate and return an ID generated from `symbols`.
pub fn format(
    allocator: std.mem.Allocator,
    random: std.Random,
    symbols: []const u8,
    size: usize,
) (std.mem.Allocator.Error || Error)![]u8 {
    const id = try allocator.alloc(u8, size);
    errdefer allocator.free(id);

    try formatInto(random, symbols, id);
    return id;
}

/// Generate a default picoid (size 21, URL-safe alphabet) without heap allocation.
pub fn picoid() [default_size]u8 {
    var id: [default_size]u8 = undefined;
    formatInto(rngs.default, alphabet.SAFE[0..], &id) catch unreachable;
    return id;
}

/// Fill `out` with a picoid using the default URL-safe alphabet.
pub fn picoidInto(out: []u8) void {
    formatInto(rngs.default, alphabet.SAFE[0..], out) catch unreachable;
}

/// Allocate and return a picoid with a custom size using the default URL-safe alphabet.
pub fn picoidAlloc(
    allocator: std.mem.Allocator,
    size: usize,
) (std.mem.Allocator.Error || Error)![]u8 {
    return format(allocator, rngs.default, alphabet.SAFE[0..], size);
}

/// Allocate and return a picoid with a custom alphabet.
pub fn customAlphabetAlloc(
    allocator: std.mem.Allocator,
    size: usize,
    symbols: []const u8,
) (std.mem.Allocator.Error || Error)![]u8 {
    return format(allocator, rngs.default, symbols, size);
}

/// Allocate and return a picoid with custom alphabet and custom random source.
pub fn customRandomAlloc(
    allocator: std.mem.Allocator,
    size: usize,
    symbols: []const u8,
    random: std.Random,
) (std.mem.Allocator.Error || Error)![]u8 {
    return format(allocator, random, symbols, size);
}

fn expectAllInAlphabet(value: []const u8, symbols: []const u8) !void {
    for (value) |ch| {
        try std.testing.expect(std.mem.indexOfScalar(u8, symbols, ch) != null);
    }
}

test "formatInto returns EmptyAlphabet for empty symbols" {
    var prng = std.Random.DefaultPrng.init(1);
    var out: [8]u8 = undefined;

    try std.testing.expectError(error.EmptyAlphabet, formatInto(prng.random(), "", &out));
}

test "formatInto returns AlphabetTooLong when symbols exceed max" {
    var prng = std.Random.DefaultPrng.init(2);
    var out: [8]u8 = undefined;
    var symbols: [max_alphabet_len + 1]u8 = undefined;
    @memset(&symbols, 'a');

    try std.testing.expectError(error.AlphabetTooLong, formatInto(prng.random(), symbols[0..], &out));
}

test "formatInto supports empty output buffer" {
    var prng = std.Random.DefaultPrng.init(3);
    var out: [0]u8 = undefined;

    try formatInto(prng.random(), alphabet.SAFE[0..], out[0..]);
}

test picoid {
    const id = picoid();
    try std.testing.expectEqual(default_size, id.len);
    try expectAllInAlphabet(id[0..], alphabet.SAFE[0..]);
}

test "picoidInto fills output with safe symbols" {
    var out: [17]u8 = undefined;
    picoidInto(out[0..]);

    try expectAllInAlphabet(out[0..], alphabet.SAFE[0..]);
}

test "picoidAlloc returns requested length and safe symbols" {
    const id = try picoidAlloc(std.testing.allocator, 33);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 33), id.len);
    try expectAllInAlphabet(id, alphabet.SAFE[0..]);
}

test "format returns requested length and chosen symbols" {
    var prng = std.Random.DefaultPrng.init(4);
    const symbols = "01";
    const id = try format(std.testing.allocator, prng.random(), symbols, 25);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 25), id.len);
    try expectAllInAlphabet(id, symbols);
}

test "customAlphabetAlloc only uses provided alphabet" {
    const symbols = "abc";
    const id = try customAlphabetAlloc(std.testing.allocator, 64, symbols);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 64), id.len);
    try expectAllInAlphabet(id, symbols);
}

test "customRandomAlloc works with deterministic random source" {
    var prng = std.Random.DefaultPrng.init(42);
    const id = try customRandomAlloc(std.testing.allocator, 10, "Z", prng.random());
    defer std.testing.allocator.free(id);

    try std.testing.expectEqualStrings("ZZZZZZZZZZ", id);
}
