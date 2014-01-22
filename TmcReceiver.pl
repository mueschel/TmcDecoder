#!/usr/bin/perl

use warnings;
use Device::SerialPort;
use Time::HiRes qw( usleep);
use Data::Dumper;
use TmcInterpreter;


#Open the serial device with correct settings
$serdev = '/dev/ttyAMA0';

my $port = new Device::SerialPort($serdev);
unless ($port) {
  print "can't open serial interface $serdev\n";
  exit;
  }
$port->user_msg('ON'); 
$port->baudrate(38400); 
$port->parity("none"); 
$port->databits(8); 
$port->stopbits(1); 
$port->handshake("xoff");
$port->handshake("none"); 
$port->read_char_time(0);
$port->read_const_time(50);
$port->write_settings;

#init    echo  -e "\xFF\x56\x78\x78\x56" >/dev/ttyAMA0 
#89.3    echo  -e "\xFF\x73\x12\x00\x73" >/dev/ttyAMA0 
#105.9   echo  -e "\xFF\x73\xb8\x00\x73" >/dev/ttyAMA0 

#Load information from DB files
if(exists $ARGV[0] && $ARGV[0] eq 'init') {
  TmcInitDB();
  }
else {
  TmcLoadDB();
  }
print "Loading database finished\n";
  

my $raw = 1;
my $str = "";
my $last = "";
my $state = -1;  #-1 init, 0 single, 1 multi 1st, 2 multi 2nd...
my ($cont,$lastcont) = (-1,-2);
my ($seq, $lastseq) = (-1,-2);
my ($x,$y,$z);
my $group = 0;
my $firstgroup = 0;
my $secondgroup = 0;
my @store;
my @bastmc;
my $rawtmc = "";
my $buffer = "";
my $rawbuffer = "";
my $cntruns = 0;

#Length and names of data fields for additional message fields
my @fieldlength = (3,3,5,5,5,8,8,8,8,11,16,16,16,16,0,0);
my @fieldnames = qw(Duration Control Length Speed Quant Quant Suppl Start Stop AddEvent Diversion Dest Resv Link Sep);



