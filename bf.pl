#!/usr/bin/env perl
use 5.010;
use strict;
use utf8;
use warnings qw(all);

use Carp qw(confess);

sub brainfuck ($;$) {
    my ($program, $WORD_SIZE) = (@_, 8);

    use bytes;
    use integer;

    local ($|, $/) = (1, \1);

    my ($data, $si) = ('', 0);

    my @code;
    my @loop;
    while ($program =~ /(([\Q><+-.,\E])(?:\2)*|.)/gsx) {
        my $instr = substr $1, 0, 1;
        my $n = length $1;

        given ($instr) {
            when (q(>)) { push @code => $n == 1 ? sub { ++$si } : sub { $si += $n } }
            when (q(<)) { push @code => $n == 1 ? sub { --$si } : sub { $si -= $n } }
            when (q(+)) { push @code => $n == 1 ? sub { ++vec $data, $si, $WORD_SIZE } : sub { vec($data, $si, $WORD_SIZE) += $n } }
            when (q(-)) { push @code => $n == 1 ? sub { --vec $data, $si, $WORD_SIZE } : sub { vec($data, $si, $WORD_SIZE) -= $n } }
            when (q(.)) { push @code => sub { print join '' => map { chr vec $data, $si, $WORD_SIZE } 1 .. $n } }
            when (q(,)) { push @code => sub { vec($data, $si, $WORD_SIZE) = ord getc for 1 .. $n } }
            when (q([)) { push @loop => $#code }
            when (q(])) {
                confess q(unmatched ']') unless @loop;
                my @sub = splice @code, 1 + pop @loop;
                push @code => sub {
                    while (vec $data, $si, $WORD_SIZE) {
                        $_->() for @sub;
                    }
                };
            }
        }
    }
    confess q(unmatched '[') if @loop;

    $_->() for @code;

    return 1;
}

use Benchmark;

timethis 100 => sub {
    # Hello World!
    brainfuck
        q(++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.);

    # 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89
    brainfuck << 'FIBONACCI';
        +++++++++++
        >+>>>>++++++++++++++++++++++++++++++++++++++++++++
        >++++++++++++++++++++++++++++++++<<<<<<[>[>>>>>>+>
        +<<<<<<<-]>>>>>>>[<<<<<<<+>>>>>>>-]<[>++++++++++[-
        <-[>>+>+<<<-]>>>[<<<+>>>-]+<[>[-]<[-]]>[<<[>>>+<<<
        -]>>[-]]<<]>>>[>>+>+<<<-]>>>[<<<+>>>-]+<[>[-]<[-]]
        >[<<+>>[-]]<<<<<<<]>>>>>[+++++++++++++++++++++++++
        +++++++++++++++++++++++.[-]]++++++++++<[->-<]>++++
        ++++++++++++++++++++++++++++++++++++++++++++.[-]<<
        <<<<<<<<<<[>>>+>+<<<<-]>>>>[<<<<+>>>>-]<-[>>.>.<<<
        [-]]<<[>>+>+<<<-]>>>[<<<+>>>-]<<[<+>-]>[<+>-]<<<-]
FIBONACCI
    print "\n";
};

brainfuck << 'ROT13';
-,+[                        Read first character and start outer character reading loop
    -[                      Skip forward if character is 0
        >>++++[>++++++++<-] Set up divisor (32) for division loop
                                (MEMORY LAYOUT: dividend copy remainder divisor quotient zero zero)
        <+<-[               Set up dividend (x minus 1) and enter division loop
            >+>+>-[>>>]     Increase copy and remainder / reduce divisor / Normal case: skip forward
            <[[>+<-]>>+>]   Special case: move remainder back to divisor and increase quotient
            <<<<<-          Decrement dividend
        ]                   End division loop
    ]>>>[-]+                End skip loop; zero former divisor and reuse space for a flag
    >--[-[<->+++[-]]]<[         Zero that flag unless quotient was 2 or 3; zero quotient; check flag
        ++++++++++++<[      If flag then set up divisor (13) for second division loop
                                (MEMORY LAYOUT: zero copy dividend divisor remainder quotient zero zero)
            >-[>+>>]        Reduce divisor; Normal case: increase remainder
            >[+[<+>-]>+>>]  Special case: increase remainder / move it back to divisor / increase quotient
            <<<<<-          Decrease dividend
        ]                   End division loop
        >>[<+>-]            Add remainder back to divisor to get a useful 13
        >[                  Skip forward if quotient was 0
            -[              Decrement quotient and skip forward if quotient was 1
                -<<[-]>>    Zero quotient and divisor if quotient was 2
            ]<<[<<->>-]>>   Zero divisor and subtract 13 from copy if quotient was 1
        ]<<[<<+>>-]         Zero divisor and add 13 to copy if quotient was 0
    ]                       End outer skip loop (jump to here if ((character minus 1)/32) was not 2 or 3)
    <[-]                    Clear remainder from first division if second division was skipped
    <.[-]                   Output ROT13ed character from copy and clear it
    <-,+                    Read next character
]                           End character reading loop
ROT13
