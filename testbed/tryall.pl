#!/usr/bin/perl

my @dirs = @ARGV ? @ARGV : qw(
                    B
                    Compress-Zlib-1.14
                    SQL-Statement-0.1020
                   );

foreach my $dir (@dirs) {
  print "\n****************** $dir **************\n";
  
  chdir '..' if -e 'Build.PL';
  chdir $dir;
  system 'perl Build.PL';
  system 'Build test';
  system 'Build realclean';
}


########################################################################
__END__

/usr/bin/perl /System/Library/Perl/ExtUtils/xsubpp  -typemap /System/Library/Perl/ExtUtils/typemap -typemap typemap  B.xs > B.xsc && mv B.xsc B.c
/usr/bin/perl "-Iblib/arch" "-Iblib/lib" defsubs_h.PL defsubs.h
Extracting defsubs.h...
cc -c   -pipe -fno-common -DHAS_TELLDIR_PROTOTYPE -fno-strict-aliasing -O3   -DVERSION=\"a5\" -DXS_VERSION=\"a5\"  "-I/System/Library/Perl/darwin/CORE"   B.c
Running Mkbootstrap for B ()
chmod 644 B.bs
rm -f blib/arch/auto/B/B.bundle
LD_RUN_PATH="" cc  -flat_namespace -bundle -undefined suppress -L/usr/local/lib B.o  -o blib/arch/auto/B/B.bundle     
chmod 755 blib/arch/auto/B/B.bundle
cp B.bs blib/arch/auto/B/B.bs
chmod 644 blib/arch/auto/B/B.bs

########################################################################

  [junior:Module-Build/testbed/Compress-Zlib-1.16] ken% make
cp Zlib.pm blib/lib/Compress/Zlib.pm
AutoSplitting blib/lib/Compress/Zlib.pm (blib/lib/auto/Compress/Zlib)
/usr/bin/perl /System/Library/Perl/ExtUtils/xsubpp  -typemap /System/Library/Perl/ExtUtils/typemap -typemap typemap  Zlib.xs > Zlib.xsc && mv Zlib.xsc Zlib.c
cc -c  -I/usr/local/include -pipe -fno-common -DHAS_TELLDIR_PROTOTYPE -fno-strict-aliasing -O3   -DVERSION=\"1.16\" -DXS_VERSION=\"1.16\"  "-I/System/Library/Perl/darwin/CORE"   Zlib.c
  Running Mkbootstrap for Compress::Zlib ()
chmod 644 Zlib.bs
rm -f blib/arch/auto/Compress/Zlib/Zlib.bundle
LD_RUN_PATH="/usr/lib" cc  -flat_namespace -bundle -undefined suppress -L/usr/local/lib Zlib.o  -o blib/arch/auto/Compress/Zlib/Zlib.bundle   -L/usr/local/lib -lz  
chmod 755 blib/arch/auto/Compress/Zlib/Zlib.bundle
cp Zlib.bs blib/arch/auto/Compress/Zlib/Zlib.bs
chmod 644 blib/arch/auto/Compress/Zlib/Zlib.bs
  Manifying blib/man3/Compress::Zlib.3



