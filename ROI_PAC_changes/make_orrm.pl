#!/usr/bin/perl
### make_orrm.pl

$] >= 5.004 or die "Perl version must be >= 5.004 (Currently $]).\n";

use Env qw(INT_SCR);
use lib "$INT_SCR";  #### Location of Generic.pm
use Generic;

###Usage info/check
sub Usage{

`$INT_SCR/pod2man.pl  $INT_SCR/make_orrm.pl`;
exit 1;
}
@ARGV >= 5 or Usage();
Log("make_orrm.pl", @ARGV);

$date       = shift;
$utc_min    = shift;
$utc_max    = shift;
$sat        = shift;
$orbit_type = shift;
$hdrdate    = shift;

$orbit_type =~ /(PRC|ODR|HDR)/ or die "Orbit type must be PRC, ODR or HDR\n";

Message "$utc_min";
Message "$utc_max";

$utc     = int($utc_min/30)*30;
$utc_max = int(($utc_max+31)/30)*30;
#$utc     = int($utc_min-40); # Sentinel-1
#$utc_max = int($utc_max+40);

Message "$utc";
Message "$utc_max";
#exit 1;

while ($utc < $utc_max){
  @list = split /\s+/, `$INT_SCR/state_vector.pl $date \\
                                                 $utc \\
                                                 $sat \\
                                                 $orbit_type \\
                                                 $hdrdate`;
  Status "state_vector.pl";
  printf("999     %8d   0 %13.6f %13.6f %13.6f %14.10f %14.10f %14.10f 0\n", $utc*1000, $list[5]/1000, $list[6]/1000, $list[7]/1000, $list[8]/1000, $list[9]/1000, $list[10]/1000);
#  $utc=int($utc+30);
  $utc=$utc+1; # Sentinel-1
}
exit 0;

=pod

=head1 USAGE

B<make_orrm.pl> I<date utc_min utc_max sat orbit_type>

=head1 FUNCTION

Give position and velocity at requested epoch in earth fixed coordinates

=head1 ROUTINES CALLED

state_vector.pl

=head1 CALLED BY

make_sim.pl

=head1 FILES USED

none

=head1 FILES CREATED

none

=head1 HISTORY

Shell Script : Francois ROGEZ 96/98
Perl  Script : Rowena LOHMAN 04/18/98
Modifications: Frederic CRAMPE, May 22, 1998

=head1 LAST UPDATE

Frederic CRAMPE, Aug 26, 1999

=cut
