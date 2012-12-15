#!/usr/bin/env perl
# ABSTRACT: Yet Another BrainFuck Compiler
# PODNAME: encephalocoitus
use 5.010;
use strict;
use utf8;
use warnings qw(all);

use B::Deparse;
use Benchmark qw(:hireswallclock);
use Carp qw(confess croak);
use Data::Dumper;
use Getopt::Long;
use PadWalker;
use Pod::Usage;

=head1 SYNOPSIS

    encephalocoitus.pl program.bf

=head1 DESCRIPTION

...

=head1 OPTIONS

=over 4

=item --help

This.

=back

=head1 SEE ALSO

...

=head1 AUTHOR

Stanislaw Pusep

=cut

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
                for qw($WORD_SIZE $n $o);

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

    return \@buffer;
}

sub brainfuck {
    my ($program, $WORD_SIZE) = @_;
    $WORD_SIZE //= 8;

    use bytes;
    use integer;

    my $to_perl = wantarray;

    local ($|, $/) = (1, \1);
    my ($data, $si, $int, $c) = ('', 0, 0, 0);

    my %stats;
    my $update_stats = sub {
        @stats{qw{
            vm_ticks
            vm_mem
        }} = (
            $c,
            length $data,
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
    while ($program =~ m{(
        \[-\] |
        ( [><+-] ) (?:\2)* |
        ( \[ ( < (?:\++|(?-1)) > ) \- \] ) |
        ( \[ \- ( > (?:\++|(?-1)) < ) \] ) |
        .
    )}gsx) {
        my $n = length $1;
        ++$stats{vm_optimizations}{shrink}
            if $n > 1;

        given ($2 // $1) {
            when (q([-])) {
                ++$stats{vm_optimizations}->{clear};
                push @code
                    => sub { vec($data, $si, $WORD_SIZE) = 0 }
            } when (m{\[(<+)(\++)>+\-\]}x) {
                ++$stats{vm_optimizations}->{move_left};
                $n = length $1;
                my $o = length $2;
                push @code
                    => sub {
                        (
                            vec($data, $si - $n, $WORD_SIZE),
                            vec($data, $si, $WORD_SIZE)
                        ) = (
                            vec($data, $si - $n, $WORD_SIZE)
                                + vec($data, $si, $WORD_SIZE) * $o,
                            0
                        )
                    }
            } when (m{\[\-(>+)(\++)<+\]}x) {
                ++$stats{vm_optimizations}->{move_right};
                $n = length $1;
                my $o = length $2;
                push @code
                    => sub {
                        (
                            vec($data, $si + $n, $WORD_SIZE),
                            vec($data, $si, $WORD_SIZE)
                        ) = (
                            vec($data, $si + $n, $WORD_SIZE)
                                + vec($data, $si, $WORD_SIZE) * $o,
                            0
                        )
                    }
            } when (q(>)) {
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
        return @{brainfuck2perl(\@code)};
    } else {
        for (@code) {
            ++$c; $_->();
            last if $int;
        }

        return $update_stats->();
    }
}

GetOptions(
    q(eval)     => \my $eval,
    q(help)     => \my $help,
    q(perl)     => \my $perl,
    q(time)     => \my $time,
    q(debug)    => \my $debug,
) or pod2usage(-verbose => 1);
pod2usage(-verbose => 2) if $help or 1 != @ARGV;

my $program;

open(my $fh, q(<:raw), $ARGV[0])
    or croak qq(Can't open $ARGV[0]: $!);
{ local $/ = undef; $program = <$fh> }
close $fh;

my $start = Benchmark->new;

if ($perl) {
    say for brainfuck($program);
} elsif ($eval) {
    my $code = join qq(\n) => brainfuck($program);
    say STDERR qq(Compilation time:\n) . timediff(Benchmark->new, $start)->timestr
        if $time;

    $start = Benchmark->new;
    my $ret = eval $code; ## no critic (ProhibitStringyEval)
    croak qq(Couldn't execute: $@)
        if not defined $ret or $@;
} else {
    my $stats = brainfuck($program);
    say STDERR Dumper $stats
        if $debug;
}

say STDERR qq(\nExecution time:\n) . timediff(Benchmark->new, $start)->timestr
    if $time;
