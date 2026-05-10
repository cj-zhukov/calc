const std = @import("std");
const calc = @import("calc");

pub fn run() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const reader = &stdin_reader.interface;
    const writer = &stdout_writer.interface;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try writer.writeAll("calculator\n");

    var out_buf: [256]u8 = undefined;

    while (true) {
        try writer.writeAll(">> ");
        try writer.flush();

        const maybe_line = try reader.takeDelimiter('\n');
        const line = maybe_line.?;
        const input = std.mem.trim(u8, line, " \t\r\n");
        if (input.len == 0) continue;

        // exit to quit from calculator
        if (std.mem.eql(u8, input, "exit")) break;

        const result = calc.calculate(allocator, input);
        if (result) |res| {
            const msg = try std.fmt.bufPrint(&out_buf, "{d}\n", .{res});
            try writer.writeAll(msg);
        } else |err| {
            const msg = try std.fmt.bufPrint(&out_buf, "Error: {s}\n", .{@errorName(err)});
            try writer.writeAll(msg);
        }
    }
}
