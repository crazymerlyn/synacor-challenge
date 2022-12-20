const std = @import("std");

const Machine = struct {
    memory: []u16,
    registers: [8]u16,
    stack: std.ArrayList(u16),
    debug: bool = false,

    fn getVal(self: *Machine, x: u16) !u16 {
        return if (x < 32768) x else if (x < 32776) self.registers[x - 32768] else error.InvalidArgs;
    }

    fn setVal(self: *Machine, x: u16, val: u16) !void {
        if ((x < 32768) or (x >= 32776)) return error.InvalidArgs;
        self.registers[x - 32768] = val;
    }

    fn getInt(stdin: anytype, buffer: []u8, delimiter: u8) !u16 {
        const registerstr = try stdin.readUntilDelimiterOrEof(buffer, delimiter) orelse {
            return error.EndOfStream;
        };
        return try std.fmt.parseUnsigned(u16, registerstr, 10);
    }

    fn getByte(self: *Machine, stdin: anytype) !u8 {
        var byte = try stdin.readByte();
        while (byte == '!') {
            var buffer: [100]u8 = undefined;
            const command = try getInt(stdin, &buffer, ' ');

            if (command == 1) {
                const register = try getInt(stdin, &buffer, '\n') - 1;
                std.debug.print("Register {any} is {any}\n", .{ register, self.registers[register] });
            } else if (command == 2) {
                var register = try getInt(stdin, &buffer, ' ') - 1;
                var value = try getInt(stdin, &buffer, '\n');
                std.debug.print("Setting register {any} to {any}\n", .{ register, value });
                self.registers[register] = value;
            } else {
                var value = try getInt(stdin, &buffer, '\n');
                std.debug.print("Setting debug to {any}\n", .{value});
                self.debug = value > 0;
            }
            byte = try stdin.readByte();
        }
        return byte;
    }

    pub fn run(self: *Machine, stdin: anytype, stdout: anytype) !void {
        var pc: u16 = 0;

        while (true) {
            if (self.debug) {
                try stdout.print("Running opcode {any} at pc {}\n", .{ self.memory[pc], pc });
            }
            switch (self.memory[pc]) {
                0 => {
                    return;
                },
                1 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    try self.setVal(self.memory[pc + 1], b);
                    pc += 3;
                },
                2 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    try self.stack.append(a);
                    pc += 2;
                },
                3 => {
                    const a = self.stack.pop();
                    try self.setVal(self.memory[pc + 1], a);
                    pc += 2;
                },
                4 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], if (b == c) 1 else 0);
                    pc += 4;
                },
                5 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], if (b > c) 1 else 0);
                    pc += 4;
                },
                6 => {
                    pc = try self.getVal(self.memory[pc + 1]);
                },
                7 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    const b = try self.getVal(self.memory[pc + 2]);
                    pc = if (a != 0) b else pc + 3;
                },
                8 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    const b = try self.getVal(self.memory[pc + 2]);
                    pc = if (a == 0) b else pc + 3;
                },
                9 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], (b + c) % 32768);
                    pc += 4;
                },
                10 => {
                    const b: u32 = try self.getVal(self.memory[pc + 2]);
                    const c: u32 = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], @intCast(u16, (b * c) % 32768));
                    pc += 4;
                },
                11 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], b % c);
                    pc += 4;
                },
                12 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], b & c);
                    pc += 4;
                },
                13 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    const c = try self.getVal(self.memory[pc + 3]);
                    try self.setVal(self.memory[pc + 1], b | c);
                    pc += 4;
                },
                14 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    try self.setVal(self.memory[pc + 1], ~b & 0x7fff);
                    pc += 3;
                },
                15 => {
                    const b = try self.getVal(self.memory[pc + 2]);
                    try self.setVal(self.memory[pc + 1], self.memory[b]);
                    pc += 3;
                },
                16 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    const b = try self.getVal(self.memory[pc + 2]);
                    self.memory[a] = b;
                    pc += 3;
                },
                17 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    try self.stack.append(pc + 2);
                    pc = a;
                },
                18 => {
                    const a = self.stack.popOrNull();
                    pc = a orelse return;
                },
                19 => {
                    const a = try self.getVal(self.memory[pc + 1]);
                    if (a > 255) return error.InvalidArgs;
                    try stdout.print("{c}", .{@intCast(u8, a)});
                    pc += 2;
                },
                20 => {
                    var x: u16 = try self.getByte(stdin);
                    try self.setVal(self.memory[pc + 1], x);
                    pc += 2;
                },
                21 => {
                    pc += 1;
                },
                else => {
                    std.debug.print("Unknown opcode: {any}\n", .{self.memory[pc]});
                    return error.UnImplementedError;
                },
            }
        }
    }
};

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
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

    var stack = std.ArrayList(u16).init(std.heap.page_allocator);
    defer stack.deinit();

    var machine = Machine{ .memory = &memory, .registers = std.mem.zeroes([8]u16), .stack = stack };
    try machine.run(stdin, stdout);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
