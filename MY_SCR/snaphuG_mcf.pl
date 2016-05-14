#!/usr/bin/perl
### snaphuG.pl

$] >= 5.004 or die "Perl version must be >= 5.004 (Currently $]).\n";

use Env qw(INT_SCR INT_BIN MY_SCR MY_BIN);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;


###Usage info/check
sub Usage{

`$INT_SCR/pod2man.pl  $MY_SCR/snaphuG.pl`;
exit 1;
}

@ARGV >= 4 or Usage();
@args = @ARGV;

$snaphumode = shift;   # mode: "topo", "defo", or "smooth"
$intfile    = shift;   # complex input interferogram file
$unwfile    = shift;   # unwrapped output file  ### could be set from int file ###
$corfile   = shift;   # correlation file
$mk_mask    = shift or $mk_mask = "no";   # make a mask for snaphu "phs" or "cor", or anything else for not creating mask
$threshold  = shift or $threshold = 0.2;  # threshold for phase sigma or correlation mask
$man_mask   = shift or $man_mask = "NULL";# manual mask input file (rmg) to mask out areas before unwrapping

Message "$snaphumode $intfile $unwfile $corfile $mk_mask $threshold $man_mask";

####### Checking syntax ###########
if($snaphumode eq "topo"){
    $snaphumode="TOPO";
}elsif($snaphumode eq "defo"){
    $snaphumode="DEFO";
    $defomax_cycle=2.0; # default to two cycles for now, should make input parameter
}elsif($snaphumode eq "smooth"){
    $snaphumode="SMOOTH";
}
if(($snaphumode ne "TOPO") 
   && ($snaphumode ne "DEFO") 
   && ($snaphumode ne "SMOOTH")){
    die "unrecognized snaphu mode $snaphumode";
}
####################################

####### Setting file names #########
($introot,$ext) = split /.int/,$intfile;   
$intrsc  = "$intfile.rsc";   
$intfilermg = "${introot}.rmg";   
$intrmgrsc = "$intfilermg.rsc"; 
($corroot,$ext) = split /.cor/,$corfile;
$corrsc  = "$corfile.rsc";
($unwroot,$ext) = split /.unw/,$unwfile;                  # could be introot???
$unwrsc = "${unwfile}.rsc";
$corfile_trim = "${corroot}_trim.cor";
$cor_trimrsc  = "${corfile_trim}.rsc";
$maskfile  = "${introot}_unwmask.byt";
$maskrsc  = "${maskfile}.rsc";

####################################

####################################
if($snaphumode eq "TOPO"){
    @ARGV >= 2 or Usage();		# this part probably does not work
#                                       # amplitude should be taken from .cor file
    $amproot      = shift;
    $ampfile      = "$amproot.amp";
    $amprsc       = "$ampfile.rsc";
    $baselineroot = shift;
    $baselinersc  = "$baselineroot.rsc";
    @Infiles  = ("$intfile", "$intrsc",
		 "$corfile", "$corrsc",
		 "$ampfile", "$amprsc",
		 "$baselinersc");
}else{
    @Infiles  = ("$intfile", "$intrsc",
		 "$corfile", "$corrsc");
}
$snaphuopts   = shift;        # snaphu format config file
if($snaphuopts){
    @Infiles  = (@Infiles, "$snaphuopts");
}

@Outfiles = ("$unwfile", "$unwrsc",
	     "$maskfile", "$maskrsc");


#######################
Message "Checking I/O";
#######################

&IOcheck(\@Infiles, \@Outfiles);
Log("snaphuG.pl", @args);
system("$INT_SCR/length.pl $intfile");

