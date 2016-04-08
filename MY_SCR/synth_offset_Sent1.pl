#!/usr/bin/perl
### synth_offset.pl


####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V1.1 -- Feb. 2015
###   grandin@ipgp.fr
####################################################
### Do offset calculation
####################################################
### Note : this file is modified from ROI_PAC software
####################################################



$] >= 5.004 or die "Perl version must be >= 5.004 (Currently $]).\n";

use Env qw(INT_SCR INT_BIN);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;

###Usage info/check
sub Usage{

`$INT_SCR/pod2man.pl  $INT_SCR/synth_offset.pl`;
exit 1;
}
@ARGV == 5  or Usage();
@args = @ARGV;

$hgt         = shift;
$cor         = shift;
$MPI_PARA    = shift;
$NUM_PROC    = shift;
$ROMIO       = shift;

$DX          = 0;
$DY          = 0;

#################
Message "Checking I/O";
#################
@Infiles  = ($cor, $hgt);
@Outfiles = ("ampmag_cull.off");
&IOcheck(\@Infiles, \@Outfiles);
Log("synth_offset.pl", @args);

#$search_max_gross = 64;  # was 128 EJF 2007/8/20
#$search_max_fine = 16;  # was 16 EJF 2007/8/20

$search_max_gross = 64;  # was 128 EJF 2007/8/20
$search_max_fine = 16;  # was 16 EJF 2007/8/20

############################################
Message "Getting gross offset";
############################################
`$INT_SCR/offset.pl $cor   \\
                    $hgt   \\
                    ampmag_gross   \\
                    2 \\
                    rmg            \\
                    $DX            \\
                    $DY            \\
                    1. 1.          \\
                    30 20 128 $search_max_gross \\
                    $MPI_PARA      \\
                    $NUM_PROC      \\
                    $ROMIO     `;
#                    100 20 64 $search_max_gross \\
#                    60 80 128 $search_max_gross \\
Status "offset.pl";
################################
Message "Culling gross offset";
################################
$origfile = "ampmag_gross.off";
$cullfile = "ampmag_gross_cull.off";
$dumpfile = "fitoff_gross.out";

`$INT_BIN/fitoff $origfile $cullfile 1.0 1.0 10 > $dumpfile`;

open CULL, "$cullfile" or
die "Can't open $cullfile\n";
open GX, ">gross_x" or die "Can't write to gross_x\n";
open GY, ">gross_y" or die "Can't write to gross_y\n";
while (<CULL>){
  @line = split /\s+/, $_;
  push @X, $line[2];
  push @Y, $line[4]; 
}
close (CULL);

@X = sort @X;
@Y = sort @Y;

foreach (@X) {print GX "$_\n";}
foreach (@Y) {print GY "$_\n";}

# Gets median of values in gross_*

$gox= Median(\@X);
$goz= Median(\@Y);

$gox or $gox = 0;
$goz or $goz = 0;
 
################################
Message "Getting the fine offset";
################################
`$INT_SCR/offset.pl $cor                \\
                    $hgt                \\
                    ampmag              \\
                    2  \\
                    rmg                 \\
                    $gox   \\
                    $goz \\
                    1. 1. \\
                    100 40 128 $search_max_fine \\
                    $MPI_PARA      \\
                    $NUM_PROC      \\
                    $ROMIO     `;
Status "offset.pl";
#########################################
Message "Culling points";
#########################################
$origfile = "ampmag.off";
$cullfile = "ampmag_cull.off";
$dumpfile = "cull.out";

`$INT_BIN/fitoff $origfile $cullfile 1.0 1.0 50 > $dumpfile`;

### Check to make sure number of culled points is greater than 50
open CULL, "$cullfile";
for ($i=1; $line = <CULL>; $i++){}
$i > 50 or die "Too few points left after culling, $i left\n";

print STDERR "$i points left after culling\n";
 
close(CULL);

exit 0;
 
=pod

=head1 USAGE

B<synth_offset.pl> I<slook hgt cor nlook>

=head1 FUNCTION

Finds the offset field between the synthetic and satellite images

=head1 ROUTINES CALLED

offset.pl

fitoff

=head1 CALLED BY

process.pl

=head1 FILES USED

I<cor>

I<hgt>

I<cor>.rsc

I<hgt>.rsc

=head1 FILES CREATED

ampmag_gross.in

ampmag_gross.out

ampmag_gross.off

ampmag_gross.off.rsc

ampmag.in

ampmag.out

ampmag.off

ampmag.off.rsc

ampmag_gross_cull.off

fitoff_gross.out

ampmag_cull.off

cull.out

gross_x

gross_y

=head1 HISTORY

Shell Script : Francois ROGEZ 96/98

Perl  Script : Rowena LOHMAN 04/18/98
Mark Simons, 01/05/01

=head1 LAST UPDATE

Eric Fielding, Aug. 20, 2007

=cut
