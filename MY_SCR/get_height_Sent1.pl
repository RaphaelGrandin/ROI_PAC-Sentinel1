#!/usr/bin/perl
### get_height.pl

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V1.1 -- Feb. 2015
###   grandin@ipgp.fr
####################################################
### Compute satellite height
####################################################
### Note : this file is modified frome
### older scripts written for TerraSAR-X
### Authors list given at the bottom of the file
####################################################


use Env qw(INT_SCR INT_BIN MY_SCR);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;
use POSIX qw(ceil floor);


sub Usage {
  print STDERR <<END;

Usage: get_height.pl outname
  outname        : input and output file name root; YYMMDD is default
 
Function: Updates I<outname>.slc.rsc with height and other parameters


END
  exit 1;
}

@ARGV >= 1  or Usage();
@args = @ARGV;

$date         = shift;
$orbit_type   = shift or $orbit_type = "HDR";

#################
#Message "Checking I/O";
#################
#@Infiles  = ($asa_file_prefix, @imagery);
#@Outfiles = ("$outname.raw",  "$outname.raw.rsc");
#&IOcheck(\@Infiles, \@Outfiles);
Log ("get_height.pl", @args);

$day   = Use_rsc "$date.slc read FIRST_LINE_DAY_OF_MONTH"; 
$month = Use_rsc "$date.slc read FIRST_LINE_MONTH_OF_YEAR"; 
$year  = Use_rsc "$date.slc read FIRST_LINE_YEAR";
$sat   = Use_rsc "$date.slc read PLATFORM";
$center_utc = Use_rsc "$date.slc read CENTER_LINE_UTC"; 
$first_line_utc = Use_rsc "$date.slc read FIRST_LINE_UTC"; 
$prf = Use_rsc "$date.slc read PRF";

if ($sat eq "TSX" || $sat eq "TDX" ||$sat eq "TSX-1" || $sat eq "TDX-1" ){
# this should be already in .rsc, but added here for now
$range_pixel_size = Use_rsc "$date.slc read RANGE_PIXEL_SIZE";
$C                        = 299792458;
  $range_sampling_frequency = $C / (2 * $range_pixel_size);
  $antenna_length = 4.784; # from Eric Gurrola script

Use_rsc "$date.slc write RANGE_SAMPLING_FREQUENCY $range_sampling_frequency";
Use_rsc "$date.slc write ANTENNA_LENGTH           $antenna_length";
}
elsif ($sat eq "S1A" || $sat eq "S1B"){
$range_pixel_size = Use_rsc "$date.slc read RANGE_PIXEL_SIZE";
$C                        = 299792458;
#  $range_sampling_frequency = $C / (2 * $range_pixel_size);
  $antenna_length = 12.3; 

#Use_rsc "$date.slc write RANGE_SAMPLING_FREQUENCY $range_sampling_frequency";
Use_rsc "$date.slc write ANTENNA_LENGTH           $antenna_length";
}

# this part from make_raw_envi.pl
###############################
Message "Using Orbit Information"; 
###############################
($q1,$q2,$Lat,$Lon,$height_mid, $x0, $y0, $z0, $vx0, $vy0,$vz0) = split /\s+/,
    `$INT_SCR/state_vector.pl $year$month$day $center_utc $sat $orbit_type $date`;
Status "state_vector.pl";

$pi   = atan2(1,1)*4;
if ($orbit_type eq "HDR"){
 $ae    = 6378137;             #GRS80 reference ellipsoid
 $flat  = 1/298.257223563;
 $r     = sqrt($x0**2+$y0**2+$z0**2);
 $r1    = sqrt($x0**2+$y0**2);
 $Lat   = atan2($z0,$r1);
 $Lon   = atan2($y0,$x0);
 $H     = $r-$ae;
 for ($i=1; $i<7; $i++){
  $N      = $ae/(sqrt(1-$flat*(2-$flat)*sin($Lat)**2));
  $TanLat = $z0/$r1/(1-(2-$flat)*$flat*$N/($N+$H));
  $Lat    = atan2($TanLat,1);
  $H      = $r1/cos($Lat)-$N;
 }
 $height_mid=$H; 
}

$ae   = 6378137;                        #WGS84 reference ellipsoid
$flat = 1./298.257223563;
$N    = $ae/sqrt(1-$flat*(2-$flat)*sin($Lat)**2);
$re_mid=$N;

$ve=-sin($Lon)*$vx0+cos($Lon)*$vy0;
$vn=-sin($Lat)*cos($Lon)*$vx0-sin($Lat)*sin($Lon)*$vy0+cos($Lat)*$vz0;
$hdg = atan2($ve,$vn);
$e2 = $flat*(2-$flat);
$M = $ae*(1-$e2)/(sqrt(1-$e2*sin($Lat)**2))**3;
$earth_radius_mid = $N*$M/($N*(cos($hdg))**2+$M*(sin($hdg))**2);