#########################################
Message "reading resource file: $intrsc";
#########################################
$width  = Use_rsc "$intfile read WIDTH";
$length = Use_rsc "$intfile read FILE_LENGTH";
$start  = Use_rsc "$intfile read FILE_START";
$xmin   = Use_rsc "$intfile read XMIN";
$xmax   = Use_rsc "$intfile read XMAX";
$ymin   = Use_rsc "$intfile read YMIN";
$ymax   = Use_rsc "$intfile read YMAX";
$altitude          = Use_rsc "$intfile read HEIGHT";
$earthradius       = Use_rsc "$intfile read EARTH_RADIUS";
$nearrange         = Use_rsc "$intfile read STARTING_RANGE";
$dr                = Use_rsc "$intfile read RANGE_PIXEL_SIZE";
$da_flight         = Use_rsc "$intfile read AZIMUTH_PIXEL_SIZE"; 
$prf               = Use_rsc "$intfile read PRF";
$velocity          = Use_rsc "$intfile read VELOCITY";
$fs                = Use_rsc "$intfile read RANGE_SAMPLING_FREQUENCY";
$taup              = Use_rsc "$intfile read PULSE_LENGTH";
$chirpslope        = Use_rsc "$intfile read CHIRP_SLOPE";
$lambda            = Use_rsc "$intfile read WAVELENGTH";
$nlooksrange       = Use_rsc "$intfile read RLOOKS";
$nlooksaz          = Use_rsc "$intfile read ALOOKS";

# Adjusting ymax and xmax for inconsistencies in ROIPAC
if ($ymax > $length) {
    $ymax = $length-1;
    Use_rsc "$intfile write YMAX $ymax";
}
if ($xmax == $width) {
    $xmax = $width-1;
    Use_rsc "$intfile write XMAX $xmax";
}

#########################################
Message "reading resource file: $corrsc";
#########################################
system("$INT_SCR/length.pl $corfile");
$corwidth  = Use_rsc "$corfile read WIDTH";
$corlength = Use_rsc "$corfile read FILE_LENGTH";

Message "$intfile length from stat $length";
Message "$corfile length from stat $corlength";


#####
Message "corlength: $corlength, intlength: $length";
#####

# adjust *.cor length in case longer than intfile (i.e. in the case of do_sim=="no" 
# resulting interferogram may be shorter than original interferogram or correlation file).
# length is measured from actual file size because resource file may not be accurate (G.P.).
$corsize = -s "$corfile" or die "$corfile has zero size\n";
$true_corlength=$corsize/$width/8;
if ($true_corlength > $length) {
#########################################
Message "Trimming cor file: $corfile";
#########################################
Message "true_corlength: $true_corlength";
#########################################

    $blocksize=8.0*$width;
    `dd if=$corfile of=$corfile_trim bs=$blocksize count=$length`;
    Status "dd";

    $nymax = $length-1;
    `cp $corrsc $cor_trimrsc`;
    Use_rsc "$corfile_trim write FILE_LENGTH           $length";
    Use_rsc "$corfile_trim write YMAX                  $nymax";
}else{
    $corfile_trim = "$corfile";
    $cor_trimrsc  = "$corrsc";
}

if ($mk_mask eq "phs") {
    #########################################
    Message "making mask from phase variance variance value: $threshold";
    #########################################
    `make_mask.pl $introot temp_mask 5.0e-5 0 5 5 $threshold`;
    Status "make_mask";
    `mask_int.pl $intfile temp_mask.rmg  ${introot}_mask.int 1`; # 1 sets both amp and phs to 0
    $intfile =  "${introot}_mask.int";

}elsif($mk_mask eq "cor") {
    #########################################
    Message "making mask from $corroot.cor threshold: $threshold";
    #########################################
    `cor_mask.pl $corroot temp_mask $threshold`;
    Status "cor_mask";
    `mask_int.pl $intfile temp_mask.rmg  ${introot}_mask.int 1`;
    $intfile =  "${introot}_mask.int";
}

if ($man_mask ne "NULL") {
    #########################################
    Message "Adding manual mask $man_mask";
    #########################################
    `mask_int.pl $intfile $man_mask ${introot}_man_mask.int 1`;
    $intfile =  "${introot}_man_mask.int";
}

#########################################
Message "unwrapping masked interferogram file: $intfile";
#########################################

    

#adjust limits  for snaphu convention 
#if ($xmin == 0) {$xmin += 1;} # add one for snaphu convention
#if ($ymin == 0) {$ymin += 1;} # add one for snaphu convention
if ($xmin == 0) {$xmin += 1; $xmax += 1;} # add one for snaphu convention
if ($ymin == 0) {$ymin += 1; $ymax += 1;} # add one for snaphu convention

