pub const CalcError = error{
    BadToken,
    MismatchedParens,
    NotEnoughOperands,
    DivisionByZero,
};
