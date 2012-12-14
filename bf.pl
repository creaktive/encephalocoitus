#!/usr/bin/env perl
use 5.010;
use strict;
use utf8;
use warnings qw(all);

use B::Deparse;
use Benchmark qw(:hireswallclock);
use Carp qw(confess croak);
use Data::Dumper;
use PadWalker;

my ($hint_bits, $warning_bits, $hinthash);

sub brainfuck2perl {
    my ($code) = @_;

    use bytes;
    use integer;

    my @buffer = (
        q(#!/usr/bin/perl),
        q(use strict;),
        q(use warnings;),
        q(),
        q(local ($|, $/) = (1, \1);),
        q(my ($data, $si) = ('', 0);),
        q(),
    );

    BEGIN { ($hint_bits, $warning_bits, $hinthash) = ($^H, ${^WARNING_BITS}, \%^H) }
    my $deparse = B::Deparse->new(q(-si0));
    $deparse->ambient_pragmas(
        hint_bits   => $hint_bits,
        warning_bits=> $warning_bits,
        q($[)       => 0 + $[,
        q(%^H)      => $hinthash,
    );

    my $translate;
    $translate = sub {
        my ($indent, $ops) = @_;
        for my $code (@{$ops}) {
            my ($perl) = ($deparse->coderef2text($code) =~ m{^\{\s+(.+)\s+\}$}sx);
            my $vars = PadWalker::closed_over($code);
            $perl =~ s{\Q$_\E}{${$vars->{$_}}}gsx
                for qw($WORD_SIZE $n);

            if (q(ARRAY) eq ref $vars->{q{@sub}}) {
                my @perl = split m{\n\r?}x, $perl;
                push @buffer => (qq(\t) x $indent) . $perl[0];
                $translate->($indent + 1, $vars->{q{@sub}});
                push @buffer => (qq(\t) x $indent) . $perl[-1];
            } else {
                push @buffer => (qq(\t) x $indent) . $perl;
            }
        }
    };
    $translate->(0, $code);

    return @buffer;
}

sub brainfuck {
    my ($program, $WORD_SIZE) = @_;
    $WORD_SIZE //= 8;

    use bytes;
    use integer;

    my $to_perl = wantarray;

    local ($|, $/) = (1, \1);
    my ($data, $si, $int, $c) = ('', 0, 0, 0);

    my ($start, %stats) = (Benchmark->new);
    my $update_stats = sub {
        @stats{qw{
            vm_ticks
            vm_mem
            vm_time
        }} = (
            $c,
            length $data,
            timediff(Benchmark->new, $start)->timestr
        );

        return \%stats;
    };
    local $SIG{INT} = sub {
        state $issued = 0;

        if (time - $issued > 1) {
            say STDERR Dumper $update_stats->();
            $issued = time;
        } else {
            ++$int;
        }
    };

    my (@code, @loop);
    $program =~ s{[^><+\-\.,\[\]]+}{}gsx;
    while ($program =~ m{(([><+\-])(?:\2)*|.)}gsx) {
        my $n = length $1;

        given ($2 // $1) {
            when (q(>)) {
                push @code
                    => $n == 1
                        ? sub { ++$si }
                        : sub { $si += $n }
            } when (q(<)) {
                push @code
                    => $n == 1
                        ? sub { --$si }
                        : sub { $si -= $n }
            } when (q(+)) {
                push @code
                    => $n == 1
                        ? sub { ++vec $data, $si, $WORD_SIZE }
                        : sub { vec($data, $si, $WORD_SIZE) += $n }
            } when (q(-)) {
                push @code
                    => $n == 1
                        ? sub { --vec $data, $si, $WORD_SIZE }
                        : sub { vec($data, $si, $WORD_SIZE) -= $n }
            } when (q(.)) {
                push @code
                    => sub { print chr vec $data, $si, $WORD_SIZE }
            } when (q(,)) {
                push @code
                    => $to_perl
                        ? sub { vec($data, $si, $WORD_SIZE) = ord getc }
                        : sub {
                            my $chr = getc;
                            if (defined $chr) {
                                vec($data, $si, $WORD_SIZE) = ord $chr;
                            } else {
                                ++$int;
                            }
                        }
            } when (q([)) {
                push @loop => $#code
            } when (q(])) {
                confess q(unmatched ']') unless @loop;
                my @sub = splice @code, 1 + pop @loop;
                push @code
                    => sub {
                        while (vec $data, $si, $WORD_SIZE) {
                            for (@sub) {
                                ++$c; $_->();
                                return if $int;
                            }
                        }
                    };
                ++$stats{nested_level};
            }
        }

        $stats{bf_count} += $n;
        $stats{vm_count} ++;
    }
    confess q(unmatched '[') if @loop;

    if ($to_perl) {
        return brainfuck2perl(\@code);
    } else {
        for (@code) {
            ++$c; $_->();
            last if $int;
        }

        return $update_stats->();
    }
}

my $program;

open(my $fh, q(<:raw), $ARGV[0])
    or croak qq(Can't open: $!);
{ local $/ = undef; $program = <$fh> }
close $fh;

#say for brainfuck($program);
brainfuck($program);
