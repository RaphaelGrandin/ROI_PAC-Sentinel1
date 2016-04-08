#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
####################################################
### STEP 7b (optional)
### Extract residual along-track offsets
### after applying spectral diversity
### and flattening
### following method from : Grandin et al. 2016, GRL
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
        set SKIP_BEG_ante = -1
else if ( $#SKIP_BEG_ante != 1 ) then
        set SKIP_BEG_ante = $SKIP_BEG_ante[$subswath]
endif
if ( ! $?SKIP_BEG_post ) then
        set SKIP_BEG_post = -1
else if ( $#SKIP_BEG_post != 1 ) then
        set SKIP_BEG_post = $SKIP_BEG_post[$subswath]
endif
if ( ! $?SKIP_END_ante ) then
        set SKIP_END_ante = -1
else if ( $#SKIP_END_ante != 1 ) then
        set SKIP_END_ante = $SKIP_END_ante[$subswath]
endif
if ( ! $?SKIP_END_post ) then
        set SKIP_END_post = -1
else if ( $#SKIP_END_post != 1 ) then
        set SKIP_END_post = $SKIP_END_post[$subswath]
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

	set burst_comp_param_file_orig=${LABEL_post}_${strip}_${polar}_param.rsc
	set burst_comp_param_file_sync=${LABEL_post}_${strip}_${polar}_param_sync.rsc
	set burst_comp_param_file_sync_sd=${LABEL_post}_${strip}_${polar}_param_sync_sd.rsc
	set burst_comp_param_file_sync_sd_fw=${LABEL_post}_${strip}_${polar}_param_sync_sd_fw.rsc
        set burst_comp_param_file_sync_sd_bw=${LABEL_post}_${strip}_${polar}_param_sync_sd_bw.rsc
	
	cp -f $burst_comp_param_file_sync_sd $burst_comp_param_file_sync_sd_fw
	cp -f $burst_comp_param_file_sync_sd $burst_comp_param_file_sync_sd_bw


	# # # # # # # # # # # #
	# # # Re-read metadata
        # # # # # # # # # # # #

	# # Master image  # #
	
        set directoryListAnte=''
        @ scene = 1
        while ($scene <= $num_files_ante )
                set directory=$DIR_IMG_ante[$scene]
                #echo $strip $directory 
                set directoryListAnte="$directoryListAnte $DIR_ARCHIVE/$directory"
            @ scene += 1
        end
	# run metadata parser
	echo $directoryListAnte
        python $dir/python/safe2rsc.py -m ${strip} -p ${polar} $directoryListAnte

        # # Slave image   # #

        set directoryListPost=''
        @ scene = 1
        while ($scene <= $num_files_post )
                set directory=$DIR_IMG_post[$scene]
                #echo $strip $directory 
                set directoryListPost="$directoryListPost $DIR_ARCHIVE/$directory"
            @ scene += 1
        end
        # run metadata parser
        echo $directoryListPost
        python $dir/python/safe2rsc.py -m ${strip} -p ${polar} $directoryListPost

        # # Crop images according to their mutually overlapping parts 
        
	# Count the number of bursts
        set numOfBurstAnte=`wc ${LABEL_ante}_${strip}_${polar}_burst.txt | awk '{print $1}'`
        set numOfBurstPost=`wc ${LABEL_post}_${strip}_${polar}_burst.txt | awk '{print $1}'`

	# # Find which image starts first
	# #  0 if images are synchrone
	# # +1 if Ante starts before Post
	# # -1 if Post starts before Ante
        set orderAntePostBeg=`(paste ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_burst.txt | head -1 | \
        awk '{time_beg_ante=$2; time_beg_post=$5; if((sqrt(((time_beg_post)-(time_beg_ante))*((time_beg_post)-(time_beg_ante)))<0.1)) print 0; else {if(time_beg_post>time_beg_ante) print 1; else print -1}}')`

        # if user has not provided any info on burst start / end
        if ( $SKIP_BEG_ante == "-1" && $SKIP_END_ante == "-1" && $SKIP_BEG_post == "-1" && $SKIP_END_post == "-1" ) then
		# Images are synchrone, at the top => check if they are synchrone at the end too
		if ( $orderAntePostBeg == "0" ) then
    			echo " Ante and Post start at the same time."
                        set SKIP_BEG_ante=0
                        set SKIP_BEG_post=0
                        if ( $numOfBurstAnte == $numOfBurstPost ) then
			# OK, everything is simple
			        echo " Ante and Post end at the same time."
                                set SKIP_END_ante=0
                                set SKIP_END_post=0
                        else if ( $numOfBurstAnte > $numOfBurstPost ) then
                                echo " Ante ends $SKIP_END_ante bursts after Post end."
                                set SKIP_END_ante=`echo $numOfBurstAnte $numOfBurstPost | awk '{print $1-$2}'`
                                set SKIP_END_post=0
                        else
                                echo " Post ends $SKIP_END_post bursts after Ante end."
                                set SKIP_END_ante=0
                                set SKIP_END_post=`echo $numOfBurstPost $numOfBurstAnte | awk '{print $1-$2}'`
                        endif
                else if ( $orderAntePostBeg == "1" ) then
                        set SKIP_BEG_ante=`paste ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_burst.txt | \
                                awk '{if(NR==1) {time_beg_ante=$2; time_beg_post=$5;} if((sqrt(((time_beg_post)-($2))*((time_beg_post)-($2)))<0.1)) print NR-1 }'`
                        set SKIP_BEG_post=0
                        echo " Ante starts $SKIP_BEG_ante bursts before Post start."
                        set SKIP_END_post=`echo $numOfBurstAnte $numOfBurstPost $SKIP_BEG_ante | awk '{print $2-($1-$3)}'`
                        if ( $SKIP_END_post < 0 ) then
                                # Problem : post image is too short
                                # Ante has to be cut at the end
                                set SKIP_END_ante=`echo $SKIP_END_post | awk '{print -1*($1)}'`
                                set SKIP_END_post=0
                                echo " Ante ends   $SKIP_END_ante bursts after Post end."
                        else
                                set SKIP_END_ante=0
                                echo " Post ends   $SKIP_END_post bursts after Ante end."
                        endif

                else if ( $orderAntePostBeg == "-1" ) then
                        set SKIP_BEG_ante=0
                        set SKIP_BEG_post=`paste ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_burst.txt | \
                                awk '{if(NR==1) {time_beg_ante=$2; time_beg_post=$5;} if((sqrt(((time_beg_ante)-($5))*((time_beg_ante)-($5)))<0.1)) print NR-1 }'`
                        echo " Post starts $SKIP_BEG_post bursts before Ante start."
                        set SKIP_END_ante=`echo $numOfBurstPost $numOfBurstAnte $SKIP_BEG_post | awk '{print $2-($1-$3)}'`
                        if ( $SKIP_END_ante < 0 ) then
                                # Problem : post image is too short
                                # Ante has to be cut at the end
                                set SKIP_END_post=`echo $SKIP_END_ante | awk '{print -1*($1)}'`
                                set SKIP_END_ante=0
                                echo " Post ends   $SKIP_END_post bursts after Ante end."
                        else
                                set SKIP_END_post=0
                                echo " Ante ends   $SKIP_END_ante bursts after Post end."
                        endif
                endif
        else
                if ( $SKIP_BEG_ante == "-1" ) then
                        set SKIP_BEG_ante=0
                endif
                if ( $SKIP_END_ante == "-1" ) then
                        set SKIP_END_ante=0
                endif
                if ( $SKIP_BEG_post == "-1" ) then
                        set SKIP_BEG_post=0
                endif
                if ( $SKIP_END_post == "-1" ) then
                        set SKIP_END_post=0
                endif
        endif

        # Select only relevant bursts
        awk '{if( (NR>('$SKIP_BEG_ante')) && (NR<=('$numOfBurstAnte'-'$SKIP_END_ante'))) print $0}' ${LABEL_ante}_${strip}_${polar}_burst.txt > ${LABEL_ante}_${strip}_${polar}_burst_sel.txt
        awk '{if( (NR>('$SKIP_BEG_post')) && (NR<=('$numOfBurstPost'-'$SKIP_END_post'))) print $0}' ${LABEL_post}_${strip}_${polar}_burst.txt > ${LABEL_post}_${strip}_${polar}_burst_sel.txt

	# We might need to update start / middle / end time in .raw.rsc file
	# if some bursts have been skipped
        if ( $SKIP_BEG_ante != 0 || $SKIP_END_ante != 0 ) then
		# Find burst duration by extracting burst cycle interval
                set burstDuration=`awk '{timePrev=time; time=$1; if(NR>1) {timeDiff+=(time-timePrev)}} END {printf("%.6f\n",  timeDiff/(NR-1))}' ${LABEL_ante}_${strip}_${polar}_burst.txt`
                # First burst start time
                set timeBeg=`head -1 ${LABEL_ante}_${strip}_${polar}_burst_sel.txt | awk '{print $1}'`
                # Last burst start time
                set timeEnd=`tail -1 ${LABEL_ante}_${strip}_${polar}_burst_sel.txt | awk '{print $1}'`
                # Last burst end time
                set timeEnd=`echo $timeEnd $burstDuration  | awk '{printf("%.6f\n", $1+$2)}'`
                # Centre time
                set timeMid=`echo $timeEnd $timeBeg  | awk '{printf("%.6f\n", ($1+$2)/2)}'`
                # Display to screen
                echo " "Ante : FIRST_LINE_UTC: $timeBeg / CENTER_LINE_UTC: $timeMid / LAST_LINE_UTC: $timeEnd
                # Update .rsc accordingly
                use_rsc.pl ${LABEL_ante}_${strip}_${polar}.raw.rsc write FIRST_LINE_UTC  $timeBeg
                use_rsc.pl ${LABEL_ante}_${strip}_${polar}.raw.rsc write CENTER_LINE_UTC $timeMid
                use_rsc.pl ${LABEL_ante}_${strip}_${polar}.raw.rsc write LAST_LINE_UTC   $timeEnd

                # Find burst duration by extracting burst cycle interval
                set burstDuration=`awk '{timePrev=time; time=$1; if(NR>1) {timeDiff+=(time-timePrev)}} END {printf("%.6f\n",  timeDiff/(NR-1))}' ${LABEL_post}_${strip}_${polar}_burst.txt`
                # First burst start time
                set timeBeg=`head -1 ${LABEL_post}_${strip}_${polar}_burst_sel.txt | awk '{print $1}'`
                # Last burst start time
                set timeEnd=`tail -1 ${LABEL_post}_${strip}_${polar}_burst_sel.txt | awk '{print $1}'`
                # Last burst end time
                set timeEnd=`echo $timeEnd $burstDuration  | awk '{printf("%.6f\n", $1+$2)}'`
                # Centre time
                set timeMid=`echo $timeEnd $timeBeg  | awk '{printf("%.6f\n", ($1+$2)/2)}'`
                # Display to screen
                echo " "Post : FIRST_LINE_UTC: $timeBeg / CENTER_LINE_UTC: $timeMid / LAST_LINE_UTC: $timeEnd
                # Update .rsc accordingly
                use_rsc.pl ${LABEL_post}_${strip}_${polar}.raw.rsc write FIRST_LINE_UTC  $timeBeg
                use_rsc.pl ${LABEL_post}_${strip}_${polar}.raw.rsc write CENTER_LINE_UTC $timeMid
                use_rsc.pl ${LABEL_post}_${strip}_${polar}.raw.rsc write LAST_LINE_UTC   $timeEnd
        endif

        # Count number of selected bursts
        set totalNumberOfBurstsAnte=`echo $numOfBurstAnte $SKIP_BEG_ante $SKIP_END_ante | awk '{print $1-$2-$3}'`
        set totalNumberOfBurstsPost=`echo $numOfBurstPost $SKIP_BEG_post $SKIP_END_post | awk '{print $1-$2-$3}'`
        echo "numOfBurstAnte (before skip) "$numOfBurstAnte / SKIP_BEG_ante $SKIP_BEG_ante SKIP_END_ante $SKIP_END_ante" / totalNumberOfBurstsAnte (after skip) "$totalNumberOfBurstsAnte
        echo "numOfBurstPost (before skip) "$numOfBurstPost / SKIP_BEG_post $SKIP_BEG_post SKIP_END_post $SKIP_END_post" / totalNumberOfBurstsPost (after skip) "$totalNumberOfBurstsPost

        # Should be the same for ante and post image... otherwise, exit.
        if ( $totalNumberOfBurstsAnte != $totalNumberOfBurstsPost ) then
            echo "Number of selected bursts for ante and post acquisitions must be the same ! Exit .."
            exit
        endif


	
    # Set a few variables
	cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT
    set MyWidthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read WIDTH`	
    set MyLengthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read FILE_LENGTH`    
    set MyWidthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read WIDTH`
    set MyLengthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read FILE_LENGTH`
    echo MyWidthFullRes $MyWidthFullRes / MyLengthFullRes $MyLengthFullRes
    echo MyWidthLooked $MyWidthLooked / MyLengthLooked $MyLengthLooked

	# Call python program to estimate best-fitting phase plane
	set overlapFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap.txt
	python $dir/python/fit_plane.py $MyWidthLooked $MyLengthLooked $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int $overlapFile
	# if required, save previous determination of SD fit
	if ( ! -e $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit_ORIG.rsc ) then
			cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit.rsc $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit_ORIG.rsc
			cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit.pdf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit_ORIG.pdf
	endif
	# Call python program to estimate best-fitting phase plane
	# if present, use mask to select only relevant overlaps 
	if ( -e $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask.txt ) then
			rm -fr $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask_sdFit.rsc
			rm -fr $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask_sdFit.pdf
        	set overlapFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask.txt
	endif
	# run SD fit using the mask and the original cross-interferogram
	python $dir/python/fit_plane.py $MyWidthLooked $MyLengthLooked $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int $overlapFile

	# Read lag deduced from offsets (Step 2)
	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/
	set outputSDFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_sdFit.rsc
	# normally, this file should have been just created
	if ( -e $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask_sdFit.rsc ) then
        	set outputSDFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask_sdFit.rsc
    else
			echo "Error : file "$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask_sdFit.rsc" not found!"
			echo "Exit"
			exit
	endif
			
	set SD_CONSTANT=`use_rsc.pl $outputSDFile read SD_CONSTANT`
    set SD_SLOPE_X=`use_rsc.pl $outputSDFile read SD_SLOPE_X`
    set SD_SLOPE_Y=`use_rsc.pl $outputSDFile read SD_SLOPE_Y`
	echo " SD_CONSTANT=$SD_CONSTANT  /  SD_SLOPE_X=$SD_SLOPE_X  /  SD_SLOPE_Y=$SD_SLOPE_Y"
	
	# Read lag deduced from spectral diversity (Step 6)
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

    # account for the difference in burst lengths	
    set NbuMaster=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read linesPerBurst`
    set NbuSlave=`use_rsc.pl ${LABEL_post}_${strip}_${polar}_param.rsc read linesPerBurst`
    echo " NbuMaster $NbuMaster  /  NbuSlave $NbuSlave"
    set NbuDiff=`(echo $NbuSlave $NbuMaster | awk '{printf("%.10f", (($1)-($2))/2)}')`
    echo " NbuDiff $NbuDiff"
    set affCoeffFShift=`(echo $AFFINE_COEFF_F $NbuDiff | awk '{printf("%.10f", (($1)-($2)))}')`
    echo " affCoeffFShift $affCoeffFShift"

    # run burst compensation / stitching step one more time (should be the last time)
    #matlab -nodesktop -nosplash -nodisplay -r "SentinelDeburst $burst_comp_param_file_sync_sd " > ${LABEL_post}_${strip}_${polar}_log_deburst_synclag_sd.txt

	# # # # # # # # # # # # # # # # # #
	# # Recalculate fw and bw SLCs

        # Forward image, ante, zero lag
        @ scene = 1
        while ($scene <= $num_files_ante )
		set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt`
		echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""
		python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_scene${scene}_log_deburst_zerolag_fw.txt
                @ scene += 1
        end

        # Backward image, ante, zero lag
        @ scene = 1
        while ($scene <= $num_files_ante )
                set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""
		python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_scene${scene}_log_deburst_zerolag_bw.txt
                @ scene += 1
        end

	# Cleanup before starting
	rm -fr ${LABEL_post}_${strip}_${polar}_bw.slc
	rm -fr ${LABEL_post}_${strip}_${polar}_fw.slc

	# Forward image, post
    cp -f $burst_comp_param_file_sync $burst_comp_param_file_sync_sd_fw
    echo "OVERLAP                                  fw" >> $burst_comp_param_file_sync_sd_fw
    cp -f ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt ${LABEL_post}_${strip}_${polar}_fw_LagInDopOffset.txt

	@ scene = 1
        while ($scene <= $num_files_post )
                set directory=$DIR_IMG_post[$scene]
                echo $strip $directory

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                #echo " --skip_beg ${SKIP_BEG_post} --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                        #echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                else if ($scene == $num_files_post) then
                        #echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt   
                        echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                else   
                        echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                        echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                endif
                echo " --azshift_mean ${COEFF_CONSTANT_FINAL} --azshift_azimuth ${COEFF_SLOPE_Y_FINAL} --azshift_range ${COEFF_SLOPE_X_FINAL} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                echo " --overlap_type Forward " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                if ($num_files_post != 1) then
                        echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                endif
		if ($scene != 1) then
			echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
			# get number of bursts already written to file
			set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_fw_Overlap.txt | awk '{print $1}'`
			if (fileGlobalBurstIndex != "") then
				echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
			endif
		endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt
                set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_fw.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""

                python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag_sd_fw.txt

                @ scene += 1
        end

        cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${LABEL_post}_${strip}_${polar}_fw.slc.rsc


	# Backward image, post
    cp -f $burst_comp_param_file_sync $burst_comp_param_file_sync_sd_bw
    echo "OVERLAP                                  bw" >> $burst_comp_param_file_sync_sd_bw
    cp -f ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt ${LABEL_post}_${strip}_${polar}_bw_LagInDopOffset.txt

	@ scene = 1
        while ($scene <= $num_files_post )
                set directory=$DIR_IMG_post[$scene]
                echo $strip $directory

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                #echo " --skip_beg ${SKIP_BEG_post} --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                        #echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                else if ($scene == $num_files_post) then
                        #echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt   
                        echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                else   
                        echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                        echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                endif
                echo " --azshift_mean ${COEFF_CONSTANT_FINAL} --azshift_azimuth ${COEFF_SLOPE_Y_FINAL} --azshift_range ${COEFF_SLOPE_X_FINAL} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                echo " --overlap_type Backward " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                if ($num_files_post != 1) then
                        echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                endif
		if ($scene != 1) then
			echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
			# get number of bursts already written to file
			set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_bw_Overlap.txt | awk '{print $1}'`
			if (fileGlobalBurstIndex != "") then
				echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
			endif
		endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt
                set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_sd_bw.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""

                python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag_sd_bw.txt

                @ scene += 1
        end

        cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${LABEL_post}_${strip}_${polar}_bw.slc.rsc




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
	
	xint:
	
    # Set a few variables
	cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
    cd INT
    set MyWidthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read WIDTH`	
    set MyLengthFullRes=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR.int.rsc read FILE_LENGTH`    
    set MyWidthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read WIDTH`
    set MyLengthLooked=`use_rsc.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc read FILE_LENGTH`
    echo MyWidthFullRes $MyWidthFullRes / MyLengthFullRes $MyLengthFullRes
    echo MyWidthLooked $MyWidthLooked / MyLengthLooked $MyLengthLooked
    
    # Compute the interferogram difference
	add_cpx ${LABEL_ante}-${LABEL_post}-sim_HDR_fw_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_bw_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $MyWidthLooked $MyLengthLooked -1	
	cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int.rsc

	# Calculate the coherence
	if ( ! -e ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_NEW_${LOOKS_RANGE}rlks.int ) then
		cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_NEW_${LOOKS_RANGE}rlks.int
		cp -f ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int.rsc ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_NEW_${LOOKS_RANGE}rlks.int.rsc
		make_cor.pl ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks
		# Replace amplitude with coherence
		cpx2mag_phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int junk phs $MyWidthLooked
		rmg2mag_phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.cor junk cor $MyWidthLooked
		mag_phs2cpx cor phs ${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $MyWidthLooked
		rm -fr junk phs cor
	endif

	# re-run SD to check that cross-interferogram is now flat
    cd $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT
	set overlapFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap.txt 
	#if ( -e $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask.txt ) then
    #    	set overlapFile=$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap_Mask.txt
	#endif
	python $dir/python/fit_plane.py $MyWidthLooked $MyLengthLooked $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int $overlapFile


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