## Get baseline from baseline file if in topo mode
if($snaphumode eq "TOPO"){
    Message "reading baseline from file: $baselinersc";
    # bh positive to the left, regadless of look direction
    # antside = 1 for left looking, = -1 for right looking
    #$bh      = Use_rsc "$baselinersc read H_BASELINE_TOP_PRC";
    #$bv      = Use_rsc "$baselinersc read V_BASELINE_TOP_PRC";
    # Use last entries in $baselinersc that begin with {H,V}_BASELINE_TOP
    $bh = &Match_rsc_last("$baselinersc H_BASELINE_TOP");
    $bv = &Match_rsc_last("$baselinersc V_BASELINE_TOP");
    $antside = Use_rsc "$intfile read ANTENNA_SIDE";
}else{
    if(($snaphumode eq "DEFO") && !$defomax_cycle){
	$snaphumode="SMOOTH";
    }
    $bh=0;
    $bv=0;
}

####
#### REFINE!!! #############################################################
####
#### typical ERS value; should read from rsc, but not yet written by ROI_PAC
####
#$azres=6.0; 
$azres=$da_flight/$nlooksaz; 


## compute derived parameters

$speed_of_light    = 299792458;
$pi                = atan2(0,-1);
$da=$da_flight*($earthradius/($earthradius+$altitude));
$rangeres=abs($speed_of_light/(2*$chirpslope*$taup));
#$nlooksrange=int($dr*($fs/($speed_of_light/2)) + 0.5);
#$nlooksaz=int($da*$prf/$velocity*($earthradius+$altitude)/$earthradius + 0.5); 
####
#### REFINE!!! #############################################################
####
#### 25 * number of initial azimuth looks might be slightly more general
####
#$ncorrlooksreal=125; ##### 5*5 box hardcoded into make_cor.pl (?) 
$ncorrlooksreal=$nlooksrange*$nlooksaz; ##### 5*5 box hardcoded into make_cor.pl (?) 
$ncorrlooks=$ncorrlooksreal*($dr/$nlooksrange)*($da/$nlooksaz)
    /($rangeres*$azres);
$baseline=sqrt($bh*$bh+$bv*$bv);
$baselineangle_deg=(180/$pi)*atan2($bv,$antside*$bh);
$transmitmode="REPEATPASS";    # no single antenna transmit in ROI_PAC 


##################################################################
Message "creating snaphu configuration file: $introot.snaphuconf";
##################################################################

open(SNAPHUCONF,">$introot.snaphuconf") 
    or die "can't open file file $introot.snaphuconf";

printf(SNAPHUCONF "%-20s %s\n","STATCOSTMODE","$snaphumode");
printf(SNAPHUCONF "%-20s %s\n","INFILE","$intfile");
printf(SNAPHUCONF "%-20s %d\n","LINELENGTH",$width);
printf(SNAPHUCONF "%-20s %s\n","OUTFILE","$unwfile");
#printf(SNAPHUCONF "%-20s %s\n","CORRFILE","$corfile");
printf(SNAPHUCONF "%-20s %s\n","CORRFILE","$corfile_trim");
if($snaphumode eq "TOPO"){
    printf(SNAPHUCONF "%-20s %s\n","AMPFILE","$ampfile");
}
printf(SNAPHUCONF "%-20s %s\n","LOGFILE","$introot.snaphulog");
printf(SNAPHUCONF "\n");

# added this for DEFO mode EJF 05/3/3
if($defomax_cycle) {
  printf(SNAPHUCONF "%-20s %d\n","DEFOMAX_CYCLE","$defomax_cycle");
}

# added this to select a piece of input EJF 2004/12/8
#printf(SNAPHUCONF "%-20s %d\n","PIECEFIRSTROW",$ymin);
#printf(SNAPHUCONF "%-20s %d\n","PIECEFIRSTCOL",$xmin);
#printf(SNAPHUCONF "%-20s %d\n","PIECENROW",($ymax-$ymin+1) );
#printf(SNAPHUCONF "%-20s %d\n","PIECENCOL",($xmax - $xmin+1) );

