#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 1
### TIFF => SLC for master and slave
### Do the stitching + deramping for the slave and 
### master images. Uses burst centre time to set the
### time origin of the deramping functions
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
        else if ( $fieldname == "DOWNLOAD_ORB" ) then
                set DOWNLOAD_ORB=($fieldcontent)
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

### Check if user wants to download orbits (default : DOWNLOAD_ORB="yes")
if ( ! $?DOWNLOAD_ORB ) then
        set DOWNLOAD_ORB="yes"
else if ( $DOWNLOAD_ORB != "no" && $DOWNLOAD_ORB != "No" && $DOWNLOAD_ORB != "NO" && $DOWNLOAD_ORB != "0" ) then
        echo "Setting DOWNLOAD_ORB to \"yes\" (default)."
        set DOWNLOAD_ORB="yes"
else
        echo "Download of orbit files will be skipped (DOWNLOAD_ORB=$DOWNLOAD_ORB)."
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



# # # # # # # # # # # # 
# # Unzip the data  # #

cd $DIR_ARCHIVE
@ scene = 1
while ( $scene <= $num_files_ante )

	if( ! -e $DIR_IMG_ante[$scene]) then
		set archiveName=$DIR_IMG_ante[$scene]:r.zip
		echo $archiveName
		echo "Unzipping "$archiveName " ... "
		unzip $archiveName
		echo "Done."
	endif
    @ scene ++
end
@ scene = 1
while ( $scene <= $num_files_post )

	if( ! -e $DIR_IMG_post[$scene]) then
		set archiveName=$DIR_IMG_post[$scene]:r.zip
		echo $archiveName
		echo "Unzipping "$archiveName " ... "
		unzip $archiveName
		echo "Done."
	endif
    @ scene ++      
end


# # # # # # # # # # # # 
# # Build the SLCs  # #

# Create SLC directory
cd $WORKINGDIR
if( ! -e SLC ) then
	mkdir SLC
endif

@ count_strip = 1
while ( $count_strip <= $num_strips )
	set strip=$strip_list[$count_strip]
        set polar=$polar_list[$count_strip]

	cd $WORKINGDIR/SLC

	if ( ! -e $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar} ) then
		mkdir $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	endif
	
	cd $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}
	
	# # # # # # # # # # # 
	# # # # # # # # # # # 
	#### Read the metadata
	# # # # # # # # # # # 
	# # # # # # # # # # # 


	# # Master image  # #
	
	#@ scene = 1
	#while ($scene <= $num_files )
		#set directory=$DIR_IMG_ante[$scene]
		#echo $strip $directory 
		
		## run metadata parser
		#python $dir/python/safe2rsc.py -m ${strip} -p ${polar} $DIR_ARCHIVE/$directory
	    #@ scene += 1
	#end
#exit(0)

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

    # Find which image starts first
    #  0 if images are synchrone
    # +1 if Ante starts before Post
    # -1 if Post starts before Ante
	set orderAntePostBeg=`(paste ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_burst.txt | head -1 | \
		awk '{time_beg_ante=$2; time_beg_post=$5; if((sqrt(((time_beg_post)-(time_beg_ante))*((time_beg_post)-(time_beg_ante)))<0.1)) print 0; else {if(time_beg_post>time_beg_ante) print 1; else print -1}}')`

	# Check
	#paste ${LABEL_ante}_${strip}_${polar}_burst.txt ${LABEL_post}_${strip}_${polar}_burst.txt 

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

	# in case of a long data take : download orbits and write hdr file
	# an orbit file has already be written, based on the metadata
	# this part of the script allows for overwriting the file
	if ( $DOWNLOAD_ORB == "yes" ) then
