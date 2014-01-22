#!/usr/bin/perl
# use warnings;
use Storable qw(lock_store lock_retrieve);
use POSIX qw/floor/;

our $lcl;
our $eve;
our $supeve;
our $types;

my ($curevt, $curlc, $curdir, $curextend);
my @months=qw(Januar Februar Maerz April Mai Juni Juli August September Oktober November Dezember);

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
  
  open($fh, '<:encoding(utf8)', $eventlist) or die "Can't read file '$eventlist' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $eve->{$fields[0]}=\@fields;
    }  
  lock_store($eve,'eve.store');  

  open($fh, '<:encoding(utf8)', $supevent) or die "Can't read file '$supevent' [$!]\n";
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/"//g;
    my @fields = split(';', $line);
    $supeve->{$fields[0]}=\@fields;
    }  
  lock_store($supeve,'supeve.store');    

  open($fh, '<:encoding(iso-8859-15)', $typesfile) or die "Can't read file '$typesfile' [$!]\n";
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
  return $types->{$t}->[1]||'';
  }
  
sub getName {
  my ($loc) = @_;
  my $q = "";
  $q .= getType($loc)." ";
  $q .= $loc->[4]." " if ($loc->[4] ne "");
  $q .= $loc->[5];
  return $q;
  }

sub getTime {  
  my $val = shift @_;
  my $t;
  if($val <= 95) {
    my $h = floor($val /4);
    my $m = ($val % 4)*15;
    return sprintf("%02d:%02d",$h,$m);
    }
  elsif($val <= 200) {
    $val -= 95;
    return "morgen $val Uhr" if($val <= 24);
    $val -= 24;
    return "übermorgen $val Uhr" if($val <= 24);
    $val -= 24;
    return "in drei Tagen $val Uhr" if($val <= 24);
    $val -= 24;
    return "in vier Tagen $val Uhr" if($val <= 24);
    return "\"T+".($val-96)."h";
    }
  elsif($val <= 231) {
    return ($val-200).".";
    }
  else {
    $val = $val - 232;
    my $m = $months[floor($val/2)];
    my $d;
    $d = "Ende" if ($val%2);
    $d = "Mitte" unless ($val%2);
    return "$d $m";
    }
  }

  
sub getBigQuant {
  my ($event,$value) = @_;
  my $type = $eve->{$event}->[3];
  my $long = 0;
     $long = 1 if ($eve->{$event}->[4] eq 'L');
  my $t = "";
  $t .= "$value" if($type == 0);
  $t .= "$value" if($type == 1);
  $t .= "weniger als $value Meter" if($type == 2);
  $t .= "$value%" if($type == 3);
  $t .= "bis zu $value km/h" if($type == 4);
  $t .= "bis zu $value Minuten" if($type == 5 && $long == 0);
  $t .= "bis zu $value Stunden" if($type == 5 && $long == 1);
  $t .= "bis zu $value°C" if($type == 6);
  $t .= "$value Uhr" if($type == 7);
  $t .= ($value/10)." Tonnen" if($type == 8);
  $t .= ($value/10)." Meter" if($type == 9);
  $t .= "bis zu $value mm" if($type == 10);
  $t .= "$value MHz" if($type == 11);
  $t .= "$value kHz" if($type == 12);
  return $t;  
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
  if($type == 1) { #control
    if ($value == 2) { #directionality changed
#       if ($eve->{$curevt}->[5] == 1) {
        push(@$t,"in beiden Richtungen,");
#         }
#       else {
#         push(@$t,"in dieser Richtung,");
#         }
      }
    if  ($value == 8) { #ext + 16
      $curextend += 8;
      }
    if ($value == 7 || $value == 8) { #ext + 8
      $curextend += 8;
      $t->[1] = getRange($curextend,$curdir,$curlc);
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
  if($type == 5) { #Big number quantifier
    push(@$t,getBigQuant($curevt,$value));
    }
  if($type == 6) { #supplemental information
    push(@$t,$supeve->{$value}->[1].",");
    }
  if($type == 7) { #start time
    push(@$t,"ab ".getTime($value).",");
    }
  if($type == 8) { #stop time
    push(@$t,"bis ".getTime($value).",");
    }
  if($type == 9) { #additional event
    push(@$t,$eve->{$value}->[1].",");
    $curevt=$value;
    }
  if($type == 11) { #Destination
    push(@$t,"in Richtung ".getName($lcl->{$value}).",");
    }
  if($type == 14) { #separator
    push(@$t,' | ');
    }    
  return @$t;
  }

1;
