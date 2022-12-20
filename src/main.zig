const std = @import("std");

fn getVal(x: u16, registers: [8]u16) !u16 {
    return if (x < 32768) x else if (x < 32776) registers[x - 32768] else error.InvalidArgs;
}

pub fn runBinary(memory: []u16, stdout: anytype) !void {
    var pc: u16 = 0;
    var registers: [8]u16 = undefined;

    while (true) {
        // std.debug.print("Running opcode: {any}\n", .{memory[pc]});
        switch (memory[pc]) {
            0 => {
                return;
            },
            19 => {
                const a = try getVal(memory[pc + 1], registers);
                if (a > 255) return error.InvalidArgs;
                try stdout.print("{c}", .{@intCast(u8, a)});
                pc += 2;
            },
            21 => {
                pc += 1;
            },
            else => {
                std.debug.print("Unknown opcode: {any}\n", .{memory[pc]});
                return error.UnImplementedError;
            },
        }
    }
}

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout = std.io.getStdOut().writer();
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);

    // skip my own exe name
    _ = args.skip();

    const filename = args.next() orelse {
        std.debug.print("Expected first argument to be path to the binary\n", .{});
        return error.InvalidArgs;
    };

    var buffer: [65536]u8 = undefined;

    const bytes_read = try std.fs.cwd().readFile(filename, &buffer);

    var memory = std.mem.zeroes([32768]u16);

    for (bytes_read) |byte, i| {
        memory[i / 2] += if (i % 2 == 0) byte else @intCast(u16, byte) * 256;
    }

    // var i: u16 = 0;
    // while (i * 2 < bytes_read.len) {
    //     std.debug.print("{any} ", .{memory[i]});
    //     i += 1;
    // }

    try runBinary(&memory, stdout);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
