#!perl -w
use strict;
use warnings;
use Test::More tests => 1;
use Test::Compile qw( pl_file_ok );

Test::Compile::_verbose(0);
pl_file_ok('t/scripts/taint.pl', 'taint.pl compiles');

