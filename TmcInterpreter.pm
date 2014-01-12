#!/usr/bin/perl

use Storable qw(lock_store lock_retrieve);

our $lcl;

my ($curevt, $curlc, $curdir, $curextend);


sub TmcInitDB {
  binmode(STDOUT, ":utf8");

  my $file = 'LCL12.0.D-121202.csv';
  my $eventlist = 'EventList.csv';
  my $supevent = 'SupEvent.csv';
  my @data; 

  open(my $fh, '<:encoding(iso-8859-15)', $file) or die "Can't read file '$file' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $lcl->{$fields[0]}=\@fields;
    }  
  lock_store($lcl,'lcl.store');  
  close $fh;
  
  open(my $fh, '<:encoding(utf-8)', $eventlist) or die "Can't read file '$eventlist' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(',', $line);
    $eve->{$fields[0]}=\@fields;
    }  
  lock_store($eve,'eve.store');  

  open(my $fh, '<:encoding(utf-8)', $supevent) or die "Can't read file '$supevent' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(',', $line);
    $supeve->{$fields[0]}=\@fields;
    }  
  lock_store($supeve,'supeve.store');    
  
  }


sub TmcLoadDB {
  $lcl = lock_retrieve('lcl.store');
  $eve = lock_retrieve('eve.store');
  $supeve = lock_retrieve('supeve.store');
  }

  
  
sub TmcBasicInfo {
  my ($evt,$lc,$dir,$extend,$duration,$diversion) = @_;
  $curevt = $evt;
  $curlc  = $lc;
  $curdir = $dir;
  $curextend = $extend;
  my $t = "";
  my $loc = $lcl->{$lc};
  my $seg = $lcl->{$loc->[8]};
  if(!$dir) {
    $t .= $seg->[3]." ".$seg->[5]." -> ".$seg->[6]." ";
    }
  else {
    $t .= $seg->[3]." ".$seg->[6]." -> ".$seg->[5]." ";
    }
  
  $t .= ": ".$loc->[4]." ".$loc->[5].":\t";
  $t .= $eve->{$evt}->[1].", ";
  return $t;
  }

sub TmcExtended {
  my ($type,$value) = @_;
  my $t = "";
  if($type == 1) {
    if ($value == 2) { #directionality changed
      if ($eve->{$curevt}->[5] == 1) {
        $t .= "in beiden Richtungen, ";
        }
      else {
        $t .= "in dieser Richtung, ";
        }
      }
    }
  if($type == 6) {
    $t .= $supeve->{$value}->[1].", ";
    }
  if($type == 9) {
    $t .= $eve->{$value}->[1].", ";
    }
  return $t;
  }

1;