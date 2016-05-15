#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 6
### Spectral diversity :
### Compute forward and backward interferograms.
### Compute the difference between them.
### Estimate how phase difference varies along azimuth
### using linear relationship.
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
        else if ( $fieldname == "SPECTRAL_DIV" ) then
                set SPECTRAL_DIV=($fieldcontent)
        else if ( $fieldname == "FULL_RES" ) then
                set FULL_RES=$fieldcontent
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
if ( $SPECTRAL_DIV == "yes" && $FULL_RES != "yes" ) then
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
#        set num_files=$num_files_ante
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
# # Spectral diversity Step 1 # #

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

	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	
	# # # # save original SLCs

	# # Master
	if ( ! -e ${LABEL_ante}_${strip}_${polar}_ORIG.slc ) then
		mv ${LABEL_ante}_${strip}_${polar}.slc ${LABEL_ante}_${strip}_${polar}_ORIG.slc
	else
		echo "Warning : ${LABEL_ante}_${strip}_${polar}_ORIG.slc already exists!"
		echo "Something is wrong."
		echo "Exit..."
        exit
	endif	
		
	# # Slave
    if ( ! -e ${LABEL_post}_${strip}_${polar}_ORIG.slc ) then
        mv ${LABEL_post}_${strip}_${polar}.slc ${LABEL_post}_${strip}_${polar}_ORIG.slc
    else
        echo "Warning : ${LABEL_post}_${strip}_${polar}_ORIG.slc already exists!"
		echo "Something is wrong."
		echo "Exit..."
        exit
    endif             

    # # # # # # # # # # # 
	# # # Forward-looking interferogram
	
	# temporarily replace previous SLCs with forward-looking SLCs
    cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	ln -sf ${LABEL_ante}_${strip}_${polar}_fw.slc ${LABEL_ante}_${strip}_${polar}.slc
    ln -sf ${LABEL_post}_${strip}_${polar}_fw.slc ${LABEL_post}_${strip}_${polar}.slc
	# calculate the interferogram
	cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
    cd INT
    rm -fr ${LABEL_ante}-${LABEL_post}.int ${LABEL_ante}-${LABEL_post}.amp
    $INT_BIN/resamp_roi ${LABEL_ante}-${LABEL_post}_resamp.in > ${LABEL_ante}-${LABEL_post}_resamp.out
    rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int radar_HDR.unw
    $INT_BIN/diffnsim diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in
    rm -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int
    look.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int $LOOKS_RANGE $LOOKS_AZIMUTH
    # save the interferogram for Spectral diversity calculation
    mv -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_fw_${LOOKS_RANGE}rlks.int
    cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_fw_${LOOKS_RANGE}rlks.int.rsc


    # # # # # # # # # # # 
    # # Backward-looking interferogram
	
	# temporarily replace previous SLCs with backward-looking SLCs
	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
    ln -sf ${LABEL_ante}_${strip}_${polar}_bw.slc ${LABEL_ante}_${strip}_${polar}.slc
    ln -sf ${LABEL_post}_${strip}_${polar}_bw.slc ${LABEL_post}_${strip}_${polar}.slc
	# calculate the interferogram
    cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
    cd INT
    rm -fr ${LABEL_ante}-${LABEL_post}.int ${LABEL_ante}-${LABEL_post}.amp
    $INT_BIN/resamp_roi ${LABEL_ante}-${LABEL_post}_resamp.in > ${LABEL_ante}-${LABEL_post}_resamp.out
    rm -fr ${LABEL_ante}-${LABEL_post}-sim_HDR.int radar_HDR.unw
	$INT_BIN/diffnsim diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in
    rm -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int
	look.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int $LOOKS_RANGE $LOOKS_AZIMUTH
    # save the interferogram for Spectral diversity calculation
    mv -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_bw_${LOOKS_RANGE}rlks.int
    cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_bw_${LOOKS_RANGE}rlks.int.rsc

    # # # # # # # # # # # 
	# # Cross-interferogram (xint)
	
    # Set a few variables
    set MyWidthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read WIDTH`	
    set MyLengthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read FILE_LENGTH`    
    set MyWidthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read WIDTH`
    set MyLengthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read FILE_LENGTH`
    # Compute the interferogram difference
	add_cpx ${LABEL_ante}-${LABEL_post}-sim_HDR_fw_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_bw_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $MyWidthLooked $MyLengthLooked -1	
	cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int.rsc

	# Calculate the coherence
	if ( ! -e ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int ) then
		cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int
		cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int.rsc
		make_cor.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks
		# Replace amplitude with coherence
		cpx2mag_phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int junk phs $MyWidthLooked
		rmg2mag_phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.cor junk cor $MyWidthLooked
		mag_phs2cpx cor phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $MyWidthLooked
		rm -fr junk phs cor
	endif

	# Call python program to estimate best-fitting phase plane
    cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	python $dir/python/fit_plane.py $MyWidthLooked $MyLengthLooked $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap.txt

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
