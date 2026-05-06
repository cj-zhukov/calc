const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const eval = @import("eval.zig");

pub fn calculate(allocator: Allocator, expr: []const u8) !f32 {
    const tokens = try lexer.tokenize(allocator, expr);
    defer allocator.free(tokens);

    const postfix = try parser.toPostfix(allocator, tokens);
    defer allocator.free(postfix);

    return try eval.evalPostfix(allocator, postfix);
}

test "test evaluator" {
    const allocator = testing.allocator;
    const res = try calculate(allocator, "(5 + 5) * 2 / 2");
    try testing.expectEqual(@as(f32, 10.0), res);
}
