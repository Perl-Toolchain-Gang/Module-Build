
use strict;
use Test;
use File::Spec;

my $common_pl = File::Spec->catfile('t', 'common.pl');
require $common_pl;

my @unix_splits = 
  (
   { q{one t'wo th'ree f"o\"ur " "five" } => [ 'one', 'two three', 'fo"ur ', 'five' ] },
   { q{ foo bar }                         => [ 'foo', 'bar'                         ] },
  );

my @win_splits = 
  (
   { 'a" "b\\c" "d'         => [ 'a b\c d'       ] },
   { '"a b\\c d"'           => [ 'a b\c d'       ] },
   { '"a b"\\"c d"'         => [ 'a b"c', 'd'    ] },
   { '"a b"\\\\"c d"'       => [ 'a b\c d'       ] },
   { '"a"\\"b" "a\\"b"'     => [ 'a"b a"b'       ] },
   { '"a"\\\\"b" "a\\\\"b"' => [ 'a\b', 'a\b'    ] },
   { '"a"\\"b a\\"b"'       => [ 'a"b', 'a"b'    ] },
   { 'a"\\"b" "a\\"b'       => [ 'a"b', 'a"b'    ] },
   { 'a"\\"b"  "a\\"b'      => [ 'a"b', 'a"b'    ] },
   { 'a           b'        => [ 'a', 'b'        ] },
   { 'a"\\"b a\\"b'         => [ 'a"b a"b'       ] },
   { '"a""b" "a"b"'         => [ 'a"b ab'        ] },
   { '\\"a\\"'              => [ '"a"'           ] },
   { '"a"" "b"'             => [ 'a"', 'b'       ] },
   { 'a"b'                  => [ 'ab'            ] },
   { 'a""b'                 => [ 'ab'            ] },
   { 'a"""b'                => [ 'a"b'           ] },
   { 'a""""b'               => [ 'a"b'           ] },
   { 'a"""""b'              => [ 'a"b'           ] },
   { 'a""""""b'             => [ 'a""b'          ] },
   { '"a"b"'                => [ 'ab'            ] },
   { '"a""b"'               => [ 'a"b'           ] },
   { '"a"""b"'              => [ 'a"b'           ] },
   { '"a""""b"'             => [ 'a"b'           ] },
   { '"a"""""b"'            => [ 'a""b'          ] },
   { '"a""""""b"'           => [ 'a""b'          ] },
   { ''                     => [                 ] },
   { ' '                    => [                 ] },
   { '""'                   => [ ''              ] },
   { '" "'                  => [ ' '             ] },
   { '""a'                  => [ 'a'             ] },
   { '""a b'                => [ 'a', 'b'        ] },
   { 'a""'                  => [ 'a'             ] },
   { 'a"" b'                => [ 'a', 'b'        ] },
   { '"" a'                 => [ '', 'a'         ] },
   { 'a ""'                 => [ 'a', ''         ] },
   { 'a "" b'               => [ 'a', '', 'b'    ] },
   { 'a " " b'              => [ 'a', ' ', 'b'   ] },
   { 'a " b " c'            => [ 'a', ' b ', 'c' ] },
);

plan tests => 14 + 2*@unix_splits + 2*@win_splits;

use Module::Build;
ok(1);

# Should always return an array unscathed
foreach my $platform ('', '::Platform::Unix', '::Platform::Windows') {
  my $pkg = "Module::Build$platform";
  my @result = $pkg->split_like_shell(['foo', 'bar', 'baz']);
  ok @result, 3, "Split using $pkg";
  ok "@result", "foo bar baz", "Split using $pkg";
}

use Module::Build::Platform::Unix;
foreach my $test (@unix_splits) {
  do_split_tests('Module::Build::Platform::Unix', $test);
}

use Module::Build::Platform::Windows;
foreach my $test (@win_splits) {
  do_split_tests('Module::Build::Platform::Windows', $test);
}


{
  # Make sure read_args() functions properly as a class method
  my @args = qw(foo=bar --food bard --foods=bards);
  my ($args) = Module::Build->read_args(@args);

  ok keys(%$args), 4;
  ok $args->{foo}, 'bar';
  ok $args->{food}, 'bard';
  ok $args->{foods}, 'bards';
  ok exists $args->{ARGV}, 1;
  ok @{$args->{ARGV}}, 0;
}

{
  # Make sure run_perl_script() propagates @INC
  local @INC = ('whosiewhatzit', @INC);
  my $output = stdout_of( sub { Module::Build->run_perl_script('', ['-le', 'print for @INC']) } );
  ok $output, qr{^whosiewhatzit}m;
}

##################################################################
sub do_split_tests {
  my ($package, $test) = @_;

  my ($string, $expected) = %$test;
  my @result = $package->split_like_shell($string);
  ok( 0 + grep( !defined(), @result ), # all defined
      0,
      "'$string' result all defined" );
  ok( join(' ', map "{$_}", @result),
      join(' ', map "{$_}", @$expected),
      join(' ', map "{$_}", @$expected) );
}
