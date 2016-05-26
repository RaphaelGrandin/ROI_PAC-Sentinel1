#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 4
### Use ampcor-derived offsets to correct the phase
### with the slave image. Re-do the stiching + deramping
### accordingly (only for the slave)
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
        else if ( $fieldname == "SPECTRAL_DIV" ) then
                set SPECTRAL_DIV=($fieldcontent)
        else if ( $fieldname == "OVERLAP" ) then
                set OVERLAP=($fieldcontent)
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


### Check if user wants to perform spectral diversity (default : SPECTRAL_DIV="yes")
if ( ! $?SPECTRAL_DIV ) then
        set SPECTRAL_DIV="yes"
        echo "Setting SPECTRAL_DIV=$SPECTRAL_DIV (default)."
        echo " > Spectral diversity will be computed."
else if ( $SPECTRAL_DIV != "no" && $SPECTRAL_DIV != "No" && $SPECTRAL_DIV != "NO" && $SPECTRAL_DIV != "0" ) then
        set SPECTRAL_DIV="yes"
        echo "Setting SPECTRAL_DIV=$SPECTRAL_DIV."
        echo " > Spectral diversity will be computed."
else
        set SPECTRAL_DIV="no"
        echo "Setting SPECTRAL_DIV=$SPECTRAL_DIV."
        echo " > Spectral diversity will be skipped."
endif

### Check if user wants to split each overlap in a different file (default) or fill between overlaps
if ( ! $?OVERLAP ) then
        set OVERLAP="split"
        echo "Setting OVERLAP=$OVERLAP (default)."
        echo " > Overlap regions will be split into different SLCs / interferograms."
else if ( $OVERLAP != "fill" ) then
        set OVERLAP="split"
        echo "Setting OVERLAP=$OVERLAP."
        echo " > Overlap regions will be split into different SLCs / interferograms."
else
        set OVERLAP="fill"
        echo "Setting OVERLAP=$OVERLAP."
        echo " > Overlap regions will be displayed into a single SLC / interferogram."
endif

### Check if user wants to process at full resolution (default : FULL_RES="yes")
if ( ! $?FULL_RES ) then
        set FULL_RES="yes"
        echo "Setting FULL_RES=$FULL_RES (default)."
        echo " > Interferograms will be computed at full resolution."
else if ( $FULL_RES != "no" && $FULL_RES != "No" && $FULL_RES != "NO" && $FULL_RES != "0" ) then
        set FULL_RES="yes"
        echo "Setting FULL_RES=$FULL_RES."
        echo " > Interferograms will be computed at full resolution."
else
        set FULL_RES="no"
        echo "Setting FULL_RES=$FULL_RES."
        echo " > Interferograms will be computed at lower resolution."
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
#        echo "Number of files for ante and post images must be the same ! Exit .."
#        exit
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


# # # # # # # # # # # # # # # # #
# # Re-process the slave SLC  # #

# normally this directory should exist
if ( ! -e $WORKINGDIR/SLC ) then
	echo "Directory "SLC" does not exist!"
	echo "Something is wrong."
	echo "Exit..."
	exit
endif

if ( $SPECTRAL_DIV == "yes" ) then
	# normally this directory should exist
	if ( ! -e $WORKINGDIR/OVL ) then
		echo "Directory "OVL" does not exist!"
		echo "Something is wrong."
		echo "Exit..."
		exit
	endif
endif