#        if ( $num_files_ante > 2 ) then
        	echo "This is a long strip : downloading orbit files from ESA Sentinel-1 QC web site"
        	echo $DIR_IMG_ante[1] $DIR_IMG_ante[$num_files_ante]
        	set antePlatform=`echo $DIR_IMG_ante[1] | awk '{print substr($1,1,3)}'`
        	set anteStartTime=`echo $DIR_IMG_ante[1] | awk '{print substr($1,18,15)}'`
        	set anteStopTime=`echo $DIR_IMG_ante[$num_files_ante] | awk '{print substr($1,34,15)}'`
        	echo " Master: "$antePlatform $anteStartTime "-->" $anteStopTime
        	echo $DIR_IMG_post[1] $DIR_IMG_post[$num_files_post]
        	set postPlatform=`echo $DIR_IMG_post[1] | awk '{print substr($1,1,3)}'`
        	set postStartTime=`echo $DIR_IMG_post[1] | awk '{print substr($1,18,15)}'`
        	set postStopTime=`echo $DIR_IMG_post[$num_files_post] | awk '{print substr($1,34,15)}'`
        	echo " Slave:  "$postPlatform $postStartTime "-->" $postStopTime

		foreach orbitType ( RESORB POEORB ) # start with restituted orbits, then precise orbits
       			echo "Downloading $orbitType orbits"
			if ( ! -e $WORKINGDIR/ORB/$antePlatform/$orbitType/hdr_data_points_${LABEL_ante}.rsc ) then 
				$dir/scripts/S1-ROI_PAC_01b_download_orbits.sh $dir $antePlatform $orbitType $anteStartTime $anteStopTime $WORKINGDIR $WORKINGDIR/ORB/$antePlatform/$orbitType
			endif
			cp -f $WORKINGDIR/ORB/$antePlatform/$orbitType/hdr_data_points_${LABEL_ante}.rsc $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/hdr_data_points_${LABEL_ante}_${strip}_${polar}.rsc
			if ( ! -e $WORKINGDIR/ORB/$postPlatform/$orbitType/hdr_data_points_${LABEL_post}.rsc ) then
				$dir/scripts/S1-ROI_PAC_01b_download_orbits.sh $dir $postPlatform $orbitType $postStartTime $postStopTime $WORKINGDIR $WORKINGDIR/ORB/$postPlatform/$orbitType
			endif
			cp -f $WORKINGDIR/ORB/$postPlatform/$orbitType/hdr_data_points_${LABEL_post}.rsc $WORKINGDIR/SLC/${LABEL_ante}-${LABEL_post}_${strip}_${polar}/hdr_data_points_${LABEL_post}_${strip}_${polar}.rsc
		end
	endif


	# # # # # # # # # # # 
	# # # # # # # # # # # 
	### Deramping / Debursting 
	# # # # # # # # # # # 
	# # # # # # # # # # # 

	# # Master image  # #

	# prepare parameter file for burst compensation / stitching step
	set burst_comp_param_file=${LABEL_ante}_${strip}_${polar}_param.rsc
    set burst_comp_param_file_fw=${LABEL_ante}_${strip}_${polar}_param_fw.rsc
    set burst_comp_param_file_bw=${LABEL_ante}_${strip}_${polar}_param_bw.rsc
	
	# optionally, extract only forward or backward look in overlap region
	#echo "OVERLAP                                  fw" >> $burst_comp_param_file
    #echo "OVERLAP                                  bw" >> $burst_comp_param_file

	# skip bursts
	echo "SKIP_BEG                            $SKIP_BEG_ante" >> $burst_comp_param_file
	echo "SKIP_END                            $SKIP_END_ante" >> $burst_comp_param_file

	# copy parameter file for forward and backward SLC processing
	cp -f $burst_comp_param_file $burst_comp_param_file_fw
	cp -f $burst_comp_param_file $burst_comp_param_file_bw

	# display incidence and squint angles
	echo "INCIDENCE                                yes" >> $burst_comp_param_file

	# # run burst compensation / stitching step
	
	# split overlap area in the middle
	@ scene = 1
	while ($scene <= $num_files_ante )
		set directory=$DIR_IMG_ante[$scene]
		echo $strip $directory 
		
		# run make SLC

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                #echo " --skip_beg ${SKIP_BEG_ante} --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		if ($scene == 1) then
			echo " --skip_beg ${SKIP_BEG_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
			#echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
			echo " --total_number_of_bursts $totalNumberOfBurstsAnte " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		else if ($scene == $num_files_ante) then
            #echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
			echo " --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		else
			echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
			echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		endif
		# if several input TIFF files are provided, append to end of output SLC file
                if ($num_files_ante != 1) then
					echo " --number_of_files $num_files_ante " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		endif
                if ($scene != 1) then
                                        echo " --file_order Append "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
					# get number of bursts already written to file
					set fileGlobalBurstIndex=`tail -1 ${LABEL_ante}_${strip}_${polar}_Overlap.txt | awk '{print $1}'`
					if (fileGlobalBurstIndex != "") then
						echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
					endif
                endif
                echo " --incidence True "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt`
		echo ""
                echo " > > Command : " $ARGS_PYTHON
		echo ""

		python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_scene${scene}_log_deburst_zerolag.txt

	    @ scene += 1
	end
			
	# read file size information
	set YSIZE=`(grep YMAX ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`

	# save file size information in .rsc metadata file (for ROI_PAC)
	echo "FILE_LENGTH                     "$YSIZE > ${LABEL_ante}_${strip}_${polar}.slc.rsc
	echo "YMIN                            "0 >> ${LABEL_ante}_${strip}_${polar}.slc.rsc
	echo "YMAX                            "$YSIZE >> ${LABEL_ante}_${strip}_${polar}.slc.rsc

	# read time information
	set FIRST_LINE_YEAR=`(grep FIRST_LINE_YEAR ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')` 
        set FIRST_LINE_MONTH_OF_YEAR=`(grep FIRST_LINE_MONTH_OF_YEAR ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_DAY_OF_MONTH=`(grep FIRST_LINE_DAY_OF_MONTH ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_HOUR_OF_DAY=`(grep FIRST_LINE_HOUR_OF_DAY ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
	set FIRST_LINE_MN_OF_HOUR=`(grep FIRST_LINE_MN_OF_HOUR ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
	set FIRST_LINE_S_OF_MN=`(grep FIRST_LINE_S_OF_MN ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_MS_OF_S=`(grep FIRST_LINE_MS_OF_S ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_STRING=`(grep FIRST_LINE_STRING ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_UTC=`(grep FIRST_LINE_UTC ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_FRAME_SCENE_CENTER_TIME=`(grep FIRST_FRAME_SCENE_CENTER_TIME ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set CENTER_LINE_UTC=`(grep CENTER_LINE_UTC ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set LAST_LINE_UTC=`(grep LAST_LINE_UTC ${LABEL_ante}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`

	# update the rsc file
	use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_YEAR $FIRST_LINE_YEAR
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_MONTH_OF_YEAR $FIRST_LINE_MONTH_OF_YEAR
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_DAY_OF_MONTH $FIRST_LINE_DAY_OF_MONTH
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_HOUR_OF_DAY $FIRST_LINE_HOUR_OF_DAY
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_MN_OF_HOUR $FIRST_LINE_MN_OF_HOUR
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_S_OF_MN $FIRST_LINE_S_OF_MN
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_MS_OF_S $FIRST_LINE_MS_OF_S
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_STRING $FIRST_LINE_STRING
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_LINE_UTC $FIRST_LINE_UTC
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write FIRST_FRAME_SCENE_CENTER_TIME $FIRST_FRAME_SCENE_CENTER_TIME
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write CENTER_LINE_UTC $CENTER_LINE_UTC
        use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc write LAST_LINE_UTC $LAST_LINE_UTC

	# merge the rsc files
	use_rsc.pl ${LABEL_ante}_${strip}_${polar}.slc.rsc merge ${LABEL_ante}_${strip}_${polar}.raw.rsc

	# incidence angles
	cp ${LABEL_ante}_${strip}_${polar}.slc.rsc ${LABEL_ante}_${strip}_${polar}_los.unw.rsc
	#look.pl ${LABEL_ante}_${strip}_${polar}_los.unw $LOOKS_RANGE $LOOKS_AZIMUTH

        if ( $SPECTRAL_DIV != "no" && $SPECTRAL_DIV != "No" && $SPECTRAL_DIV != "NO" && $SPECTRAL_DIV != "0" ) then

    # # extract forward-looking SLC and backward-looking SLC for later Spectral Diversity step

	# forward looking geometry
        echo "OVERLAP                                  fw" >> $burst_comp_param_file_fw
	@ scene = 1
        while ($scene <= $num_files_ante )
                set directory=$DIR_IMG_ante[$scene]
                echo $strip $directory

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                #echo " --skip_beg ${SKIP_BEG_ante} --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                        #echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsAnte " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                else if ($scene == $num_files_ante) then
                        #echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                        echo " --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                else
                        echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                        echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                endif
                echo " --overlap_type Forward " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
		# if several input TIFF files are provided, append to end of output SLC file
		if ($num_files_ante != 1) then
                                        echo " --number_of_files $num_files_ante " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                endif
                if ($scene != 1) then
                                        echo " --file_order Append "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
					# get number of bursts already written to file
					set fileGlobalBurstIndex=`tail -1 ${LABEL_ante}_${strip}_${polar}_fw_Overlap.txt | awk '{print $1}'`
					if (fileGlobalBurstIndex != "") then
                                                echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
                                        endif
                endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt
		set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_fw.txt`
		echo ""
		echo " > > Command : " $ARGS_PYTHON 
		echo ""

		python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_scene${scene}_log_deburst_zerolag_fw.txt

		@ scene += 1
	end

	cp -f ${LABEL_ante}_${strip}_${polar}.raw.rsc ${LABEL_ante}_${strip}_${polar}_fw.slc.rsc

	# backward looking geometry
        echo "OVERLAP                                  bw" >> $burst_comp_param_file_bw
        @ scene = 1
        while ($scene <= $num_files_ante )
                set directory=$DIR_IMG_ante[$scene]
                echo $strip $directory

                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                #echo " --skip_beg ${SKIP_BEG_ante} --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                        #echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsAnte " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                else if ($scene == $num_files_ante) then
                        #echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                        echo " --skip_end ${SKIP_END_ante} " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                else   
                        #echo " --skip_beg 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                        echo " --skip_end 0 " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                endif
                echo " --overlap_type Backward " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
		# if several input TIFF files are provided, append to end of output SLC file
		if ($num_files_ante != 1) then
			echo " --number_of_files $num_files_ante " >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
		endif
                if ($scene != 1) then
                                        echo " --file_order Append "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
					# get number of bursts already written to file
					set fileGlobalBurstIndex=`tail -1 ${LABEL_ante}_${strip}_${polar}_bw_Overlap.txt | awk '{print $1}'`
                                        if (fileGlobalBurstIndex != "") then
                                                echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                                        endif
		endif
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt
                set ARGS_PYTHON=`cat ${LABEL_ante}_${strip}_${polar}_scene${scene}_command_slc_zerolag_bw.txt`
		echo ""
                echo " > > Command : " $ARGS_PYTHON
		echo ""

                python $ARGS_PYTHON > ${LABEL_ante}_${strip}_${polar}_scene${scene}_log_deburst_zerolag_bw.txt

                @ scene += 1
        end

	cp -f ${LABEL_ante}_${strip}_${polar}.raw.rsc ${LABEL_ante}_${strip}_${polar}_bw.slc.rsc
	endif

	# # Slave image   # #
            
    # prepare parameter file for burst compensation / stitching step
    set burst_comp_param_file=${LABEL_post}_${strip}_${polar}_param.rsc
	
	# skip bursts
	echo "SKIP_BEG                            $SKIP_BEG_post" >> $burst_comp_param_file
	echo "SKIP_END                            $SKIP_END_post" >> $burst_comp_param_file

	# # run burst compensation / stitching step
	
	# split overlap area in the middle
	@ scene = 1
	while ($scene <= $num_files_post )
		set directory=$DIR_IMG_post[$scene]
		echo $strip $directory 
		
                echo " $dir/python/nsb_make_slc_s1.py --verbose --output-directory . --swath ${subswath} --polarization ${polar} " > ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                #echo " --skip_beg ${SKIP_BEG_post} --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                if ($scene == 1) then
                        echo " --skip_beg ${SKIP_BEG_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                        #echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                        echo " --total_number_of_bursts $totalNumberOfBurstsPost " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                else if ($scene == $num_files_post) then
                        #echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                        echo " --skip_end ${SKIP_END_post} " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                else   
                        echo " --skip_beg 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                        echo " --skip_end 0 " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                endif
		# if several input TIFF files are provided, append to end of output SLC file
		if ($num_files_post != 1) then
			echo " --number_of_files $num_files_post " >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
		endif
		if ($scene != 1) then
                        echo " --file_order Append "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
			# get number of bursts already written to file
			set fileGlobalBurstIndex=`tail -1 ${LABEL_post}_${strip}_${polar}_Overlap.txt | awk '{print $1}'`
			if (fileGlobalBurstIndex != "") then
                               echo " --file_global_burst_index $fileGlobalBurstIndex "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                        endif
		endif
                #echo " --incidence True "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                echo " $DIR_ARCHIVE/$directory "  >> ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt
                set ARGS_PYTHON=`cat ${LABEL_post}_${strip}_${polar}_scene${scene}_command_slc_zerolag.txt`
                echo ""
                echo " > > Command : " $ARGS_PYTHON
                echo ""

                python $ARGS_PYTHON > ${LABEL_post}_${strip}_${polar}_scene${scene}_log_deburst_zerolag.txt

	    @ scene += 1
	end
			
	# read file size information
	set YSIZE=`(grep YMAX ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`

    # save file size information in .rsc metadata file (for ROI_PAC)
    echo "FILE_LENGTH                     "$YSIZE > ${LABEL_post}_${strip}_${polar}.slc.rsc
    echo "YMIN                            "0 >> ${LABEL_post}_${strip}_${polar}.slc.rsc
    echo "YMAX                            "$YSIZE >> ${LABEL_post}_${strip}_${polar}.slc.rsc


        # read time information
        set FIRST_LINE_YEAR=`(grep FIRST_LINE_YEAR ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_MONTH_OF_YEAR=`(grep FIRST_LINE_MONTH_OF_YEAR ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_DAY_OF_MONTH=`(grep FIRST_LINE_DAY_OF_MONTH ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_HOUR_OF_DAY=`(grep FIRST_LINE_HOUR_OF_DAY ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_MN_OF_HOUR=`(grep FIRST_LINE_MN_OF_HOUR ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_S_OF_MN=`(grep FIRST_LINE_S_OF_MN ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_MS_OF_S=`(grep FIRST_LINE_MS_OF_S ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_STRING=`(grep FIRST_LINE_STRING ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_LINE_UTC=`(grep FIRST_LINE_UTC ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set FIRST_FRAME_SCENE_CENTER_TIME=`(grep FIRST_FRAME_SCENE_CENTER_TIME ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set CENTER_LINE_UTC=`(grep CENTER_LINE_UTC ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`
        set LAST_LINE_UTC=`(grep LAST_LINE_UTC ${LABEL_post}_${strip}_${polar}.slc.aux.xml | awk 'BEGIN {FS=">"} {print $2}' | awk 'BEGIN {FS="<"} {print $1}')`

        # update the rsc file
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_YEAR $FIRST_LINE_YEAR
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_MONTH_OF_YEAR $FIRST_LINE_MONTH_OF_YEAR
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_DAY_OF_MONTH $FIRST_LINE_DAY_OF_MONTH
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_HOUR_OF_DAY $FIRST_LINE_HOUR_OF_DAY
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_MN_OF_HOUR $FIRST_LINE_MN_OF_HOUR
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_S_OF_MN $FIRST_LINE_S_OF_MN
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_MS_OF_S $FIRST_LINE_MS_OF_S
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_STRING $FIRST_LINE_STRING
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_LINE_UTC $FIRST_LINE_UTC
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write FIRST_FRAME_SCENE_CENTER_TIME $FIRST_FRAME_SCENE_CENTER_TIME
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write CENTER_LINE_UTC $CENTER_LINE_UTC
        use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc write LAST_LINE_UTC $LAST_LINE_UTC

    # merge the rsc files
    use_rsc.pl ${LABEL_post}_${strip}_${polar}.slc.rsc merge ${LABEL_post}_${strip}_${polar}.raw.rsc



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
