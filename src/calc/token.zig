pub const Operator = enum {
    Add,
    Sub,
    Mul,
    Div,
};

pub const Bracket = enum {
    Open,
    Close,
};

pub const Token = union(enum) {
    Number: f32,
    Op: Operator,
    Bracket: Bracket,
};
