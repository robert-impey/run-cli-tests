#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Cwd;
use File::Find::Rule;
use Capture::Tiny qw/capture/;

{
    my $dir = '.';
    my $verbose = 0;
    my $test_data_dir = '.';

    GetOptions(
        'd|directory=s' => \$dir,
        'v|verbose' => \$verbose,
        't|test-data-directory=s' => \$test_data_dir
    );

    $dir =~ s{/$}{};
    $dir = Cwd::abs_path($dir);

    $test_data_dir =~ s{/$}{};
    $test_data_dir = Cwd::abs_path($test_data_dir);

    my $successes = 0;
    my $tests = 0;

    print "Searching $dir\n" if $verbose;

    foreach my $program_dir (File::Find::Rule->directory->in($dir)) {
        $program_dir =~ m{(?:\\|/)\.} && next;

        chdir $program_dir or die $!;

        if ($verbose) {
            print_separator('+');
            print "Program directory: $program_dir\n";
        }

        my $tests_dir = "tests";

        if (-d $tests_dir) {
            my @test_files = glob "$tests_dir/*.txt";

            foreach my $test_file (sort @test_files) {
                $tests++;

                my $success = run_test($test_file, $test_data_dir, $verbose, 'out');
                $successes += $success ? 1 : 0;
            }

            my @err_test_files = glob "$tests_dir/*.err";

            foreach my $test_file (sort @err_test_files) {
                $tests++;

                my $success = run_test($test_file, $test_data_dir, $verbose, 'err');
                $successes += $success ? 1 : 0;
            }
        }

        print_separator('+') if $verbose;
    }

    if ($tests == 0) {
        print "No tests found!\n";
    } else {
        printf("Success rate: %d/%d (%.1f%%)\n", $successes, $tests, ($successes/$tests)*100);
    }
}

# Subs

sub run_test
{
    my $test_file = shift;
    my $test_data_dir = shift;
    my $verbose = shift;
    my $test_type = shift;

    $test_file = Cwd::abs_path($test_file);

    &print_separator if $verbose;

    print "Test file: $test_file", $verbose ? "\n" : ' ';

    my $test_file_data_ref = read_test_file($test_file, $test_data_dir, $verbose);

    my $test_output = $$test_file_data_ref{test_output};
    chomp $test_output;

    if ($verbose) {
        print "Test output:\n";
        print_separator('.');
        print "$test_output\n";
        print_separator('.');
    }

    my $command = $$test_file_data_ref{command};
    chomp $command;

    my ($stdout, $stderr, $exit) = capture {
        system( $command, qw// );
    };

    my $command_output;
    if ($test_type eq 'out') {
        $command_output = $stdout;
    } elsif ($test_type eq 'err') {
        $command_output = $stderr;
    }
    chomp $command_output;

    if ($verbose) {
        print "Command output:\n";
        print_separator('.');
        print "$command_output\n" ;
        print_separator('.');
    }

    my $success = $command_output eq $test_output;
    if ($success) {
        print "OK\n";
    } else {
        print "FAIL\n";
    }

    &print_separator if $verbose;

    return $success;
}

sub read_test_file
{
    my $test_file = shift;
    my $test_data_dir = shift;
    my $verbose = shift;

    open(my $test_fh, $test_file);

    my $command = readline $test_fh;

    die "Empty command in $test_file!\n" unless $command;

    $command = "./$command" unless $^O eq 'MSWin32';
    $command =~ s/TEST_DATA_DIR/$test_data_dir/g;

    print "Command: $command\n" if $verbose;

    readline $test_fh;

    my $test_output = '';

    while (my $new_line = readline($test_fh)) {
        $test_output .= $new_line;
    }
    close $test_fh;

    return {
        command => $command,
        test_output => $test_output
    };
}

sub print_separator
{
    my $char = shift || '-';
    my $repetitions = shift || 40;

    print "\n", $char x $repetitions, "\n";
}
