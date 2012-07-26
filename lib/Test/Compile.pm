package Test::Compile;

use 5.006;
use warnings;
use strict;

use Test::Builder;
use UNIVERSAL::require;
use Test::Compile::Internal;

our $VERSION = '0.19';
my $Test = Test::Builder->new;
my $internal = Test::Compile::Internal->new();

sub import {
    my $self   = shift;
    my $caller = caller;
    for my $func (
        qw(
        pm_file_ok pl_file_ok all_pm_files all_pl_files all_pm_files_ok
        all_pl_files_ok
        )
      ) {
        no strict 'refs';
        *{ $caller . "::" . $func } = \&$func;
    }
    $Test->exported_to($caller);
    $Test->plan(@_);
}

sub pm_file_ok {
    my ($file,$name,$verbose) = @_;

    $name ||= "Compile test for $file";

    my $old = $internal->verbose();
    $internal->verbose($verbose);
    my $ok = $internal->pm_file_compiles($file);
    $internal->verbose($old);

    $Test->ok($ok, $name);
    $Test->diag("$file does not compile") unless $ok;
    return $ok;
}

sub pl_file_ok {
    my ($file,$name,$verbose) = @_;

    $name ||= "Compile test for $file";

    # don't "use Devel::CheckOS" because Test::Compile is included by
    # Module::Install::StandardTests, and we don't want to have to ship
    # Devel::CheckOS with M::I::T as well.
    if (Devel::CheckOS->require) {

        # Exclude VMS because $^X doesn't work. In general perl is a symlink to
        # perlx.y.z but VMS stores symlinks differently...
        unless (Devel::CheckOS::os_is('OSFeatures::POSIXShellRedirection')
            and Devel::CheckOS::os_isnt('VMS')) {
            $Test->skip('Test not compatible with your OS');
            return;
        }
    }

    my $old = $internal->verbose();
    $internal->verbose($verbose);
    my $ok = $internal->pl_file_compiles($file);
    $internal->verbose($old);

    $Test->ok($ok, $name);
    $Test->diag("$file does not compile") unless $ok;
    return $ok;
}

sub all_pm_files_ok {
    my @files = @_ ? @_ : all_pm_files();
    $Test->plan(tests => scalar @files);
    my $ok = 1;
    for (@files) {
        pm_file_ok($_) or undef $ok;
    }
    $ok;
}

sub all_pl_files_ok {
    my @files = @_ ? @_ : all_pl_files();
    $Test->skip_all("no pl files found") unless @files;
    $Test->plan(tests => scalar @files);
    my $ok = 1;
    for (@files) {
        pl_file_ok($_) or undef $ok;
    }
    $ok;
}

sub all_pm_files {
    return $internal->all_pm_files(@_);
}

sub all_pl_files {
    return $internal->all_pl_files(@_);
}

1;
__END__

=head1 NAME

Test::Compile - Check whether Perl module files compile correctly

=head1 SYNOPSIS

    #!perl -w
    use strict;
    use warnings;
    use Test::Compile;
    all_pm_files_ok();

=head1 DESCRIPTION

C<Test::Compile> lets you check the whether a Perl module or script file
compiles properly, and report its results in standard C<Test::Simple> fashion.

    BEGIN {
        use Test::Compile tests => $num_tests;
        pm_file_ok($file, "Valid Perl module file");
    }

It's probably a good idea to run this in a BEGIN block. The examples below
omit it for clarity.

Module authors can include the following in a F<t/00_compile.t> file and
have C<Test::Compile> automatically find and check all Perl module files in a
module distribution:

    use Test::More;
    eval "use Test::Compile 0.09";
    Test::More->builder->BAIL_OUT(
        "Test::Compile 0.09 required for testing compilation") if $@;
    all_pm_files_ok();

You can also specify a list of files to check, using the
C<all_pm_files()> function supplied:

    use strict;
    use Test::More;
    eval "use Test::Compile 0.09";
    Test::More->builder->BAIL_OUT(
        "Test::Compile 0.09 required for testing compilation") if $@;
    my @pmdirs = qw(blib script);
    all_pm_files_ok(all_pm_files(@pmdirs));

