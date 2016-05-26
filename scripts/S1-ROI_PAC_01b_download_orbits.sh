#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP)  -- April 2016
###   grandin@ipgp.fr
####################################################
### STEP 1b (optional)
### Download Sentinel-1 orbit files
####################################################

date

set myPath=/home/rgrandin/S1-ROI_PAC_V2.1

set platform=S1A

#set myOrbitType="RESORB"
set myOrbitType="POEORB"

set myStartUTC="20151011T223400"
set myStopUTC="20151011T224500"

set myVerbose=1
#set myVerbose=0

set myPath=$1
set platform=$2
set myOrbitType=$3
set myStartUTC=$4
set myStopUTC=$5
set orbDir=$6
set hdrDir=$7

# Output directory
if ( $orbDir == "" ) then
	set orbDir=`pwd`
endif

# Minimum time distance for orbit start/stop with respect to data start/stop
set minTimeDistanceSec=1000

# Reformat input start / stop times
set myStartDate=`echo $myStartUTC | awk '{print substr($1,1,8)}'`
set myStartYear=`echo $myStartDate | awk '{print substr($1,1,4)}'`
set myStartMonth=`echo $myStartDate | awk '{print substr($1,5,2)}'`
set myStartDay=`echo $myStartDate | awk '{print substr($1,7,2)}'`
set myStartTime=`echo $myStartUTC | awk '{print substr($1,10,6)}'`
set myStartHour=`echo $myStartTime | awk '{print substr($1,1,2)}'`
set myStartMin=`echo $myStartTime | awk '{print substr($1,3,2)}'`
set myStartSec=`echo $myStartTime | awk '{print substr($1,5,2)}'`
set myStartSecSince1970=`date -d "$myStartDate ${myStartHour}:${myStartMin}:${myStartSec}" +%s`

set myStopDate=`echo $myStopUTC | awk '{print substr($1,1,8)}'`
set myStopYear=`echo $myStopDate | awk '{print substr($1,1,4)}'`
set myStopMonth=`echo $myStopDate | awk '{print substr($1,5,2)}'`
set myStopDay=`echo $myStopDate | awk '{print substr($1,7,2)}'`
set myStopTime=`echo $myStopUTC | awk '{print substr($1,10,6)}'`
set myStopHour=`echo $myStopTime | awk '{print substr($1,1,2)}'`
set myStopMin=`echo $myStopTime | awk '{print substr($1,3,2)}'`
set myStopSec=`echo $myStopTime | awk '{print substr($1,5,2)}'`
set myStopSecSince1970=`date -d "$myStopDate ${myStopHour}:${myStopMin}:${myStopSec}" +%s`

if ($myVerbose) echo "Looking for orbit file for interval:"
if ($myVerbose) echo " ${myStartYear}-${myStartMonth}-${myStartDay} ${myStartHour}:${myStartMin}:${myStartSec} --> ${myStopYear}-${myStopMonth}-${myStopDay} ${myStopHour}:${myStopMin}:${myStopSec}  (platform : $platform)"


# Put donwloaded orbit files to this location
set orbDownloadDirTop="ORB/"$platform

if ( $myOrbitType == "RESORB") then
	# Restituted orbits (available in near-real time)
	set myURL="https://qc.sentinel1.eo.esa.int/aux_resorb/"
	set orbDownloadDir="$orbDir/$orbDownloadDirTop/RESORB"
	set shiftInHours=4
	set searchInHours=1
	set initRangeSearchInHours=2
else if ( $myOrbitType == "POEORB") then
	# Precise orbits (available after ~20 days)
	set myURL="https://qc.sentinel1.eo.esa.int/aux_poeorb/"
	set orbDownloadDir="$orbDir/$orbDownloadDirTop/POEORB"
	set shiftInHours=48
	set searchInHours=24
	set initRangeSearchInHours=24
else
	echo "Orbit type not recognized!"
	exit
endif

if ( $hdrDir == "" ) then
        set hdrDir=$orbDownloadDir
endif
if ( $myVerbose ) echo "Downloading orbit files from URL : $myURL"
if ( $myVerbose ) echo "Download orbit files to : $orbDownloadDir"
if ( $myVerbose ) echo "Writing hdr files to : $hdrDir"

# Options passed to wget
if ($myVerbose) then
	set myWgetOptions="-r -l1 -np -nd --no-check-certificate -N -P$orbDownloadDir "
