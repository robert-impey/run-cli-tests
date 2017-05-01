# run-cli-tests
A simple test runner for CLI Programs.

A simple test runner for CLI Programs

The script searches for files ending in .txt or .err which have this format:

command

expected output
on several lines
if necessary

The tests pass if the output the standard output or error of the command matches the lines after the blank line.
