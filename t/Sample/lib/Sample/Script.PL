#!/usr/bin/perl

my $filename = shift;
open FH, "> $filename" or die "Can't create $filename: $!";
print FH "Contents: $filename\n";
close FH;