else
	set myWgetOptions="-r -l1 -np -nd --no-check-certificate -N -q -P$orbDownloadDir "
endif
set myWgetOptions="-r -l1 -np -nd --no-check-certificate -N -q -P$orbDownloadDir "

# Cleanup
rm -f $orbDownloadDir/file_list.txt

# Download orbit files that bracket the acquisition time
set itershiftInHours=`echo $shiftInHours | awk '{print $1*(-1)}'`
set itershiftInHours=0
set fileFound="0"
while ($itershiftInHours <= $shiftInHours )
	set rangeInHours=$initRangeSearchInHours
	set currentUTC=`date -d "$myStartDate $myStartHour -$itershiftInHours hours" +%Y%m%d" "%H`
	set currentStr=`date -d "$myStartDate $myStartHour -$itershiftInHours hours" +%Y-%m-%d`
	# update URL to narrow search parameters
	set currentDate=`echo $currentUTC | awk '{print $1}'`
	set currentHour=`echo $currentUTC | awk '{print $2}'`
	echo $currentUTC
	if ($myVerbose) echo "Searching for orbit file for date $currentDate"
	while ($rangeInHours <= $shiftInHours )
        	set currentAfterUTC=`date -d "$currentDate +$currentHour hours +$rangeInHours hours" +%Y%m%d" "%H`
		set currentAfterDate=`echo $currentAfterUTC | awk '{print $1}'`
		set currentAfterHour=`echo $currentAfterUTC | awk '{print $2}'`
		echo "   "$currentAfterUTC
		if ( $myOrbitType == "RESORB") then
                        # RESORB : orbits are provided hour by hour
			if ($myVerbose) echo "Trying download of $orbDownloadDir/${platform}*V${currentDate}T${currentHour}????_${currentAfterDate}T${currentAfterHour}????.EOF from $myURL"
			# Download command
			alias myWgetCommand 'set noglob; wget $myWgetOptions -A '${platform}\*V${currentDate}T${currentHour}\?\?\?\?_${currentAfterDate}T${currentAfterHour}\?\?\?\?.EOF' $myURL\?\&validity_start_time=${currentStr} ;unset noglob'
		else if ( $myOrbitType == "POEORB") then
                        # POEORB : orbits are provided day by day
                        if ($myVerbose) echo "Trying download of $orbDownloadDir/${platform}*V${currentDate}T??????_${currentAfterDate}T??????.EOF from $myURL"
			# Download command
			alias myWgetCommand 'set noglob; wget $myWgetOptions -A '${platform}\*V${currentDate}T\?\?\?\?\?\?_${currentAfterDate}T\?\?\?\?\?\?.EOF' $myURL\?\&validity_start_time=${currentStr} ;unset noglob'
		endif

		# Try download
		myWgetCommand
	
		# If file has been successfully downloaded, write it to ASCII file	
		echo "$orbDownloadDir/${platform}*V${currentDate}T??????_${currentAfterDate}T??????.EOF"
		if ( $myOrbitType == "RESORB") then
			(ls $orbDownloadDir/${platform}*V${currentDate}T${currentHour}????_${currentAfterDate}T${currentAfterHour}????.EOF >> $orbDownloadDir/file_list.txt) >& /dev/null
                else if ( $myOrbitType == "POEORB") then
			(ls $orbDownloadDir/${platform}*V${currentDate}T??????_${currentAfterDate}T??????.EOF >> $orbDownloadDir/file_list.txt) >& /dev/null
		endif
		@ rangeInHours += $searchInHours
	end	
        @ itershiftInHours += $searchInHours 
end

# Cleanup
rm -f $orbDownloadDir/robot*.txt*

set numberOfOrbitFiles=`wc $orbDownloadDir/file_list.txt | awk '{print $1}'`
if ($numberOfOrbitFiles == 0) then
        echo "Error : orbit file not found!"
        exit
endif

