#!/usr/bin/env perl
use strict;
use utf8;
use warnings qw(all);

use constant WORD_SIZE => 8;
use constant DATA_SIZE => 65536;

sub brainfuck ($) {
    my ($program) = @_;

    local ($|, $/) = (1, \1);

    my $data = '';
    my (%start, %end);
    my ($ip, $si) = (0, 0);

    my $op = {
        q(>) => sub { ++$si },
        q(<) => sub { --$si },
        q(+) => sub { ++vec $data, $si, WORD_SIZE },
        q(-) => sub { --vec $data, $si, WORD_SIZE },
        q(.) => sub { print STDOUT chr vec $data, $si, WORD_SIZE },
        q(,) => sub { vec($data, $si, WORD_SIZE) = ord <STDIN> },
        q([) => sub { $ip = vec($data, $si, WORD_SIZE) ? $ip : $end{$ip} },
        q(]) => sub { $ip = $start{$ip} - 1 },
    };

    my @code = grep { exists $op->{$_} } split // => $program;

    my @stack;
    for my $i (0 .. $#code) {
        if ($code[$i] eq q([)) {
            push @stack => $i;
        } elsif ($code[$i] eq q(])) {
            $end{$start{$i} = pop @stack} = $i;
        }
    }

    while ($ip <= $#code) {
        $op->{$code[$ip]}->();
        $si %= DATA_SIZE;
    } continue {
        ++$ip;
    }
}

use Benchmark;

timethis 100 => sub {
    brainfuck q(++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.);

    brainfuck q(
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
    );

    print "\n";
};

__DATA__
timethis 100: 12 wallclock secs (12.14 usr +  0.03 sys = 12.17 CPU) @  8.22/s (n=100)
timethis 100: 15 wallclock secs (15.11 usr +  0.03 sys = 15.14 CPU) @  6.61/s (n=100)
