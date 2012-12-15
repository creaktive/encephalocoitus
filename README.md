# SYNOPSIS

encephalocoitus.pl \[options\] program.bf

# DESCRIPTION

Slightly optimized BrainFuck compiler, also capable of BF-to-Perl translation.
Initially translates BF to an array of `sub { ... }` statements, which can
be executed on-fly or deparsed via [B::Deparse](http://search.cpan.org/perldoc?B::Deparse)/[PadWalker](http://search.cpan.org/perldoc?PadWalker).

# OPTIONS

- \--help

    This.

- \--cell

    Memory cell size, in bits.
    (default: 8)

- \--debug

    Display compilation phase statistics.

- \--time

    Compute and display host CPU usage statistics.

- \--perl

    Output compiled Perl code to _STDOUT_.

- \--eval

    Executes compiled Perl code via ["eval" in perlfunc](http://search.cpan.org/perldoc?perlfunc#eval).

# REFERENCES

- [Acme::Brainfuck](http://search.cpan.org/perldoc?Acme::Brainfuck)
- [Language::BF](http://search.cpan.org/perldoc?Language::BF)
- [Brainfuck page at esoteric programming languages wiki](http://esolangs.org/wiki/Brainfuck)
- [Optimizing BF interpreter programed with JavaScript](http://www.iwriteiam.nl/Ha\_bf\_online.html)

# AUTHOR

Stanislaw Pusep <stas@sysd.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
