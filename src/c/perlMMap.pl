#!/usr/local/bin/perl

use Sys::Mmap;

$fileSize = -s 'release3_genomic';

$arm = $ARGV[0];
$start = $ARGV[1];
$end = $ARGV[2];

new Sys::Mmap($buf,$fileSize,'release3_genomic') or die $!;

if ($buf =~ m/>arm_$arm/g) {
   print pos($buf),"\n";
   print substr($buf,pos($buf)+$start,$end-$start),"\n";
}