if ($myVerbose) echo "Found $numberOfOrbitFiles file(s):"
if ($myVerbose) cat $orbDownloadDir/file_list.txt
set foundFile=0
set iterFile=1
while ( $iterFile <= $numberOfOrbitFiles && ! $foundFile )
	set file=`awk 'NR=='$iterFile' {print $0}' $orbDownloadDir/file_list.txt`
	set fileBase=$file:t
	set orbitStartUTC=`echo $fileBase | awk '{print substr($1,43,15)}'`
	set orbitStopUTC=`echo $fileBase | awk '{print substr($1,59,15)}'`

	set orbitStartDate=`echo $orbitStartUTC | awk '{print substr($1,1,8)}'`
	set orbitStartYear=`echo $orbitStartDate | awk '{print substr($1,1,4)}'`
	set orbitStartMonth=`echo $orbitStartDate | awk '{print substr($1,5,2)}'`
	set orbitStartDay=`echo $orbitStartDate | awk '{print substr($1,7,2)}'`
	set orbitStartTime=`echo $orbitStartUTC | awk '{print substr($1,10,6)}'`
	set orbitStartHour=`echo $orbitStartTime | awk '{print substr($1,1,2)}'`
	set orbitStartMin=`echo $orbitStartTime | awk '{print substr($1,3,2)}'`
	set orbitStartSec=`echo $orbitStartTime | awk '{print substr($1,5,2)}'`
        set orbitStartSecSince1970=`date -d "$orbitStartDate ${orbitStartHour}:${orbitStartMin}:${orbitStartSec}" +%s`

        set orbitStopDate=`echo $orbitStopUTC | awk '{print substr($1,1,8)}'`
        set orbitStopYear=`echo $orbitStopDate | awk '{print substr($1,1,4)}'`
        set orbitStopMonth=`echo $orbitStopDate | awk '{print substr($1,5,2)}'`
        set orbitStopDay=`echo $orbitStopDate | awk '{print substr($1,7,2)}'`
        set orbitStopTime=`echo $orbitStopUTC | awk '{print substr($1,10,6)}'`
        set orbitStopHour=`echo $orbitStopTime | awk '{print substr($1,1,2)}'`
        set orbitStopMin=`echo $orbitStopTime | awk '{print substr($1,3,2)}'`
        set orbitStopSec=`echo $orbitStopTime | awk '{print substr($1,5,2)}'`
        set orbitStopSecSince1970=`date -d "$orbitStopDate ${orbitStopHour}:${orbitStopMin}:${orbitStopSec}" +%s`

	set diffStart=`echo $myStartSecSince1970 $orbitStartSecSince1970 | awk '{printf("%d\n",($1)-($2))}'`
        set diffStop=`echo $myStopSecSince1970 $orbitStopSecSince1970 | awk '{printf("%d\n",($2)-($1))}'`

	set testStart=`echo $diffStart | awk '{if($1>'$minTimeDistanceSec') print 1; else print 0;}'`
        set testStop=`echo $diffStop | awk '{if($1>'$minTimeDistanceSec') print 1; else print 0;}'`
	if ( $testStart && $testStop ) then
		echo "Best orbit file : $fileBase"
		if ($myVerbose) echo " $orbitStartDate ${orbitStartHour}:${orbitStartMin}:${orbitStartSec} < [ $myStartDate ${myStartHour}:${myStartMin}:${myStartSec} -- $myStopDate ${myStopHour}:${myStopMin}:${myStopSec} ] < $orbitStopDate ${orbitStopHour}:${orbitStopMin}:${orbitStopSec} "
                if ($myVerbose) echo " diff. in sec. :  $diffStart                                         $diffStop"
		set foundFile = 1
		set bestFile=$fileBase
	endif

	@ iterFile ++
end

# No file fits
if (! $foundFile) then
	echo "Error : no orbit file fits time constraints!"
	exit
else
	python $myPath/python/decode_POEORB_S1.py --tmin ${myStartYear}-${myStartMonth}-${myStartDay}T${myStartHour}:${myStartMin}:${myStartSec} --tmax ${myStopYear}-${myStopMonth}-${myStopDay}T${myStopHour}:${myStopMin}:${myStopSec} --outdir $hdrDir --verbose $orbDownloadDir/$fileBase
endif


exit
alias foo 'set noglob; wget -r -l1 -np -nd --no-check-certificate -P$orbDownloadDir -A '\*$myDate\*.EOF' https://qc.sentinel1.eo.esa.int/aux_poeorb/ ;unset noglob'
foo

exit

set myArguments="-r -l1 -np --no-check-certificate $myURL -A V20151011"
echo $myArguments
exit
`wget $myArguments`
exit


wget -r -l1 -np --no-check-certificate -A '*V20151011*.EOF' https://qc.sentinel1.eo.esa.int/aux_poeorb/
# wget -r -l1 -np --no-check-certificate -A '*V20151011*.EOF' "${URL_RESORB}"
# wget -r -l1 -np --no-check-certificate -A '*V${myDate}*.EOF' ${URL_RESORB}


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

