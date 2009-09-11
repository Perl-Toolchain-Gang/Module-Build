#!/usr/bin/env perl
use strict;
use warnings;

use Path::Class;
require YAML::Tiny;
require PPI;
require PPI::Dumper;

my $Doc = PPI::Document->new($INC{'YAML/Tiny.pm'});
$Doc->prune('PPI::Token::Pod');
$Doc->prune( sub {
        $_[1]->isa('PPI::Statement') 
    &&  $_[1]->first_element->isa('PPI::Token::Symbol')
    &&  $_[1]->first_element->symbol =~ /EXPORT|ISA/
  }
);
$Doc->prune( sub {
        $_[1]->isa('PPI::Statement::Include') 
    &&  $_[1]->child(2)->isa('PPI::Token::Word')
    &&  $_[1]->child(2)->content eq 'Exporter'
  }
);

#my $Dumper = PPI::Dumper->new( $Doc );
#$Dumper->print;

my $content = $Doc->serialize;
$content =~ s{YAML::Tiny}{Module::Build::YAML}g;
$content = "# Adapted from YAML::Tiny " . YAML::Tiny->VERSION . "\n$content";
$content =~ s{^\s+\n(\s+\n)+}{\n}gms;

my $mby = file(qw/lib Module Build YAML.pm/);
die "Can't find $mby" unless -e $mby;
my $fh = $mby->openw;
print {$fh} $content;

