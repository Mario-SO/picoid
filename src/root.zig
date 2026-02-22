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

/// Backward-compatible alias.
pub fn nanoid() [default_size]u8 {
    return picoid();
}

/// Backward-compatible alias.
pub fn nanoidInto(out: []u8) void {
    picoidInto(out);
}

/// Backward-compatible alias.
pub fn nanoidAlloc(
    allocator: std.mem.Allocator,
    size: usize,
) (std.mem.Allocator.Error || Error)![]u8 {
    return picoidAlloc(allocator, size);
}

/// Allocate and return a Nano ID with a custom alphabet.
pub fn customAlphabetAlloc(
    allocator: std.mem.Allocator,
    size: usize,
    symbols: []const u8,
) (std.mem.Allocator.Error || Error)![]u8 {
    return format(allocator, rngs.default, symbols, size);
}

/// Allocate and return a Nano ID with custom alphabet and custom random source.
pub fn customRandomAlloc(
    allocator: std.mem.Allocator,
    size: usize,
    symbols: []const u8,
    random: std.Random,
) (std.mem.Allocator.Error || Error)![]u8 {
    return format(allocator, random, symbols, size);
}

test "format generates deterministic string" {
    const CyclingRng = struct {
        index: usize = 0,

        fn fill(self: *@This(), out: []u8) void {
            const bytes = [_]u8{ 2, 255, 0, 1 };
            for (out) |*b| {
                b.* = bytes[self.index % bytes.len];
                self.index += 1;
            }
        }

        fn random(self: *@This()) std.Random {
            return std.Random.init(self, fill);
        }
    };

    const symbols = [_]u8{ 'a', 'b', 'c' };
    var id: [4]u8 = undefined;
    var deterministic = CyclingRng{};
    try formatInto(deterministic.random(), symbols[0..], &id);

    try std.testing.expectEqualStrings("cabc", id[0..]);
}

test "bad alphabet is rejected" {
    var big: [257]u8 = undefined;
    for (&big, 0..) |*ch, i| ch.* = @intCast(i % 256);

    var out: [8]u8 = undefined;
    try std.testing.expectError(error.AlphabetTooLong, formatInto(rngs.default, big[0..], &out));
}

test "non power of 2 alphabet" {
    const id = try customAlphabetAlloc(std.testing.allocator, 42, alphabet.SAFE[0..62]);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 42), id.len);
}

test "simple default ID length" {
    const id = picoid();
    try std.testing.expectEqual(@as(usize, 21), id.len);
}

test "custom size" {
    const id = try picoidAlloc(std.testing.allocator, 42);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 42), id.len);
}

test "custom alphabet" {
    const id = try customAlphabetAlloc(std.testing.allocator, 42, alphabet.SAFE[0..]);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 42), id.len);
}

test "custom random source" {
    var seeded = std.Random.DefaultPrng.init(42);
    const id = try customRandomAlloc(std.testing.allocator, 4, alphabet.SAFE[0..], seeded.random());
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 4), id.len);
}

test "same deterministic source yields same ID" {
    const uuid = "8936ad0c-9443-4007-9430-e223c64d4629";

    const ConstantRng = struct {
        offset: usize = 0,

        fn fill(self: *@This(), out: []u8) void {
            for (out, 0..) |*byte, idx| {
                byte.* = uuid[(self.offset + idx) % uuid.len];
            }
            self.offset += out.len;
        }

        fn random(self: *@This()) std.Random {
            return std.Random.init(self, fill);
        }
    };

    var rng1 = ConstantRng{};
    var rng2 = ConstantRng{};

    const id1 = try customRandomAlloc(std.testing.allocator, 20, alphabet.SAFE[0..], rng1.random());
    defer std.testing.allocator.free(id1);

    const id2 = try customRandomAlloc(std.testing.allocator, 20, alphabet.SAFE[0..], rng2.random());
    defer std.testing.allocator.free(id2);

    try std.testing.expectEqualStrings(id1, id2);
}

test "simple expression for size" {
    const id = try picoidAlloc(std.testing.allocator, 42 / 2);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 21), id.len);
}

test "size zero returns empty string" {
    const id = try picoidAlloc(std.testing.allocator, 0);
    defer std.testing.allocator.free(id);

    try std.testing.expectEqual(@as(usize, 0), id.len);
}
