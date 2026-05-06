pub const CalcError = error{
    BadToken,
    MismatchedParens,
    NotEnoughOperands,
    DivisionByZero,
};

// #TODO make error more verbose
// pub const CalcError = union(enum) {
//     BadToken: u8,
//     MismatchedParens,
//     NotEnoughOperands,
//     DivisionByZero,
// };
