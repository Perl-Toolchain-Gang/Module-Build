# -*- perl -*-

use strict;
require SQL::Statement::Hash;


$| = 1;
$^W = 1;


package main;

sub ArrEq {
    my($arr1, $arr2) = @_;
    if (@$arr1 != @$arr2) {
	printf("Mismatch in number of cols, %d vs. %d\n", @$arr1, @$arr2);
	return 0;
    }
    my($elem1, $elem2, $i);
    $i = 0;
    while (@$arr1) {
	$elem1 = shift @$arr1;
	$elem2 = shift @$arr2;
	if (!defined($elem1)) {
	    return !defined($elem2);
	}
	if (ref($elem1)) {
	    if (!ref($elem2)) {
		printf("Mismatch in type: ref vs. scalar\n");
		return 0;
	    }
	    if (!ArrEq($elem1, $elem2)) {
		printf("Mismatch in row $i detected.\n");
		return 0;
	    }
	} else {
	    if (ref($elem2)) {
		printf("Mismatch in type: scalar vs. ref\n");
		return 0;
	    }
	    if ($elem1 ne $elem2) {
		printf("Mismatch: $elem1 vs. $elem2\n");
		return 0;
	    }
	}
	++$i;
    }
    1;
}


my $testNum = 0;

sub Test($) {
    my $ok = shift;
    ++$testNum; print(($ok ? "" : "not "), "ok $testNum\n");
    $ok;
}


print "1..2\n";

# Verify the stringification methods.
print "Checking _array2str\n";
my $a = [undef,1,"a\000b\001c\002d\003e\004f"];
my $str_a = "\002\0011\001a\002\001b\002\002c\002\003d\002\004e\004f";
my $res;
Test(($res = SQL::Statement::Hash::_array2str($a)) eq $str_a)
    or printf("Expected %s, got %s\n",
	      unpack("H*", $str_a), unpack("H*", $res));
print "Checking _str2array\n";
$res = SQL::Statement::Hash::_str2array($str_a);
Test(ArrEq($res, $a))
    or printf("Expected %s, got %s\n",
	      "@$res", "@$a");
