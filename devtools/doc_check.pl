#!/usr/bin/perl -ln

BEGIN{
  @ARGV = qw( lib/Module/Build/Base.pm
	      lib/Module/Build.pm
	      lib/Module/Build/Authoring.pod );
}


if (@ARGV==2) {
  m/^\s*sub\s+ACTION_(\w+)/ ? $actions{$1}++ :
  m/^\s*sub\s+([^_\W]\w+)/  ? $subs{$1}++    :
  undef;
} else {
  $docs{$1}++ if m/^=item (\w+)/;
}

END{
  print "Methods:";
  print ($docs{$_} ? "$_*" : $_) for sort keys %subs;
  print "\nActions:";
  print ($docs{$_} ? "$_*" : $_) for sort keys %actions;
}
