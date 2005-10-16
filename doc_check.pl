#!/usr/bin/perl -ln

BEGIN{
  @ARGV = qw( lib/Module/Build/Base.pm
	      lib/Module/Build.pm
	      lib/Module/Build/Authoring.pod );
}


if (@ARGV==2) {
  $subs{$1}++ if m/^\s*sub\s+([^_\W]\w+)/;
} else {
  $docs{$1}++ if m/^=item (\w+)\(/;
}

END{
  print ($docs{$_} ? "$_*" : $_) for sort keys %subs;
}
