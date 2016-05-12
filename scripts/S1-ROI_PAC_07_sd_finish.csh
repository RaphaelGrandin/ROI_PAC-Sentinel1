#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 7
### Use spectral diversity-derived offsets to correct
### the phase with the slave image.  Re-do the stiching
### + deramping accordingly (only for the slave)
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
        else if ( $fieldname == "SKIP_BEG_ante" ) then
                set SKIP_BEG_ante=$fieldcontent
        else if ( $fieldname == "SKIP_BEG_post" ) then
                set SKIP_BEG_post=$fieldcontent
        else if ( $fieldname == "SKIP_END_ante" ) then
                set SKIP_END_ante=$fieldcontent
        else if ( $fieldname == "SKIP_END_post" ) then
                set SKIP_END_post=$fieldcontent
        else if ( $fieldname == "SPECTRAL_DIV" ) then
                set SPECTRAL_DIV=($fieldcontent)
        else if ( $fieldname == "FULL_RES" ) then
                set FULL_RES=$fieldcontent
	else
		#echo "Unknown field : "$linecurrent
	endif
	@ count ++
end

set strip_list=""
set strip_list=$argv[2]
echo "Strip list : " $strip_list
@ num_strips = 1

set polar_list=$argv[3]
echo "Polar list : " $polar_list

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

### Set sub-swath number
if ( $strip_list == "iw1" ) then
        set subswath=1
else if ( $strip_list == "iw2" ) then
        set subswath=2
else if ( $strip_list == "iw3" ) then
        set subswath=3
else   
        set subswath=1
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

### Check if user wants to perform spectral diversity (default : SPECTRAL_DIV="yes")
if ( ! $?SPECTRAL_DIV ) then
        set SPECTRAL_DIV="yes"
else if ( $SPECTRAL_DIV != "no" && $SPECTRAL_DIV != "No" && $SPECTRAL_DIV != "NO" && $SPECTRAL_DIV != "0" ) then
        echo "Setting SPECTRAL_DIV to \"yes\" (default)."
        set SPECTRAL_DIV="yes"
else
        echo "Spectral diversity will be skipped (SPECTRAL_DIV=$SPECTRAL_DIV)."
endif

### Check if user wants to process at full resolution (default : FULL_RES="yes")
if ( ! $?FULL_RES ) then
        set FULL_RES="yes"
else if ( $FULL_RES != "no" && $FULL_RES != "No" && $FULL_RES != "NO" && $FULL_RES != "0" ) then
        echo "Setting FULL_RES to \"yes\" (default)."
        set FULL_RES="yes"
else
        echo "Full resolution processing will be performed (FULL_RES=$FULL_RES)."
endif

### Setting SPECTRAL_DIV to "yes" and FULL_RES to "no" is currently not supported
### Default behaviour : set SPECTRAL_DIV back to "no"
if ( $SPECTRAL_DIV == "yes" && $SPECTRAL_DIV != "yes" ) then
        echo "SPECTRAL_DIV=yes and FULL_RES=no are incompatible."
        set SPECTRAL_DIV="no"
        echo "Spectral diversity will be skipped (SPECTRAL_DIV=$SPECTRAL_DIV)."
endif

set num_files_ante=$#DIR_IMG_ante
set num_files_post=$#DIR_IMG_post

#if ( $num_files_ante != $num_files_post ) then
#    echo "Number of files for ante and post images must be the same ! Exit .."
#    exit
#else
#    set num_files=$num_files_ante
#endif

echo "WORKINGDIR       "$WORKINGDIR
echo "DIR_ARCHIVE      "$DIR_ARCHIVE
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


if ( $SPECTRAL_DIV != "no" && $SPECTRAL_DIV != "No" && $SPECTRAL_DIV != "NO" && $SPECTRAL_DIV != "0" ) then

# # # # # # # # # # # # # # # # # 
# # Spectral diversity Step 2 # #

# normally this directory should exist
if ( ! -e $WORKINGDIR/SLC ) then
	echo "Directory "SLC" does not exist!"
	echo "Something is wrong."
	echo "Exit..."
	exit
endif

