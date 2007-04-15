#!/usr/bin/perl -w

use strict;
use lib $ENV{PERL_CORE} ? '../lib/Module/Build/t/lib' : 't/lib';
use MBTest 'no_plan';#tests => 0;

use Cwd ();
my $cwd = Cwd::cwd();
my $tmp = File::Spec->catdir($cwd, 't', '_tmp');

use DistGen;

my $dist = DistGen->new(dir => $tmp);


$dist->regen;


chdir( $dist->dirname ) or die "Can't chdir to '@{[$dist->dirname]}': $!";

use_ok 'Module::Build';

########################################################################
{ # check the =item style
my $mb = Module::Build->subclass(
  code => join "\n", map {s/^ {4}//; $_} split /\n/, <<'  ---',
    =head1 ACTIONS

    =over

    =item foo

    Does the foo thing.

    =item bar

    Does the bar thing.

    =item help

    Does the help thing.

    You should probably not be seeing this.  That is, we haven't
    overridden the help action, but we're able to override just the
    docs?  That seems reasonable, but might be wrong.

    =back

    =cut

    sub ACTION_foo { die "fooey" }
    sub ACTION_bar { die "barey" }
    sub ACTION_baz { die "bazey" }

    # guess we can have extra pod later 

    =over

    =item baz

    Does the baz thing.

    =back

    =cut

  ---
  )->new(
      module_name => $dist->name,
  );

ok $mb;
can_ok($mb, 'ACTION_foo');

foreach my $action (qw(foo bar baz)) { # typical usage
  my $doc = $mb->get_action_docs($action);
  ok($doc, "got doc for '$action'");
  like($doc, qr/^=\w+ $action\n\nDoes the $action thing\./s,
    'got the right doc');
}

{ # user typo'd the action name
  ok( ! eval {$mb->get_action_docs('batz'); 1}, 'slap');
  like($@, qr/No known action 'batz'/, 'informative error');
}

{ # XXX this one needs some thought
  my $action = 'help';
  my $doc = $mb->get_action_docs($action);
  ok($doc, "got doc for '$action'");
  0 and warn "help doc >\n$doc<\n";
  TODO: {
    local $TODO = 'Do we allow overrides on just docs?';
    unlike($doc, qr/^=\w+ $action\n\nDoes the $action thing\./s,
      'got the right doc');
  }
}
} # end =item style
$dist->clean();
########################################################################
if(0) { # the =item style without spanning =head1 sections
my $mb = Module::Build->subclass(
  code => join "\n", map {s/^ {4}//; $_} split /\n/, <<'  ---',
    =head1 ACTIONS

    =over

    =item foo

    Does the foo thing.

    =item bar

    Does the bar thing.

    =back

    =head1 thbbt

    =over

    =item baz

    Should not see this.

    =back

    =cut

    sub ACTION_foo { die "fooey" }
    sub ACTION_bar { die "barey" }
    sub ACTION_baz { die "bazey" }

  ---
  )->new(
      module_name => $dist->name,
  );

ok $mb;
can_ok($mb, 'ACTION_foo');

foreach my $action (qw(foo bar)) { # typical usage
  my $doc = $mb->get_action_docs($action);
  ok($doc, "got doc for '$action'");
  like($doc, qr/^=\w+ $action\n\nDoes the $action thing\./s,
    'got the right doc');
}
is($mb->get_action_docs('baz'), undef, 'no jumping =head1 sections');

} # end =item style without spanning =head1's
$dist->clean();
########################################################################
TODO: { # the =item style with 'Actions' not 'ACTIONS'
local $TODO = 'Support capitalized Actions section';
my $mb = Module::Build->subclass(
  code => join "\n", map {s/^ {4}//; $_} split /\n/, <<'  ---',
    =head1 Actions

    =over

    =item foo

    Does the foo thing.

    =item bar

    Does the bar thing.

    =back

    =cut

    sub ACTION_foo { die "fooey" }
    sub ACTION_bar { die "barey" }

  ---
  )->new(
      module_name => $dist->name,
  );

foreach my $action (qw(foo bar)) { # typical usage
  my $doc = $mb->get_action_docs($action);
  ok($doc, "got doc for '$action'");
  like($doc || 'undef', qr/^=\w+ $action\n\nDoes the $action thing\./s,
    'got the right doc');
}

} # end =item style with Actions
$dist->clean();
########################################################################
TODO: { # check the =head2 style
local $TODO = 'Support =head[234] sections';
my $mb = Module::Build->subclass(
  code => join "\n", map {s/^ {4}//; $_} split /\n/, <<'  ---',
    =head1 ACTIONS

    =head2 foo

    Does the foo thing.

    =head2 bar

    Does the bar thing.

    =cut

    sub ACTION_foo { die "fooey" }
    sub ACTION_bar { die "barey" }
    sub ACTION_baz { die "bazey" }
    sub ACTION_batz { die "batzey" }

    # guess we can have extra pod later 

    =head2 baz

    Does the baz thing.

    =head1 Thing

    =head2 batz

    This is not an action doc.

    =cut

  ---
  )->new(
      module_name => $dist->name,
  );

foreach my $action (qw(foo bar baz)) { # typical usage
  my $doc = $mb->get_action_docs($action);
  ok($doc, "got doc for '$action'");
  like($doc || 'undef', qr/^=\w+ $action\n\nDoes the $action thing\./s,
    'got the right doc');
}

} # end =head2 style
$dist->clean();
########################################################################

# cleanup
chdir( $cwd );
use File::Path;
rmtree( $tmp );

# vim:ts=2:sw=2:et:sta
