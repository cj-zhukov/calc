const calc = @import("root.zig");
const CalcError = calc.err.CalcError;
const Token = calc.token.Token;
const Operator = calc.token.Operator;
const Bracket = calc.token.Bracket;

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub fn toPostfix(
    allocator: Allocator,
    tokens: []const Token,
) ![]Token {
    var output = try std.ArrayList(Token).initCapacity(allocator, 0);
    defer output.deinit(allocator);

    var stack = try std.ArrayList(Token).initCapacity(allocator, 0);
    defer stack.deinit(allocator);

    for (tokens) |token| {
        switch (token) {
            .Number => {
                try output.append(allocator, token);
            },

            .Op => |op| {
                while (stack.items.len > 0) {
                    const top = stack.items[stack.items.len - 1];

                    switch (top) {
                        .Op => |top_op| {
                            if (precedence(top_op) >= precedence(op)) {
                                _ = stack.pop();
                                try output.append(allocator, top);
                                continue;
                            }
                        },
                        else => {},
                    }
                    break;
                }

                try stack.append(allocator, token);
            },

            .Bracket => |b| {
                switch (b) {
                    .Open => {
                        try stack.append(allocator, token);
                    },

                    .Close => {
                        while (stack.items.len > 0) {
                            const top = stack.items[stack.items.len - 1];

                            switch (top) {
                                .Bracket => |bracket| {
                                    if (bracket == Bracket.Open) {
                                        break;
                                    }
                                },
                                else => {},
                            }

                            _ = stack.pop();
                            try output.append(allocator, top);
                        }

                        // pop '('
                        if (stack.items.len > 0) {
                            _ = stack.pop();
                        }
                    },
                }
            },
        }
    }

    // drain stack
    while (stack.items.len > 0) {
        const t = stack.pop().?;
        try output.append(allocator, t);
    }

    return output.toOwnedSlice(allocator);
}

fn precedence(op: Operator) u8 {
    return switch (op) {
        .Add, .Sub => 1,
        .Mul, .Div => 2,
    };
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

test "postfix simple add" {
    const allocator = testing.allocator;

    const input = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 2.0 },
    };

    const res = try toPostfix(allocator, &input);
    defer allocator.free(res);

    const expected = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Number = 2.0 },
        Token{ .Op = Operator.Add },
    };

    try expectTokensEqual(&expected, res);
}

test "postfix precedence" {
    const allocator = testing.allocator;

    const input = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 2.0 },
        Token{ .Op = Operator.Mul },
        Token{ .Number = 3.0 },
    };

    const res = try toPostfix(allocator, &input);
    defer allocator.free(res);

    const expected = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Number = 2.0 },
        Token{ .Number = 3.0 },
        Token{ .Op = Operator.Mul },
        Token{ .Op = Operator.Add },
    };

    try expectTokensEqual(&expected, res);
}

test "postfix parentheses" {
    const allocator = testing.allocator;

    const input = [_]Token{
        Token{ .Bracket = Bracket.Open },
        Token{ .Number = 1.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 2.0 },
        Token{ .Bracket = Bracket.Close },
        Token{ .Op = Operator.Mul },
        Token{ .Number = 3.0 },
    };

    const res = try toPostfix(allocator, &input);
    defer allocator.free(res);

    const expected = [_]Token{
        Token{ .Number = 1.0 },
        Token{ .Number = 2.0 },
        Token{ .Op = Operator.Add },
        Token{ .Number = 3.0 },
        Token{ .Op = Operator.Mul },
    };

    try expectTokensEqual(&expected, res);
}
