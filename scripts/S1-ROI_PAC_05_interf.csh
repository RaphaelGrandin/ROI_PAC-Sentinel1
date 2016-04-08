#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
####################################################
### STEP 5
### Run ROI_PAC up to "begin_filt"
####################################################



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

		# Use ampcor offsets to guess the default offset
	    set offset_guess_x=`(awk '{if($5>10) print $2}' $WORKINGDIR/CORREL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}-${LABEL_post}_${strip}_${polar}_ampcor_gross.off | sort -n | awk ' { a[i++]=$1; } END { print a[int(i/2)]; }')`
	    set offset_guess_y=`(awk '{if($5>10) print $4}' $WORKINGDIR/CORREL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}-${LABEL_post}_${strip}_${polar}_ampcor_gross.off | sort -n | awk ' { a[i++]=$1; } END { print a[int(i/2)]; }')`
		# write that in the .proc file
		echo x_start=$offset_guess_x >> int.proc
	    echo y_start=$offset_guess_y >> int.proc

		# # # Continue process_2pass # # #
		
		# # 1/ first run process_2pass as usual, until offsets calculation :
		process_2pass.pl int.proc slcs offsets >>& log_process2pass_${LABEL_ante}-${LABEL_post}_${strip}_${polar}.txt

		# # 2/ if process_2pass failed during SLC offset calculation (which can sometimes happen..)
		# # then re-do the whole process with different parameters (is it useful??)
    	( /bin/ls INT/????????-????????.int > /dev/null ) >& /dev/null
    	if ( "$status" ) then
        	cd INT
        	set ampcor_file=`(ls ????????-????????_ampcor.off)`
        	set cull_file=`(ls ????????-????????_cull.off)`
        	# re-do the culling
        	$INT_BIN/fitoff $ampcor_file $cull_file 1.5 0.3 1.5 > fitoff_ampcor.out
        	cd ..
        	# finish the job
        	process_2pass.pl int.proc slcs offsets >>& log_process2pass_${LABEL_ante}-${LABEL_post}_${strip}_${polar}.txt
    	endif

		# # 3/ start over until flatorb
        process_2pass.pl int.proc offsets flatorb >>& log_process2pass_${LABEL_ante}-${LABEL_post}_${strip}_${polar}.txt

		# # 4/ go up to begin_filt
        process_2pass.pl int.proc flatorb begin_filt >>& log_process2pass_${LABEL_ante}-${LABEL_post}_${strip}_${polar}.txt	

		# # 5/ Sometimes calculation of the offsets between amplitude image and simulation fails
		# # in that case, re-run ampcor with a denser sampling
        ( /bin/ls INT/${LABEL_ante}-${LABEL_post}-sim_HDR.int > /dev/null ) >& /dev/null
        if ( "$status" ) then
                    cd INT
					rm -f ampmag_cull.off ampmag.off ampmag_gross_cull.off cull.out ampmag_gross.out ampmag.out

					# # Use modified ROI_PAC script here
					# # dense sampling, too dense for Sentinel
					# $MY_SCR/synth_offset_TSX_ScanSAR.pl SIM.hgt ${LABEL_ante}-${LABEL_post}.cor no 1 no
					# # less dense, but still more dense than default
					# # compromise between effectiveness and speed
					$MY_SCR/synth_offset_Sent1.pl SIM.hgt ${LABEL_ante}-${LABEL_post}.cor no 1 no
                    cd ..
                    # finish the job
                    process_2pass.pl int.proc done_sim_off begin_filt >>& log_process2pass_${LABEL_ante}-${LABEL_post}_${strip}_${polar}.txt
        endif

		# # # # # # # # # # #
		# # Multilooking  # #
		
		# # Sentinel IW pixels are ~15m in azimuth, and ~2m in range
		# # the pixel ratio – as defined by ROI_PAC – would be less than one
		# # Here, "12 looks" for Sentinel is actually 12 (az) x 4 (ra)
		# # ROI_PAC does not understand that so we have to multilook again
 		cd INT
		# cleanup
    	rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.amp ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.cor  
		# take the looks
    	look.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int $LOOKS_RANGE $LOOKS_AZIMUTH
    	look.pl ${LABEL_ante}-${LABEL_post}.amp $LOOKS_RANGE $LOOKS_AZIMUTH
		# re-calculate .cor
    	make_cor.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks
		# update resource files
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

