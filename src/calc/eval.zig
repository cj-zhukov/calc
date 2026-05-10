const calc = @import("root.zig");
const CalcError = calc.err.CalcError;
const Token = calc.token.Token;
const Operator = calc.token.Operator;

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub fn evalPostfix(
    allocator: Allocator,
    tokens: []const Token,
) !f32 {
    var stack = try std.ArrayList(f32).initCapacity(
        allocator,
        tokens.len,
    );
    defer stack.deinit(allocator);

    for (tokens) |token| {
        switch (token) {
            .Number => |num| {
                try stack.append(allocator, num);
            },

            .Op => |operator| {
                const right = stack.pop() orelse
                    return CalcError.NotEnoughOperands;

                const left = stack.pop() orelse
                    return CalcError.NotEnoughOperands;

                const res = switch (operator) {
                    .Add => left + right,
                    .Sub => left - right,
                    .Mul => left * right,
                    .Div => blk: {
                        if (right == 0.0)
                            return CalcError.DivisionByZero;

                        break :blk left / right;
                    },
                };

                try stack.append(allocator, res);
            },

            else => {},
        }
    }

    if (stack.items.len != 1)
        return CalcError.NotEnoughOperands;

    return stack.pop().?;
}

fn n(x: f32) Token {
    return Token{ .Number = x };
}

fn op(o: Operator) Token {
    return Token{ .Op = o };
}

test "eval add" {
    const input = [_]Token{
        n(1.0), n(2.0), op(.Add),
    };

    const res = try evalPostfix(testing.allocator, &input);
    try testing.expectEqual(@as(f32, 3.0), res);
}

test "eval all ops" {
    // (5 + 5) * 2
    const input = [_]Token{
        n(5.0), n(5.0), op(.Add), n(2.0), op(.Mul),
    };

    const res = try evalPostfix(testing.allocator, &input);
    try testing.expectEqual(@as(f32, 20.0), res);
}

test "eval sub order" {
    const input = [_]Token{
        n(10.0), n(5.0), op(.Sub),
    };

    const res = try evalPostfix(testing.allocator, &input);
    try testing.expectEqual(@as(f32, 5.0), res);
}

test "eval div" {
    const input = [_]Token{
        n(10.0), n(5.0), op(.Div),
    };

    const res = try evalPostfix(testing.allocator, &input);
    try testing.expectEqual(@as(f32, 2.0), res);
}

test "eval div by zero" {
    const input = [_]Token{
        n(10.0), n(0.0), op(.Div),
    };

    const err = evalPostfix(testing.allocator, &input);
    try testing.expectError(CalcError.DivisionByZero, err);
}

test "eval not enough operands" {
    const input = [_]Token{
        op(.Add),
    };

    const err = evalPostfix(testing.allocator, &input);
    try testing.expectError(CalcError.NotEnoughOperands, err);
}

test "eval partial expression" {
    const input = [_]Token{
        n(1.0), op(.Add),
    };

    const err = evalPostfix(testing.allocator, &input);
    try testing.expectError(CalcError.NotEnoughOperands, err);
}

test "eval extra operands should fail" {
    const input = [_]Token{
        n(1.0), n(2.0), n(3.0), op(.Add),
    };

    const err = evalPostfix(testing.allocator, &input);
    try testing.expectError(CalcError.NotEnoughOperands, err);
}

test "eval empty" {
    const input = [_]Token{};

    const err = evalPostfix(testing.allocator, &input);
    try testing.expectError(CalcError.NotEnoughOperands, err);
}
