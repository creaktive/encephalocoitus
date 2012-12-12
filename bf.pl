#!/usr/bin/env perl
use strict;
use utf8;
use warnings qw(all);

use constant WORD_SIZE => 8;
use constant DATA_SIZE => 65536;

sub brainfuck ($) {
    my ($program) = @_;
    local ($|, $/) = (1, \1);

    my @data = (0) x DATA_SIZE;
    my (%start, %end);
    my ($ip, $si) = (0, 0);

    my $op = {
        q(>) => sub { $si = ($si + 1) % @data },
        q(<) => sub { $si = ($si - 1) % @data },
        q(+) => sub { $data[$si] = ($data[$si] + 1) % (1 << WORD_SIZE) },
        q(-) => sub { $data[$si] = ($data[$si] - 1) % (1 << WORD_SIZE) },
        q(.) => sub { print STDOUT chr $data[$si] },
        q(,) => sub { $data[$si] = ord <STDIN> },
        q([) => sub { $ip = $data[$si] ? $ip : $end{$ip} },
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
