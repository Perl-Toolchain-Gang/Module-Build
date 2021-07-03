#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest tests => 16;

use Encode 'encode';

blib_load('Module::Build::PodParser');

#########################

{
open my $fh, '<', \<<'EOF';
=head1 NAME

Foo::Bar - Perl extension for blah blah blah

=head1 AUTHOR

C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF


my $pp = Module::Build::PodParser->new(fh => $fh);
ok $pp, 'object created';

is $pp->get_author->[0], 'C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.', 'author';
is $pp->get_abstract, 'Perl extension for blah blah blah', 'abstract';
}

{
  # Try again without a valid author spec
open my $fh, '<', \<<'EOF';
=head1 NAME

Foo::Bar - Perl extension for blah blah blah

=cut
EOF

  my $pp = Module::Build::PodParser->new(fh => $fh);
  ok $pp, 'object created';

  is_deeply $pp->get_author, [], 'author';
  is $pp->get_abstract, 'Perl extension for blah blah blah', 'abstract';
}


{
    # Try again with mixed-case =head1s.
open my $fh, '<', \<<'EOF';
=head1 Name

Foo::Bar - Perl extension for blah blah blah

=head1 Author

C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF

  my $pp = Module::Build::PodParser->new(fh => $fh);
  ok $pp, 'object created';

  is $pp->get_author->[0], 'C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.', 'author';
  is $pp->get_abstract, 'Perl extension for blah blah blah', 'abstract';
}


{
    # Now with C<Module::Name>
open my $fh, '<', \<<'EOF';
=head1 Name

C<Foo::Bar> - Perl extension for blah blah blah

=head1 Author

C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF

  my $pp = Module::Build::PodParser->new(fh => $fh);
  ok $pp, 'object created';

  is $pp->get_author->[0], 'C<Foo::Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.', 'author';
  is $pp->get_abstract, 'Perl extension for blah blah blah', 'abstract';
}

{
open my $fh, '<', \<<'EOF';
=head1 NAME

Foo_Bar - Perl extension for eating pie

=head1 AUTHOR

C<Foo_Bar> was written by Engelbert Humperdinck I<E<lt>eh@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF


  my $pp = Module::Build::PodParser->new(fh => $fh);
  ok $pp, 'object created';
  is $pp->get_abstract, 'Perl extension for eating pie', 'abstract';
}

{
  open my $fh, '<', \ encode 'UTF-8', <<"EOF";
=encoding utf8

=head1 NAME

Foo_Bar - I \x{2764} Perl

=head1 AUTHOR

C<Foo_Bar> was written by Engelbert Humperdinck I<E<lt>eh\@example.comE<gt>> in 2004.

Home page: http://example.com/~eh/

=cut
EOF

  my $pp = Module::Build::PodParser->new(fh => $fh);
  ok $pp, 'object created';
  is $pp->get_abstract, "I \x{2764} Perl", 'abstract with unicode';
}
