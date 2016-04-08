#!/usr/bin/perl -w


####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V1.1 -- Feb. 2015
###   grandin@ipgp.fr
####################################################
### Compute PEG
####################################################
#### Note : this file is modified from ROI_PAC software
#####################################################


use Env qw(INT_SCR INT_BIN);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;

$infile      = shift;
$orbit_type  = shift;
$orbit_type  =~ /(ODR|PRC|HDR)/ || die "Orbit type must be ODR, PRC or HDR\n";

$prf         = Use_rsc "$infile read PRF";
$t0          = Use_rsc "$infile read FIRST_LINE_UTC";
$length      = Use_rsc "$infile read FILE_LENGTH";
$az_pix_size = Use_rsc "$infile read AZIMUTH_PIXEL_SIZE";
$velocity    = Use_rsc "$infile read VELOCITY";
$year        = Use_rsc "$infile read FIRST_LINE_YEAR";
$month       = Use_rsc "$infile read FIRST_LINE_MONTH_OF_YEAR";
$day         = Use_rsc "$infile read FIRST_LINE_DAY_OF_MONTH";
$sat         = Use_rsc "$infile read PLATFORM";
$gm          = Use_rsc "$infile read PLANET_GM";
$spinrate    = Use_rsc "$infile read PLANET_SPINRATE";

($name = $infile) =~ s/\.[^.]*$//; #strip the last extension from the input file name

if( defined($az_pix_size) && $az_pix_size > 0 ){    #Or use ALOOKS if it's always available
    $slc_az_pix_size = $velocity / $prf;
    $looks = sprintf( "%.0f", $az_pix_size / $slc_az_pix_size );
}else{
    $looks = 1;
}

$slc_lines = $length * $looks;

#$SvStep = 30;
$SvStep = 2; # Sentinel-1
#($hdrdate = $name) =~ s/\.[^.]*$//; #strip the last extension from the input file name; #used if orbit_type == HDR;
$hdrdate = $name; #used if orbit_type == HDR;
$Orrm_str = "";
for( $t=$t0-$SvStep*3; $t<=$t0+$SvStep*3+$length/$prf/$looks; $t+=$SvStep ){
    $t = sprintf( "%.0f", $t );
    $SvIn_str = "$year$month$day $t $sat $orbit_type $hdrdate";;

    #($q1, $q2, $q3, $q4, $q5, $x1[0], $x1[1], $x1[2], $v[0], $v[1], $v[2], $qq)
    @SvOut = split /\s+/, `$INT_SCR/state_vector.pl $SvIn_str`;
    $Orrm_str .= "$t";
    $Orrm_str .= sprintf " %12.3f %12.3f %12.3f", $SvOut[5], $SvOut[6], $SvOut[7];
    $Orrm_str .= sprintf " %12.6f %12.6f %12.6f", $SvOut[8], $SvOut[9], $SvOut[10];
    $Orrm_str .= "\n";
}
open ORRM, ">$name.orrm";
print ORRM $Orrm_str;
close ORRM;

$GetPegInfo_InStr = "
Number of Orbits                                      (-) = 1
Line in Reference SLC for Interferogram Start         (-) = 1
Number of Lines in Interferogram                      (-) = $length
Number of Lines in SLC 1                              (-) = $slc_lines
Number of Azimuth Looks in Interferogram              (-) = $looks
PRF for Reference SLC                                 (-) = $prf
Time of First Line in SLC 1                           (s) = $t0
Orbit Info in RDF or Separate Files                   (-) = File Orbit
Output Print Frequency for Position Data              (-) = 30
State Vector File for Interferogram                   (-) = $name.sv
Peg Point Info File                                   (-) = $name.peg
Ephemeris File for Orbit 1                            (-) = $name.orrm
Planet GM                                             (-) = $gm
Planet Spinrate                                       (-) = $spinrate
";

open OUT, ">$name.peg.in";
print OUT $GetPegInfo_InStr;
close OUT;

system "$INT_BIN/get_peg_info $name.peg.in > $name.peg.out";