@ count_strip = 1
while ( $count_strip <= $num_strips )
	set strip=$strip_list[$count_strip]
	set polar=$polar_list[$count_strip]

	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	
	# prepare parameter file for burst compensation / stitching step
	# original parameter file created during Step 1
	set burst_comp_param_file_orig=${LABEL_post}_${strip}_${polar}_param.rsc
	# new parameter file
	set burst_comp_param_file_sync=${LABEL_post}_${strip}_${polar}_param_sync.rsc

	# extract the PRF
	set prf=`(grep PRF ${LABEL_ante}_${strip}_${polar}.raw.rsc | awk '{printf("%10.6f\n",$2)}')`
	#echo $prf

	# # Check consistency of burst_end and burst_beg
	set SKIP_BEG_CHECK = `grep SKIP_BEG $burst_comp_param_file_orig | awk 'NR==1 {print $2}'`
        set SKIP_END_CHECK = `grep SKIP_END $burst_comp_param_file_orig | awk 'NR==1 {print $2}'`
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


	###### R. Grandin, 2015/04/28
	## select only relevant bursts
	#set Nburst_ante=`wc ${LABEL_ante}_${strip}_${polar}_burst.txt | awk '{print $1}'`
	#set Nburst_post=`wc ${LABEL_post}_${strip}_${polar}_burst.txt | awk '{print $1}'`
	#echo Nburst_ante $Nburst_ante Nburst_post $Nburst_post
	#echo SKIP_END_ante $SKIP_END_ante SKIP_END_post $SKIP_END_post
	#echo SKIP_BEG_ante $SKIP_BEG_ante SKIP_BEG_post $SKIP_BEG_post
	#awk '{if( (NR>('$SKIP_BEG_ante')) && (NR<=('$Nburst_ante'-'$SKIP_END_ante'))) print $0}' ${LABEL_ante}_${strip}_${polar}_burst.txt > ${LABEL_ante}_${strip}_${polar}_burst_sel.txt
	#awk '{if( (NR>('$SKIP_BEG_post')) && (NR<=('$Nburst_post'-'$SKIP_END_post'))) print $0}' ${LABEL_post}_${strip}_${polar}_burst.txt > ${LABEL_post}_${strip}_${polar}_burst_sel.txt
	
	##### R. Grandin, 2015/04/28
	# extract burst length differences
#	paste ${LABEL_ante}_${strip}_${polar}_LagOutDop.txt ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_LagOutDop.txt ${LABEL_post}_${strip}_${polar}_burst.txt | awk '{if(NR==1) {firstLineOffset=(($9-$4)*'$prf');} print $1,-($9-$4)*'$prf'+firstLineOffset}' > ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt

#	paste ${LABEL_ante}_${strip}_${polar}_LagOutDop.txt ${LABEL_ante}_${strip}_${polar}_burst_sel.txt ${LABEL_post}_${strip}_${polar}_LagOutDop.txt ${LABEL_post}_${strip}_${polar}_burst_sel.txt | awk '{if(NR==1) {firstLineOffset=(($9-$4)*'$prf');} printf("%2d\t%10.6f\n",$1,-($9-$4)*'$prf'+firstLineOffset)}' > ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt
paste ${LABEL_ante}_${strip}_${polar}_LagOutDop.txt ${LABEL_ante}_${strip}_${polar}_burst_sel.txt ${LABEL_post}_${strip}_${polar}_LagOutDop.txt ${LABEL_post}_${strip}_${polar}_burst_sel.txt | awk '{currentLineOffset=($4)-($9); if(NR==1) {firstLineOffset=currentLineOffset;} printf("%2d\t%.0f\n",$6,(currentLineOffset-firstLineOffset)*'$prf')}' > ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt

	# extract offset and stretch from fitoff
	set fitoffFile=$WORKINGDIR/CORREL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}-${LABEL_post}_${strip}_${polar}_fitoff_gross.out
	# assuming affine matrix is [A,B;D,E]
	# and translation is [C;F]
	# range offset will be :
	# x' = Ax + By + C
	# azimuth offset will be :
	# y' = Dx + Ey + F
	# Need to check if we really need "D"
	set affCoeffD=`(awk 'NR==16 {printf("%.10f",($1))}' $fitoffFile)`
