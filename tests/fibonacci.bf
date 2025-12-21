# cell(0)  = countdown of nth elements
# cell(1)  = counter starting from zero
# cell(2)  = tmp
# cell(16) = nth fibonacci element you want to calculate

cell(0) = 40
++++++++++++++++++++++++++++++++++++++++

while cell(0) minus minus loop
[

    Copy cell(1) to cell(2); then increment cell(1)
    >
    [->+>+<<]>>[<<+>>-]<<
    +
    <

    Transfer cell(2) to cell(16)
    >>
    [->>>>>>>>>>>>>>+<<<<<<<<<<<<<<]
    <<

    Go to cell(16)
    >>>>>>>>>>>>>>>>

    From https://gist dot github dot com/wxsBSD/31e2e9cf8b41d624403c91e6d7e6da3f
    Fibonacci nth element calculator;
    cell(16) = fib(cell(16))
    >+>+<<[->>[->+>+<<]<[->>+<<]>>[-<+>]>[-<<<+>>>]<<<<]>><[-]>>[-]>[-]<<[-<<+>>]<<

    From https://esolangs dot org/wiki/brainfuck_algorithms
    Print string (plus newline) from int;
    print_and_clear(cell(16))
    >[-]>[-]+>[-]+<[>[-<-<<[->+>+<<]>[-<+>]>>]++++++++++>[-]+>[-]>[-]>[-]<<<<<[->-[>+>>]
    >[[-<+>]+>+>>]<<<<<]>>-[-<<+>>]<[-]++++++++[-<++++++>]>>[-<<+>>]<<]<[.[-]<]
    ++++++++++.----------<[-]

    Go back to cell(0)
    <<<<<<<<<<<<<<<<

-]
