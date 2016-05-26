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

if ( $SPECTRAL_DIV == "yes" ) then

# # # # # # # # # # # # # # # # # 
# # Spectral diversity Step 1 # #

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

    echo strip $strip polar $polar

	
	# New method, faster but less accurate
        if ( $OVERLAP == "split" ) then

		cd $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	
		## Import files necessary for interferogram calculation
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}_resamp.in .
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}_cull.off .
		set resampInFile="${LABEL_ante}-${LABEL_post}_resamp.in"
		set cullInFile="${LABEL_ante}-${LABEL_post}_cull.off"

		# Forward and backward interferograms
		foreach SLCfileMaster (`ls ${LABEL_ante}_${strip}_${polar}_ovl_???_?w.slc`)
	
			# File names
			set overlapNumber=`echo $SLCfileMaster:r | awk '{print substr($1,length($1)-5,3)}'`
			set overlapType=`echo $SLCfileMaster:r | awk '{print substr($1,length($1)-1,2)}'`
			set SLCfileSlave=`ls ${LABEL_post}_${strip}_${polar}_ovl_${overlapNumber}_${overlapType}.slc`
			set resampOutFile="${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_${overlapType}_resamp.in"
			set interfOutFile="${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_${overlapType}.int"
			set ampOutFile="${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_${overlapType}.amp"
			set cullOutFile="${LABEL_ante}-${LABEL_post}_cull_ovl_${overlapNumber}_${overlapType}.off"

			echo "Processing $SLCfileMaster -- $SLCfileSlave to generate $interfOutFile"
			
			# Catch necessary information
			set NumRanSampIm1=`grep "Number of Range Samples Image 1" $resampInFile | awk '{print $NF}'`
			set NumRanSampIm2=`grep "Number of Range Samples Image 2" $resampInFile | awk '{print $NF}'`
			set StartLine=`grep "Starting Line, Number of Lines, and First Line Offset" $resampInFile | awk '{print $(NF-2)}'`
			set NumLines=`grep "Starting Line, Number of Lines, and First Line Offset" $resampInFile | awk '{print $(NF-1)}'`
			set FirstLineOffset=`grep "Starting Line, Number of Lines, and First Line Offset" $resampInFile | awk '{print $(NF)}'`
			set FirstLineOffsetShift=`awk '{if($1=='$overlapNumber') print $2}' ${LABEL_ante}_${strip}_${polar}_Overlap.txt`
			set RadWavelength=`grep "Radar Wavelength" $resampInFile | awk '{print $NF}'`
			set SlantRangePxSpacing=`grep "Slant Range Pixel Spacing" $resampInFile | awk '{print $NF}'`
			set YMAX=`use_rsc.pl ${SLCfileMaster}.rsc read FILE_LENGTH`

			# Shift offsets
			awk '{printf("%6d%11.3f%7d%12.3f%11.5f%11.6f%11.6f%11.6f\n", $1,$2,($3)-('$FirstLineOffsetShift'),$4,$5,$6,$7,$8)}' $cullInFile > $cullOutFile 
		
			# Write input file for resamp_roi
			echo "" > $resampOutFile
			echo "Image Offset File Name                                  (-)     = $cullOutFile"          >> $resampOutFile
			echo "Display Fit Statistics to Screen                        (-)     = No Fit Stats"         >> $resampOutFile
			echo "Number of Fit Coefficients                              (-)     = 6"                    >> $resampOutFile
			echo "SLC Image File 1                                        (-)     = $SLCfileMaster"       >> $resampOutFile
			echo "Number of Range Samples Image 1                         (-)     = $NumRanSampIm1"       >> $resampOutFile
			echo "SLC Image File 2                                        (-)     = $SLCfileSlave"        >> $resampOutFile
			echo "Number of Range Samples Image 2                         (-)     = $NumRanSampIm2"       >> $resampOutFile
			echo "Output Interferogram File                               (-)     = $interfOutFile"       >> $resampOutFile
			echo "Multi-look Amplitude File                               (-)     = $ampOutFile"          >> $resampOutFile
			echo "Starting Line, Number of Lines, and First Line Offset   (-)     = $StartLine $YMAX $FirstLineOffset" >> $resampOutFile
			echo "Doppler Cubic Fit Coefficients - PRF Units              (-)     = 0 0 0 0"              >> $resampOutFile
			echo "Radar Wavelength                                        (m)     = $RadWavelength"       >> $resampOutFile
			echo "Slant Range Pixel Spacing                               (m)     = $SlantRangePxSpacing" >> $resampOutFile
			echo "Number of Range and Azimuth Looks                       (-)     = 1 1"                  >> $resampOutFile
			echo "Flatten with offset fit?                                (-)     = No"                   >> $resampOutFile
			
			# Run resamp_roi to compute interferogram
			$INT_BIN/resamp_roi $resampOutFile
	
			cp -f ${SLCfileMaster}.rsc ${interfOutFile}.rsc
			cp -f ${SLCfileMaster}.rsc ${ampOutFile}.rsc
			
			# Multilook
			look.pl ${interfOutFile} $LOOKS_RANGE $LOOKS_AZIMUTH
			look.pl ${ampOutFile} $LOOKS_RANGE $LOOKS_AZIMUTH

	                # Cleanup
			rm -fr $cullOutFile
		
		end
	
		# Double difference interferograms
		foreach IntFileFw (`ls ${LABEL_ante}-${LABEL_post}_ovl_???_fw.int`)

			# File names
			set overlapNumber=`echo $IntFileFw:r | awk '{print substr($1,length($1)-5,3)}'`
			set IntFileBw=`ls ${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_bw.int`
			
			set IntFileFwLook=`echo ${IntFileFw:r}_${LOOKS_RANGE}rlks.int`
			set IntFileBwLook=`echo ${IntFileBw:r}_${LOOKS_RANGE}rlks.int`
	
			set AmpFileFw=`ls ${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_fw.amp`
			set AmpFileFwLook=`echo ${AmpFileFw:r}_${LOOKS_RANGE}rlks.amp`

			set AmpFileBw=`ls ${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_bw.amp`
			set AmpFileBwLook=`echo ${AmpFileBw:r}_${LOOKS_RANGE}rlks.amp`
		
			set OutFileXint=`echo ${LABEL_ante}-${LABEL_post}_ovl_${overlapNumber}_xint.int`
			set OutFileXintLook=`echo ${OutFileXint:r}_${LOOKS_RANGE}rlks.int`
			echo "Processing $IntFileFwLook -- $IntFileBwLook to generate $OutFileXintLook"

		    	# Set a few variables
			set MyWidthFullRes=`use_rsc.pl ${IntFileFwLook}.rsc read WIDTH`	
			set MyLengthFullRes=`use_rsc.pl ${IntFileFwLook}.rsc read FILE_LENGTH`    
			set MyWidthLooked=`use_rsc.pl ${IntFileFwLook}.rsc read WIDTH`
			set MyLengthLooked=`use_rsc.pl ${IntFileFwLook}.rsc read FILE_LENGTH`

			# Compute the interferogram difference
			$INT_BIN/add_cpx $IntFileFwLook $IntFileBwLook $OutFileXintLook $MyWidthLooked $MyLengthLooked -1	
			cp -f $IntFileFwLook.rsc $OutFileXintLook.rsc

			# Calculate the coherence
			make_cor.pl ${OutFileXintLook:r} ${AmpFileFwLook:r} ${OutFileXintLook:r}

			# Replace amplitude with coherence
			$INT_BIN/cpx2mag_phs $OutFileXintLook junk phs $MyWidthLooked
			$INT_BIN/rmg2mag_phs ${OutFileXintLook:r}.cor junk cor $MyWidthLooked
			$INT_BIN/mag_phs2cpx cor phs $OutFileXintLook $MyWidthLooked
			rm -fr junk phs cor

                	# Cleanup
                	rm -fr $IntFileBw $IntFileBw.rsc
                	rm -fr $IntFileFw $IntFileFw.rsc
                	rm -fr $AmpFileFw $AmpFileFw.rsc
                	rm -fr $AmpFileBw $AmpFileBw.rsc
                	rm -fr $IntFileFwLook $IntFileBwLook $IntFileFwLook.rsc $IntFileBwLook.rsc

		end

	# Old method (more accurate, but takes longer)
        else if ( $OVERLAP == "fill" ) then

		cd $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}

		## Import files necessary for interferogram calculation
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}_resamp.in .
                cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/${LABEL_ante}-${LABEL_post}_cull.off .
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in
		ln -sf $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/radar.hgt .
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/radar.hgt.rsc .

		set resampInFile="${LABEL_ante}-${LABEL_post}_resamp.in"
		set cullInFile="${LABEL_ante}-${LABEL_post}_cull.off"
		set diffnsimInFile="diffnsim_${LABEL_ante}-${LABEL_post}-sim_HDR.int.in"
		

		# File names
                set SLCfileMaste=`ls ${LABEL_ante}_${strip}_${polar}_fw.slc`
                set SLCfileSlave=`ls ${LABEL_post}_${strip}_${polar}_fw.slc`
                set resampOutFile="${LABEL_ante}-${LABEL_post}_fw_resamp.in"
                set interfOutFile="${LABEL_ante}-${LABEL_post}.int"
                set ampOutFile="${LABEL_ante}-${LABEL_post}.amp"
                set ampOutFileLooked="${LABEL_ante}-${LABEL_post}_${LOOKS_RANGE}rlks.amp"
                set interfSimOutFile="${LABEL_ante}-${LABEL_post}-sim_HDR.int"
                set interfSimOutFileLooked="${LABEL_ante}-${LABEL_post}-sim_HDR_${LOOKS_RANGE}rlks.int"


                # # # # # # # # # # # 
                # # # Forward-looking interferogram
                set SLCfileMasteFw=`ls ${LABEL_ante}_${strip}_${polar}_fw.slc`
                set SLCfileSlaveFw=`ls ${LABEL_post}_${strip}_${polar}_fw.slc`
                set interfOutFileFw="${LABEL_ante}-${LABEL_post}-sim_HDR_fw_${LOOKS_RANGE}rlks.int"

		echo "Processing $SLCfileMasterFw -- $SLCfileSlaveFw to generate $interfOutFileFw"

		ln -sf $SLCfileMasteFw $SLCfileMaste
                ln -sf $SLCfileSlaveFw $SLCfileSlave

                # Run resamp_roi to compute interferogram
		rm -fr $interfOutFile $ampOutFile
		$INT_BIN/resamp_roi $resampInFile
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/$interfOutFile.rsc $interfOutFile.rsc
		cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/$ampOutFile.rsc    $ampOutFile.rsc
		# Multilook amplitude
		rm -fr $ampOutFileLooked
                look.pl ${ampOutFile} $LOOKS_RANGE $LOOKS_AZIMUTH
		# Subtract simulation
		rm -fr $interfSimOutFile radar_HDR.unw
		$INT_BIN/diffnsim $diffnsimInFile
                rm -fr $interfSimOutFileLooked
                look.pl $interfSimOutFile $LOOKS_RANGE $LOOKS_AZIMUTH

                # save the interferogram for Spectral diversity calculation
                mv -f $interfSimOutFileLooked     $interfOutFileFw
		cp -f $interfSimOutFileLooked.rsc $interfOutFileFw.rsc

                # # # # # # # # # # # 
                # # # Backward-looking interferogram
                set SLCfileMasteBw=`ls ${LABEL_ante}_${strip}_${polar}_bw.slc`
                set SLCfileSlaveBw=`ls ${LABEL_post}_${strip}_${polar}_bw.slc`
                set interfOutFileBw="${LABEL_ante}-${LABEL_post}-sim_HDR_bw_${LOOKS_RANGE}rlks.int"

                echo "Processing $SLCfileMasterBw -- $SLCfileSlaveBw to generate $interfOutFileBw"

                ln -sf $SLCfileMasteBw $SLCfileMaste
                ln -sf $SLCfileSlaveBw $SLCfileSlave

                # Run resamp_roi to compute interferogram
                rm -fr $interfOutFile $ampOutFile
                $INT_BIN/resamp_roi $resampInFile
                cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/$interfOutFile.rsc $interfOutFile.rsc
                cp -f $WORKINGDIR/INTERFERO/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/INT/$ampOutFile.rsc    $ampOutFile.rsc
                # Subtract simulation
                rm -fr $interfSimOutFile radar_HDR.unw
                $INT_BIN/diffnsim $diffnsimInFile
                rm -fr $interfSimOutFileLooked
                look.pl $interfSimOutFile $LOOKS_RANGE $LOOKS_AZIMUTH

                # save the interferogram for Spectral diversity calculation
                mv -f $interfSimOutFileLooked     $interfOutFileBw
                cp -f $interfSimOutFileLooked.rsc $interfOutFileBw.rsc

		# cleanup
		rm -fr radar_HDR.unw

    		# # # # # # # # # # # 
    		# # # Double-difference interferogram (xint)
    		# Set a few variables
    		set MyWidthLooked=`use_rsc.pl  $interfSimOutFileLooked.rsc read WIDTH`
    		set MyLengthLooked=`use_rsc.pl $interfSimOutFileLooked.rsc read FILE_LENGTH`
		set XintOutFile="${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int"
                set XintOutFileOrig="${LABEL_ante}-${LABEL_post}-sim_HDR_xint_ORIG_${LOOKS_RANGE}rlks.int"
		set CorOutFile="${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.cor"

                echo "Processing $interfOutFileFw -- $interfOutFileBw to generate $XintOutFile"

    		# Compute the interferogram difference
            	$INT_BIN/add_cpx $interfOutFileFw $interfOutFileBw $XintOutFile $MyWidthLooked $MyLengthLooked -1
        	cp -f $interfSimOutFileLooked.rsc $XintOutFile.rsc

        	# Calculate the coherence
        	if ( ! -e $XintOutFileOrig ) then
                	cp -f $XintOutFile     $XintOutFileOrig
                        cp -f $XintOutFile.rsc $XintOutFileOrig.rsc
                	make_cor.pl ${XintOutFile:r} ${ampOutFileLooked:r} ${XintOutFile:r}
                	# Replace amplitude with coherence
			$INT_BIN/cpx2mag_phs $XintOutFile junk phs $MyWidthLooked
			$INT_BIN/rmg2mag_phs $CorOutFile  junk cor $MyWidthLooked
			$INT_BIN/mag_phs2cpx cor phs $XintOutFile $MyWidthLooked
                	rm -fr junk phs cor
		else
			echo "File $XintOutFileOrig already exists!"
        		echo "Something is wrong."
        		echo "Exit..."
        	endif

	endif

        # # # # # # # # # # # 
        # # # Fit plane on double-difference interferogram

        # Call python program to estimate best-fitting phase plane
        cd $WORKINGDIR
        if ( $OVERLAP == "split" ) then
	    cd $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
            set example_file=`ls $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}-${LABEL_post}_ovl_???_xint_${LOOKS_RANGE}rlks.int | head -1`
            set INPUT_XINT="${example_file}"
            set SPLIT_OVERLAP="yes"
        else
	    cd $WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
            set INPUT_XINT="$WORKINGDIR/OVL/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}-${LABEL_post}-sim_HDR_xint_${LOOKS_RANGE}rlks.int"
            set SPLIT_OVERLAP="no"
        endif
	set MyWidthLooked=`use_rsc.pl $INPUT_XINT read WIDTH`
	set MyLengthLooked=`use_rsc.pl $INPUT_XINT read FILE_LENGTH`
        set INPUT_OVERLAP="$WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/${LABEL_ante}_${strip}_${polar}_Overlap.txt"
	
	echo " $dir/python/fit_plane.py $MyWidthLooked $MyLengthLooked $INPUT_XINT $INPUT_OVERLAP $SPLIT_OVERLAP" > ${LABEL_ante}_${strip}_${polar}_fitplane_command.txt
	set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_fitplane_command.txt`
        echo ""
        echo " > > Command : " $ARGS_PYTHON
        echo ""
	python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_fitplane_log.txt

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
