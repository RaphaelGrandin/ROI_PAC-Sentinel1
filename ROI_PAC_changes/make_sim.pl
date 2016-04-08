#!/usr/bin/perl
### make_sim.pl

$] >= 5.004 or die "Perl version must be >= 5.004 (Currently $]).\n";

use Env qw(INT_BIN INT_SCR);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;

###Usage info/check
sub Usage{

`$INT_SCR/pod2man.pl  $INT_SCR/make_sim.pl`;
exit 1;
}
@ARGV >= 7 or Usage();
@args = @ARGV;

$sim_name   = shift;
$sim_dir    = shift;
$pair       = shift;
$Rlooks     = shift;
$Rlooks_sml = shift;
$orbit_type = shift;
$DEM        = shift;
$lookdown   = $Rlooks_sml/$Rlooks;
$skip       = 1;

$DEM =~ /\.dem$/ or $DEM = "$DEM.dem";
$SLP = $DEM;
$SLP =~ s/\.dem/\.slp/;

if ($Rlooks > 1){$Lint = "_${Rlooks}rlks";}
else{$Lint = "";}

@hdr=split/-/,$pair;
$hdrdate=$hdr[0];

#################
Message "Checking I/O";
#################
@Infiles  = ("$pair.int.rsc");
@Outfiles = ("$sim_dir/${sim_name}$Lint.hgt.rsc",
	     "$sim_dir/${sim_name}$Lint.hgt");
&IOcheck(\@Infiles, \@Outfiles);
Log("make_sim.pl", @args);

### Check to see if orrm file has already been done
$do_orrm = 1;
if (-e "$sim_dir/$sim_name.orrm"){
  if (-M "$pair.int.rsc" > -M "$sim_dir/$sim_name.orrm"){
    $do_orrm = "0";
  }
}
#################
Message "Reading resource file: $pair.int.rsc";
#################
$orbit_number       = Use_rsc "$pair.int read ORBIT_NUMBER";
$width              = Use_rsc "$pair.int read WIDTH";
$length             = Use_rsc "$pair.int read FILE_LENGTH";
$first_line_utc     = Use_rsc "$pair.int read FIRST_LINE_UTC";
$range_pixel_size   = Use_rsc "$pair.int read RANGE_PIXEL_SIZE";
$azimuth_pixel_size = Use_rsc "$pair.int read AZIMUTH_PIXEL_SIZE";
$rlks               = Use_rsc "$pair.int read RLOOKS";
$alks               = Use_rsc "$pair.int read ALOOKS";
$delta_line_utc     = Use_rsc "$pair.int read DELTA_LINE_UTC";
$time_span_year     = Use_rsc "$pair.int read TIME_SPAN_YEAR";
$rt                 = Use_rsc "$pair.int read EARTH_RADIUS";
$r0                 = Use_rsc "$pair.int read STARTING_RANGE";
$r0_raw             = Use_rsc "$pair.int read RAW_DATA_RANGE";
$h                  = Use_rsc "$pair.int read HEIGHT";
$squint             = Use_rsc "$pair.int read SQUINT";
$year               = Use_rsc "$pair.int read FIRST_LINE_YEAR";
$month              = Use_rsc "$pair.int read FIRST_LINE_MONTH_OF_YEAR";
$day                = Use_rsc "$pair.int read FIRST_LINE_DAY_OF_MONTH";
$date               = Use_rsc "$pair.int read DATE";
$sat                = Use_rsc "$pair.int read PLATFORM";
$direction          = Use_rsc "$pair.int read ORBIT_DIRECTION";
$dop_rng0           = Use_rsc "$pair.int read DOPPLER_RANGE0";
$dop_rng1           = Use_rsc "$pair.int read DOPPLER_RANGE1";
$dop_rng2           = Use_rsc "$pair.int read DOPPLER_RANGE2";
$dop_rng3           = Use_rsc "$pair.int read DOPPLER_RANGE3";
$prf                = Use_rsc "$pair.int read PRF";
$wvl                = Use_rsc "$pair.int read WAVELENGTH";

if($rlks != 1){
  die "make_sim: This script assumes single look data input\n";
}

##########################
Message "Building ORRM file";
##########################
chdir $sim_dir;
# increased padding of extracted orbit data per Matt Pritchard
#$utc0=$first_line_utc-400;
#$utc1=$first_line_utc+$length*$delta_line_utc+400;
$utc0=$first_line_utc-100; # Sentinel-1
$utc1=$first_line_utc+$length*$delta_line_utc+100;

