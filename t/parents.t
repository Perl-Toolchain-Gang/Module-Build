#!/usr/bin/perl -w

use lib 't/lib';
use strict;

use Test::More tests => 27;

use File::Spec ();
my $common_pl = File::Spec->catfile( 't', 'common.pl' );
require $common_pl;


#########################

use Module::Build;
ok(1);

package Foo;
sub foo;

package MySub1;
use base 'Module::Build';

package MySub2;
use base 'MySub1';

package MySub3;
use base qw(MySub2 Foo);

package MyTest;
use base 'Module::Build';

package MyBulk;
use base qw(MySub2 MyTest);

package main;

ok my @parents = MySub1->mb_parents;
# There will be at least one platform class in between.
ok @parents >= 2;
# They should all inherit from Module::Build::Base;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
is $parents[0], 'Module::Build';
is $parents[-1], 'Module::Build::Base';

ok @parents = MySub2->mb_parents;
ok @parents >= 3;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
is $parents[0], 'MySub1';
is $parents[1], 'Module::Build';
is $parents[-1], 'Module::Build::Base';

ok @parents = MySub3->mb_parents;
ok @parents >= 4;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
is $parents[0], 'MySub2';
is $parents[1], 'MySub1';
is $parents[2], 'Module::Build';
is $parents[-1], 'Module::Build::Base';

ok @parents = MyBulk->mb_parents;
ok @parents >= 5;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
is $parents[0], 'MySub2';
is $parents[1], 'MySub1';
is $parents[2], 'Module::Build';
is $parents[-2], 'Module::Build::Base';
is $parents[-1], 'MyTest';
