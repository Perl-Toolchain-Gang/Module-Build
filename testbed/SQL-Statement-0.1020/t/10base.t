#!/usr/local/bin/perl

print "1..2\n";

$@ = '';
eval { require SQL::Statement; };
print (($@ ? "not " : ""), "ok 1\n");

$@ = '';
eval { require SQL::Eval; };
print (($@ ? "not " : ""), "ok 2\n");