if ($do_orrm){
  `$INT_SCR/make_orrm.pl $year$month$day \\
                         $utc0           \\
                         $utc1           \\
                         $sat            \\
                         $orbit_type     \\
                         $hdrdate > ${sim_name}.orrm`;
  Status "make_orrm.pl";
}

########################################
Message "Reading resource file: $DEM.rsc";
########################################

$DEM_width    = Use_rsc "$DEM read WIDTH";        
$DEM_length   = Use_rsc "$DEM read FILE_LENGTH";        
$DEM_x_first  = Use_rsc "$DEM read X_FIRST";
$DEM_y_first  = Use_rsc "$DEM read Y_FIRST";
$DEM_x_step   = Use_rsc "$DEM read X_STEP";
$DEM_y_step   = Use_rsc "$DEM read Y_STEP";
$DEM_z_scale  = Use_rsc "$DEM read Z_SCALE";
$DEM_z_offset = Use_rsc "$DEM read Z_OFFSET";
$DEM_datum    = Use_rsc "$DEM read DATUM";

####################################
Message "Creating slope file";
####################################
`$INT_SCR/gradient.pl $DEM $SLP`;
Status "gradient.pl";

#####################################################
Message "Writing resource file: ${sim_name}_raw.hgt.rsc";
#####################################################
$sim_width     = int($width/$Rlooks);
$sim_length    = int($length/$Rlooks);
$sim_dr        = $range_pixel_size*$Rlooks;
$sim_dz        = $azimuth_pixel_size*$Rlooks; 
$sim_dz_ground = $sim_dz*$rt/($rt+$h);
$sim_dt        = $delta_line_utc*$Rlooks;

$xmax          = $sim_width-1;
$ymax          = $sim_length-1;
$Alooks        = $alks*$Rlooks;

Use_rsc "${sim_name}_raw.hgt write WIDTH              $sim_width";
Use_rsc "${sim_name}_raw.hgt write FILE_LENGTH        $sim_length";
Use_rsc "${sim_name}_raw.hgt write XMIN               0";
Use_rsc "${sim_name}_raw.hgt write XMAX               $xmax";
Use_rsc "${sim_name}_raw.hgt write YMIN               0";
Use_rsc "${sim_name}_raw.hgt write YMAX               $ymax";
Use_rsc "${sim_name}_raw.hgt write RANGE_PIXEL_SIZE   $sim_dr";
Use_rsc "${sim_name}_raw.hgt write AZIMUTH_PIXEL_SIZE $sim_dz";
Use_rsc "${sim_name}_raw.hgt write AZIMUTH_PIXEL_GROUND $sim_dz_ground"; # added EJF 06/3/23
Use_rsc "${sim_name}_raw.hgt write DELTA_LINE_UTC     $sim_dt";
Use_rsc "${sim_name}_raw.hgt write FILE_START         1";
Use_rsc "${sim_name}_raw.hgt write DOPPLER_RANGE0     $dop_rng0";
Use_rsc "${sim_name}_raw.hgt write DOPPLER_RANGE1     $dop_rng1";
Use_rsc "${sim_name}_raw.hgt write DOPPLER_RANGE2     $dop_rng2";
Use_rsc "${sim_name}_raw.hgt write DOPPLER_RANGE3     $dop_rng3";
Use_rsc "${sim_name}_raw.hgt write HEIGHT             $h";
Use_rsc "${sim_name}_raw.hgt write EARTH_RADIUS       $rt";
Use_rsc "${sim_name}_raw.hgt write STARTING_RANGE     $r0";
Use_rsc "${sim_name}_raw.hgt write RAW_DATA_RANGE     $r0_raw";
Use_rsc "${sim_name}_raw.hgt write WAVELENGTH         $wvl";
Use_rsc "${sim_name}_raw.hgt write TIME_SPAN_YEAR     $time_span_year";
Use_rsc "${sim_name}_raw.hgt write SQUINT             $squint";
Use_rsc "${sim_name}_raw.hgt write FIRST_LINE_UTC     $first_line_utc";
Use_rsc "${sim_name}_raw.hgt write ORBIT_DIRECTION    $direction";
Use_rsc "${sim_name}_raw.hgt write ORBIT_NUMBER       $orbit_number";
Use_rsc "${sim_name}_raw.hgt write DATE               $date";
Use_rsc "${sim_name}_raw.hgt write FIRST_LINE_YEAR          $year";
Use_rsc "${sim_name}_raw.hgt write FIRST_LINE_MONTH_OF_YEAR $month";
Use_rsc "${sim_name}_raw.hgt write FIRST_LINE_DAY_OF_MONTH  $day";
Use_rsc "${sim_name}_raw.hgt write PLATFORM                 $sat";
Use_rsc "${sim_name}_raw.hgt write RLOOKS              $Rlooks";
Use_rsc "${sim_name}_raw.hgt write ALOOKS              $Alooks";

