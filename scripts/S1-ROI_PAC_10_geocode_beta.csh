#!/bin/csh

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V1.1 -- Feb. 2015
###   grandin@ipgp.fr
####################################################
### STEP 10 (unstable)
### Mosaick the three sub-swaths in range
### To do so, estimate an integer number of 2*Pi phase jumps across sub-swath overlaps
####################################################


# # # # # # # # # # # # # # # # # # #
# # Interpret the parameter file  # #

### Read parameter file
if ($#argv <= 1) then
    echo "Usage: $0 topsar_input_file.in hh"
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

#set strip_list=""
#set strip_list=$argv[2]
#echo "Strip list : " $strip_list
@ num_strips = 1

set polar_list=$argv[2]
echo "Polar list : " $polar_list
@ count_strip = 1
while ( $count_strip <= $num_strips )
#    set strip=$strip_list[$count_strip]
    set polar=$polar_list[$count_strip]

	set pairdates=${LABEL_ante}"-"${LABEL_post}
	echo "Pair: "$pairdates
	
	# Set this factor to -1 to reverse sign of interferogram
	# if "ante" date is after "post" date
	# Otherwise, leave the factor equal to 1.
	if ( $LABEL_ante > $LABEL_post ) then
		set FACTOR_LOS="-1"
		set FACTOR_LOS="-0.4456338406573"
	else
		set FACTOR_LOS="1"
                set FACTOR_LOS="0.4456338406573"
	endif	
	echo "Factor: "$FACTOR_LOS
	
	gmtset BASEMAP_TYPE PLAIN
	gmtset PLOT_DEGREE_FORMAT D
	
	# # Use either unwrapped (unw) or wrapped (int) interferogram
	#set GEO_FORMAT="int"
	set GEO_FORMAT="unw"
	
	# YOU NEED TO PROVIDE A DEM HERE (GMT format)
	#set MYDEM=/media/Quadra_2/Pamir2015/DEM/Pamir_SRTM_lowres.grd
        set MYDEM=/media/Quadra_4/Taiwan/dem/Tout_Taiwan_AB_resample15_4rlks_large.dem.grd

	
	# set grid dimensions
	set GRIDMOS=`grep "Latitude and longitude" INTERFERO/${pairdates}_iw*//SIM/IntSim.out | minmax | awk '{print $(NF)"/"$(NF-1)}' | awk '{gsub("<",""); gsub(">",""); print $0}'`
	echo $GRIDMOS
	#set GRIDMOS="-72.5/-68.5/-34/-28.5"
	#echo $GRIDMOS
	
	# prepare a few directories
	set WORKINGDIR=`pwd`
	if( ! -e GEO ) then
		mkdir GEO
	endif
	cd GEO
	if( ! -e PALDIR ) then
		mkdir PALDIR
	endif
	set PALDIR=$WORKINGDIR/GEO/PALDIR
	if( ! -e MOSAIC ) then
	        mkdir MOSAIC
	endif
	set MOSDIR=$WORKINGDIR/GEO/MOSAIC
	
	# GMT parameters for the figures
	set PROJMOS=M10
	set STEPMOS=0.004
	set filein="mosaic_"$pairdates
	
	# Prepare a few color palettes
	makecpt -T-0.5/0.5/0.1 -Cjet > ${PALDIR}/paloffset_azi.cpt
	makecpt -T-4/4/0.1 -Cjet > ${PALDIR}/paloffset_ran.cpt
	makecpt -T0/1/0.01 -I -Cseis > ${PALDIR}/palsnr.cpt
	makecpt -T-3.14/3.14/0.01 -Ccmy > ${PALDIR}/palpi.cpt
	makecpt -T-50/10/0.1 -Ccmy > ${PALDIR}/palcmy_unw.cpt
        makecpt -T-1/1/0.01 -Ccmy > ${PALDIR}/palcmy_cor.cpt
	makecpt -T-1/1/0.01 -Cgray > ${PALDIR}/palnb_1.cpt
	
	# Prepare file names
	
	if ( $GEO_FORMAT == "int" ) then
	### INT ###
	    set MY_PALETTE=${PALDIR}/palpi.cpt
            set filein="geo_"${pairdates}
            set fileout="geo_"${pairdates}
            set grdout="geo_"${pairdates}
            set imoutmos=${filein}"_int"
            set imout=${grdout}_int

	    #set filein="geo_"${pairdates}_xint
            #set fileout="geo_"${pairdates}_xint
	    #set grdout="geo_"${pairdates}_xint
	    #set imoutmos=${filein}"_xint"
	    #set imout=${grdout}_xint
	else if ( $GEO_FORMAT == "unw" ) then
	###?| UNW ###
	    set MY_PALETTE=${PALDIR}/palcmy_unw.cpt 
	    set filein="geo_"${pairdates}
	    set fileout="geo_"$pairdates
	    set grdout="geo_"$pairdates
	    set imoutmos=${filein}"_unw"
	    set imout=${grdout}_unw

	    #set MY_PALETTE=${PALDIR}/palcmy_cor.cpt
	    #set filein="geo_"${pairdates}_cor
            #set fileout="geo_"${pairdates}_cor
            #set grdout="geo_"${pairdates}_cor
            #set imoutmos=${filein}"_cor"
            #set imout=${grdout}_cor

	endif
	
	# Resample the DEM and compute shaded DEM accordingly
	if ( ! -e $MOSDIR/${imoutmos}.dem.grad.grd ) then
	    grdsample -R$GRIDMOS -I$STEPMOS= $MYDEM -G$MOSDIR/${imoutmos}.dem.grd -V -F
	    grdgradient $MOSDIR/${imoutmos}.dem.grd -A200 -Ne0.3 -G$MOSDIR/${imoutmos}.dem.grad.grd
	endif
	
	cd $MOSDIR
	gmtset BASEMAP_TYPE PLAIN
	gmtset PLOT_DEGREE_FORMAT D
	gmtset ANNOT_FONT_SIZE_PRIMARY 10p
	gmtset LABEL_FONT_SIZE 14p
	
	# Prepare background for the figures
	psbasemap -R$GRIDMOS -J$PROJMOS -B0.5 -Xc -Yc -K > ${imoutmos}.ps
	pscoast -Ir/0.25p,blue -Na/0.25p,- -R -J -Df -W4 -K -O >> ${imoutmos}.ps
	grdimage ${imoutmos}.dem.grad.grd -R -J -Sn -C${PALDIR}/palnb_1.cpt -O -K >> ${imoutmos}.ps
	
		    #set MY_PALETTE=${PALDIR}/palcmy_unw.cpt
#goto mos
#exit	
	@ count_file = 1
	foreach imdir ( INTERFERO/${pairdates}_iw1_${polar} INTERFERO/${pairdates}_iw2_${polar} )

	
	    set INTERFDIR=$WORKINGDIR/${imdir}/INT
	    set GEODIR=$WORKINGDIR/GEO/$imdir
	
	    if ( ! -e $GEODIR ) then
	            mkdir -p $GEODIR
	    endif
	
	    echo ""
	    echo " ######### "
	    echo " # " $GEODIR " # "
	    cd $GEODIR
	
	    gmtset BASEMAP_TYPE PLAIN
	    gmtset PLOT_DEGREE_FORMAT D
	    gmtset D_FORMAT=%.12g
	    set PROJ=M10
	
	    if ( $GEO_FORMAT == "int" ) then
	### INT ###
		    #set MY_PALETTE=${PALDIR}/palpi.cpt
		    #set imoutmos=${filein}"_xint"
		    #set imout=${grdout}_int
		    ln -sf $INTERFDIR/${filein}.int .
		    cp -f $INTERFDIR/${filein}.int.rsc .
		    set rscfile=${filein}.int.rsc
		    set WAVELENGTH=`(grep WAVELENGTH $rscfile | awk '{print $NF}')`
	
		    set XSIZE_FULLRES=`(grep WIDTH $rscfile | awk '{print $NF}')`
		    set YSIZE_FULLRES=`(grep FILE_LENGTH $rscfile | awk '{print $NF}')`
		    set GRID_FULLRES=1/$XSIZE_FULLRES/1/$YSIZE_FULLRES
		    echo GRID_FULLRES $GRID_FULLRES

			# amplitude has to be between -1 and 1
			# a logarithm does the job
		    if ( ! -e ${imout}_normamp.grd ) then
				set XYZ2GRDINFO=`(int2grd_geo ${filein}.int 1 0)`
				xyz2grd ${filein}.int.band1 $XYZ2GRDINFO -G${imout}_amp.grd -V
				rm -fr ${filein}.int.band1
				grdmath ${imout}_amp.grd LOG10 2.5 SUB = ${imout}_normamp.grd
				rm -fr ${imout}_amp.grd
		    endif
	
		    if ( ! -e ${imout}.grd ) then
				set XYZ2GRDINFO=`(int2grd_geo ${filein}.int 0 1)`
				xyz2grd ${filein}.int.band2 $XYZ2GRDINFO -G${imout}.grd -V
				rm -fr ${filein}.int.band2
		    endif
	
	            set GRIDINFO=`(grdinfo -I- ${imout}.grd)`
	            set STEPINFO=`(grdinfo -C ${imout}.grd | awk '{print "-I"$8"=/"$9"="}')`
	
		    echo "GRIDINFO : "$GRIDINFO "  / STEPINFO : "$STEPINFO
	
		    if ( ! -e ${filein}.dem.grad.grd ) then
				grdsample $GRIDINFO $STEPINFO $MYDEM -G${filein}.dem.grd -V
				grdgradient ${filein}.dem.grd -A200 -Ne0.3 -G${filein}.dem.grad.grd
		    endif
	
		    gmtset BASEMAP_TYPE PLAIN
		    gmtset PLOT_DEGREE_FORMAT D
		    set PROJ=M12
	    
		    psbasemap $GRIDINFO -J$PROJ -B0.5 -Xc -Yc -P -K > ${imout}.ps 
		    #pscoast -Ir/0.25p,blue -Na/0.25p,- -R -J -Df -W4 -K -O >> ${imout}.ps
		    grdimage ${filein}.dem.grad.grd -R -J -Sn -C${PALDIR}/palnb_1.cpt -O -K >> ${imout}.ps	
#		    grdimage ${imout}.grd -I${imout}_normamp.grd -R -J -Sn -Q -C$MY_PALETTE -O -K >> ${imout}.ps
                    grdimage ${imout}.grd  -R -J -Sn -Q -C$MY_PALETTE -O -K >> ${imout}.ps
		    pscoast -Ir/0.25p,blue -Na/0.25p,- -S230 -R -J -Df -W4 -K -O >> ${imout}.ps
		    psscale -D0c/-12c/5c/0.5ch -C$MY_PALETTE -B3.14:LOS:/:rad: -O >> ${imout}.ps
		    mogrify -format png -density 200 -rotate 90 ${imout}.ps
		#eog ${imout}.png
	
		    grdimage ${imout}.grd -R$GRIDMOS -J$PROJMOS -Sn -Q -C$MY_PALETTE -O -K >> $MOSDIR/${imoutmos}.ps
	
	    else if ( $GEO_FORMAT == "unw" ) then
	### UNW ###
		    #set MY_PALETTE=${PALDIR}/palcmy_unw.cpt
		    #set imoutmos=${filein}"_unw"
		    #set imout=${grdout}_unw
		    ln -sf $INTERFDIR/$filein.unw .
		    cp -f $INTERFDIR/$filein.unw.rsc .
		    set rscfile=${filein}.unw.rsc
		    set WAVELENGTH=`(grep WAVELENGTH $rscfile | awk '{print $NF}')`
	
		    set XSIZE_FULLRES=`(grep WIDTH $rscfile | awk '{print $NF}')`
		    set YSIZE_FULLRES=`(grep FILE_LENGTH $rscfile | awk '{print $NF}')`
		    set GRID_FULLRES=1/$XSIZE_FULLRES/1/$YSIZE_FULLRES
		    echo GRID_FULLRES $GRID_FULLRES
	
			# amplitude has to be between -1 and 1
			# a logarithm does the job
		    if ( ! -e ${imout}_normamp.grd ) then
				set XYZ2GRDINFO=`(unw2grd_geo ${filein}.unw 1 0)`
				xyz2grd ${filein}.unw.band1 $XYZ2GRDINFO -G${imout}_amp.grd -V
				rm -fr ${filein}.unw.band1
				grdmath ${imout}_amp.grd LOG10 3.2 SUB = ${imout}_normamp.grd
				rm -fr ${imout}_amp.grd		
		    endif
	
		    if ( ! -e ${imout}.grd ) then
				set XYZ2GRDINFO=`(unw2grd_geo ${filein}.unw 0 1)`
				xyz2grd ${filein}.unw.band2 $XYZ2GRDINFO -G${imout}.grd -V
				rm -fr ${filein}.unw.band2
		    endif
	    
	            set GRIDINFO=`(grdinfo -I- ${imout}.grd)`
	            set STEPINFO=`(grdinfo -C ${imout}.grd | awk '{print "-I"$8"=/"$9"="}')`
	
		    echo "GRIDINFO : "$GRIDINFO "  / STEPINFO : "$STEPINFO
	
		    if ( $imdir == 000 ) then
				grdmath ${imout}.grd PI 4 MUL SUB = ${imout}_shift.grd
		    else
				ln -sf ${imout}.grd ${imout}_shift.grd
		    endif
	    
		    if ( ! -e ${filein}.dem.grad.grd ) then
				grdsample $GRIDINFO $STEPINFO $MYDEM -G${filein}.dem.grd -V
				grdgradient ${filein}.dem.grd -A200 -Ne0.3 -G${filein}.dem.grad.grd
		    endif
	
		    # extend boundaries
		    echo ${imout}_shift.grd $GRIDINFO 1 > blend.txt
		    #echo "" >> blend.txt
		    if ( $count_file == 1 ) then
				set shift_integer=0
				grdblend blend.txt -G$MOSDIR/${imoutmos}.grd -R$GRIDMOS $STEPINFO
		    else
	                grdblend blend.txt -G$MOSDIR/tmp.grd -R$GRIDMOS $STEPINFO
	                grdmath $MOSDIR/tmp.grd $MOSDIR/${imoutmos}.grd SUB 2 PI MUL DIV MODE = shift.grd
	                grdsample shift.grd -I0.1 -Q -Gshift_low.grd
	                set shift_integer=`(grd2xyz shift_low.grd | blockmedian -R -I100 | awk '{printf("%.0f\n", $3)}')`
	
			if ( ($shift_integer == "NaN") || ($shift_integer == "") ) then
				set shift_integer=0
			endif
		    
			grdmath $MOSDIR/tmp.grd PI 2 MUL $shift_integer MUL SUB = $MOSDIR/tmp2.grd
			grdmath $MOSDIR/${imoutmos}.grd $MOSDIR/tmp2.grd AND = $MOSDIR/tmp3.grd
		        mv -f $MOSDIR/tmp3.grd $MOSDIR/${imoutmos}.grd
			rm -f tmp.grd tmp3.grd shift.grd shift_low.grd
		    endif
		    echo shift_integer $shift_integer
		    echo shift_integer $shift_integer > shift_integer.txt
		    set shift_phase=`(echo $shift_integer | awk '{print $1*2*(atan2(1,0)*2)}')`
		    echo shift_phase $shift_phase
	
		    awk '{if(substr($1,1,1)!="#" && NF==8) printf("%.1f\t%d\t%d\t%d\t%.1f\t%d\t%d\t%d\n",$1+('$shift_phase'),$2,$3,$4,$5+('$shift_phase'),$6,$7,$8); else print $0}' $MY_PALETTE > my_palette.cpt
	
		    psbasemap $GRIDINFO -J$PROJ -B0.5 -Xc -Yc -P -K > ${imout}.ps
		    #pscoast -Ir/0.25p,blue -Na/0.25p,- -R -J -Df -W4 -K -O >> ${imout}.ps
		    grdimage ${filein}.dem.grad.grd -R -J -Sn -C${PALDIR}/palnb_1.cpt -O -K >> ${imout}.ps
		    #grdimage ${imout}_shift.grd -I${imout}_normamp.grd -R -J -Sn -Q -Cmy_palette.cpt -O -K >> ${imout}.ps
		    grdimage ${imout}_shift.grd -I${imout}_normamp.grd -R -J -Sn -Q -C$MY_PALETTE -O -K >> ${imout}.ps
		    #grdcontour ${imout}_shift.grd -C6.28 -Q100 -R -J -O -K -V >> ${imout}.ps
                    pscoast -Ir/0.25p,blue -Na/0.25p,- -S230 -R -J -Df -W4 -K -O >> ${imout}.ps
		    psscale -D0c/-12c/5c/0.5ch -I -Cmy_palette.cpt -B50:LOS:/:cm: -O >> ${imout}.ps
                    #psscale -D0c/-12c/5c/0.5ch -I -C$MY_PALETTE -B0.5:COR:/:: -O >> ${imout}.ps
		    mogrify -format png -density 200 -rotate 90 ${imout}.ps
eog ${imout}.png
	
	    endif
	
		@ count_file ++
	end	
	
mos:	
	echo ""
	echo " ############ "
	echo " #  MOSAIC  # "
	cd $MOSDIR
	if ( $GEO_FORMAT == "unw" ) then
		grdsample -I$STEPMOS= ${imoutmos}.grd -Gtmp.grd -V -F
		grdmath tmp.grd $FACTOR_LOS MUL = ${imoutmos}.grd
	#	mv -f tmp.grd ${imoutmos}.grd
		grdimage ${imoutmos}.grd -R$GRIDMOS -J$PROJMOS -I${imoutmos}.dem.grad.grd -Sn -Q -C$MY_PALETTE -O -K >> $MOSDIR/${imoutmos}.ps
		grdcontour ${imoutmos}.grd -C10 -R -J -O -K >> $MOSDIR/${imoutmos}.ps
		psscale -D8c/3c/3c/0.5c -I -C$MY_PALETTE -B10:LOS:/:cm: -O >> ${imoutmos}.ps
	endif
	
	mogrify -format png -density 300 -rotate 90 ${imoutmos}.ps
	
	if ( $GEO_FORMAT == "unw" ) then
		grd2xyz -Zf ${imoutmos}.grd > ${imoutmos}.r4
		set SIZEINFO=`(grdinfo -C ${imoutmos}.grd)`
		set today=`(date +%d\ %b\ %Y)`
		echo "ENVI" > ${imoutmos}.r4.hdr
		echo "description = {" >> ${imoutmos}.r4.hdr
		echo "samples = "$SIZEINFO[10] >> ${imoutmos}.r4.hdr
		echo "lines   = "$SIZEINFO[11] >> ${imoutmos}.r4.hdr
		echo "bands   = 1" >> ${imoutmos}.r4.hdr
		echo "header offset = 0" >> ${imoutmos}.r4.hdr
		echo "file type = ENVI Standard" >> ${imoutmos}.r4.hdr
		echo "data type = 4" >> ${imoutmos}.r4.hdr
		echo "interleave = bsq" >> ${imoutmos}.r4.hdr
		echo "sensor type = TSX" >> ${imoutmos}.r4.hdr
		echo "byte order = 0" >> ${imoutmos}.r4.hdr
		echo "map info = {Geographic Lat/Lon, 1.0000, 1.0000, "$SIZEINFO[2]", "$SIZEINFO[5]", "$SIZEINFO[8]", "$SIZEINFO[9]", WGS-84, units=Degrees}" >> ${imoutmos}.r4.hdr
		echo "coordinate system string = {GEOGCS["\""GCS_WGS_1984"\"",DATUM["\""D_WGS_1984"\"",SPHEROID["\""WGS_1984"\"",63781.00,298.252223563]],PRIMEM["\""Greenwich"\"",0.0],UNIT["\""Degree"\"",0.0174532925199433]]}" >> ${imoutmos}.r4.hdr
		echo "wavelength units = Unknown" >> ${imoutmos}.r4.hdr
		echo "band names = {"${imoutmos}"}" >> ${imoutmos}.r4.hdr
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
