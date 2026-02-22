const std = @import("std");

/// Thread-local cryptographically secure random source.
pub const default: std.Random = std.crypto.random;

/// Non-cryptographic random source seeded from secure entropy on each call.
pub const non_secure: std.Random = .{
    .ptr = undefined,
    .fillFn = nonSecureFill,
};

/// Non-cryptographic random source with thread-local PRNG state.
pub const thread_local: std.Random = .{
    .ptr = undefined,
    .fillFn = threadLocalFill,
};

const ThreadLocalState = struct {
    initialized: bool = false,
    prng: std.Random.DefaultPrng = undefined,
};

threadlocal var tls_state: ThreadLocalState = .{};

fn randomSeed() u64 {
    var seed_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&seed_bytes);
    return std.mem.readInt(u64, &seed_bytes, .little);
}

fn nonSecureFill(_: *anyopaque, buf: []u8) void {
    var prng = std.Random.DefaultPrng.init(randomSeed());
    prng.random().bytes(buf);
}

fn threadLocalFill(_: *anyopaque, buf: []u8) void {
    if (!tls_state.initialized) {
        tls_state.prng = std.Random.DefaultPrng.init(randomSeed());
        tls_state.initialized = true;
    }

    tls_state.prng.random().bytes(buf);
}

test "default fills random vectors" {
    var bytes: [5]u8 = undefined;
    default.bytes(&bytes);
    try std.testing.expectEqual(@as(usize, 5), bytes.len);
}

test "non_secure fills random vectors" {
    var bytes: [5]u8 = undefined;
    non_secure.bytes(&bytes);
    try std.testing.expectEqual(@as(usize, 5), bytes.len);
}

test "thread_local fills random vectors" {
    var bytes: [5]u8 = undefined;
    thread_local.bytes(&bytes);
    try std.testing.expectEqual(@as(usize, 5), bytes.len);
}