($q1,$q2,$q3,$q4,$height_top, $x0, $y0, $z0, $vx, $vy,$vz) = split /\s+/,
    `$INT_SCR/state_vector.pl $year$month$day $first_line_utc $sat $orbit_type $date`;
Status "state_vector.pl";

if ($orbit_type eq "HDR" ){
  $ae    = 6378137;             #GRS80 reference ellipsoid
  $flat  = 1/298.257223563;
  $r     = sqrt($x0**2+$y0**2+$z0**2);
  $r1    = sqrt($x0**2+$y0**2);
  $Lat   = atan2($z0,$r1);
  $Lon   = atan2($y0,$x0);
  $H     = $r-$ae;
  for ($i=1; $i<7; $i++){
    $N      = $ae/(sqrt(1-$flat*(2-$flat)*sin($Lat)**2));
    $TanLat = $z0/$r1/(1-(2-$flat)*$flat*$N/($N+$H));
    $Lat    = atan2($TanLat,1);
    $H      = $r1/cos($Lat)-$N;
  }
  $height_top=$H; 
}

$height_dt=($height_mid-$height_top)/($center_utc-$first_line_utc);
if ($vz0 > 0) {$orbit_direction =  "ascending";}
else          {$orbit_direction = "descending";}
$velocity_mid=sqrt($vx0**2 + $vy0**2 + $vz0**2);

$Latd=$Lat*180./$pi;
$Lond=$Lon*180./$pi;
$hdgd=$hdg*180./$pi;

# some of these already calculated by Walter's make_slc_tsx
Use_rsc "$date.slc write HEIGHT_TOP   $height_top";
#Use_rsc "$date.slc write HEIGHT       $height_mid";
#Use_rsc "$date.slc write HEIGHT_DT    $height_dt";
#Use_rsc "$date.slc write VELOCITY     $velocity_mid";
Use_rsc "$date.slc write LATITUDE     $Latd";
Use_rsc "$date.slc write LONGITUDE    $Lond";
Use_rsc "$date.slc write HEADING      $hdgd";
#Use_rsc "$date.slc write EQUATORIAL_RADIUS   $ae";
#Use_rsc "$date.slc write ECCENTRICITY_SQUARED $e2";
Use_rsc "$date.slc write EARTH_EAST_RADIUS $N";
Use_rsc "$date.slc write EARTH_NORTH_RADIUS $M";
#Use_rsc "$date.slc write EARTH_RADIUS $earth_radius_mid";
Use_rsc "$date.slc write ORBIT_DIRECTION $orbit_direction";

# these calculations from roi_prep.pl
$delta_line_utc          = 1/$prf;
$azimuth_pixel_size      = $velocity_mid/$prf;
Use_rsc "$date.slc write DELTA_LINE_UTC    $delta_line_utc";
Use_rsc "$date.slc write AZIMUTH_PIXEL_SIZE     $azimuth_pixel_size";
Use_rsc "$date.slc write ALOOKS     1";
Use_rsc "$date.slc write RLOOKS     1";

# starting with SLC so infile and outfile the same
$infile = "$date.slc";
$outfile = "$date.slc";

###############################################
# Get peg info and update geometry parameters #
# now extracted for SLC, not raw data         #
###############################################

system "cp ${infile}.rsc debug.rsc";

#system "$INT_SCR/GetPeg.pl $outfile $orbit_type";
system "$MY_SCR/GetPeg_Sent1.pl $outfile $orbit_type"; # Sentinel-1

($name = $outfile) =~ s/\.[^.]*$//; #strip the last extension from the input file name

open PEGOUT, "$name.peg.out";
while( defined( $Line = <PEGOUT> ) ){
	if( $Line =~ /Peg Lat\/Lon , H =\s+(\S+)\s+(\S+)\s+(\S+)/ ){
		$Latd   = $1;
		$Lond   = $2;
		$PegHgt = $3;
	}
	if( $Line =~ /Peg Heading =\s+(\S+)/ ){
		$hdgd = $1;
	}
	if( $Line =~ /Vertical Fit:\s+(\S+)\s+(\S+)\s+(\S+)/ ){
		@Height_poly = ( $1, $2, $3 );
	}
	if( $Line =~ /Horizontal Fit:\s+(\S+)\s+(\S+)\s+(\S+)/ ){
		@CrossT_poly = ( $1, $2, $3 );
	}
	if( $Line =~ /Vertical Velocity Fit:\s+(\S+)\s+(\S+)/ ){
		@Vert_V_poly = ( $1, $2 );
	}
	if( $Line =~ /Cross-Track Velocity Fit:\s+(\S+)\s+(\S+)/ ){
		@CrossT_V_poly = ( $1, $2 );
	}
	if( $Line =~ /Along-Track Velocity Fit:\s+(\S+)\s+(\S+)/ ){
		@AlongT_V_poly = ( $1, $2 );
	}
	if( $Line =~ /Platform SCH Velocity \(m\/s\):\s+(\S+)\s+(\S+)\s+(\S+)/ ){
		@VelocitySCH = ( $1, $2, $3 );
		$velocity_mid = Norm( @VelocitySCH );
	}
	if( $Line =~ /Platform SCH Acceleration \(m\/s\^2\):\s+(\S+)\s+(\S+)\s+(\S+)/ ){
		@AccelerationSCH = ( $1, $2, $3 );
	}
	if( $Line =~ /Time to first\/middle scene:\s+\S+\s+(\S+)/ ){
		$PegUtc = $1;
	}
}