############################################
Message "Writing IntSim input_file: IntSim.in";
############################################
$r0_km      = $r0/1000;
$r0_raw_km  = $r0_raw/1000;
$squint90   = 90 - $squint;
$projection = Use_rsc "$DEM read PROJECTION";

# Set parameters for UTM or LatLon
if ($projection =~ /UTM/){
  $utm_zone = $'; ### stuff after UTM in "PROJECTION"
  $projection = "UTM";
}
else {### For lat/lon
  $projection = "LL";
  $utm_zone = 11; ##dummy number, just need something or IntSim crashes
}

open INT, ">IntSim.in";
print INT <<END;
Digital Elevation Model Filename                      (-) = $DEM
Slope Filename                                        (-) = $SLP
ORRM formatted filename                               (-) = ${sim_name}.orrm
Height in simulated range,doppler coordinates         (-) = ${sim_name}_raw.hgt
Coordinates of simulated range,doppler in map format  (-) = /dev/null
GPS vector inputs filename                            (-) = GPS.in
GPS vector mapped to radar LOS output filename        (-) = GPS.out
Rectified height in simulated coordinates             (-) = simfile
Rectified height in simulated coordinates with GPS    (-) = simoutfile
Dimensions of rectified height file                 (-,-) = $sim_width $sim_length
DEM projection                                        (-) = $projection
DEM datum                                             (-) = $DEM_datum

DEM corner easting                                    (m) = $DEM_x_first
DEM easting spacing                                   (m) = $DEM_x_step
DEM total easting pixels                              (-) = $DEM_width 
DEM UTM zone                                          (-) = $utm_zone

DEM corner northing                                   (m) =  $DEM_y_first
DEM northing spacing                                  (m) =  $DEM_y_step
DEM total northing pixels                             (-) =  $DEM_length

DEM corner latitude                                 (deg) = $DEM_y_first
DEM latitude spacing                                (deg) = $DEM_y_step
DEM total latitude pixels                             (-) = $DEM_length

DEM corner longitude                                (deg) = $DEM_x_first
DEM longitude spacing                               (deg) = $DEM_x_step
DEM total longitude pixels                            (-) = $DEM_width

DEM corner s                                          (m) = 0.
DEM s spacing                                         (m) = 0.
DEM total s pixels                                    (-) = 0.

DEM corner c                                          (m) = 0.
DEM c spacing                                         (m) = 0.
DEM total c pixels                                    (-) = 0.

SCH Peg lat                                         (deg) = 0.
SCH Peg lon                                         (deg) = 0.
SCH Heading                                         (deg) = 0.

DEM height bias                                       (-) = $DEM_z_offset
DEM height scale factor                               (-) = $DEM_z_scale
DEM Northing bias                                     (-) = 0.
DEM Easting bias                                      (-) = 0.
Range output reference                               (km) = $r0_km
Time  output reference                              (sec) = $first_line_utc
Range output spacing                                  (m) = $sim_dr
Azimuth output spacing                                (m) = $sim_dz_ground 
Number of range pixels                                (-) = $sim_width
Number of azimuth pixels                              (-) = $sim_length

Nominal squint angle from heading                   (deg) = $squint90
GPS scale factor                                      (-) = 1.
Datum conversion bias vector                          (m) = 0. 0. 0. 
Affine matrix row 1                                   (-) = 1 0
Affine matrix row 2                                   (-) = 0 1
Affine offset vector                                  (-) = 0 0
Do simulation?                                        (-) = yes
Do mapping?                                           (-) = no
Do GPS mapping?                                       (-) = no
Output skip factor                                    (-) = $skip
Search method                                         (-) = DOPPLER
Range reference for Doppler                          (km) = $r0_km ! $r0_raw_km
Range spacing for Doppler                             (m) = $range_pixel_size
Doppler coefficients                            (-,-,-,-) = $dop_rng0 $dop_rng1 $dop_rng2 $dop_rng3
Radar Wavelength                                      (m) = $wvl
Radar PRF                                             (-) = $prf
Desired center latitude                             (deg) = 0.0
Desired center longitude                            (deg) = 0.0
END
    close(INT);