Or even (if you're running under L<Apache::Test>):

    use strict;
    use Test::More;
    eval "use Test::Compile 0.09";
    Test::More->builder->BAIL_OUT(
        "Test::Compile 0.09 required for testing compilation") if $@;

    my @pmdirs = qw(blib script);
    use File::Spec::Functions qw(catdir updir);
    all_pm_files_ok(
        all_pm_files(map { catdir updir, $_ } @pmdirs)
    );

Why do the examples use C<BAIL_OUT()> instead of C<skip_all()>? Because
testing whether a module compiles is important. C<skip_all()> is ok to use
with L<Test::Pod>, because if the pod is malformed the program is still going
to run. But checking whether a module even compiles is something else.
Test::Compile should be mandatory, not optional.

=head1 FUNCTIONS

=over 4

=item C<pm_file_ok(FILENAME[, TESTNAME ])>

C<pm_file_ok()> will okay the test if the Perl module compiles correctly.

The optional second argument C<TESTNAME> is the name of the test. If it is
omitted, C<pm_file_ok()> chooses a default test name C<Compile test for
FILENAME>.

=item C<pl_file_ok(FILENAME[, TESTNAME ])>

C<pl_file_ok()> will okay the test if the Perl script compiles correctly. You
need to give the path to the script relative to this distribution's base
directory. So if you put your scripts in a 'top-level' directory called script
the argument would be C<script/filename>.

The optional second argument C<TESTNAME> is the name of the test. If it is
omitted, C<pl_file_ok()> chooses a default test name C<Compile test for
FILENAME>.

=item C<all_pm_files_ok([@files/@directories])>

Checks all the files in C<@files> for compilation. It runs L<all_pm_files()>
on each file/directory, and calls the C<plan()> function for you (one test for
each function), so you can't have already called C<plan>.

If C<@files> is empty or not passed, the function finds all Perl module files
in the F<blib> directory if it exists, or the F<lib> directory if not. A Perl
module file is one that ends with F<.pm>.

If you're testing a module, just make a F<t/00_compile.t>:

    use Test::More;
    eval "use Test::Compile 0.09";
    plan skip_all => "Test::Compile 0.09 required for testing compilation"
      if $@;
    all_pm_files_ok();

Returns true if all Perl module files are ok, or false if any fail.

Or you could just let L<Module::Install::StandardTests> do all the work for
you.

=item C<all_pl_files_ok([@files])>

Checks all the files in C<@files> for compilation. It runs L<pl_file_ok()>
on each file, and calls the C<plan()> function for you (one test for
each file), so you can't have already called C<plan>.

If C<@files> is empty or not passed, the function uses all_pl_files() to find
scripts to test

If you're testing a module, just make a F<t/00_compile_scripts.t>:

    use Test::More;
    eval "use Test::Compile 0.09";
    plan skip_all => "Test::Compile 0.09 required for testing compilation"
      if $@;
    all_pl_files_ok();

Returns true if all Perl module files are ok, or false if any fail.

=item C<all_pm_files([@dirs])>

Returns a list of all the perl module files - that is, files ending in F<.pm>
- in I<$dir> and in directories below. If no directories are passed, it
defaults to F<blib> if F<blib> exists, or else F<lib> if not. Skips any files
in C<CVS> or C<.svn> directories.

The order of the files returned is machine-dependent. If you want them
sorted, you'll have to sort them yourself.

=item C<all_pl_files([@files/@dirs])>

Returns a list of all the perl script files - that is, files ending in F<.pl>
or with no extension. Directory arguments are searched recursively . If
arguments are passed, it defaults to F<script> if F<script> exists, or else
F<bin> if F<bin> exists. Skips any files in C<CVS> or C<.svn> directories.

The order of the files returned is machine-dependent. If you want them
sorted, you'll have to sort them yourself.

=back

=head1 AUTHORS

Sagar R. Shah C<< <srshah@cpan.org> >>,
Marcel GrE<uuml>nauer, C<< <marcel@cpan.org> >>,
Evan Giles, C<< <egiles@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2012 by the authors.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::LoadAllModules> just handles modules, not script files, but has more
fine-grained control.

=cut
