#!/usr/bin/perl
### cleanR.pl

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V1.1 -- Feb. 2015
###   grandin@ipgp.fr
####################################################
### Delete unecessary files
####################################################
### Note: this program is Based on older perl scripts written
### by C. Lasserre, G. Peltzer (and probably others)
####################################################


use Env qw(INT_SCR MY_PERL);

###Usage info/check###

sub Usage{

`$INT_SCR/pod2man.pl $MY_PERL/clean.pl`;
exit 1;
}
@ARGV >= 2 or Usage();
@args = @ARGV;

###Infiles/Outputfiles###

$filein1=shift;
$filein2=shift;
$orbit="$filein1"."-"."$filein2";
$geodir="GEO";
$intdir="INT";
$simdir="SIM";
print "$orbit";

$dir=`pwd`;
print "\nWill delete files in\n $dir Is that OK (y/n)?\n";
$answer=<STDIN>;

$list = `ls -m "$intdir/$orbit.amp"\\
              "$intdir/$orbit.int"\\
              "$intdir/$orbit-sim_HDR_4rlks.int"\\
              "$intdir/$orbit-sim_HDR_12rlks.int"\\
              "$intdir/reference.hgt"\\
              "$intdir/ramp_HDR.unw"\\
              "$intdir/reference_4rlks.hgt"\\
              "$intdir/ramp_HDR_4rlks.unw"\\
              "$intdir/pha4baseest.unw"\\
              "$intdir/$orbit.cor"\\
              "$intdir/"$orbit"_4rlks.cor"\\
              "$intdir/"$orbit"_12rlks.cor"\\
              "$intdir/filt_"$orbit"-sim_HDR_12rlks_cut.flg"\\
              "$intdir/filt_"$orbit"-sim_HDR_12rlks.int"\\
	      "$intdir/filt_"$orbit"-sim_HDR_12rlks_cut.flg"\\
              "$intdir/filt_"$orbit"-sim_HDR_12rlks_c8.flg"\\
              "$intdir/filt_"$orbit"-sim_HDR_12rlks_c8.unw"\\
	      "$intdir/radar_4rlks.hgt"\\
              "$intdir/radar_HDR_4rlks.unw"\\
              "$intdir/flat_HDR_"$orbit".int"\\
              "$intdir/flat_HDR_"$orbit"_4rlks.int"\\
              $intdir/radar_12rlks.hgt\\
	      $intdir/baseest.msk\\
              $intdir/low_cor_HDR.msk \\
              $intdir/phase_var_HDR_12rlks.msk\\
              $intdir/geo_"$orbit".unw\\
              $geodir/geomap_64rlks.trans\\
              $simdir/SIM_raw.hgt\\
              $simdir/SIM_4rlks.hgt\\
              $simdir/SIM_12rlks.hgt`;
	      

print "delete : $list ? (y/n) ";
$yes=<STDIN>;

$list =~ s/\s//g;
@list =  split /,/,$list;

foreach $list (@list){
#print "delete : $list ? (y/n) ";
#$yes=<STDIN>;
#$yes='y';

if($yes=~ "y") {`rm $list`;}

};

print "Delete fullres slc files in $filein1 and $filein2? (y/n) ";
$ans1=<STDIN>;
if($ans1=~ "y") {`rm $filein1/"$filein1"_12rlks.slc $filein2/"$filein2"_12rlks.slc $filein1/"$filein1".sv $filein2/"$filein2".sv`;}
#                     $filein1/*roi* $filein2/*roi* `;}

#print "Delete raw files in $filein1 and $filein2? (y/n) ";
#$ans2=<STDIN>;
#if($ans2=~ "y") {`rm $filein1/$filein1.raw $filein2/$filein2.raw`;}

#print "Delete geomap.trans in $geodir/? (y/n) ";
#$ans2=<STDIN>;
#if($ans2=~ "y") {`rm $geodir/geomap.trans`;}


print "END\n";

exit 0;

=head1 USAGE

B<cleanR.pl> I<filein1 filein2>

  filein1: oOrbit1 (Example o10508)
  filein2: oOrbit2 (Example o22031)

=head1 FUNCTION

Delete files after processing

=head1 ROUTINES CALLED

no

=head1 LAST UPDATE

Cecile, Nov 7, 2001

=cut