############################################
Message "IntSim IntSim.in > IntSim.out";
############################################
`touch GPS.in simfile`;
`$INT_BIN/IntSim IntSim.in > IntSim.out`;
Status "IntSim";

open INT, "IntSim.out" or die "Can't read IntSim.out\n";
$i = 0;
while (<INT>){
  if ($_ =~ /First DEM pixel/){
    @array = split /\s+/, $_;
    $trans_y0 = "$array[8]";
    $trans_x0 = "$array[9]";
  }
  if ($_ =~ /Last  DEM pixel/){
    @array = split /\s+/, $_;
    $trans_y1 = "$array[8]";
    $trans_x1 = "$array[9]";
  }
  if ($_ =~ /Spacecraft heading/){
    @array = split /\s+/, $_;
    $heading_deg = "$array[5]";
  }
  if ($_ =~ /Slant range/){
    @array = split /\s+/, $_;
    $range_ref[$i] = "$array[5]";
  }
  if ($_ =~ /Look angle/){
    @array = split /\s+/, $_;
    $look_ref[$i] = "$array[5]";
  }
  if ($_ =~ /Latitude and longitude/){
    @array = split /\s+/, $_;
    $lat_ref[$i] = "$array[6]";
    $lon_ref[$i] = "$array[7]";
    $i++;
  }
}
close (INT);

