package Module::Build::Cookbook;

=head1 NAME

Module::Build::Cookbook - Examples of Module::Build Usage

=head1 DESCRIPTION

C<Module::Build> isn't conceptually very complicated, but examples are
always helpful.  I got the idea for writing this cookbook when
attending Brian Ingerson's "Extreme Programming Tools for Module
Authors" presentation at YAPC 2003, when he said, straightforwardly,
"Write A Cookbook."

The definitional of how stuff works is in the main C<Module::Build>
documentation.  It's best to get familiar with that too.

=head1 BASIC RECIPES

=head2 Installing modules that use Module::Build

In most cases, you can just issue the following commands from your
shell:

 perl Build.PL
 Build
 Build test
 Build install

That may vary a bit depending on how you invoke perl scripts on your
system.  For instance, if you have multiple versions of perl
installed, you can install to its library directories like so:

 /usr/bin/perl5.8.1 Build.PL
 Build
 Build test
 Build install

Notice that the F<Build> script knows what perl was used to run
C<Build.PL>.

XXX - F<Build> may not be in the path, do F<./Build> or C<perl Build foo>



=head2 Install modules using the programmatic interface:

 my $b = Module::Build->new(
   module_name => 'Foo::Bar',
   license => 'perl',
   requires => { 'Some::Module'   => '1.23' },
 );
 $b->dispatch('build');
 $b->dispatch('test');
 $b->dispatch('install);

=head1 AUTHOR

Ken Williams, ken@mathforum.org

=head1 SEE ALSO

perl(1), Module::Build(3)

=cut