close PEGOUT;

$HgtDt = $Height_poly[1] * $VelocitySCH[0];

Use_rsc "$outfile write HEIGHT                   $Height_poly[0]";
Doc_rsc(
 RSC_Tip => 'Platform Altitude at Peg Point',
 RSC_Doc => q[
   "Platform Altitude" based on RDF usage in diffnsim.pl

   First coefficient (constant term) of orbit "Vertical Fit" polynomial
   output by get_peg_info run by GetPeg.pl.

   Polynomial is function of SCH 'S' coordinate.
   Value is in 'H' direction, which is height above SCH reference sphere.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter',
);

Use_rsc "$outfile write HEIGHT_DS                $Height_poly[1]";
Doc_rsc(
 RSC_Tip => 'Platform Altitude Rate at Peg Point',
 RSC_Doc => q[
   "Platform Altitude Rate" based on RDF usage in diffnsim.pl

   Second coefficient (linear term) of orbit "Vertical Fit" polynomial
   output by get_peg_info run by GetPeg.pl.

   Polynomial is function of SCH 'S' coordinate.
   Value is in 'H' direction, which is height above SCH reference sphere.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:meter',
);

Use_rsc "$outfile write HEIGHT_DDS               $Height_poly[2]";
Doc_rsc(
 RSC_Tip => 'Platform Altitude Acceleration at Peg Point',
 RSC_Doc => q[
   "Platform Altitude Acceleration" based on RDF usage in diffnsim.pl

   Third coefficient (quadratic term) of orbit "Vertical Fit" polynomial
   output by get_peg_info run by GetPeg.pl.

   Polynomial is function of SCH 'S' coordinate.
   Value is in 'H' direction, which is height above SCH reference sphere.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:meter**2',
);

Use_rsc "$outfile write HEIGHT_DT                $HgtDt";
Doc_rsc(
 RSC_Tip => 'Platform Altitude change w.r.t. time at Peg Point',
 RSC_Derivation => q[
   $HgtDt = $Height_poly[1] * $VelocitySCH[0];
   ],
 RSC_Comment => q[
   Does not appear to ever be used.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:second',
);

Use_rsc "$outfile write CROSSTRACK_POS           $CrossT_poly[0]";
Use_rsc "$outfile write CROSSTRACK_POS_DS        $CrossT_poly[1]";
Use_rsc "$outfile write CROSSTRACK_POS_DDS       $CrossT_poly[2]";
Use_rsc "$outfile write VELOCITY                 $velocity_mid";
Doc_rsc(
 RSC_Tip => 'Norm of Platform SCH Velocity at Peg Point',
 RSC_Doc => q[
   "Body fixed S/C velocities" based on RDF usage in roi_prep.pl and autofocus.pl.
   "Spacecraft Along Track Velocity" based on RDF usage in inverse3d.pl
   "Platform Velocity" based on RDF usage in diffnsim.pl and phase2base.pl
   ],
 RSC_Derivation => q[
   $velocity_mid = Norm( @VelocitySCH );
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second',
);

Use_rsc "$outfile write VELOCITY_S               $VelocitySCH[0]";
Doc_rsc(
 RSC_Tip => 'Platform Velocity S Component',
 RSC_Doc => q[
   'S' Component of 'Platform SCH Velocity'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second',
);

Use_rsc "$outfile write VELOCITY_C               $VelocitySCH[1]";
Doc_rsc(
 RSC_Tip => 'Platform Velocity C Component',
 RSC_Doc => q[
   'C' Component of 'Platform SCH Velocity'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   Note - this is not the speed of light.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second',
);
Use_rsc "$outfile write VELOCITY_H               $VelocitySCH[2]";
Doc_rsc(
 RSC_Tip => 'Platform Velocity H Component',
 RSC_Doc => q[
   'H' Component of 'Platform SCH Velocity'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second',
);

Use_rsc "$outfile write ACCELERATION_S           $AccelerationSCH[0]";
Doc_rsc(
 RSC_Tip => 'Platform Acceleration S Component',
 RSC_Doc => q[
   'S' Component of 'Platform SCH Acceleration'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second**2',
);

Use_rsc "$outfile write ACCELERATION_C           $AccelerationSCH[1]";
Doc_rsc(
 RSC_Tip => 'Platform Acceleration C Component',
 RSC_Doc => q[
   'C' Component of 'Platform SCH Acceleration'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second**2',
);

Use_rsc "$outfile write ACCELERATION_H           $AccelerationSCH[2]";
Doc_rsc(
 RSC_Tip => 'Platform Acceleration H Component',
 RSC_Doc => q[
   'H' Component of 'Platform SCH Acceleration'
   produced by get_peg_info run by GetPeg.pl.

   SCH Coordinate system.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used by roi_prep.pl and autofocus.pl
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:meter/SI:second**2',
);

Use_rsc "$outfile write VERT_VELOCITY            $Vert_V_poly[0]";
Use_rsc "$outfile write VERT_VELOCITY_DS         $Vert_V_poly[1]";
Use_rsc "$outfile write CROSSTRACK_VELOCITY      $CrossT_V_poly[0]";
Use_rsc "$outfile write CROSSTRACK_VELOCITY_DS   $CrossT_V_poly[1]";
Use_rsc "$outfile write ALONGTRACK_VELOCITY      $AlongT_V_poly[0]";
Use_rsc "$outfile write ALONGTRACK_VELOCITY_DS   $AlongT_V_poly[1]";
Use_rsc "$outfile write LATITUDE     $Latd";
Doc_rsc(
 RSC_Tip => 'Latitude of SCH Peg Point',
 RSC_Doc => q[
   'Lat' value of 'Peg Lat/Lon , H'
   produced by get_peg_info run by GetPeg.pl.

   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used in inverse3d.pl to specify "Peg Point Data"
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);

Use_rsc "$outfile write LONGITUDE    $Lond";
Doc_rsc(
 RSC_Tip => 'Longitude of SCH Peg Point',
 RSC_Doc => q[
   'Lon' value of 'Peg Lat/Lon , H'
   produced by get_peg_info run by GetPeg.pl.

   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used in inverse3d.pl to specify "Peg Point Data"
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);

Use_rsc "$outfile write HEADING      $hdgd";
Doc_rsc(
 RSC_Tip => 'Heading of SCH Peg Point',
 RSC_Doc => q[
   'Peg Heading' value
   produced by get_peg_info run by GetPeg.pl.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used in inverse3d.pl to specify "Peg Point Data"
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);

Use_rsc "$outfile write PEG_UTC      $PegUtc";
Doc_rsc(
 RSC_Tip => 'Scene start time-of-day',
 RSC_Doc => q[
   'first' value of 'Time to first/middle scene'
   produced by get_peg_info run by GetPeg.pl.
   ],
 RSC_Derivation => q[
   See baseline/get_peg_info.f
   ],
 RSC_Comment => q[
   Appears to only be used in inverse3d.pl to calculate
     $PegLine = int( ( $PegUtc - $slc_first_line_utc ) / $delta_line_utc );
   which is used for
     'Reference Line for SCH Coordinates' RDF value
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:second',
);

#########################
Message "SLC data ready for processing";
#########################

exit 0;


=pod

=head1 USAGE

B<make_raw_envi_subset.pl> I< asa_file_prefix_root [orbit type] >

orbit type: ODR, HDR(HDR ECEF), HDI (HDR ECI), DOR(DORIS ECEF), DOI(DORIS ECI), UCL (GSFC+UCL), NOM (GSFC+Norminal)

=head1 FUNCTION

Creates I<date>.raw and I<date>.raw.rsc from imagery files

=head1 ROUTINES CALLED

state_vector.pl


=head1 CALLED BY

none

=head1 FILES USED


=head1 FILES CREATED

I<date>.raw

I<date>.raw.rsc

I<date>_parse_line.out

shift.out

shift.out.rsc

=head1 HISTORY

Perl  Script : Yuri Fialko 03/24/2004
modified by Ingrid Johanson 10/2004 to include DOR as orbit option
modified to add range bias adjustment Eric Fielding 1/2005
Other cleanup Eric Fielding 2/2005
added HEIGHT_TOP keyword to .raw.rsc to keep both top and middle (peg) heights EJF 2005/3/21
modified code to find orbit file with Mark Simon's fix to avoid problems with underscores in directory path EJF 2005/8/19
added optional choice of starting window code EJF 2005/9/28
added UCL and NOM orbit options by Zhenhong Li on 24 Oct 2005
added DOI option by Zhenhong Li on 12 Nov 2005

=head1 LAST UPDATE

2005/11/12 Zhenhong Li

=cut

