pub const CalcError = error{
    BadToken, // #TODO make error more verbose
    MismatchedParens,
    NotEnoughOperands,
    DivisionByZero,
};