while(1) {
  #get a bunch of data from the serial device
  my ($cnt,$a) = $port->read(255);
  $str .= $a; #str can contain leftover bits from last buffer
  my @o = split('\?',$str);
  $str = $o[-1]; #store last string as it may be incomplete

  #loop over all RDS groups received
  for(my $i = 0; $i < (scalar @o)-1; $i++) {
    next if ($o[$i] eq '');
    #Convert string to array of 8 bytes
    my @c = split('',$o[$i]);
    @c = map {ord($_)} @c;
    $c[7] = 0x3F unless exists $c[7];
    next if(($c[2]&0xF0) != 0x80); #skip any non-TMC message
    next if($last eq $o[$i]);      #skip repeated message
    if($raw) { #Print raw data if requested
      map{printf("%02x ",$_)} @c;
      #print("\n");
      }

    $rawbuffer .= join ' ',map{sprintf("%02x",$_)} @c;
    $rawbuffer .= "\n";
    #Reassemble interesting part of RDS data blocks
    $z    = ($c[6] << 8) + $c[7];
    $y    = ($c[4] << 8) + $c[5];
    $x    = $c[3] & 0x1F;
    
    #Get some special bits
    $section     = $x>>4  & 1;
    $singlegroup = $x>>3  & 1;
    $cont        = $x & 0x7;
    $firstgroup  = $y>>15 & 1;
    $secondgroup = $y>>14 & 1;
    $gsi         = $y>>12 & 0x3;
    
    #printf("%02x %04x %04x\t",$x,$y,$z);
    
    #decide on next state depending on last state and current group information
      if($section) {  #'for future use / service'
        $state = -1;
        }
      #if got idle, single-group or last part of multi-group
      elsif($state == -1 || $state == 0 || ($lastgsi == 0 && $state >= 2)) {
        #Next group is start of a new single/multi-group  
        @bastmc = ();
        $rawtmc = "";
        if($singlegroup) { 
          $state = 0;
          $gsi   = 0;
          }
        elsif(!$singlegroup && $firstgroup) {
          $state = 1;
          }
        else {
          $state = -1;
          }
        }
      elsif($state == 1) {
        #Next group  must be second part of multi-group
        @store = (); #clear buffer from any prior message part
        if(!$singlegroup && !$firstgroup && $secondgroup) { 
          $state = 2;
          }
        else {
          $state = -1;
          }
        }
      else {
        #Inside multi-group
        if(!$singlegroup && !$firstgroup && !$secondgroup && $cont == $lastcont ) {
          $state++;
          }
        else {
          $state = -1;
          }
        }
    
    #Skip yet ignored group types
    print("\t/S$state/\n");  
    unless($section) {
      #printf("%x %x %x %x %x\t",$cont,$singlegroup,$firstgroup,$secondgroup,$gsi);
      
      #If single-group: take data and decode
      if($state == 0) { 
        my $evt = $y & 0x7FF; 
        my $lc  = $z;
        my $dir = (($y>>14)&1)?'neg':'pos';
        my $extend = ($y>>11)&7;
        my $duration = $x & 7;
        my $diversion = $y>>15 & 1;
        $rawtmc = sprintf("Ev %4d \tLC %5d\tDir %s\tExten %x\tDura %x\tDiver %x\n",
                          $evt, $lc, $dir, $extend, $duration, $diversion);
        push(@bastmc,TmcBasicInfo($evt,$lc,$dir,$extend,$duration,$diversion));
        print $rawtmc.join(' ',@bastmc)."\n\n";
        $buffer .= $rawtmc.join(' ',@bastmc)."\n\n";
        }
      #First word of multi-group is almost like a single-group  
      if($state == 1) { 
        my $evt = $y & 0x7FF; 
        my $lc  = $z;
        my $dir = (($y>>14)&1)?'neg':'pos';
        my $extend = ($y>>11)&7;
        my $duration = $x & 7;
        my $diversion = $y>>15 & 1;
        $rawtmc = sprintf("Ev %4d \tLC %5d\tDir %s\tExten %x\t",
                          $evt, $lc, $dir, $extend);
        push(@bastmc,TmcBasicInfo($evt,$lc,$dir,$extend));
        }
      #Inside multi group: Store information as bit-array
      if($state >= 2) {
        #printf(" %08x ",(($y & 0xFFF) << 16) + $z);
        push(@store,split('',reverse unpack("b[12]",pack("S",$y))));
        push(@store,split('',reverse unpack("b[16]",pack("S",$z))));
        }
      #At end of multi group: take bit array and start decoding  
      if($state >= 2 && $gsi == 0) {
        while(scalar @store > 4) {
          my $type = 0;
          my $data = 0;
          #Read 4 Bit for type
          $type = ($type << 1) | (shift @store) for (1..4);
          
          #read payload if enough bits left, size defined by type
          if(scalar @store >= $fieldlength[$type]) {
            $data = ($data << 1) | (shift @store) for (1..$fieldlength[$type]);
            }
          #all bits 0 means end of data, otherwise print information
          unless($type == 0 && $data == 0) {
            TmcExtended($type,$data,\@bastmc);
            $rawtmc .= sprintf("(%x)%s %d\t",$type,$fieldnames[$type],$data);
            }
          }
        print $rawtmc."\n";
        print join(' ',@bastmc)."\n\n";
        $buffer .= $rawtmc."\n".join(' ',@bastmc)."\n\n";
        }
      }
      
    #Additional information, not decoded yet  
    if($section) {
      #Just a good guess to detect end of message block and begin of next iteration
      if ($z == 0x2020 && ($y&0xFF) == 0x20) {
        print "--------------------------------$cntruns\n";
        print "--------------------------------$cntruns\n";
        if(++$cntruns >= 4) {
          $cntruns = 0;
          savefile($buffer."\n".$rawbuffer);
          $rawbuffer = "";
          $buffer = "";
          }
        }
      else {
        #print ("other\t\t");
        #map{printf("%02x ",$_)} @c;
        #print("\n");        
        }
      }
    $last = $o[$i];
    $lastcont = $cont;
    $lastgsi  = $gsi;
    }
  usleep(1000);
  }
