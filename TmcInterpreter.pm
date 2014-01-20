#!/usr/bin/perl

use Storable qw(lock_store lock_retrieve);

our $lcl;
our $eve;
our $supeve;
our $types;

my ($curevt, $curlc, $curdir, $curextend);


sub TmcInitDB {
  binmode(STDOUT, ":utf8");

  my $file = 'Loc.csv';
  my $eventlist = 'EventList.csv';
  my $supevent = 'SupEvent.csv';
  my $typesfile = 'types.csv';
  my @data; 

  open(my $fh, '<:encoding(utf8)', $file) or die "Can't read file '$file' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $lcl->{$fields[0]}=\@fields;
    }  
  lock_store($lcl,'lcl.store');  
  close $fh;
  
  open(my $fh, '<:encoding(utf8)', $eventlist) or die "Can't read file '$eventlist' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $eve->{$fields[0]}=\@fields;
    }  
  lock_store($eve,'eve.store');  

  open(my $fh, '<:encoding(utf8)', $supevent) or die "Can't read file '$supevent' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $supeve->{$fields[0]}=\@fields;
    }  
  lock_store($supeve,'supeve.store');    

  open(my $fh, '<:encoding(iso-8859-15)', $typesfile) or die "Can't read file '$typesfile' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $types->{$fields[0]}=\@fields;
    }  
  lock_store($types,'types.store');  
  
  }


sub TmcLoadDB {
  binmode(STDOUT, ":utf8");
  $lcl = lock_retrieve('lcl.store');
  $eve = lock_retrieve('eve.store');
  $supeve = lock_retrieve('supeve.store');
  $types = lock_retrieve('types.store');
  }

sub savefile {
  my ($t) = @_;
  open(my $fh, '>:encoding(utf8)', '/tmp/tmc.txt') or die "Can't open file '$file' [$!]\n";
  print $fh localtime."\n";
  print $fh $t;
  close $fh;
  }

sub getType {
  my ($loc) = @_;
  my $q = "";
  my $t = $loc->[1].'.'.$loc->[2];
  return $types->{$t}->[1];
  }
  
sub getName {
  my ($loc) = @_;
  my $q = "";
  $q .= getType($loc)." ";
  $q .= $loc->[4]." " if ($loc->[4] ne "");
  $q .= $loc->[5]
  }
  
  
sub getRange {
  my ($extend,$dir,$loc) = @_;
  my $q = "";
  my $e = $extend;
  my $start = $loc;
  while($e-- > 0) {
    if(!$dir && $start->[9] ne "") {
      $start = $lcl->{$start->[9]};
      }
    elsif ($start->[10] ne "") {
      $start = $lcl->{$start->[10]};
      }
    }
    
  if($extend > 0) {
    $q .= "zwischen ".getName($start)." und ";    
    }
  else {
    $q .= "- ";
    }
  $q .= getName($loc).':';  
  return $q;
  }
  
  
sub TmcBasicInfo {
  my ($evt,$lc,$dir,$extend,$duration,$diversion) = @_;
  $curevt = $evt;
  $curlc  = $lc;
  $curdir = $dir;
  $curextend = $extend;
  my @t;
  my $loc = $lcl->{$lc};
  my $seg = $lcl->{$loc->[8]};
  if(!$dir) {
    push(@t,$seg->[3]." ".$seg->[5]." -> ".$seg->[6]);
    }
  else {
    push(@t,$seg->[3]." ".$seg->[6]." -> ".$seg->[5]);
    }
  push(@t,getRange($extend,$dir,$loc));
  push(@t,$eve->{$evt}->[1].",");
  return @t;
  }

sub TmcExtended {
  my ($type,$value,$t) = @_;
  if($type == 1) {
    if ($value == 2) { #directionality changed
      if ($eve->{$curevt}->[5] == 1) {
        push(@$t,"in beiden Richtungen,");
        }
      else {
        push(@$t,"in dieser Richtung,");
        }
      }
    }
  if($type == 2) {#Length
    if($value>=1 && $value<=10) {
      push(@$t,$value."km,");
      }
    if($value>=11 && $value<=15) {
      my $v = ($value-5)*2;
      push(@$t,$v."km,");
      }
    if($value>=16 && $value<=31) {
      my $v = ($value-11)*5;
      push(@$t,$v."km,");
      }
    if($value == 0) {
      push(@$t,">100km,");
      }
    }    
  if($type == 6) {
    push(@$t,$supeve->{$value}->[1].",");
    }
  if  ($type == 8) { #ext + 16
    $curextend += 8;
    }
  if ($type == 7 || $type == 8) { #ext + 8
    $curextend += 8;
    $t->[1] = getRange($curextend,$curdir,$loc);
    }
  if($type == 9) {
    push(@$t,$eve->{$value}->[1].",");
    $curevt=$value;
    }
  return @$t;
  }

1;
