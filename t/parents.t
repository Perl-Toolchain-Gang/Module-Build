use strict;
use Test;
BEGIN { plan tests => 27 }
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
ok $parents[0], 'Module::Build';
ok $parents[-1], 'Module::Build::Base';

ok @parents = MySub2->mb_parents;
ok @parents >= 3;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
ok $parents[0], 'MySub1';
ok $parents[1], 'Module::Build';
ok $parents[-1], 'Module::Build::Base';

ok @parents = MySub3->mb_parents;
ok @parents >= 4;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
ok $parents[0], 'MySub2';
ok $parents[1], 'MySub1';
ok $parents[2], 'Module::Build';
ok $parents[-1], 'Module::Build::Base';

ok @parents = MyBulk->mb_parents;
ok @parents >= 5;
ok ! grep { !$_->isa('Module::Build::Base') } @parents;
ok $parents[0], 'MySub2';
ok $parents[1], 'MySub1';
ok $parents[2], 'Module::Build';
ok $parents[-2], 'Module::Build::Base';
ok $parents[-1], 'MyTest';
