
use strict;
use Test;
plan tests => 4;

use Module::Build::PodParser;
ok(1);

{
  package IO::StringBased;
  
  sub TIEHANDLE {
    my ($class, $string) = @_;
    return bless {
		  data => [ map "$_\n", split /\n/, $string],
		 }, $class;
  }
  
  sub READLINE {
    shift @{ shift()->{data} };
  }
}

local *FH;
tie *FH, 'IO::StringBased', <<'EOF';
=head1 NAME

Foo::Bar - Perl extension for blah blah blah

=head1 AUTHOR

C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF


my $pp = Module::Build::PodParser->new(fh => *FH);
ok $pp;

ok $pp->get_author->[0], 'C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.';
ok $pp->get_abstract, 'Perl extension for blah blah blah';
