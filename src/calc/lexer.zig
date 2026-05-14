const calc = @import("root.zig");
const CalcError = calc.err.CalcError;
const Token = calc.token.Token;
const Operator = calc.token.Operator;
const Bracket = calc.token.Bracket;

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub fn tokenize(
    allocator: Allocator,
    expr: []const u8,
) ![]Token {
    var tokens = try std.ArrayList(Token)
        .initCapacity(allocator, expr.len);
    defer tokens.deinit(allocator);

    var paren_depth: usize = 0;

    // start index of current number
    var num_start: ?usize = null;

    for (expr, 0..) |c, i| {
        switch (c) {
            '0'...'9', '.' => {
                // number started
                if (num_start == null)
                    num_start = i;
            },

            '+', '-', '*', '/' => {
                try flushNumber(
                    allocator,
                    expr,
                    i,
                    &num_start,
                    &tokens,
                );

                const op = switch (c) {
                    '+' => Operator.Add,
                    '-' => Operator.Sub,
                    '*' => Operator.Mul,
                    '/' => Operator.Div,
                    else => unreachable,
                };

                try tokens.append(
                    allocator,
                    Token{ .Op = op },
                );
            },

            '(' => {
                try flushNumber(
                    allocator,
                    expr,
                    i,
                    &num_start,
                    &tokens,
                );

                try tokens.append(
                    allocator,
                    Token{ .Bracket = Bracket.Open },
                );

                paren_depth += 1;
            },

            ')' => {
                try flushNumber(
                    allocator,
                    expr,
                    i,
                    &num_start,
                    &tokens,
                );

                if (paren_depth == 0)
                    return CalcError.MismatchedParens;

                paren_depth -= 1;

                try tokens.append(
                    allocator,
                    Token{ .Bracket = Bracket.Close },
                );
            },

            ' ', '\n', '\t' => {
                try flushNumber(
                    allocator,
                    expr,
                    i,
                    &num_start,
                    &tokens,
                );
            },

            else => {
                std.log.err("bad token: '{c}'", .{c});
                return CalcError.BadToken;
            },
        }
    }

    // flush final number
    try flushNumber(
        allocator,
        expr,
        expr.len,
        &num_start,
        &tokens,
    );

    if (paren_depth != 0)
        return CalcError.MismatchedParens;

    return tokens.toOwnedSlice(allocator);
}

fn flushNumber(
    allocator: Allocator,
    expr: []const u8,
    end: usize,
    num_start: *?usize,
    tokens: *std.ArrayList(Token),
) !void {
    const start = num_start.* orelse return;

    const slice = expr[start..end];

    const number = std.fmt.parseFloat(
        f32,
        slice,
    ) catch {
        return CalcError.BadToken;
    };

    try tokens.append(
        allocator,
        Token{ .Number = number },
    );

    num_start.* = null;
}

fn expectTokensEqual(expected: []const Token, actual: []const Token) !void {
    try testing.expectEqual(expected.len, actual.len);

    for (expected, actual) |e, a| {
        switch (e) {
            .Number => |v1| {
                switch (a) {
                    .Number => |v2| try testing.expectEqual(v1, v2),
                    else => return error.TestExpectedEqual,
                }
            },
            .Op => |op1| {
                switch (a) {
                    .Op => |op2| try testing.expectEqual(op1, op2),
                    else => return error.TestExpectedEqual,
                }
            },
            .Bracket => |b1| {
                switch (a) {
                    .Bracket => |b2| try testing.expectEqual(b1, b2),
                    else => return error.TestExpectedEqual,
                }
            },
        }
    }
}

test "tokenize simple expression" {
    const allocator = testing.allocator;

    const tokens = try tokenize(allocator, "1 + 2");
    defer allocator.free(tokens);

    const expected = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 2.0 },
    };

    try expectTokensEqual(&expected, tokens);
}

test "tokenize multi digit number" {
    const allocator = testing.allocator;

    const tokens = try tokenize(allocator, "123 + 45");
    defer allocator.free(tokens);

    const expected = [_]Token{
        Token{ .Number = 123.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 45.0 },
    };

    try expectTokensEqual(&expected, tokens);
}

test "tokenize parentheses" {
    const allocator = testing.allocator;

    const tokens = try tokenize(allocator, "(1 + 2)");
    defer allocator.free(tokens);

    const expected = [_]Token{
        Token{ .Bracket = Bracket.Open },
        Token{ .Number = 1.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 2.0 },
        Token{ .Bracket = Bracket.Close },
    };

    try expectTokensEqual(&expected, tokens);
}

test "error unexpected closing paren" {
    const allocator = testing.allocator;

    const result = tokenize(allocator, "1 + 2)");

    try testing.expectError(CalcError.MismatchedParens, result);
}

test "error bad token" {
    const allocator = testing.allocator;

    const result = tokenize(allocator, "1 + a");

    try testing.expectError(CalcError.BadToken, result);
}

test "tokenize empty input" {
    const allocator = testing.allocator;

    const tokens = try tokenize(allocator, "");
    defer allocator.free(tokens);

    try testing.expectEqual(@as(usize, 0), tokens.len);
}

test "tokenize numbers separated by space" {
    const allocator = testing.allocator;

    const tokens = try tokenize(allocator, "1 2");
    defer allocator.free(tokens);

    const expected = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Number = 2.0 },
    };

    try expectTokensEqual(&expected, tokens);
}