# 	set affCoeffD=0 # test
   	set affCoeffE=`(awk 'NR==16 {printf("%.10f", ($2))}' $fitoffFile)`
        set affCoeffEminusOne=`(awk 'NR==16 {printf("%.10f", ($2)-1)}' $fitoffFile)`
    set affCoeffF=`(awk 'NR==20 {printf("%.10f", ($2))}' $fitoffFile)`
	echo "affCoeffD = "$affCoeffD " / "affCoeffE = "$affCoeffE " / "affCoeffF = "$affCoeffF

	# account for the difference in burst lengths
	set NbuMaster=`use_rsc.pl ${LABEL_ante}_${strip}_${polar}_param.rsc read linesPerBurst` 
    set NbuSlave=`use_rsc.pl ${LABEL_post}_${strip}_${polar}_param.rsc read linesPerBurst`
	echo " NbuMaster $NbuMaster  /  NbuSlave $NbuSlave"
    set NbuDiff=`(echo $NbuSlave $NbuMaster | awk '{printf("%.10f", (($1)-($2))/2)}')`
    echo " NbuDiff $NbuDiff"
    set affCoeffFShift=`(echo $affCoeffF $NbuDiff | awk '{printf("%.10f", (($1)-($2)))}')`
    echo " affCoeffF $affCoeffF"

	# write compensation input file
    awk '{if($1!="SETLAGTOZERO") print $0}' $burst_comp_param_file_orig > $burst_comp_param_file_sync
    echo "SETLAGTOZERO                             no" >> $burst_comp_param_file_sync
	#	echo "OVERLAP                                  fw" >> $burst_comp_param_file_sync
	#   echo "OVERLAP                                  bw" >> $burst_comp_param_file_sync
    echo "AFFINE_COEFF_D                    "$affCoeffD >> $burst_comp_param_file_sync
    echo "AFFINE_COEFF_E                    "$affCoeffE >> $burst_comp_param_file_sync
    echo "AFFINE_COEFF_F                    "$affCoeffF >> $burst_comp_param_file_sync
    echo "AFFINE_COEFF_F_SHIFT              "$affCoeffFShift >> $burst_comp_param_file_sync
    

	# # run burst compensation / stitching step
	
	# split overlap area in the middle
	@ scene = 1
	while ($scene <= $num_files_post )
		set directory=$DIR_IMG_post[$scene]
		echo $strip $directory 
		
		echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                else if ($scene == $num_files_post) then
                        echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                else   
                        echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                        echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                endif
                echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                echo " --azshift_mean ${affCoeffFShift} --azshift_azimuth ${affCoeffEminusOne} --azshift_range ${affCoeffD} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                if ($num_files_post != 1) then
                        echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                endif
		if ($scene == 1) then
			# Set first burst number in slave image to fit with burst number of master image
			set fileGlobalBurstIndex=`head -1 ${LABEL_ante}_${strip}_${polar}_Overlap.txt | awk '{print $1 - 2}'`
			if (fileGlobalBurstIndex != "") then
                      echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
            endif
		else 
			echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
			# get number of bursts already written to file
			set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_Overlap.txt | awk '{print $1}'`
			if (fileGlobalBurstIndex != "") then
				echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
			endif
		endif
		if ( $SPECTRAL_DIV == "yes" && $OVERLAP == "split" ) then
			echo " --split_overlap yes "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
		endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt
                set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""

                python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag.txt

	    @ scene += 1
	end
	
	if ( $SPECTRAL_DIV == "yes" && $OVERLAP == "split" ) then
		# # Update file length of each overlap SLC
		# Forward
		foreach SLCfile (`ls ${LABEL_post}_${strip}_${polar}_ovl_???_fw.slc`)
			set YSIZE=`(grep lines ${SLCfile}.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
			cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${SLCfile}.rsc
			use_rsc.pl ${SLCfile}.rsc write FILE_LENGTH $YSIZE
			use_rsc.pl ${SLCfile}.rsc write YMAX $YSIZE
			use_rsc.pl ${SLCfile}.rsc write RLOOKS $YSIZE
			use_rsc.pl ${SLCfile}.rsc write ALOOKS $YSIZE
                        ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile} $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}
                        cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc
		end
		# Backward
		foreach SLCfile (`ls ${LABEL_post}_${strip}_${polar}_ovl_???_bw.slc`)
			set YSIZE=`(grep lines ${SLCfile}.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
			cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${SLCfile}.rsc
			use_rsc.pl ${SLCfile}.rsc write FILE_LENGTH $YSIZE
			use_rsc.pl ${SLCfile}.rsc write YMAX $YSIZE
			use_rsc.pl ${SLCfile}.rsc write RLOOKS $YSIZE
			use_rsc.pl ${SLCfile}.rsc write ALOOKS $YSIZE
                        ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile} $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}
                        cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc
		end
                # Overlap location
                cp -f ${LABEL_post}_${strip}_${polar}_Overlap.txt $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/
	endif
	
	if ( $SPECTRAL_DIV == "yes" && $OVERLAP == "fill" ) then

    	# # extract forward-looking SLC and backward-looking SLC for later Spectral Diversity step

		# forward looking geometry
    		set burst_comp_param_file_sync_fw=${LABEL_post}_${strip}_${polar}_param_sync_fw.rsc
    		cp -f $burst_comp_param_file_sync $burst_comp_param_file_sync_fw
    		echo "OVERLAP                                  fw" >> $burst_comp_param_file_sync_fw
    		cp -f ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt ${LABEL_post}_${strip}_${polar}_fw_LagInDopOffset.txt

        	@ scene = 1
        	while ($scene <= $num_files_post )
                	set directory=$DIR_IMG_post[$scene]
                	echo $strip $directory

                	echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	if ($scene == 1) then
                        	echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	else if ($scene == $num_files_post) then
                        	echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	else  
                        	echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                        	echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	endif
                    echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
			        echo " --azshift_mean ${affCoeffFShift} --azshift_azimuth ${affCoeffEminusOne} --azshift_range ${affCoeffD} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                    echo " --split_overlap no "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	echo " --overlap_type Forward " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	if ($num_files_post != 1) then
                        	echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	endif
			if ($scene == 1) then
				# Set first burst number in slave image to fit with burst number of master image
				set fileGlobalBurstIndex=`head -1 ${LABEL_ante}_${strip}_${polar}_Overlap.txt | awk '{print $1 - 2}'`
				if (fileGlobalBurstIndex != "") then
	                      echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
	            endif
			else
				echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
				# get number of bursts already written to file
				set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_fw_Overlap.txt | awk '{print $1}'`
				if (fileGlobalBurstIndex != "") then
					echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
				endif
			endif
                	echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt
                	set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_fw.txt`
                	echo ""
                	echo " > > Command : " $ARGS_PYTHON
                	echo ""

                	python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag_fw.txt

                	@ scene += 1
        	end

                # Update rsc file
        	cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${LABEL_post}_${strip}_${polar}_fw.slc.rsc

                # Link new SLC  to OVL directory
                set SLCfile=${LABEL_post}_${strip}_${polar}_fw.slc
                ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile} $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}
                cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc

		# backward looking geometry
    		set burst_comp_param_file_sync_bw=${LABEL_post}_${strip}_${polar}_param_sync_bw.rsc
    		cp -f $burst_comp_param_file_sync $burst_comp_param_file_sync_bw
    		echo "OVERLAP                                  bw" >> $burst_comp_param_file_sync_bw
    		cp -f ${LABEL_post}_${strip}_${polar}_LagInDopOffset.txt ${LABEL_post}_${strip}_${polar}_bw_LagInDopOffset.txt

        	@ scene = 1
        	while ($scene <= $num_files_post )
                	set directory=$DIR_IMG_post[$scene]
                	echo $strip $directory

                	echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	if ($scene == 1) then
                        	echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	else if ($scene == $num_files_post) then
                        	echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	else
                        	echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                        	echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	endif
                    echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
               	    echo " --azshift_mean ${affCoeffFShift} --azshift_azimuth ${affCoeffEminusOne} --azshift_range ${affCoeffD} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
               	    echo " --split_overlap no "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	echo " --overlap_type Backward " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	if ($num_files_post != 1) then
                        	echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	endif
			if ($scene == 1) then
				# Set first burst number in slave image to fit with burst number of master image
				set fileGlobalBurstIndex=`head -1 ${LABEL_ante}_${strip}_${polar}_Overlap.txt | awk '{print $1 - 2}'`
				if (fileGlobalBurstIndex != "") then
	                      echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
	            endif
			else
				echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
				# get number of bursts already written to file
				set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_bw_Overlap.txt | awk '{print $1}'`
				if (fileGlobalBurstIndex != "") then
					echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
				endif
			endif
                	echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt
                	set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_synclag_bw.txt`
                	echo ""
                	echo " > > Command : " $ARGS_PYTHON
                	echo ""

                	python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_synclag_bw.txt
		
			@ scene += 1
		end

                # Update rsc file
        	cp -f ${LABEL_post}_${strip}_${polar}.slc.rsc ${LABEL_post}_${strip}_${polar}_bw.slc.rsc

                # Link new SLC  to OVL directory
                set SLCfile=${LABEL_post}_${strip}_${polar}_bw.slc
		ln -sf $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile} $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}
                cp -f $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${SLCfile}.rsc

	endif

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