@ count_strip = 1
while ( $count_strip <= $num_strips )
    set strip=$strip_list[$count_strip]
    set polar=$polar_list[$count_strip]
    echo strip $strip polar $polar

	# # Go back to the SLC in order to adjust the lag 
	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	
    # # Cleanup backward- and forward-looking SLCs
    rm -f ${LABEL_ante}_${strip}_${polar}_bw.slc ${LABEL_ante}_${strip}_${polar}_fw.slc
    rm -f ${LABEL_post}_${strip}_${polar}_bw.slc ${LABEL_post}_${strip}_${polar}_fw.slc
    # # Cleanup slave SLC, because we will re-calculate it
    rm -f ${LABEL_post}_${strip}_${polar}.slc ${LABEL_post}_${strip}_${polar}_ORIG.slc
	
    # # Put things back in order for the master SLC
    if ( -e ${LABEL_ante}_${strip}_${polar}_ORIG.slc ) then # assuming this is the correct SLC
		rm -f ${LABEL_ante}_${strip}_${polar}.slc
		# restore previously saved SLC
		mv -f ${LABEL_ante}_${strip}_${polar}_ORIG.slc ${LABEL_ante}_${strip}_${polar}.slc
		echo "Using ${LABEL_ante}_${strip}_${polar}_ORIG.slc (calculated previously) as the master slc."
	else # assuming that ORIG file has already been calculated
		echo "Warning : ${LABEL_ante}_${strip}_${polar}_ORIG.slc does not exist!"
		echo "Assuming ${LABEL_ante}_${strip}_${polar}.slc is correct (?)"
		# or should we exit? This would be safer.
		echo "Something is wrong."
		echo "Exit..."
	        #exit
	endif

	# Read lag deduced from offsets (Step 2)
	set outputSDFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit.rsc
	set SD_CONSTANT=`use_rsc.pl $outputSDFile read SD_CONSTANT`
    set SD_SLOPE_X=`use_rsc.pl $outputSDFile read SD_SLOPE_X`
    set SD_SLOPE_Y=`use_rsc.pl $outputSDFile read SD_SLOPE_Y`
	echo " SD_CONSTANT=$SD_CONSTANT  /  SD_SLOPE_X=$SD_SLOPE_X  /  SD_SLOPE_Y=$SD_SLOPE_Y"
	
	# Read lag deduced from spectral diversity (Step 6)
    set burst_comp_param_file_orig=${LABEL_post}_${strip}_${polar}_param.rsc
    set burst_comp_param_file_sync=${LABEL_post}_${strip}_${polar}_param_sync.rsc
    set burst_comp_param_file_sync_sd=${LABEL_post}_${strip}_${polar}_param_sync_sd.rsc
	cp -f $burst_comp_param_file_sync $burst_comp_param_file_sync_sd
    set AFFINE_COEFF_D=`use_rsc.pl $burst_comp_param_file_sync_sd read AFFINE_COEFF_D`
    set AFFINE_COEFF_E=`use_rsc.pl $burst_comp_param_file_sync_sd read AFFINE_COEFF_E`
    set AFFINE_COEFF_F=`use_rsc.pl $burst_comp_param_file_sync_sd read AFFINE_COEFF_F`
    echo " AFFINE_COEFF_D=$AFFINE_COEFF_D  /  AFFINE_COEFF_E=$AFFINE_COEFF_E  /  AFFINE_COEFF_F=$AFFINE_COEFF_F"

    set AFFINE_COEFF_F_SHIFT=`use_rsc.pl $burst_comp_param_file_sync_sd read AFFINE_COEFF_F_SHIFT`
    set affCoeffEminusOne=`(echo "$AFFINE_COEFF_E - 1" | bc -l | awk '{printf("%.10f",$1)}')`

	# Read necessary information
    #set ktmean=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read ktMean` 
    #set povl=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read ovlLength`
    set q=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read azimuthTimeInterval`
    set nbu=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read linesPerBurst`

    set ktmean=`awk '{mean+=($2); count++;} END {print mean/count}' ${LABEL_ante}_${strip}_${polar}_ktMean.txt`
    set povl=`awk '{mean+=(($3)-($2)); count++;} END {print mean/count}' ${LABEL_ante}_${strip}_${polar}_Overlap.txt`

	echo $ktmean $nbu $povl $q 
	
	# Convert phase difference to time difference
	set factorSD=`echo $ktmean $nbu $povl $q | awk '{printf("%.10f", 1/(2*3.14159*$1*($2-$3/2)*$4*$4))}'`
	echo factorSD $factorSD
	set SD_CONSTANT=`echo $factorSD $SD_CONSTANT | awk '{printf("%.10f", $1*$2)}'`
    set SD_SLOPE_X=`echo $factorSD $SD_SLOPE_X | awk '{printf("%.10f", $1*$2)}'`
    set SD_SLOPE_Y=`echo $factorSD $SD_SLOPE_Y | awk '{printf("%.10f", $1*$2)}'`
    echo " SD_CONSTANT=$SD_CONSTANT  /  SD_SLOPE_X=$SD_SLOPE_X  /  SD_SLOPE_Y=$SD_SLOPE_Y"

	# Merge offset coefficients from ampcor and spectral dif
	set COEFF_SLOPE_X_FINAL=` echo $AFFINE_COEFF_D    $SD_SLOPE_X | awk '{printf("%.10f", ($1) + ($2))}'`
	set COEFF_SLOPE_Y_FINAL=` echo $affCoeffEminusOne $SD_SLOPE_Y | awk '{printf("%.10f", ($1) + ($2))}'`
	set COEFF_CONSTANT_FINAL=`echo $AFFINE_COEFF_F_SHIFT $SD_CONSTANT | awk '{printf("%.10f", ($1) + ($2))}'`
	

	# Update and save to file
	use_rsc.pl $burst_comp_param_file_sync_sd write SD_CONSTANT $SD_CONSTANT
    use_rsc.pl $burst_comp_param_file_sync_sd write SD_SLOPE_X $SD_SLOPE_X
    use_rsc.pl $burst_comp_param_file_sync_sd write SD_SLOPE_Y $SD_SLOPE_Y

    # run burst compensation / stitching step one more time (should be the last time)
    #matlab -nodesktop -nosplash -nodisplay -r "SentinelDeburst $burst_comp_param_file_sync_sd " > ${LABEL_post}_${strip}_${polar}_log_deburst_synclag_sd.txt

        # # Check consistency of burst_end and burst_beg
        set SKIP_BEG_CHECK = `grep SKIP_BEG $burst_comp_param_file_orig | awk '{print $2}'`
        set SKIP_END_CHECK = `grep SKIP_END $burst_comp_param_file_orig | awk '{print $2}'`
        if ( ( $SKIP_BEG_CHECK != $SKIP_BEG_post ) && ( $SKIP_BEG_CHECK != "" ) ) then
                set SKIP_BEG_post=$SKIP_BEG_CHECK
                echo "SKIP_BEG_post set to "$SKIP_BEG_post
        endif
        if ( ( $SKIP_END_CHECK != $SKIP_END_post ) && ( $SKIP_END_CHECK != "" ) ) then
                set SKIP_END_post=$SKIP_END_CHECK
                echo "SKIP_END_post set to "$SKIP_END_post
        endif

        # Count the number of bursts
        set numOfBurstAnte=`wc ${LABEL_ante}_${strip}_${polar}_burst.txt | awk '{print $1}'`
        set numOfBurstPost=`wc ${LABEL_post}_${strip}_${polar}_burst.txt | awk '{print $1}'`
        set totalNumberOfBurstsAnte=`echo $numOfBurstAnte $SKIP_BEG_ante $SKIP_END_ante | awk '{print $1-$2-$3}'`
        set totalNumberOfBurstsPost=`echo $numOfBurstPost $SKIP_BEG_post $SKIP_END_post | awk '{print $1-$2-$3}'`
        echo "numOfBurstAnte (before skip) "$numOfBurstAnte / SKIP_BEG_ante $SKIP_BEG_ante SKIP_END_ante $SKIP_END_ante" / totalNumberOfBurstsAnte (after skip) "$totalNumberOfBurstsAnte
        echo "numOfBurstPost (before skip) "$numOfBurstPost / SKIP_BEG_post $SKIP_BEG_post SKIP_END_post $SKIP_END_post" / totalNumberOfBurstsPost (after skip) "$totalNumberOfBurstsPost

        @ scene = 1
        while ($scene <= $num_files_post )
                set directory=$DIR_IMG_post[$scene]
                echo $strip $directory

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                #echo " --skip_beg ${SKIP_BEG_post} --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                        #echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                else if ($scene == $num_files_post) then
                        #echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                        echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                else   
                        echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                        echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                endif
                echo " --azshift_mean ${COEFF_CONSTANT_FINAL} --azshift_azimuth ${COEFF_SLOPE_Y_FINAL} --azshift_range ${COEFF_SLOPE_X_FINAL} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                if ($num_files_post != 1) then
                        echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                endif
		if ($scene != 1) then
			echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
			# get number of bursts already written to file
			set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_Overlap.txt | awk '{print $1}'`
			if (fileGlobalBurstIndex != "") then
				echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
			endif
		endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt
                set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""
	
		python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag_sd.txt

		@ scene += 1
	end

    # re-calculate the interferogram
    cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
    cd INT
    rm -fr ${LABEL_ante}-${LABEL_post}.int ${LABEL_ante}-${LABEL_post}.amp
    $INT_BIN/resamp_roi ${LABEL_ante}-${LABEL_post}_resamp.in > ${LABEL_ante}-${LABEL_post}_resamp.out
    rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int radar_HDR.unw
    rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int
    $INT_BIN/diffnsim diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in
	
	# re-do the multilooking
    rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.amp ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.cor  
    look.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int $LOOKS_RANGE $LOOKS_AZIMUTH
    look.pl ${LABEL_ante}-${LABEL_post}.amp $LOOKS_RANGE $LOOKS_AZIMUTH
    make_cor.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks

	@ count_strip ++
end
else
        echo "Skipping spectral diversity step!"
endif

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
#