printf(SNAPHUCONF "%-20s %f\n","ALTITUDE",$altitude);
printf(SNAPHUCONF "%-20s %f\n","EARTHRADIUS",$earthradius);
printf(SNAPHUCONF "%-20s %f\n","NEARRANGE",$nearrange);
printf(SNAPHUCONF "%-20s %f\n","BASELINE",$baseline);
printf(SNAPHUCONF "%-20s %f\n","BASELINEANGLE_DEG",$baselineangle_deg);
printf(SNAPHUCONF "%-20s %s\n","TRANSMITMODE",$transmitmode);
printf(SNAPHUCONF "%-20s %f\n","DR",$dr);
printf(SNAPHUCONF "%-20s %f\n","DA",$da);
printf(SNAPHUCONF "%-20s %f\n","RANGERES",$rangeres);
printf(SNAPHUCONF "%-20s %f\n","AZRES",$azres);
printf(SNAPHUCONF "%-20s %f\n","LAMBDA",$lambda);
printf(SNAPHUCONF "%-20s %d\n","NLOOKSRANGE",$nlooksrange); 
printf(SNAPHUCONF "%-20s %d\n","NLOOKSAZ",$nlooksaz);       
printf(SNAPHUCONF "%-20s %d\n","NLOOKSOTHER",1);            
printf(SNAPHUCONF "%-20s %f\n","NCORRLOOKS",$ncorrlooks);   
printf(SNAPHUCONF "\n");

printf(SNAPHUCONF "%-20s %s\n","CONNCOMPFILE",$maskfile);
printf(SNAPHUCONF "%-20s %d\n","MINCONNCOMPFRAC",0.005);  #  Minimum size of a single connected component, as a fraction (double)
                                                          #  of the total number of pixels in tile.
printf(SNAPHUCONF "%-20s %d\n","MAXNCOMPS",20);
printf(SNAPHUCONF "\n");

printf(SNAPHUCONF "%-20s %s\n","INFILEFORMAT","COMPLEX_DATA");
printf(SNAPHUCONF "%-20s %s\n","OUTFILEFORMAT","ALT_LINE_DATA");
printf(SNAPHUCONF "%-20s %s\n","CORRFILEFORMAT","ALT_LINE_DATA");
if($snaphumode eq "TOPO"){
    printf(SNAPHUCONF "%-20s %s\n","AMPFILEFORMAT","ALT_SAMPLE_DATA");
}
printf(SNAPHUCONF "%-20s %s\n","VERBOSE","FALSE");
printf(SNAPHUCONF "\n");

close(SNAPHUCONF) or warn "$0: error in closing file $introot.snaphuconf\n";

$stdoutfile = "$introot.snaphuout";
$stderrfile = "$introot.snaphuerr";

#########################
Message "running snaphu";
#########################

## Make rsc files for outputs
Use_rsc "$unwfile merge $intfile";
#Set new size. Should be done only if xmin/xmax/ymin/ymax differ from 0/width-1/0/length-1
$new_width=($xmax-$xmin+1);
$new_file_length=($ymax-$ymin+1);
$new_xmax=($xmax-$xmin); 
$new_ymax=($ymax-$ymin);
#########################################
Message "writing resource file: $unwrsc";
#########################################
Use_rsc "$unwfile write WIDTH                 $new_width";
Use_rsc "$unwfile write FILE_LENGTH           $new_file_length";
Use_rsc "$unwfile write XMIN                  0";
Use_rsc "$unwfile write XMAX                  $new_xmax";
Use_rsc "$unwfile write YMIN                  0";
Use_rsc "$unwfile write YMAX                  $new_ymax";
#Use_rsc "$unwfile write XMIN                  $xmin";
#Use_rsc "$unwfile write XMAX                  $xmax";
#Use_rsc "$unwfile write YMIN                  $ymin";
#Use_rsc "$unwfile write YMAX                  $ymax";

Use_rsc "$maskfile merge $unwfile";

