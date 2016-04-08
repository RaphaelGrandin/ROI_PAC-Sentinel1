#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 0
### Process all steps automatically and recursively 
### on all different sub-swaths and polarisation modes
####################################################

# # # # # # # # # # # # # # # # # # #
# # Interpret the parameter file  # #

### Read parameter file
if ($#argv <= 0) then
    echo "Usage: $0 topsar_input_file.in"
    exit
endif
if ( ! -e $1 ) then
    echo "Input file not found ! Exit .."
    exit
else
    set topsar_param_file=$1
endif
set num_lines_param_file=`(wc $topsar_param_file | awk '{print $1}')`
if ( $num_lines_param_file == 0 ) then
    echo "Input file empty ! Exit .."
    exit
endif

### Read parameters
@ count = 1
set DIR_IMG_ante=""
set DIR_IMG_post=""
while ( $count <= $num_lines_param_file )
	set linecurrent=`(awk 'NR=='$count' {print $0}' $topsar_param_file)`
	set fieldname=`(echo $linecurrent | awk '{print $1}')`
	set fieldcontent=`(echo $linecurrent | awk '{print $2}')`
	if ( $fieldname == "WORKINGDIR" ) then
		set WORKINGDIR=$fieldcontent
	else if ( $fieldname == "PATHDIR" ) then
		set dir=$fieldcontent
	else
		#echo "Unknown field : "$linecurrent
	endif
	@ count ++
end


foreach strip ( iw1 iw2 iw3 )
	foreach pol ( vv )
		$dir/scripts/S1-ROI_PAC_01_stitch.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_02_baseline.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_03_correl.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_04_sync.csh $topsar_param_file $strip $pol
		#$dir/scripts/S1-ROI_PAC_05b_interf_rerun.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_05_interf.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_06_sd.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_07_sd_finish.csh $topsar_param_file $strip $pol
		#$dir/scripts/S1-ROI_PAC_07b_sd_refine.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_08_unwrap.csh $topsar_param_file $strip $pol
		$dir/scripts/S1-ROI_PAC_09_done.csh $topsar_param_file $strip $pol
	end
end

exit


# * Copyright (C) 2016 R.GRANDIN
#
# * grandin@ipgp.fr
#
# * This file is part of "Sentinel-1 pre-processor for ROI_PAC".
#
# *    "Sentinel-1 pre-processor for ROI_PAC" is free software: you can redistribute
#      it and/or modify it under the terms of the GNU General Public License
# 	 as published by the Free Software Foundation, either version 3 of
# 	 the License, or (at your option) any later version.
#
# *    "Sentinel-1 pre-processor for ROI_PAC" is distributed in the hope that it
#      will be useful, but WITHOUT ANY WARRANTY; without even the implied
# 	 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 	 See the GNU General Public License for more details.
#
# *     You should have received a copy of the GNU General Public License
#      along with "Sentinel-1 pre-processor for ROI_PAC".
# 	 If not, see <http://www.gnu.org/licenses/>.