Use_rsc "${sim_name}_raw.hgt write HEADING_DEG  $heading_deg";
Doc_rsc(
 RSC_Tip => 'Spacecraft heading',
 RSC_Derivation => q[
   'Spacecraft heading (deg)' value
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);



Use_rsc "${sim_name}_raw.hgt write RGE_REF1     $range_ref[0]";
Doc_rsc(
 RSC_Tip => 'Corner 1 Slant range',
 RSC_Derivation => q[
   'Slant range' value
   for 'Corner 1 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Appears to only be used in diffnsim.pl to determine if
    a .hgt.rsc file contains *REF[1234] keywords to
    be propagated to $diffile (eg. 930110-950523-sim_PRC_4rlks.int.rsc)
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:kilometer',
);


Use_rsc "${sim_name}_raw.hgt write LOOK_REF1    $look_ref[0]";
Doc_rsc(
 RSC_Tip => 'Corner 1 Look angle',
 RSC_Derivation => q[
   'Look angle' value
   for 'Corner 1 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LAT_REF1     $lat_ref[0]";
Doc_rsc(
 RSC_Tip => 'Corner 1 Latitude',
 RSC_Derivation => q[
   'Latitude' value of 'Latitude and longitude'
   for 'Corner 1 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LON_REF1     $lon_ref[0]";
Doc_rsc(
 RSC_Tip => 'Corner 1 Longitude',
 RSC_Derivation => q[
   'longitude' value of 'Latitude and longitude'
   for 'Corner 1 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);




Use_rsc "${sim_name}_raw.hgt write RGE_REF2     $range_ref[1]";
Doc_rsc(
 RSC_Tip => 'Corner 2 Slant range',
 RSC_Derivation => q[
   'Slant range' value
   for 'Corner 2 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:kilometer',
);


Use_rsc "${sim_name}_raw.hgt write LOOK_REF2    $look_ref[1]";
Doc_rsc(
 RSC_Tip => 'Corner 2 Look angle',
 RSC_Derivation => q[
   'Look angle' value
   for 'Corner 1 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LAT_REF2     $lat_ref[1]";
Doc_rsc(
 RSC_Tip => 'Corner 2 Latitude',
 RSC_Derivation => q[
   'Latitude' value of 'Latitude and longitude'
   for 'Corner 2 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LON_REF2     $lon_ref[1]";
Doc_rsc(
 RSC_Tip => 'Corner 2 Longitude',
 RSC_Derivation => q[
   'longitude' value of 'Latitude and longitude'
   for 'Corner 2 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);




Use_rsc "${sim_name}_raw.hgt write RGE_REF3     $range_ref[2]";
Doc_rsc(
 RSC_Tip => 'Corner 3 Slant range',
 RSC_Derivation => q[
   'Slant range' value
   for 'Corner 3 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:kilometer',
);


Use_rsc "${sim_name}_raw.hgt write LOOK_REF3    $look_ref[2]";
Doc_rsc(
 RSC_Tip => 'Corner 3 Look angle',
 RSC_Derivation => q[
   'Look angle' value
   for 'Corner 3 (on ellipsoid)'
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LAT_REF3     $lat_ref[2]";
Doc_rsc(
 RSC_Tip => 'Corner 3 Latitude',
 RSC_Derivation => q[
   'Latitude' value of 'Latitude and longitude'
   for 'Corner 3 (on ellipsoid)'
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LON_REF3     $lon_ref[2]";
Doc_rsc(
 RSC_Tip => 'Corner 3 Longitude',
 RSC_Derivation => q[
   'longitude' value of 'Latitude and longitude'
   for 'Corner 3 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);




Use_rsc "${sim_name}_raw.hgt write RGE_REF4     $range_ref[3]";
Doc_rsc(
 RSC_Tip => 'Corner 4 Slant range',
 RSC_Derivation => q[
   'Slant range' value
   for 'Corner 4 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:kilometer',
);


Use_rsc "${sim_name}_raw.hgt write LOOK_REF4    $look_ref[3]";
Doc_rsc(
 RSC_Tip => 'Corner 4 Look angle',
 RSC_Derivation => q[
   'Look angle' value
   for 'Corner 4 (on ellipsoid)'
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LAT_REF4     $lat_ref[3]";
Doc_rsc(
 RSC_Tip => 'Corner 4 Latitude',
 RSC_Derivation => q[
   'Latitude' value of 'Latitude and longitude'
   for 'Corner 4 (on ellipsoid)'
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);


Use_rsc "${sim_name}_raw.hgt write LON_REF4     $lon_ref[3]";
Doc_rsc(
 RSC_Tip => 'Corner 4 Longitude',
 RSC_Derivation => q[
   'longitude' value of 'Latitude and longitude'
   for 'Corner 4 (on ellipsoid)'
   in file IntSim.out
   produced by IntSim run by make_sim.pl and make_geomap.pl
   ],
 RSC_Comment => q[
    Value does not appear to be used anywhere.
   ],
 RSC_Type => Real,
 RSC_Unit => 'SI:degree',
);



############################################################
Message "Writing Aik_resample input_file: Aik_resample.in";
############################################################
$win_size=64/$Rlooks;
if ($Rlooks < 4) {
  $pad_size=3;  # need more padding to avoid NaNs in high relief EJF 2006/3/15
}
else {
  $pad_size=1;  # only one needed for 4rlks or greater EJF 2006/3/16
}

open RESAMP, ">Aik_resample.in" or die "Can't write to ffile_resamp.in\n";
print RESAMP <<END;
RMG input file                             (-)    =  ${sim_name}_raw.hgt
RMG output file                            (-)    =  ${sim_name}$Lint.hgt
Number of pixels across                    (-)    =  $sim_width 
Number of pixels down                      (-)    =  $sim_length
Start and end pixels to process across     (-,-)  =  1 $sim_width
Start and end pixels to process down       (-,-)  =  1 $sim_length
Block size                                 (-)    =  $win_size
Pad size                                   (-)    =  $pad_size
Threshold                                  (-)    =  .9
Number of points for partials              (-)    =  3
Print flag                                 (-)    =  0
END
    close(RESAMP);

`cp ${sim_name}_raw.hgt.rsc ${sim_name}$Lint.hgt.rsc`;
`$INT_BIN/Aik_resample Aik_resample.in`;
Status "Aik_resample";
####################################
Message "Doing looked down height map";
####################################
`$INT_SCR/look.pl ${sim_name}$Lint.hgt $lookdown`;
Status "look.pl";

exit 0;

=pod

=head1 USAGE

B<make_sim.pl> I<sim_name sim_dir pair Rlooks Rlooks_sml orbit_type DEM>

=head1 FUNCTION

builds the simulation files

=head1 ROUTINES CALLED

make_orrm.pl

gradient.pl

IntSim

length.pl

Aik_resample

look.pl

=head1 CALLED BY

process.pl

=head1 FILES USED

I<DEM>

I<DEM>.rsc

=head1 FILES CREATED

I<SLP>

I<SLP>.rsc

I<sim_name>_raw.hgt

I<sim_name>_raw.hgt.rsc

I<sim_name>_I<Rlooks>looks.hgt.rsc

I<sim_name>_I<Rlooks>looks.hgt

I<sim_name>_I<lookdown>looks.hgt.rsc

I<sim_name>_I<lookdown>looks.hgt

IntSim.in

IntSim.out

simfile

simoutfile

Aik_resample.in

GPS.in

GPS.out

=head1 HISTORY

Shell Script : Francois ROGEZ 96/98
Perl  Script : Rowena LOHMAN 04/18/98
Modifications: Frederic CRAMPE, Oct 13, 1998

=head1 LAST UPDATE

Frederic CRAMPE, Aug 26, 1999

=cut