## Create snaphu command line call
$call_snaphu="$MY_BIN/snaphu --mcf -i -f $introot.snaphuconf -v";
if($snaphuopts){
    $call_snaphu="$call_snaphu -f $snaphuopts";
}

## Redirect output (shell syntax: 1> redirects stdout, 2> redirects stderr)
#bash syntax added EJF 05/3/3
$call_snaphu="bash -c '$call_snaphu 1>$stdoutfile 2>$stderrfile'";

## Run it
Message "$call_snaphu";
system "$call_snaphu";
Status "snaphu";


#clean up ### TO BE FINALIZED ####
#`rm ${introot}_man_mask.int*`;
#`rm ${introot}_mask.int*`;
#`rm temp_mask*`;
#`rm pwr phs`;
#`rm $intfilermg`;
#`rm ${intfilermg}.hst`;
#`rm $intrmgrsc`;
#`rm ${intrmgrsc}.hst`;
#`rm $corfile_trim`;
#`rm $cor_trimrsc`;
#`rm ${corfile_trim}.hst`;
#`rm ${cor_trimrsc}.hst`;
#`rm $intfilermg`;
#`rm ${intfilermg}.hst`;
#`rm $intrmgrsc`;
#`rm ${intrmgrsc}.hst`;
#`rm $introot_mask.int`;
#`rm $introot_mask.int.hst`;
#`rm $introot_mask.int.rsc`;
#`rm $introot_mask.int.rsc.hst`;
#`rm $introot_mask.rmg`;
#`rm $introot_mask.rmg.hst`;
#`rm $introot_mask.rmg.rsc`;
#`rm $introot_mask.rmg.rsc.hst`;

exit 0;

#############################################################################

# Usage: Match_rsc_last rsc_prefix string
#
# Reads an rsc file and returns the last parameter whose keyword begins
# with the specified string.

sub Match_rsc_last{

    local(@args);
    local($rscfile);
    local($keystring);
    local($keyword);
    local($value);
    local($line);

    @args = split /\s+/, shift @_;
    $rscfile   = shift @args;
    $keystring = shift @args;
    $rscfile =~ /\.rsc$/ or $rscfile = "$rscfile.rsc";

    open RSCFILE, "$rscfile" or die "Can't read $rscfile\n";
    foreach $line (<RSCFILE>) {
	if ($line =~ /(^$keystring\S+)\s+(\S+)/) {  
	    $keyword = "$1";
	    $value   = "$2";
	}
    } 
    defined $value or warn 
	"No matches of keystring $keystring in file $rscfile, returning 0\n";
    close(RSCFILE) or warn "$0: error in closing file $rscfile\n";
    return($value);

}

#############################################################################


=pod

=head1 USAGE



B<snaphuG.pl> {defo|smooth}  I<intfile unwfile corfile \
  [{phs/cor/no} threshold manual_mask_file/{NULL} opt_snaphu_snaphu_config_file]> 

or

B<snaphuG.pl> topo I<intfileroot unwfileroot maskfileroot corfileroot \
  ampfileroot baselineroot [opt_snaphu_config_file]> 

intfile:  interferogram file  is I<intfile> 
unwfile:  unwrapped output file  is I<unwfile> 
corfile:  correlation file  is I<corfile> 
ampfile:  amplitude file is I<ampfile>
baselinefile: baseline file is I<baselinefile>
snaphuconf:   optional snaphu configuration file is I<snaphuconf>


=head1 FUNCTION

Unwraps an interferogram using snaphu 

=head1 ROUTINES CALLED

snaphu

=head1 CALLED BY

int2filtmaskunwrap.pl

=head1 FILES USED

I<intfile>.int

I<intfile>.int.rsc

I<corfile>.cor

I<corfile>.cor.rsc

=head1 FILES CREATED



=head1 HISTORY

Based on snaphu.pl written by Curtis W. Chen Oct 14, 2002:
and modified by Paul Lundgren and Eric Fielding

=head1 LAST UPDATE

Gilles Peltzer July 17, 2006: 
removed zero_pad stuff 
changed the names of created files and added 
option to input a manual mask

=cut
