#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 3
### Dense ampcor calculation
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
	set fieldcontent=`(echo $linecurrent | awk '{for(i=2;i<=NF;++i)print $i}')`
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
		set SKIP_BEG_ante=($fieldcontent)
	else if ( $fieldname == "SKIP_BEG_post" ) then
		set SKIP_BEG_post=($fieldcontent)
	else if ( $fieldname == "SKIP_END_ante" ) then
		set SKIP_END_ante=($fieldcontent)
	else if ( $fieldname == "SKIP_END_post" ) then
		set SKIP_END_post=($fieldcontent)
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
else if ( $#SKIP_BEG_ante != 1 ) then
	set SKIP_BEG_ante = $SKIP_BEG_ante[$subswath]
endif
if ( ! $?SKIP_BEG_post ) then
	set SKIP_BEG_post = 0
else if ( $#SKIP_BEG_post != 1 ) then
	set SKIP_BEG_post = $SKIP_BEG_post[$subswath]
endif
if ( ! $?SKIP_END_ante ) then
	set SKIP_END_ante = 0
else if ( $#SKIP_END_ante != 1 ) then
	set SKIP_END_ante = $SKIP_END_ante[$subswath]
endif
if ( ! $?SKIP_END_post ) then
	set SKIP_END_post = 0
else if ( $#SKIP_END_post != 1 ) then
	set SKIP_END_post = $SKIP_END_post[$subswath]
endif



set num_files_ante=$#DIR_IMG_ante
set num_files_post=$#DIR_IMG_post

#if ( $num_files_ante != $num_files_post ) then
#    echo "Number of files for ante and post images must be the same ! Exit .."
#    exit
#else
#	set num_files=$num_files_ante
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



# # # # # # # # # # # # # # # # # # # #
# # Compute the offsets from ampcor # #

# Create the directory that will hold the dense correlations
if ( ! -e CORREL ) then
	mkdir CORREL
endif

@ count_strip = 1
while ( $count_strip <= $num_strips )

	# Guess the offset from the orbits
	set strip=$strip_list[$count_strip]
	set polar=$polar_list[$count_strip]
	set baselineFile="$WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}_${LABEL_post}_baseline.rsc"
	set guessOffsetRange=`use_rsc.pl $baselineFile read ORB_SLC_R_OFFSET_HDR`

	# if we have skipped some bursts, the guessed az offsets are probably wrong

	##### R. Grandin, 2015/04/28
#	if ( $SKIP_BEG_ante != "0" || $SKIP_BEG_post != "0" || $SKIP_END_ante != "0" || $SKIP_END_post != "0" ) then
#		set guessOffsetAzimuth="0"
#	else
#		set guessOffsetAzimuth=`use_rsc.pl $baselineFile read ORB_SLC_AZ_OFFSET_HDR`
#	endif
#	if ( $SKIP_BEG_ante == "0" && $SKIP_BEG_post == "0" && $SKIP_END_ante == "0" && $SKIP_END_post == "0" ) then

	## For large Bperp, increase search distance in range
	# Search distance increases by 1 pixel every $factor_search_range (minimum set to 5)
#	set search_distance_range="5"
	set factor_search_range="40"
	set bperp=`use_rsc.pl $baselineFile read P_BASELINE_TOP_HDR`
	set search_distance_range=`echo $bperp | awk '{printf("%.0f\n", 5 + sqrt($1*$1)/'$factor_search_range')}'`
	echo "bperp = $bperp  =>  search_distance_range = $search_distance_range"
	
	if ( ($SKIP_BEG_ante == "0") && ($SKIP_BEG_post == "0") && ($SKIP_END_ante == "0") && ($SKIP_END_post == "0") ) then
		set guessOffsetAzimuth=`use_rsc.pl $baselineFile read ORB_SLC_AZ_OFFSET_HDR`
#		set search_distance="5 5"
		set search_distance_azimuth="5"
	else
		set guessOffsetAzimuth="0"
#		set search_distance="5 20"
		set search_distance_azimuth="20"
	endif
	set search_distance="$search_distance_range $search_distance_azimuth"
	echo search_distance $search_distance

	# for some reason an integer might be needed here
	set guess_offset=`(echo $guessOffsetRange $guessOffsetAzimuth  | awk '{ printf("%.0f %.0f",$1,$2)}')`
	echo "guess_offset $guess_offset"
	

	# prepare files and directories for ampcor
	cd $WORKINGDIR/CORREL
	if ( ! -e ${LABEL_ante}-${LABEL_post}_${strip}_${polar} ) then
		mkdir ${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	endif
	cd ${LABEL_ante}-${LABEL_post}_${strip}_${polar}
			
	ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}.slc .
	cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}.slc.rsc .

	ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_post}_${strip}_${polar}.slc .
	cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_post}_${strip}_${polar}.slc.rsc .
		
	# read file size information
	set XSIZE_ANTE=`(grep WIDTH         ${LABEL_ante}_${strip}_${polar}.slc.rsc | awk '{print $NF}')`
	set YSIZE_ANTE=`(grep FILE_LENGTH   ${LABEL_ante}_${strip}_${polar}.slc.rsc | awk '{print $NF}')`
	set XSIZE_POST=`(grep WIDTH         ${LABEL_post}_${strip}_${polar}.slc.rsc | awk '{print $NF}')`
	set YSIZE_POST=`(grep FILE_LENGTH   ${LABEL_post}_${strip}_${polar}.slc.rsc | awk '{print $NF}')`
		
	# keep larger file size
	set XSIZE=`(echo $XSIZE_ANTE $XSIZE_POST | awk '{if($1>$2) print $1; else print $2}')`
	set YSIZE=`(echo $YSIZE_ANTE $YSIZE_POST | awk '{if($1>$2) print $1; else print $2}')`

	# set start line / columns
	# shift start line / column by one window width + 1 pixel
	# for some reason an integer might be needed here
	set XSTART_CORREL=`(echo $guess_offset | awk '{if($1<0) printf("%d", -1*$1+65); else {print 65}}')`
	set YSTART_CORREL=`(echo $guess_offset | awk '{if($2<0) printf("%d", -1*$2+65); else {print 65}}')`

		
	# prepare the ampcor imput file
	echo "                 AMPCOR INPUT FILE" > ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "DATA TYPE" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "Data Type for Reference Image Real or Complex                   (-)    =  Complex" >> ampcor_gross.in
	echo "Data Type for Search Image Real or Complex                      (-)    =  Complex" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "INPUT/OUTPUT FILES" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "Reference Image Input File                                      (-)    =  ${LABEL_ante}_${strip}_${polar}.slc" >> ampcor_gross.in
	echo "Search Image Input File                                         (-)    =  ${LABEL_post}_${strip}_${polar}.slc" >> ampcor_gross.in
	echo "Match Output File                                               (-)    =  ${LABEL_ante}-${LABEL_post}_${strip}_${polar}_ampcor_gross.off" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "MATCH REGION" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "Number of Samples in Reference/Search Images                    (-)    =  $XSIZE_ANTE $XSIZE_POST" >> ampcor_gross.in
	echo "Start, End and Skip Lines in Reference Image                    (-)    =  $YSTART_CORREL $YSIZE 400" >> ampcor_gross.in
	echo "Start, End and Skip Samples in Reference Image                  (-)    =  $XSTART_CORREL $XSIZE 400" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "MATCH PARAMETERS" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	# for now, these parameters are hardcoded
	echo "Reference Window Size Samples/Lines                             (-)    =  128 128" >> ampcor_gross.in
	echo "Search Pixels Samples/Lines                                     (-)    =  "$search_distance >> ampcor_gross.in
	echo "Pixel Averaging Samples/Lines                                   (-)    =  1 1" >> ampcor_gross.in
	echo "Covariance Surface Oversample Factor and Window Size            (-)    =  64 16" >> ampcor_gross.in
	echo "Mean Offset Between Reference and Search Images Samples/Lines   (-)    =  "$guess_offset >> ampcor_gross.in
	echo "Matching Scale for Sample/Line Directions                       (-)    = 1.000 1.000" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "MATCH THRESHOLDS AND DEBUG DATA" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	echo "SNR and Covariance Thresholds                                   (-)    =  0 1" >> ampcor_gross.in
	echo "Debug and Display Flags T/F                                     (-)    =  f f" >> ampcor_gross.in
	echo "" >> ampcor_gross.in
	
	# run ampcor
	ampcor ampcor_gross.in rdf > /dev/null

	# run fitoff
	# fitoff parameters might be too permissive... anyway.
	fitoff ${LABEL_ante}-${LABEL_post}_${strip}_${polar}_ampcor_gross.off ${LABEL_ante}-${LABEL_post}_${strip}_${polar}_cull_gross.off 1.5 0.3 50 > ${LABEL_ante}-${LABEL_post}_${strip}_${polar}_fitoff_gross.out

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
