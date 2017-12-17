#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 5
### Run ROI_PAC up to "begin_filt"
####################################################

date

# # # # # # # # # # # # # # # # # # #
# # Interpret the parameter file  # #

### Read parameter file
if ($#argv <= 2) then
    echo "Usage: $0 topsar_input_file.in iw1 hh"
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
	else if ( $fieldname == "DIR_ARCHIVE" ) then
		set DIR_ARCHIVE=$fieldcontent
	else if ( $fieldname == "DIR_IMG_ante" ) then
		set DIR_IMG_ante= ( $DIR_IMG_ante $fieldcontent )
	else if ( $fieldname == "DIR_IMG_post" ) then
		set DIR_IMG_post= ( $DIR_IMG_post $fieldcontent )
	else if ( $fieldname == "DEM" ) then
		set DEM=$fieldcontent
	else if ( $fieldname == "DEM_low" ) then
		set DEM_low=$fieldcontent
	else if ( $fieldname == "LABEL_ante" ) then
		set LABEL_ante=$fieldcontent
	else if ( $fieldname == "LABEL_post" ) then
		set LABEL_post=$fieldcontent
	else if ( $fieldname == "PATHDIR" ) then
		set dir=$fieldcontent
	else if ( $fieldname == "LOOKS_RANGE" ) then
		set LOOKS_RANGE=$fieldcontent
	else if ( $fieldname == "LOOKS_AZIMUTH" ) then
		set LOOKS_AZIMUTH=$fieldcontent
	else
		#echo "Unknown field : "$linecurrent
	endif
	@ count ++
end


### Verify that all the necessary variables are defined
if ( ! $?WORKINGDIR ) then
        echo "Field WORKINGDIR is empty ! Exit .."
        exit
endif
if ( ! $?DIR_ARCHIVE ) then
        echo "Field DIR_ARCHIVE is empty ! Exit .."
        exit
endif
if ( ! $?dir ) then
        echo "Field PATHDIR is empty ! Exit .."
        exit
endif
if ( ! $?DIR_IMG_ante ) then
        echo "Field DIR_IMG_ante is empty ! Exit .."
        exit
endif
if ( ! $?DIR_IMG_post ) then
        echo "Field DIR_IMG_post is empty ! Exit .."
        exit
endif
if ( ! $?LABEL_ante ) then
        echo "Field LABEL_ante is empty ! Exit .."
        exit
endif
if ( ! $?LABEL_post ) then
        echo "Field LABEL_post is empty ! Exit .."
        exit
endif
if ( ! $?DEM ) then
        echo "Field DEM is empty ! Exit .."
        exit
endif
if ( ! $?DEM_low ) then
        echo "Field DEM_low is empty ! Exit .."
        exit
endif

### Set number of looks to default values, if needed
if ( ! $?LOOKS_RANGE ) then
        set LOOKS_RANGE = 12
endif
if ( ! $?LOOKS_AZIMUTH ) then
        set LOOKS_AZIMUTH = 4
endif
if ( ! $?SKIP_BEG_ante ) then
        set SKIP_BEG_ante = 0
endif
if ( ! $?SKIP_BEG_post ) then
        set SKIP_BEG_post = 0
endif
if ( ! $?SKIP_END_ante ) then
        set SKIP_END_ante = 0
endif
if ( ! $?SKIP_END_post ) then
        set SKIP_END_post = 0
endif



set num_files_ante=$#DIR_IMG_ante
set num_files_post=$#DIR_IMG_post
#if ( $num_files_ante != $num_files_post ) then
#        echo "Number of files for ante and post images must be the same ! Exit .."
#        exit
#else
#        set num_files=$num_files_ante
#endif

echo "WORKINGDIR       "$WORKINGDIR
echo "DIR_ARCHIVE      "$DIR_ARCHIVE
#echo "ORBIT            "$orbit
#echo "SCAN             "$scan
@ scene = 1
while ( $scene <= $num_files_ante )
    echo "DIR_IMG_"$scene " ; ante : " $DIR_IMG_ante[$scene]
    @ scene ++
end
@ scene = 1
while ( $scene <= $num_files_post )
    echo "DIR_IMG_"$scene " ; post : "  $DIR_IMG_post[$scene]
    @ scene ++
end

set strip_list=""
set strip_list=$argv[2]
echo "Strip list : " $strip_list
@ num_strips = 1

set polar_list=$argv[3]
echo "Polar list : " $polar_list




# # # # # # # # # # # # # # # #
# # Process interferometry  # #

# normally this directory should exist
if ( ! -e INTERFERO ) then
	echo "Directory "INTERFERO" does not exist!"
	echo "Something is wrong."
	echo "Exit..."
	exit
endif

@ count_strip = 1
while ( $count_strip <= $num_strips )
        set strip=$strip_list[$count_strip]
        set polar=$polar_list[$count_strip]
        echo strip $strip polar $polar

		cd $WORKINGDIR/INTERFERO

		# normally this directory should exist
		if ( ! -e $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar} ) then
			echo "Directory "INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}" does not exist!"
			echo "Something is wrong."
			echo "Exit..."
			exit
		endif

		# # # Go to processing directory created at Step 2
		cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}

		# normally this file should exist
		if ( ! -e int.proc ) then
			echo "File "int.proc" does not exist!"
			echo "Something is wrong."
			echo "Exit..."
			exit
		endif

                # # # Re-run interferogram calculation
                cd INT

                # normally these files should exist
                if ( ! -e ${LABEL_ante}-${LABEL_post}.int ) then
                        echo "Warning : File "${LABEL_ante}-${LABEL_post}.int" does not exist!"
                endif
                if ( ! -e ${LABEL_ante}-${LABEL_post}-sim_HDR.int ) then
                        echo "Warning : File "${LABEL_ante}-${LABEL_post}-sim_HDR.int" does not exist!"
                endif
                if ( ! -e ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ) then
                        echo "Warning : File "${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int" does not exist!"
                endif

                # # # Re-calculate full resolution interferogram
                rm -fr ${LABEL_ante}-${LABEL_post}.int ${LABEL_ante}-${LABEL_post}.amp
                $INT_BIN/resamp_roi ${LABEL_ante}-${LABEL_post}_resamp.in > ${LABEL_ante}-${LABEL_post}_resamp.out

                # # # Re-subtract simulation interferogram
                rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int radar_HDR.unw
                rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int
                $INT_BIN/diffnsim diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in

                # # # Re-do multilooking
                rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int
                look.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int $LOOKS_RANGE $LOOKS_AZIMUTH
                rm -fr ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.amp
                look.pl ${LABEL_ante}-${LABEL_post}.amp $LOOKS_RANGE $LOOKS_AZIMUTH

                # # # Re-calculate coherence
                rm -f ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.cor
                make_cor.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks

                # # # Update resource files
                cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_ORIG_${LOOKS_RANGE}rlks.int
                cp -f ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.cor ${LABEL_ante}-${LABEL_post}-sim_HDR_ORIG_${LOOKS_RANGE}rlks.cor
                cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_ORIG_${LOOKS_RANGE}rlks.int.rsc
                cp -f ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.cor.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_ORIG_${LOOKS_RANGE}rlks.cor.rsc

		@ count_strip ++
end

exit

# * Copyright (C) 2016 R.GRANDIN
# #
# # * grandin@ipgp.fr
# #
# # * This file is part of "Sentinel-1 pre-processor for ROI_PAC".
# #
# # *    "Sentinel-1 pre-processor for ROI_PAC" is free software: you can redistribute
# #      it and/or modify it under the terms of the GNU General Public License
# # 	 as published by the Free Software Foundation, either version 3 of
# # 	 the License, or (at your option) any later version.
# #
# # *    "Sentinel-1 pre-processor for ROI_PAC" is distributed in the hope that it
# #      will be useful, but WITHOUT ANY WARRANTY; without even the implied
# # 	 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# # 	 See the GNU General Public License for more details.
# #
# # *     You should have received a copy of the GNU General Public License
# #      along with "Sentinel-1 pre-processor for ROI_PAC".
# # 	 If not, see <http://www.gnu.org/licenses/>.
#

