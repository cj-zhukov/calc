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
    var tokens = try std.ArrayList(Token).initCapacity(allocator, 0);
    defer tokens.deinit(allocator);

    var parens = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer parens.deinit(allocator);

    var number_buf = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer number_buf.deinit(allocator);

    for (expr) |c| {
        switch (c) {
            '0'...'9', '.' => {
                try number_buf.append(allocator, c);
            },

            '+', '-', '*', '/' => {
                try flushNumber(allocator, &number_buf, &tokens);

                const op = switch (c) {
                    '+' => Operator.Add,
                    '-' => Operator.Sub,
                    '*' => Operator.Mul,
                    '/' => Operator.Div,
                    else => unreachable,
                };

                try tokens.append(allocator, Token{ .Op = op });
            },

            '(' => {
                try flushNumber(allocator, &number_buf, &tokens);
                try tokens.append(allocator, Token{ .Bracket = Bracket.Open });
                try parens.append(allocator, c);
            },

            ')' => {
                try flushNumber(allocator, &number_buf, &tokens);
                try tokens.append(allocator, Token{ .Bracket = Bracket.Close });

                if (parens.items.len == 0) {
                    return CalcError.MismatchedParens;
                }
                _ = parens.pop();
            },

            ' ', '\n' => {
                try flushNumber(allocator, &number_buf, &tokens);
            },

            else => return CalcError.BadToken,
        }
    }

    // flush last number
    try flushNumber(allocator, &number_buf, &tokens);

    if (parens.items.len != 0) {
        return CalcError.MismatchedParens;
    }

    return tokens.toOwnedSlice(allocator);
}

fn flushNumber(
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    tokens: *std.ArrayList(Token),
) !void {
    if (buf.items.len == 0) return;

    const slice = buf.items;

    const number = std.fmt.parseFloat(f32, slice) catch {
        return CalcError.BadToken;
    };

    try tokens.append(allocator, Token{ .Number = number });
    buf.clearRetainingCapacity();
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
