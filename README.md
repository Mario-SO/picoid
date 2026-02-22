# picoid

A tiny, secure, URL-friendly unique ID generator for Zig `0.15.2`. 

## Features

- Cryptographically secure random IDs by default (`std.crypto.random`)
- URL-safe default alphabet (`A-Za-z0-9_-`)
- Custom size, custom alphabet, and custom random sources
- Allocation-free default helper for the common 21-character ID

## Usage

```zig
const std = @import("std");
const picoid = @import("picoid");

pub fn main() !void {
    const fixed = picoid.picoid();
    std.debug.print("{s}\n", .{fixed[0..]});

    const allocator = std.heap.page_allocator;
    const id = try picoid.picoidAlloc(allocator, 32);
    defer allocator.free(id);
    std.debug.print("{s}\n", .{id});
}
```

Sample output (values will differ each run):

```text
ZqRTEjLqW4X09G6uj-jhb
iNWX-4Fwnx3nDaBeawuQ1rXQd2n_CdtB
```

### Custom Alphabet

```zig
const std = @import("std");
const picoid = @import("picoid");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hex = "1234567890abcdef";
    const id = try picoid.customAlphabetAlloc(allocator, 10, hex);
    defer allocator.free(id);
    std.debug.print("{s}\n", .{id});
}
```

Sample output (value will differ each run):

```text
21a15d29d2
```

### Custom Random Source

```zig
const std = @import("std");
const picoid = @import("picoid");

pub fn main() !void {
    var prng = std.Random.DefaultPrng.init(42);
    const allocator = std.heap.page_allocator;

    const id = try picoid.customRandomAlloc(
        allocator,
        12,
        picoid.alphabet.SAFE[0..],
        prng.random(),
    );
    defer allocator.free(id);

    std.debug.print("{s}\n", .{id});
}
```

Sample output (deterministic for seed `42`):

```text
tCQ2dbQefRJl
```

## API

- `picoid.picoid() [21]u8`
- `picoid.picoidInto(out: []u8) void`
- `picoid.picoidAlloc(allocator, size) ![]u8`
- `picoid.customAlphabetAlloc(allocator, size, symbols) ![]u8`
- `picoid.customRandomAlloc(allocator, size, symbols, random) ![]u8`
- `picoid.formatInto(random, symbols, out) !void`
- `picoid.format(allocator, random, symbols, size) ![]u8`

Random source helpers are available in `picoid.rngs`:

- `picoid.rngs.default`
- `picoid.rngs.non_secure`
- `picoid.rngs.thread_local`
