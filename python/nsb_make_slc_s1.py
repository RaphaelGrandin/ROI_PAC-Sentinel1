print #!/usr/bin/env python
# -*- coding: utf-8 -*-
############################################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
###   Author        : Matthieu Volat (ISTerre)
###                   Raphael Grandin (IPGP)
####################################################
### Parser for Sentinel-1 metadata
# 
# NSBAS - New Small Baseline Chain
# 
############################################################################
#
# The method implemented hereby follows the one developed by R. Grandin[1].
#
# [1] Grandin, R. (2015, March). INTERFEROMETRIC PROCESSING OF SLC 
#     SENTINEL-1 TOPS DATA. In Proceedings of the European Space Agency
#     Symposium “Fringe”. Frascati, Italy.
#
############################################################################

import datetime, getopt, glob, os, sys, xml.etree.ElementTree

import numpy as np

import imp

C = 299792458.0
ae = 6378137
flat = 1.0 / 298.257223563
eccentricity2 = flat * (2-flat)

def module_exists(module_name):
    try:
        __import__(module_name)
    except ImportError:
        return False
    else:
        return True

def open_annotationxml(safepath, swath, polarization):
    globpat = os.path.join(safepath,
                           "annotation",
                           "*-iw%d-slc-%s-*.xml" % (swath, polarization))
    g = glob.glob(os.path.join(globpat))
    if g == None:
        return None
    if len(g) != 1:
        return None
    doc = xml.etree.ElementTree.ElementTree()
    doc.parse(g[0])
    return doc
    
def get_ipfversion(safepath):
    globpat = os.path.join(safepath,"manifest.safe")
    manifestfile = glob.glob(os.path.join(globpat))
    if len(manifestfile) == 0:
       return None
    # Read IPF version in manifest (simple grep)
    for line in open(manifestfile[0]):
        if "software name=\"Sentinel-1 IPF\" version=" in line:
            ipfversion = float(line.split("\"")[-2])
            break
    return ipfversion

def open_measurementds(safepath, swath, polarization):
    globpat = os.path.join(safepath,
                           "measurement",
                           "*-iw%d-slc-%s-*.tiff" % (swath, polarization))
    g = glob.glob(os.path.join(globpat))
    if g == None:
        return None
    if len(g) != 1:
        return None
    return gdal.Open(g[0], gdal.GA_ReadOnly)

def read_hdr_data_points(doc):
    nbextrapts = 200
    # read the state vectors in metadata
    orbitList = doc.findall("generalAnnotation/orbitList/orbit")
    vectors = np.ndarray((len(orbitList), 7))
    for i in range(len(orbitList)):
        orbit = orbitList[i]
        t = datetime.datetime.strptime(orbit.find("time").text,
                                       "%Y-%m-%dT%H:%M:%S.%f")
        vectors[i, :] = [float(t.hour*3600+t.minute*60+t.second+t.microsecond/1000000.0),
                         float(orbit.find("position/x").text),
                         float(orbit.find("position/y").text),
                         float(orbit.find("position/z").text),
                         float(orbit.find("velocity/x").text),
                         float(orbit.find("velocity/y").text),
                         float(orbit.find("velocity/z").text)]

    # extend the state vectors using third degree polynomial extrapolation
    polys = []
    for i in range(1, 7):
        polys.append(np.poly1d(np.polyfit(vectors[:, 0], vectors[:, i], 3)))
    # sample extrapolated orbit at appropriate rate
    #   dates before first line
    timesBef = np.linspace(vectors[0, 0]-nbextrapts,
                           vectors[0, 0],
                           num=nbextrapts,
                           endpoint=False)
    #   dates after last line
    timesAft = np.linspace(vectors[-1, 0]+1,
                           vectors[-1, 0]+nbextrapts,
                           num=nbextrapts)
    # compute the interpolated values
    #   dates before first line
    vectors_b = np.ndarray((len(timesBef), 7))
    vectors_b[:, 0] = timesBef
    for i in range(6):
        vectors_b[:, i+1] = np.polyval(polys[i], timesBef)
    #   dates after last line
    vectors_a = np.ndarray((len(timesAft), 7))
    vectors_a[:, 0] = timesAft
    for i in range(6):
        vectors_a[:, i+1] = np.polyval(polys[i], timesAft)

    return np.concatenate((vectors_b, vectors, vectors_a))

def read_doppler_centroid_data(doc):
    dcEstimateList = doc.findall("dopplerCentroid/dcEstimateList/dcEstimate")
    dcd = np.ndarray((len(dcEstimateList), 7))
    for i in range(len(dcEstimateList)):
        dce = dcEstimateList[i]
        t = datetime.datetime.strptime(dce.find("azimuthTime").text,
                                       "%Y-%m-%dT%H:%M:%S.%f")
        polynomial = dce.find("dataDcPolynomial").text.split()
        dcd[i, :] = [float(t.hour*3600+t.minute*60+t.second+t.microsecond/1000000.0),
                     float(dce.find('t0').text),
                     float(polynomial[0]),
                     float(polynomial[1]),
                     float(polynomial[2]),
                     0,
                     0]
    return dcd
def read_doppler_centroid_geometry(doc):
    dcEstimateList = doc.findall("dopplerCentroid/dcEstimateList/dcEstimate")
    dcg = np.ndarray((len(dcEstimateList), 7))
    for i in range(len(dcEstimateList)):
        dce = dcEstimateList[i]
        t = datetime.datetime.strptime(dce.find("azimuthTime").text,
                                       "%Y-%m-%dT%H:%M:%S.%f")
        polynomial = dce.find("geometryDcPolynomial").text.split()
        dcg[i, :] = [float(t.hour*3600+t.minute*60+t.second+t.microsecond/1000000.0),
                     float(dce.find('t0').text),
                     float(polynomial[0]),
                     float(polynomial[1]),
                     float(polynomial[2]),
                     0,
                     0]
    return dcg

def read_azimuth_fm_rate(doc,ipfVersion):
    azimuthFmRateList = doc.findall("generalAnnotation/azimuthFmRateList/azimuthFmRate")
    rates = np.ndarray((len(azimuthFmRateList), 5))
    for i in range(len(azimuthFmRateList)):
        azfmr = azimuthFmRateList[i]
        t = datetime.datetime.strptime(azfmr.find("azimuthTime").text,
                                       "%Y-%m-%dT%H:%M:%S.%f")
        c0, c1, c2 = 0., 0., 0.
        if(ipfVersion < 2.43):
            c0 = float(azfmr.find("c0").text)
            c1 = float(azfmr.find("c1").text)
            c2 = float(azfmr.find("c2").text)
        elif(ipfVersion >= 2.43):
            c0, c1, c2 = map(float, azfmr.find("azimuthFmRatePolynomial").text.split())
        rates[i,:] = [
                float(t.hour*3600+t.minute*60+t.second+t.microsecond/1000000.0),
                float(azfmr.find('t0').text),
                c0, c1, c2 ]
    return rates

def read_burst_info(doc):
    burst_info = []
    for burst in doc.findall("swathTiming/burstList/burst"):
        t = datetime.datetime.strptime(burst.find("azimuthTime").text,
                                       "%Y-%m-%dT%H:%M:%S.%f")
        burst_info.append([
                float(t.hour*3600+t.minute*60+t.second+t.microsecond/1000000.0),
                float(burst.find("azimuthAnxTime").text),
                int(burst.find('byteOffset').text),
                np.array(map(int, burst.find('firstValidSample').text.split())),
                np.array(map(int, burst.find('lastValidSample').text.split())) ])
    return burst_info

def read_incidence_angle_poly(doc):
    srt, ia = [], []
    for ap in doc.findall("antennaPattern/antennaPatternList/antennaPattern"):
        srt.extend(map(float, ap.find("slantRangeTime").text.split()))
        ia.extend(map(float, ap.find("incidenceAngle").text.split()))
    srt, ia = np.array(srt), np.array(ia)
    poly_incidence = np.polyfit(srt-srt.min(), ia, 2)
    return [srt.min(), poly_incidence[2], poly_incidence[1], poly_incidence[0]]

def read_burst_interf_lag(FileNameLagInterfIn):
        indexLag = []
	myLag = []
	try:
		fin = open(FileNameLagInterfIn, 'r')
	except IOError, ioex:
		print 'Error with',FileNameLagInterfIn,':', os.strerror(ioex.errno)
		myLag = [-9999] # flag indicating something has gone wrong
	else:
		for line in fin:
			line = line.strip()
			columns = line.split()
			indexLag.append(int(columns[0]))
			myLag.append(float(columns[1]))
		fin.close
	return [indexLag, myLag]

def write_burst_interf_lag(FileNameLagInterfOut,burstsList,myLag,fileOrder):
	try:
		if fileOrder == 'Append':
			fout = open(FileNameLagInterfOut, 'a')
		else:
			fout = open(FileNameLagInterfOut, 'w')
	except IOError, ioex:
            print 'Error with',FileNameLagInterfOut,':', os.strerror(ioex.errno)
	else :
		for BurstNumber in range(0,len(burstsList)):
			fout.write("%-6d\t%10.6f\n" % (burstsList[BurstNumber], myLag[BurstNumber]))
		fout.close()

#def write_overlap(FileNameOverlapOut,burstsList,overlapTopFirstLine,overlapTopLastLine,overlapBotLastLine,invalidLinesTop,overlapFirstValidSample,overlapLastValidSample,fileOrder):
def write_overlap(FileNameOverlapOut,burstsList,overlapTopFirstLine,overlapTopLastLine,overlapBotLastLine,overlapFirstValidSample,overlapLastValidSample,fileOrder):
	try:   
		if fileOrder == 'Append':
			fout = open(FileNameOverlapOut, 'a') # append to existing file
		else:
			fout = open(FileNameOverlapOut, 'w') # erase any existing file
	except IOError, ioex:
        	print 'Error with',FileNameOverlapOut,':', os.strerror(ioex.errno)
    	else : 
        	for BurstNumber in range(0,len(burstsList)):
#                        fout.write("%-6d\t%6d\t%6d\t%6d\t%6d\t%6d\t%6d\n" % (burstsList[BurstNumber], overlapTopFirstLine[BurstNumber], overlapTopLastLine[BurstNumber], overlapBotLastLine[BurstNumber], invalidLinesTop[BurstNumber], overlapFirstValidSample[BurstNumber], overlapLastValidSample[BurstNumber]))
            		fout.write("%-6d\t%6d\t%6d\t%6d\t%6d\t%6d\n" % (burstsList[BurstNumber], overlapTopFirstLine[BurstNumber], overlapTopLastLine[BurstNumber], overlapBotLastLine[BurstNumber], overlapFirstValidSample[BurstNumber], overlapLastValidSample[BurstNumber]))
        	fout.close()

def read_overlap(FileNameOverlapIn):
	overlapsListPrev = []
	overlapTopFirstLinePrev = []
	overlapTopLastLinePrev = []
	overlapBotLastLinePrev = []
        #invalidLinesTopPrev =[]
	overlapFirstValidSamplePrev = []
	overlapLastValidSamplePrev = []
	try:   
		fin = open(FileNameOverlapIn, 'r')
	except IOError, ioex:
		print 'Error with',FileNameOverlapIn,':', os.strerror(ioex.errno)
	else : 
		for line in fin:
			line = line.strip()
			columns = line.split()
			overlapsListPrev.append(int(columns[0]))
			overlapTopFirstLinePrev.append(int(columns[1]))
			overlapTopLastLinePrev.append(int(columns[2]))
			overlapBotLastLinePrev.append(int(columns[3]))
                        #invalidLinesTopPrev.append(int(columns[4]))
			overlapFirstValidSamplePrev.append(int(columns[4]))
			overlapLastValidSamplePrev.append(int(columns[5]))
		fin.close
#	return overlapsListPrev, overlapTopFirstLinePrev, overlapTopLastLinePrev, overlapBotLastLinePrev, invalidLinesTopPrev, overlapFirstValidSamplePrev, overlapLastValidSamplePrev
        return overlapsListPrev, overlapTopFirstLinePrev, overlapTopLastLinePrev, overlapBotLastLinePrev, overlapFirstValidSamplePrev, overlapLastValidSamplePrev


def write_ktmean(FileNameKtmeanOut,burstsList,ktMean,fileOrder):
	try:
		if fileOrder == 'Append':
			fout = open(FileNameKtmeanOut, 'a')
		else:
			fout = open(FileNameKtmeanOut, 'w')
	except IOError, ioex:
        	print 'Error with',FileNameKtmeanOut,':', os.strerror(ioex.errno)
	else : 
        	for BurstNumber in range(0,len(burstsList)):
            		fout.write("%-6d\t%10.6f\n" % (burstsList[BurstNumber], ktMean[BurstNumber]))
        	fout.close()

def state_vector(year, month, day, time, satelite, orbit_type):
    global svectors
    sv = svectors
    v = [0., 0., 0., 0., 0., 0.]
    for i in range(6):
        for x in sv:
            tmp = 1
            for y in sv:
                if y[0] == x[0]: continue
                tmp = tmp * (y[0]-float(time))/(y[0]-x[0])
            v[i] = v[i] + x[i+1]*tmp
    return ["HDR", 0., 0., 0., 0.] + v
    
def lon_lat_height(state_vector):
    e2 = eccentricity2
    x, y, z = state_vector[5:8]
    r = np.sqrt(x*x + y*y + z*z)
    r1 = np.sqrt(x*x + y*y)
    lat = np.arctan2(z, r1)
    lon = np.arctan2(y, x)
    h = r - ae
    for i in range(6):
        n = ae / np.sqrt(1 - e2*np.power(np.sin(lat), 2))
        tanlat = z / r1 / (1 - (2-flat)*flat*n/(n+h))
        lat = np.arctan2(tanlat, 1)
        h = r1 / np.cos(lat) - n
    return (lat, lon, h)

def heading(state_vector, lat, lon):
    vx, vy, vz = state_vector[8:11]
    ve = -np.sin(lon)*vx + np.cos(lon)*vy
    vn = -np.sin(lat)*np.cos(lon)*vx - np.sin(lat)*np.sin(lon)*vy + np.cos(lat)*vz
    return np.arctan2(ve, vn)

def earth_radius(lat, lon, hdg):
    e2 =eccentricity2
    n = ae / np.sqrt(1 - e2*np.power(np.sin(lat), 2))
    m = ae * (1-e2) / np.power(np.sqrt(1 - e2*np.power(np.sin(lat), 2)), 3)
    r = n * m / (n*np.power(np.cos(hdg), 2) + m*np.power(np.sin(hdg), 2))
    return (n, m, r)

def UTC2YYMMDD(timeUTC, timeRefYYMMDD):
	myTimeFloat = timeUTC
	myTimeFloatHour = int(myTimeFloat / 3600)
	myTimeFloatMin = int((myTimeFloat /3600 - myTimeFloatHour)*60)
	myTimeFloatSec = int(myTimeFloat - myTimeFloatHour*3600 - myTimeFloatMin*60)
	myTimeFloatMicrosec = int((myTimeFloat - myTimeFloatHour*3600 - myTimeFloatMin*60 - myTimeFloatSec)*1000000.0)
	myTimeString = "%02d:%02d:%02d.%06d" % (myTimeFloatHour, myTimeFloatMin, myTimeFloatSec, myTimeFloatMicrosec)
	#print "myTimeFloat", myTimeFloat
	#print myTimeFloatHour, myTimeFloatMin, myTimeFloatSec, myTimeFloatMicrosec
	#print myTimeString
	myDateString = str(timeRefYYMMDD.strftime("%Y-%m-%d"))
	#print myDateString
	myYYMMDD = datetime.datetime.strptime(myDateString+"T"+myTimeString,"%Y-%m-%dT%H:%M:%S.%f")
	return myYYMMDD

# Save SLC only in one overlap region
def save_SLC_overlap(outFilePrefix, samples_in_output_file, dataArray, xOffset, yOffset):
	# Output file name
	outFileName = os.path.join(outdir, outFilePrefix+".slc")
	# Get array size
	myWidth  = dataArray.shape[1]
	myLength = dataArray.shape[0]
	# Display some info
	if verbose:
		print " > Writing to %s" % (outFileName)
		print " >  Width = %d / Length = %d / xOffset = %d / yOffset = %d " % (myWidth, myLength, xOffset, yOffset)	
	# Prepare output file
	dst_ds_ovl = drv.Create(outFileName,
		samples_in_output_file,
		myLength,
		1,
		gdal.GDT_CFloat32)	        
	dst_band_ovl = dst_ds_ovl.GetRasterBand(1)
	dst_band_ovl.Fill(0, 0)	
	# Save to SLC
	print dataArray.shape
	# If array too wide, crop it
	if myWidth + xOffset > samples_in_output_file:
		dataArray = dataArray[:,:int(samples_in_output_file-xOffset)]
		print dataArray.shape
		if verbose:
			print (" > Warning : Overlap array is too wide (%d whereas image width is only %d). Array has been cropped.")  % (myWidth + xOffset, samples_in_output_file)
	dst_band_ovl.WriteArray( dataArray, xOffset, yOffset)	
	# Write metadata
	dst_md_ovl = dst_ds_ovl.GetMetadata("ENVI")
	dst_ds_ovl.SetMetadata(dst_md_ovl, "ENVI")	
	# Close file
	del dst_ds_ovl
	del dst_md_ovl
	

# Check if module osgeo exists
try:
    imp.find_module('osgeo')
    found_osgeo = True
except ImportError:
    found_osgeo = False

# Check if module nsbas exists
try:
    imp.find_module('nsbas')
    found_nsbas = True
except ImportError:
    found_nsbas = False

# Check if gdal is available and import it from osgeo or nsbas
if found_osgeo: # by default, use osgeo
    from osgeo import gdal
    print 'Using osgeo version of gdal'
else:
    # Check if module nsbas exists
    try:
        imp.find_module('nsbas')
        found_nsbas = True
    except ImportError:
        found_nsbas = False
    if found_nsbas: # if osgeo is not found, use nsbas instead
        from nsbas import gdal
        print 'Using nsbas version of gdal'
    else:
        raise Exception("gdal not found, neither in osgeo nor in nsbas!")

# ENVI format
drv = gdal.GetDriverByName("ENVI")

# 0. Read arguments passed to python script
#swath = 1
#polarization = "vv"
outdir = ""
verbose = False
zeroLag = True
opts, argv = getopt.getopt(sys.argv[1:], "", ["output-directory=", "swath=", "polarization=", "skip_beg=", "skip_end=", "azshift_mean=", "azshift_azimuth=", "azshift_range=", "split_overlap=", "overlap_type=", "number_of_files=", "file_order=", "file_global_burst_index=", "total_number_of_bursts=", "incidence=", "verbose", "help"])
for o, a in opts:
    if   o == "--output-directory":
        outdir = a
    elif o == "--swath":
        swath = int(a)
    elif o == "--polarization":
        polarization = a
    elif o == "--skip_beg":
   	skipBeg = int(a)
    elif o == "--skip_end":
        skipEnd = int(a)
    elif o == "--azshift_mean":
        azshiftMean = float(a)
        zeroLag = False
    elif o == "--azshift_azimuth":
	azshiftAzimuth = float(a)
	zeroLag = False
    elif o == "--azshift_range":
	azshiftRange = float(a)
	zeroLag = False
    elif o == "--split_overlap":
	splitOverlap = a
    elif o == "--overlap_type":
	overlapType = a
    elif o == "--number_of_files":
	numberOfFiles = int(a)
    elif o == "--file_order":
	fileOrder = a
    elif o == "--file_global_burst_index":
	fileGlobalBurstIndex = int(a)
    elif o == "--total_number_of_bursts":
        totalNumberOfBursts = int(a)
    elif o == "--incidence":
	WriteIncidence = bool(a)
    elif o == "--verbose":
        verbose = True
    elif o == "--help":
        print("%s [--verbose] [--output-directory <out_dir>] [--swath <swath_no>] [--polarization <polarization>] \
			[--skip_beg <skip_beg>] [--skip_end <skip_end>] \
			[--azshift_mean <azshift_mean>] [--azshift_azimuth <azshift_azimuth>] [--azshift_range <azshift_range>] \
			[--write_overlap <write_overlap>] [--overlap_type <overlap_type>] \
			[--number_of_files <number_of_files>] [--file_order <file_order>] \
                        [--total_number_of_bursts <total_number_of_bursts>] [--file_global_burst_index <file_global_burst_index>] \
			[--incidence <incidence>] \
			<SAFE_DIRECTORY>" % (os.path.basename(sys.argv[0])))
        exit(0)
    else:
        pass
if len(argv) != 1:
    raise Exception("Wrong number of arguments")

# Check arguments
try:
    swath
except:
    swath = 1
    print "Warning : swath number not provided! Swath 1 will be processed by default."
else:
    if verbose:
        print "Processing swath %d." % swath

try:
    polarization
except:
    polarization = "vv"
    print "Warning : polarization not provided! Polarization VV will be processed by default."
else:
    if verbose:
        print "Processing polarization %s." % polarization



# 1. Open the XML annotation file
safepath = argv[0]
prefix = os.path.basename(safepath)[17:25]
prefix = prefix + '_iw' + str(swath) + '_' + polarization

if verbose:
    print "reading annotation file"
t = open_annotationxml(safepath, swath, polarization)
if not t:
    raise Exception("Cannot open XML annotation file")

# 1b. Open manifest file and get IPF version
if verbose:
    print "reading manifest file"
ipfVersion = get_ipfversion(safepath)
if not ipfVersion:
    raise Exception("Cannot open manifest file")
else:
    if verbose:
        print "IPF version = %.2f" % ipfVersion

# 1c. Check if overlap instructions have been provided
try:   
        splitOverlap
except:
        splitOverlap = bool(False)
        if verbose:
            print "> A single SLC will be generated (default) : splitOverlap = '%s' " % (splitOverlap )
else:
    if splitOverlap == 'True' or splitOverlap == 'Yes' or splitOverlap == 'yes' or splitOverlap == 'YES' or splitOverlap == 'y' or splitOverlap == 'Y':
        splitOverlap = bool(True)
        if verbose:
            print "> Overlaps will be split into several distinct SLCs : splitOverlap = '%s' " % (splitOverlap )
    elif splitOverlap == 'False' or splitOverlap == 'No' or splitOverlap == 'no' or splitOverlap == 'NO' or splitOverlap == 'n' or splitOverlap == 'N':
        splitOverlap = bool(False)
        if verbose:
            print "> A single SLC will be generated : splitOverlap = '%s' " % (splitOverlap )
    else:
        splitOverlap = bool(False)
        print "> split_overlap option not recognized. Set to default. A single SLC will be generated (default) : splitOverlap = '%s' " % (splitOverlap )

try:   
        overlapType
except:
        if splitOverlap:
			overlapType = 'Both'
			if verbose:
				print "> Both Forward and Backward overlaps will be written (default) : overlapType = '%s' " % (overlapType )
        else:
			overlapType = 'None'
                        if verbose:
                                print "> No overlap will be written : overlapType = '%s' " % (overlapType )
else:
        if splitOverlap and  ( overlapType == 'Forward' or overlapType == 'Backward' ) :
                if verbose:
                        print "> Warning : splitOverlap='yes' incompatible with overlapType = '%s'." % (overlapType)
                overlapType = 'Both' # splitOverlap=yes means that both overlaps are to be written
                if verbose:
                        print "> Both Forward and Backward overlaps will be written (default) : overlapType = '%s' " % (overlapType )
        elif not(splitOverlap) and  ( overlapType == 'Both'  or overlapType == 'both') :
                if verbose:
                        print "> Warning : splitOverlap='no' incompatible with overlapType = '%s'"  % (overlapType )
                splitOverlap = bool(False)
                overlapType = 'None'
                if verbose:
                        print "> No overlap will be written : overlapType = '%s' " % (overlapType )
        elif splitOverlap and  ( overlapType != 'Forward' and overlapType != 'Backward' ) :
                overlapType = 'Both'
                if verbose:
                        print "> Both Forward and Backward overlaps will be written (default) : overlapType = '%s' " % (overlapType )
        elif not(splitOverlap) and  ( overlapType == 'Forward' or overlapType == 'Backward' ) :
                if verbose:
                        print "> Overlap to be written : overlapType = '%s' " % (overlapType )
        else:
                if verbose:
                        print "> Overlap type not recognized : '%s'" % (overlapType)
                overlapType = 'None'
                splitOverlap = bool(False)
                if verbose:
                        print "> Set to default : splitOverlap = '%s' " % (splitOverlap)
                        print "> Set to default : overlapType = '%s' " % (overlapType )
    
# 1d. Check if the data should be appenned (multiple files handling)
try:
	numberOfFiles
except:
	numberOfFiles = 1
else:
	if verbose:
            print "> Number of files: %d" % (numberOfFiles)

try:
        fileOrder
except:
        fileOrder = 'None'
        if verbose:
            print "> Creating new file. "
        factorShrinkSLC = 0.95 # typically, burst overlaps represent 10% of image size. Take safety margin.
        #factorShrinkSLC = 1.00 # no shrinking
        if verbose:
            print "> SLC will be shrunk by a factor %f with respect to TIFF to account for overlap stitching. " % factorShrinkSLC
        try:   
            fileGlobalBurstIndex
        except:
            fileGlobalBurstIndex = 0
else:
    if fileOrder == 'Append':

        if verbose:
            print "> Appending to existing files. "
        FileNameOverlapIn = os.path.join(outdir, prefix+"_Overlap.txt")
#        (overlapsListPrev, overlapTopFirstLinePrev, overlapTopLastLinePrev, overlapBotLastLinePrev, invalidLinesTopPrev, overlapFirstValidSamplePrev, overlapLastValidSamplePrev) = read_overlap(FileNameOverlapIn)
        (overlapsListPrev, overlapTopFirstLinePrev, overlapTopLastLinePrev, overlapBotLastLinePrev, overlapFirstValidSamplePrev, overlapLastValidSamplePrev) = read_overlap(FileNameOverlapIn)
        print "overlapsListPrev", overlapsListPrev
        print "overlapTopFirstLinePrev", overlapTopFirstLinePrev
        print "overlapTopLastLinePrev", overlapTopLastLinePrev
        print "overlapBotLastLinePrev", overlapBotLastLinePrev
#        print "invalidLinesTopPrev", invalidLinesTopPrev
        print "overlapFirstValidSamplePrev", overlapFirstValidSamplePrev
        print "overlapLastValidSamplePrev", overlapLastValidSamplePrev

        try:   
                fileGlobalBurstIndex
        except:
		# last burst in list of bursts in "Overlap" file
                fileGlobalBurstIndex = overlapsListPrev[ len(overlapsListPrev) - 1 ]
	# last burst in list of bursts in "Overlap" file
	indexLastOverlapPrevFile = overlapsListPrev.index(fileGlobalBurstIndex)
        if verbose:
            print "> Index last overlap: %d" % (indexLastOverlapPrevFile)
	filePreviousYlastLine = overlapBotLastLinePrev[indexLastOverlapPrevFile]
#        filePreviousYOff2 = invalidLinesTopPrev[indexLastOverlapPrevFile]
	filePreviousFVS = overlapFirstValidSamplePrev[indexLastOverlapPrevFile]
	filePreviousLVS = overlapLastValidSamplePrev[indexLastOverlapPrevFile]
	if verbose:
            print "> Global Y index: %d" % (filePreviousYlastLine)
            #print " filePreviousYOff2", filePreviousYOff2
            print " filePreviousFVS  ", filePreviousFVS
            print " filePreviousLVS  ", filePreviousLVS

    else:
        print "Overlap type not recognized. Creating new files."
        fileOrder = 'None'
	fileGlobalBurstIndex = 0
if verbose:
    print "> Starting global burst numbering from %d. " % ( fileGlobalBurstIndex )

# 1e. Write incidence angles?
try:   
        WriteIncidence
except:
        WriteIncidence = False
else:
    if WriteIncidence == False or WriteIncidence == True:
        if verbose:
            print "> WriteIncidence : %s " % (WriteIncidence )
    else:
        print "WriteIncidence flag not recognized. Set to False."
        WriteIncidence = False

# prepare for storing overlap top/bottom & left/right indexes for later output to ASCII
overlapTopFirstLine = []
overlapTopLastLine = []
overlapBotLastLine = []
overlapTopFirstLine_curr = []
overlapTopLastLine_curr = []
overlapBotLastLine_curr = []
numLinesKeepBottom = int(150) # number of lines at bottom of bursts to account for overlap (should be greater than the length of longest possible overlap region)
overlapFirstValidSample = []
overlapLastValidSample = []
#invalidLinesTop = []
ktMean = []

# update prefix accordingly
if overlapType == 'Forward':
        prefix = prefix + '_fw'
elif overlapType == 'Backward':
        prefix = prefix + '_bw'
if verbose:
        print 'prefix:', prefix

# 2.a Read the state vectors
if verbose:
    print "extracting state vectors"
svectors = read_hdr_data_points(t)
svectors_velocity = np.sqrt(svectors[:, 4]*svectors[:, 4] + svectors[:, 5]*svectors[:, 5] + svectors[:, 6]*svectors[:, 6])
svectors_position = np.sqrt(svectors[:, 1]*svectors[:, 1] + svectors[:, 2]*svectors[:, 2] + svectors[:, 3]*svectors[:, 3])
#np.savetxt(os.path.join(outdir, "hdr_data_points_"+prefix+".rsc"),
#           svectors, "%-15s")
# 2.b Read doppler centroid polynomials
if verbose:
    print "extracting doppler centroid polynomials"
doppler_centroid_data = read_doppler_centroid_data(t)
doppler_centroid_geometry = read_doppler_centroid_geometry(t)
#np.savetxt(os.path.join(outdir, "doppler_centroid_data_"+prefix+".txt"),
#           doppler_centroid_data, "%-15s")
#np.savetxt(os.path.join(outdir, "doppler_centroid_geometry_"+prefix+".txt"),
#           doppler_centroid_geometry, "%-15s")
# 2.c Read azimuth FM rate estimations
if verbose:
    print "extracting FM rate estimations"
azimuth_fm_rate = read_azimuth_fm_rate(t,ipfVersion)
#np.savetxt(os.path.join(outdir, "azimuth_fm_rate_"+prefix+".txt"),
#           azimuth_fm_rate, "%-15s")
# 2.d Read burst information
if verbose:
    print "extracting burst information"
burst_info = read_burst_info(t)
if verbose:
    print "> %d bursts in swath %d" % (len(burst_info), swath)
# Check if a by offset exists at top of file
if burst_info[0][2]!=0:
    tiffOffset = burst_info[0][2]	
    if verbose:
        print " Warning : TIFF offset of %d pixels!" % tiffOffset
else:
    tiffOffset = 0
if verbose:
    print 'tiffOffset       : %d' % tiffOffset

# 2.e Read incidence angle polynomials
incidence_angle_poly = read_incidence_angle_poly(t)
#np.savetxt(os.path.join(outdir, "incidence_angle_poly_"+prefix+".txt"),
#           incidence_angle_poly, "%-15s")
# 2.f Various info needed for processing
kpsi = float(t.find("generalAnnotation/productInformation/azimuthSteeringRate").text)/180.*np.pi
fc = float(t.find("generalAnnotation/productInformation/radarFrequency").text)
deltats = float(t.find("imageAnnotation/imageInformation/azimuthTimeInterval").text)
t0 = float(t.find("imageAnnotation/imageInformation/slantRangeTime").text)
rsr = float(t.find("generalAnnotation/productInformation/rangeSamplingRate").text)
lines_per_burst = int(t.find("swathTiming/linesPerBurst").text)
samples_per_burst = int(t.find("swathTiming/samplesPerBurst").text)
burst_duration = deltats * lines_per_burst

if verbose:
	print 'linesPerBurst       : %d' % lines_per_burst
	print 'samplesPerBurst     : %d' % samples_per_burst
	print 'azimuthTimeInterval : %f' % deltats
	print 'azimuthSteeringRate : %f' % kpsi
	print 'rangeSamplingRate   : %f' % rsr
	print 'slantRangeTime      : %f' % t0
	print 'radarFrequency      : %f' % fc
	print 'burstDuration       : %f' % burst_duration

# A few more info from the annotation
# - Times at the first, last and center lines
flt = datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productFirstLineUtcTime").text,
                                 "%Y-%m-%dT%H:%M:%S.%f")
llt = datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productLastLineUtcTime").text,
                                 "%Y-%m-%dT%H:%M:%S.%f")
clt = flt + (llt - flt)/2
if verbose:
	print "first  line in image (uncropped)", flt
	print "center line in image (uncropped)", clt
	print "last   line in image (uncropped)", llt
# - Compute the lat/lon/height of the satelite
sv_top = state_vector(str(flt.year), str(flt.month), str(flt.day), str(flt.hour*3600+flt.minute*60+flt.second+flt.microsecond/1000000.0), "SENTINEL1", "HDR")
sv_mid = state_vector(str(clt.year), str(clt.month), str(clt.day), str(clt.hour*3600+clt.minute*60+clt.second+clt.microsecond/1000000.0), "SENTINEL1", "HDR")
sv_bot = state_vector(str(llt.year), str(llt.month), str(llt.day), str(llt.hour*3600+llt.minute*60+llt.second+clt.microsecond/1000000.0), "SENTINEL1", "HDR")
lat_top, lon_top, height_top = lon_lat_height(sv_top)
lat_mid, lon_mid, height_mid = lon_lat_height(sv_mid)
lat_bot, lon_bot, height_bot = lon_lat_height(sv_bot)
hdg_mid = heading(sv_mid, lat_mid, lon_mid)
earth_eradius, earth_nradius, earth_radius = earth_radius(lat_mid, lon_mid, hdg_mid)

# time of first line in burst
timeBurstTop = np.array([bi[1] for bi in burst_info])
# time of last line in burst
timeBurstBot = timeBurstTop + burst_duration
# duration of burst overlap
overlapDuration = np.append(np.zeros(1), np.array([timeBurstBot[i] - timeBurstTop[i+1] for i in range(len(timeBurstTop)-1)]))
# number of lines in burst overlap
overlapNumOfLines = np.round(overlapDuration/deltats)
# number of lines between successive burst tops
linesBetweenBurstTop = np.append(np.zeros(1), np.round(np.diff(timeBurstTop)/deltats))

if verbose:
	print 'timeBurstTop         ', timeBurstTop
	print 'timeBurstBot         ', timeBurstBot
	print 'overlapDuration      ', overlapDuration
	print 'overlapNumOfLines    ', overlapNumOfLines
	print 'linesBetweenBurstTop ', linesBetweenBurstTop
				
# 2.g Check if user passed information on burst start / end
try:
	skipBeg
except:
	skipBeg = 0
try:
	skipEnd
except:
	skipEnd = 0
# number of bursts
numOfBursts = len(burst_info) - skipBeg - skipEnd
if verbose:
    print "> Processing bursts %d to %d (= %d bursts)" % (skipBeg + 1, len(burst_info) - skipEnd, numOfBursts )

try:
    totalNumberOfBursts
except:
    totalNumberOfBursts = numOfBursts * numberOfFiles
else:
    if verbose:
        print "> Total number of bursts: %d" % (totalNumberOfBursts)

# 2.h If user passed information on azimuth shift, read "LagInDopOffset" input file
if zeroLag == False:
	# check if the necessary values have been provided
	try:
		azshiftMean
	except NameError:
		if verbose:
			print "Warning : You must provide a value for azshift_mean. It will be set to zero."
		azshiftMean = 0		
	try:
		azshiftAzimuth
	except NameError:
		if verbose:
			print "Warning : You did not provide a value for azshift_azimuth. It will be set to zero."
		azshiftAzimuth = 0		
	try:
		azshiftRange
	except NameError:
		if verbose:
			print "Warning : You did not provide a value for azshift_range. It will be set to zero."
		azshiftRange = 0
		
	# open the input file
	FileNameLagInterfIn = os.path.join(outdir, prefix+"_LagInDopOffset.txt")
        [indexLag, myLag] = read_burst_interf_lag(FileNameLagInterfIn)
	print indexLag, myLag
	# correct the lags if something wrong happenned
	if myLag == -9999: # missing file?
		if verbose:
			print "Warning : Decoding of \"LagInDopOffset\" went wrong. All the lags will be set to zero."
		myLag = [np.zeros((numOfBursts,1))]
	if len(myLag) < numOfBursts: # incomplete file ?
		if verbose:
			print "Warning : Not enough lags in \"LagInDopOffset\". Missing lags will be set to zero."
		for i in range(len(myLag)+1,numOfBursts):
			myLag.append('0.0')	
else:
	myLag = []

# 2g. Times at the first, last and center lines, taking into account only the selected bursts
if verbose:
    print "Total number of bursts in original image (uncropped) : %d " % len(burst_info)
    print "Skipping %d bursts at the top / Skipping %d bursts at the bottom" % (skipBeg, skipEnd)
#for i in range(len(burst_info)):
#	print i, burst_info[i][0]
#	print burst_info[i][:]
#print burst_info[len(burst_info) - skipEnd - 1][0]
timeFirstLineFirstBurst = burst_info[skipBeg][0]
timeLasLineLastBurst = burst_info[len(burst_info) - skipEnd - 1][0] + burst_duration
timeCenterImage = (timeFirstLineFirstBurst + timeLasLineLastBurst)/2
if verbose:
    print "timeFirstLineFirstBurstUTC %f / timeCenterImageUTC %f / timeLasLineLastBurstUTC %f " % (timeFirstLineFirstBurst, timeCenterImage, timeLasLineLastBurst)

# # Convert times back to YYMMDD format
# First line
firstLineYYMMDD = UTC2YYMMDD(timeFirstLineFirstBurst, flt)
# Center line
centerLineYYMMDD = UTC2YYMMDD(timeCenterImage, clt)
# Last line
lastLineYYMMDD = UTC2YYMMDD(timeLasLineLastBurst, llt)
if verbose:
    print "timeFirstLineFirstBurst  ", firstLineYYMMDD
    print "timeCenterImage          ", centerLineYYMMDD
    print "timeLasLineLastBurst     ", lastLineYYMMDD

# 3. Open the measurement dataset
if verbose:
    print "Opening measurement dataset"
src_ds = open_measurementds(safepath, swath, polarization)
src_band = src_ds.GetRasterBand(1)

# 4. And the output dataset
if verbose:
    print "Opening output dataset"
if fileOrder != 'Append':
	# if multiple files, write a long file
	dst_ds = drv.Create(os.path.join(outdir, prefix+".slc"),
                    samples_per_burst,
                    #lines_per_burst*numOfBursts*numberOfFiles,
                    #lines_per_burst*totalNumberOfBursts,
                    int(lines_per_burst*totalNumberOfBursts*factorShrinkSLC),
                    1,
                    gdal.GDT_CFloat32)
	dst_band = dst_ds.GetRasterBand(1)
	dst_band.Fill(0, 0)
        if verbose:
           print (" > File size %d x %d ") % (samples_per_burst, int(lines_per_burst*totalNumberOfBursts*factorShrinkSLC))
	#if WriteIncidence:
		#inc_ds = drv.Create(os.path.join(outdir, prefix+".inc"),
	        #            samples_per_burst,
	        #            lines_per_burst*numOfBursts*numberOfFiles,
	        #            2,
	        #            gdal.GDT_Float32,
                #            options = ['INTERLEAVE=BIL'])
		#inc_band = inc_ds.GetRasterBand(1)
                #squ_band = inc_ds.GetRasterBand(2)
		#inc_band.Fill(0, 0)
                #squ_band.Fill(0, 0)
		
else:
        dst_ds = gdal.Open(os.path.join(outdir, prefix+".slc"), gdal.GA_Update)
        #if WriteIncidence:
			#inc_ds = gdal.Open(os.path.join(outdir, prefix+".inc"), gdal.GA_Update)

	# Read the metadata from SLC
	dst_md = dst_ds.GetMetadata("ENVI")
	# Get time of first line in the SLC
	firstLineUTCGlobal = float(dst_md["FIRST_LINE_UTC"])
	# Get time of first line in the TIFF
	firstLineUTCCurrent = float(str(flt.hour*3600+flt.minute*60+flt.second+flt.microsecond/1000000.0))
	print "firstLineUTCCurrent", flt
	print "firstLineUTCCurrent", firstLineUTCCurrent
	print "firstLineUTCGlobal", firstLineUTCGlobal 
	# Time difference
	firstLineUTCDiff = firstLineUTCCurrent - firstLineUTCGlobal
	# Number of lines corresponding to this time difference
	firstLineIndexDiff = int(round(firstLineUTCDiff / deltats))

	dst_band = dst_ds.GetRasterBand(1)
	#if WriteIncidence:
		#inc_band = inc_ds.GetRasterBand(1)
                #squ_band = inc_ds.GetRasterBand(2)

# 5. Read the bursts

# index of first line in TIFF relative to first line in SLC 
if fileOrder == 'Append':
	#dst_yoff = fileGlobalBurstIndex
	dst_yoff = firstLineIndexDiff
        dst_yoff2 = firstLineIndexDiff
        if verbose:
            print "> firstLineIndexDiff %d" % firstLineIndexDiff
else:
	dst_yoff = 0 # TODO: Include the swath offet (use GCP?)

# add number of invalid lines in first burst found in TIFF
for j in range(burst_info[0][3].size):
    # if firstValidSample = -1, this is an invalid line
    if burst_info[0][3][j] == -1:
        dst_yoff = dst_yoff+1
    else:
        break
if verbose:
    print "> dst_yoff %d" % dst_yoff

# alternatively, add  number of invalid lines in first USED burst found in TIFF
if fileOrder == 'Append':
    for j in range(burst_info[skipBeg][3].size):
        # if firstValidSample = -1, this is an invalid line
        if burst_info[skipBeg][3][j] == -1:
            dst_yoff2 = dst_yoff2+1
        else:
            break
    if verbose:
        print "> dst_yoff2 %d" % dst_yoff2
    # normally, should yield the same results, as fileOrder == 'Append' => skipBeg = 0
    if dst_yoff != dst_yoff2:
        print (" > Warning : dst_yoff (%d) is different from dst_yoff2 (%d)! Should be equal.") % (dst_yoff, dst_yoff2)

# Loop over all bursts in TIFF
for i in range(len(burst_info)):
    bi = burst_info[i]
    afr = azimuth_fm_rate[i]
    dcg = doppler_centroid_geometry[i]

    # Index of burst (local = relative to first burst found in current image)
    iLocal = i + 1

    # Index of burst (global = relative to first burst used in master image)    
    iGlobal = fileGlobalBurstIndex+1+i-skipBeg

    if verbose:
        print ""
        print "   > Processing burst %d" % (iLocal)
        print "   > Global burst index = %d" % (iGlobal)
        
    #print 'bi', bi 
    #print 'afr', afr 
    #print 'dcg', dcg 

    # first valid line in current burst
    dst_yoff3 = 0
    for j in range(bi[3].size):
        # if firstValidSample = -1, this is an invalid line
        if bi[3][j] == -1:
            dst_yoff3 = dst_yoff3+1
        else:
            break
    if verbose:
        print "> dst_yoff3 %d" % dst_yoff3

    # Find the coordinates of the burst, discarding invalid lines/samples
    #xoff, yoff = int(bi[2]%src_ds.RasterXSize/4), int(bi[2]/src_ds.RasterXSize/4)
    # offset relative to beginning of TIFF
    xoff, yoff = int((bi[2]-tiffOffset)%src_ds.RasterXSize/4), int((bi[2]-tiffOffset)/src_ds.RasterXSize/4)
    xoff2, yoff2 = 0, 0
    xsize, ysize = 0, 0
    before_fvl = True
    fvsMax = 0
    lvsMin = samples_per_burst
    for j in range(bi[3].size):
        # first / last valid samples
        fvs, lvs = bi[3][j], bi[4][j]
        if fvs == -1 and lvs == -1 and before_fvl:
            # invalid lines at the top
            yoff2 = yoff2 + 1
        elif fvs != -1 and lvs != -1:
            if before_fvl:
                # reached first valid line
                before_fvl =  False
                # invalid samples in near range
                xoff2 = fvs
                xsize = lvs - xoff - xoff2
                ysize = 1
            else:
                # next valid line
                ysize = ysize + 1
            if fvs > fvsMax:
				fvsMax = fvs
            if lvs < lvsMin:
				lvsMin = lvs
        elif fvs == -1 and lvs == -1 and not before_fvl:
            # reached just after last valid line
            break # Nothing else to do?

    # save write offsets from previous burst, if applicable
    if ( i > 0 ):
        xOffsetWritePrev = xOffsetWrite
        yOffsetWritePrev = yOffsetWrite

    # X offset when writing to output file
    xOffsetWrite = xoff + xoff2
    # Y offset when writing to output file
    yOffsetWrite = yoff + yoff2
    if verbose:
        print ("xOffsetWrite %d / yOffsetWrite %d ") % (xOffsetWrite, yOffsetWrite)

    # Only deal with the requested bursts
    if ( (i >= skipBeg) and (i < len(burst_info) - skipEnd)) :
		            
        # Handle first / last valid samples
        if i == skipBeg: # First burst in current file
			if fileOrder == 'Append': # .. but this is not the first file
				if verbose:
					print 'filePreviousFVS %s / filePreviousLVS %s' % (filePreviousFVS, filePreviousLVS)
				# We have to compare against first / last valid samples from last burst of previous file
				overlapFirstValidSample = np.append(overlapFirstValidSample, np.max([filePreviousFVS, fvsMax]))
				overlapLastValidSample =  np.append(overlapLastValidSample,  np.min([filePreviousLVS, lvsMin]))
        else: # This is not the first burst, just compare with previous burst
			overlapFirstValidSample = np.append(overlapFirstValidSample, np.max([overlapFirstValidSamplePrev,fvsMax]))
			overlapLastValidSample =  np.append(overlapLastValidSample,  np.min([overlapLastValidSamplePrev, lvsMin]))
		
        # Save first / last valid samples from current burst to compare with next burst, if applicable
        overlapFirstValidSamplePrev = fvsMax
        overlapLastValidSamplePrev =  lvsMin
        if verbose:
            print 'overlapFirstValidSamplePrev %s / overlapLastValidSamplePrev %s' % (overlapFirstValidSamplePrev, overlapLastValidSamplePrev)
            print 'overlapFirstValidSample     %s / overlapLastValidSample     %s' % (overlapFirstValidSample, overlapLastValidSample)
		   
       # Read the burst
	#tiffOffsetX = tiffOffset/8 % samples_per_burst
        #tiffOffsetY = tiffOffset/8 // samples_per_burst
        if verbose:
            #print 'tiffOffsetX %d / tiffOffsetY %d' % (tiffOffsetX, tiffOffsetY)
            print 'xsize %d / ysize %d' % (xsize, ysize)
            #print 'samples_per_burst %d' % (samples_per_burst)
        #data = src_band.ReadAsArray(int(xoff+xoff2-tiffOffsetX), int(yoff+yoff2-tiffOffsetY), int(xsize), int(ysize))
        data = src_band.ReadAsArray(int(xOffsetWrite), int(yOffsetWrite), int(xsize), int(ysize))
    
        # Compute deramping function
        # - zero-doplper azimuth time centered in the middle of the burst
        eta = deltats * np.arange(1, lines_per_burst+1)
        eta = eta - np.mean(eta)
        eta = np.tile(eta[yoff2:yoff2+ysize], (xsize, 1)).T
        #eta = np.arange(-ysize/2, ysize/2) * deltats
        #eta = np.tile(eta, (xsize, 1)).T
        # - velocity interpolated from state vectors
        vs = np.interp(bi[0]+burst_duration/2, svectors[:, 0], svectors_velocity)
        # - radius of orbit interpolated from state vectors
        radiusOrbit = np.interp(bi[0]+burst_duration/2, svectors[:, 0], svectors_position)
        # - two-way slant range (fast) time
        #tau = t0 + np.arange(xoff2, xoff2+xsize)/rsr/2 # one-way travel time??
	tau = t0 + np.arange(xoff2, xoff2+xsize)/rsr # two-way travel time??
        # - doppler centroid frequency
        #   use either doppler centroid data or geometry: ESA recommands data,
        #   but pratical usage tells us otherwise.
        d = tau - dcg[1]
        d2 = d*d
        d3 = d2*d
        d4 = d2*d2
        fetac = dcg[2] + dcg[3]*d + dcg[4]*d2 + dcg[5]*d3 + dcg[6]*d4
        fetac0 = fetac[0]
        fetac = np.tile(fetac, (ysize, 1))
        # - classical doppler FM rate
        d = tau - afr[1]
        d2 = d*d
        ka = afr[2] + afr[3]*d + afr[4]*d2
        ka0 = ka[0]
        ka = np.tile(ka, (ysize, 1))
        # - doppler centroid rate introduced by steering of the antenna
        ks = 2 * vs / C * fc * kpsi
        # - doppler centroid rate in the focused SLC
        alpha = 1 - ks/ka
        kt = ks / alpha
	ktMean = np.append(ktMean, np.mean(kt)); 

        # - beam centre crossing time
        etac = -fetac / ka
        etaref = 0 #etac - etac[0, 0]
	etac0= -1* fetac0 / ka0
	dopCentAzPix = etac0 / deltats 
	
	#Compute look angle(s)
	if WriteIncidence:
		# Squint angle
		squintDegree = kpsi*( (eta) / (1+(np.tile(tau, (ysize, 1))*C*kpsi)/(2*vs)) )*180./np.pi
		#Incidence angle
		incidenceDegree = np.polyval( incidence_angle_poly[:0:-1], np.tile(tau, (ysize, 1)) - incidence_angle_poly[0] )

		if verbose:
		    print 'incidence_angle_poly %s' % (incidence_angle_poly[1:])
		    print 'kpsi %s / vs %s' % (kpsi, vs)
		    print 'backward, near-range: tau %.6f / eta %+.6f / squintDegree %+.6f / incidenceDegree %.6f' % (tau[0],       eta[0,0],     squintDegree[0,0],     incidenceDegree[0,0])
		    print '      middle        : tau %.6f / eta %+.6f / squintDegree %+.6f / incidenceDegree %.6f' % (np.mean(tau), np.mean(eta), np.mean(squintDegree), np.mean(incidenceDegree))
		    print ' forward,  far-range: tau %.6f / eta %+.6f / squintDegree %+.6f / incidenceDegree %.6f' % (tau[-1],      eta[-1,-1],   squintDegree[-1,-1],   incidenceDegree[-1,-1])

	# Count from beginning
        # first USED burst
        if i == skipBeg:
			if fileOrder != 'Append': # first image : just write to output
                                yoff3 = dst_yoff3
				# No overlap need to be taken into account at the top
				yoff4 = 0
                                yoff5 = 0
			else: # not the first image : need to account for overlap with last burst in previous image
                                #yoff3 = dst_yoff + yoff2 - filePreviousYOff2 + 1
                                yoff3 = dst_yoff
                                #print "yoff2 - filePreviousYOff2", yoff2 - filePreviousYOff2
				# Length of top overlap
                                yoff5 = filePreviousYlastLine - dst_yoff
				#yoff3 = dst_yoff - 1 # for test
				# Overlap
				if overlapType == 'None' or overlapType == 'Both':
					yoff4 = int( ( yoff5 ) / 2)
				elif overlapType == 'Backward':				
					yoff4 = 0
				elif overlapType == 'Forward':				
					yoff4 = int( yoff5 )
                                # number of invalid lines at top of current burst
                                #invalidLinesTop  = np.append ( invalidLinesTop , yoff2 )
        else:  
			yoff3 = yoff3 + int(linesBetweenBurstTop[i]) + yoff2 - yoff2_prev
			# Length of top overlap
                        yoff5 = ysize-linesBetweenBurstTop[i]
			if overlapType == 'None' or overlapType == 'Both':
				yoff4 = int( ( yoff5 ) / 2)
			elif overlapType == 'Backward':
				yoff4 = 0
			elif overlapType == 'Forward':
				yoff4 = int( yoff5 )
			# number of invalid lines at top of current burst
                        #invalidLinesTop  = np.append ( invalidLinesTop , yoff2 )
	
        yoff2_prev = yoff2

        if i != skipBeg  or fileOrder== 'Append': # except for first burst of first image (no overlap) :
			# first line in overlap at top of current burst
                        overlapTopFirstLine_curr = int(yoff3-1)
                        overlapTopFirstLine = np.append ( overlapTopFirstLine , overlapTopFirstLine_curr )
			# last line in overlap at top of current burst
			if i == skipBeg: # use value from previous file
                                overlapTopLastLine_curr = filePreviousYlastLine
			else:
                                overlapTopLastLine_curr = int(yoff3-1+int(ysize-linesBetweenBurstTop[i]))
                        overlapTopLastLine  = np.append ( overlapTopLastLine , overlapTopLastLine_curr )
			# last line in overlap at bottom of current burst
                        overlapBotLastLine_curr = int(yoff3-1+int(ysize))
                        overlapBotLastLine  = np.append ( overlapBotLastLine , overlapBotLastLine_curr)
			
		## first line in overlap at top of current burst
		#overlapTopFirstLine = np.append ( overlapTopFirstLine , int(yoff3-1) )
		## last line in overlap at top of current burst
		#overlapTopLastLine  = np.append ( overlapTopLastLine , int(yoff3-1+int(ysize-linesBetweenBurstTop[i])) )
        ## last line in overlap at bottom of current burst
		#overlapBotLastLine  = np.append ( overlapBotLastLine , int(yoff3-1+int(ysize)) )
		                        
        if verbose:
			print 'overlapTopFirstLine %s / overlapTopLastLine %s / overlapBotLastLine %s' % (overlapTopFirstLine_curr, overlapTopLastLine_curr, overlapBotLastLine_curr)

	#print "check: ", ysize, yoff, yoff2, yoff3, yoff4, dst_yoff, int(linesBetweenBurstTop[i]), ysize-int(linesBetweenBurstTop[i]), linesBetweenBurstTop
        if verbose:
                print "check : ysize %d / yoff %d / yoff2 %d / yoff3 %d / yoff4 %d / dst_yoff %d" % (ysize, yoff , yoff2, yoff3, yoff4, dst_yoff)
	if verbose:
		print 'FirstValidLineInBurst   : %d     /  LastValidLineInBurst   : %d' % (yoff2, ysize+yoff2)
		print 'FirstValidSampleInBurst : %d     /  LastValidSampleInBurst : %d' % (fvsMax, lvsMin)

        # Account for user-provided lag, if necessary
	if zeroLag == True: # no lag, use burst centre time for compensation
        	lagOffset = 0
		myLag.append(dopCentAzPix)
    	else: # use lag provided by user
                if verbose:
                    print "indexLag", indexLag
                    #print "fileGlobalBurstIndex", fileGlobalBurstIndex, "i", i
                #indexLagCurrentBurst = indexLag.index(fileGlobalBurstIndex+1+i)
                indexLagCurrentBurst = indexLag.index(iGlobal)
		myLagCurrentBurst = myLag[indexLagCurrentBurst]
                if verbose:
		    print 'indexLagCurrentBurst', indexLagCurrentBurst, 'myLagCurrentBurst', myLagCurrentBurst

		
		# range-dependent term
		xCoordOrig = range(xsize)
		offsetRange = [float(x*azshiftRange) for x in xCoordOrig]
		offsetRange = np.tile(offsetRange, (ysize, 1))
		
		# azimuth-dependent term
		yCoordOrig = range(ysize)
		offsetAzimuth = [float((y + int(yoff3-1))*azshiftAzimuth) for y in yCoordOrig]
		offsetAzimuth = np.tile(offsetAzimuth, (xsize, 1)).T
		
		# add them to the constant term and also account for lag
                lagOffset = offsetRange + offsetAzimuth + azshiftMean + float(myLagCurrentBurst)

	# mean offset for this burst
	lagOffsetMean = np.mean(lagOffset)
	if verbose:
		print " ka0 %.8f / fetac0 %.8f / etac0 %.8f " % (ka0, fetac0, etac0)
		print " dopCentAzPix  %.8f / lagOffsetMean %.8f" % (dopCentAzPix, lagOffsetMean)
                print " kaMean %.8f / ksMean %.8f / ktMean %.8f / alphaMean %.8f " % (np.mean(ka), np.mean(ks),np.mean(kt), np.mean(alpha))

	# Finally, the compensation term
        phi = np.exp(-1j * np.pi * kt * (eta-etaref-lagOffset*deltats)*(eta-etaref-lagOffset*deltats))
        # Apply deramping function
        data = data * phi

#        if splitOverlap and ( overlapType == 'Backward' or overlapType == 'Both' ):
#            # Keep only top of burst
#            data_ovl_bw = data[:int(yoff5),:].copy()

        #if splitOverlap and ( overlapType == 'Forward' or overlapType == 'Both' ):
        #    # Keep "numLinesKeepBottom" lines at bottom of burst
        #    data_ovl_fw = data[ysize-int(numLinesKeepBottom):,:].copy()
               
        if ( i != skipBeg or fileOrder== 'Append' ) and splitOverlap: # except for first burst of first image (no overlap) :
            # Number of lines in overlap at the top of current burst
            overlapTopNumberOfLines = int(overlapTopLastLine_curr - overlapTopFirstLine_curr)
            if verbose:
                     print " overlapTopNumberOfLines = ", overlapTopNumberOfLines
            # Number of lines in overlap at the top of current burst
            overlapBotNumberOfLines = overlapTopNumberOfLines # TODO : use Master file to determine size of bottom overlap
            if verbose:
                    print " overlapBotNumberOfLines = ", overlapBotNumberOfLines

        # # Write backward looking phase in overlap region at the top of CURRENT burst
        if ( i != skipBeg or fileOrder== 'Append' ) and splitOverlap: # except for first burst of first image (no overlap) :
 			
			# # Write Backward overlap region of current burst
 			if overlapType == 'Backward' or overlapType == 'Both':
				# Base name
			    prefix_ovl_bw = ( prefix + '_ovl_' + '%03d' + '_bw' ) % (iGlobal )
			    if verbose:
					print "Backward SLC : ", prefix_ovl_bw
			    # Keep only top of burst
			    data_ovl_bw = data[:int(yoff5),:].copy()
			    # Save to SLC
			    save_SLC_overlap(prefix_ovl_bw, samples_per_burst, data_ovl_bw, int(xOffsetWrite), int(0))

        # # Write forward looking phase in overlap region at the bottom of PREVIOUS burst
        if ( i != skipBeg or ( fileOrder== 'Append' and i != 0 ) ) and splitOverlap: # except for first burst of image (no overlap) :
			# # Write Forward overlap region of previous burst
 			if overlapType == 'Forward' or overlapType == 'Both':
				# Base name
			    prefix_ovl_fw = ( prefix + '_ovl_' + '%03d' + '_fw' ) % (iGlobal )
			    if verbose:
				    print "Forward SLC : ", prefix_ovl_fw
			    # Keep only bottom of burst
			    data_ovl_fw = np.delete(data_ovl_fw, range(int(numLinesKeepBottom-yoff5)), axis=0)
			    # Save to SLC
			    save_SLC_overlap(prefix_ovl_fw, samples_per_burst, data_ovl_fw, int(xOffsetWritePrev), int(0))

        # # Save bottom of CURRENT burst
        if splitOverlap and ( overlapType == 'Forward' or overlapType == 'Both' ):
            # Keep "numLinesKeepBottom" lines at bottom of burst
            data_ovl_fw = data[ysize-int(numLinesKeepBottom):,:].copy()

        # # Also write forward looking phase in overlap region at the bottom of CURRENT burst
        # # if bottom of image has been reached
        if ( ( i == len(burst_info) - skipEnd - 1 ) and ( iGlobal != totalNumberOfBursts )  ) : # only last burst of not last image 
			# # Write Forward overlap region of curent burst
 			if overlapType == 'Forward' or overlapType == 'Both':
			    # Base name, anticipate
			    prefix_ovl_fw = ( prefix + '_ovl_' + '%03d' + '_fw' ) % (iGlobal + 1 )
			    if verbose:
			        print "Forward SLC : ", prefix_ovl_fw
			    # Keep only bottom of burst
			    data_ovl_fw = np.delete(data_ovl_fw, range(int(numLinesKeepBottom-yoff5)), axis=0)
			    # Save to SLC
			    save_SLC_overlap(prefix_ovl_fw, samples_per_burst, data_ovl_fw, int(xOffsetWrite), int(0))

        # Crop burst at the top in the overlap area
        data = np.delete(data, range(yoff4), axis=0)
        if WriteIncidence:
                incidenceDegree  = np.delete(incidenceDegree, range(yoff4), axis=0)
                squintDegree     = np.delete(squintDegree,    range(yoff4), axis=0)

        # Write out the burst
        print " Writing burst %d" % (i + 1)
#        dst_band.WriteArray(data, int(xoff+xoff2), int(yoff3-1))
#        print data.shape
#        print int(xoff+xoff2), int(yoff3-1+yoff4)
#        print samples_per_burst
        dst_band.WriteArray(data, int(xOffsetWrite), int(yoff3-1+yoff4))
        #if WriteIncidence:
                        #inc_band.WriteArray(incidenceDegree, int(xoff+xoff2), int(yoff3-1+yoff4))
			#squ_band.WriteArray(squintDegree, int(xoff+xoff2), int(yoff3-1+yoff4))

    else:
        print " Skipping burst %d" % (i + 1)

#5.b If user did not pass information on azimuth shift, write "LagOutDop" output file
if zeroLag == True:
        FileNameLagInterfOut = os.path.join(outdir, prefix+"_LagOutDop.txt")
	#burstsList = range (fileGlobalBurstIndex + skipBeg + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd + 1)
        burstsList = range (fileGlobalBurstIndex + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd - skipBeg + 1)
	#print 'burstsList %s' % burstsList
	#print 'myLag %s' % myLag
        write_burst_interf_lag(FileNameLagInterfOut, burstsList, myLag,fileOrder)

## 5.c If this is the master image, write azimuth time corresponding to burst overlap cut
#if overlapType == 'Master' :
#	burstsList = range (skipBeg + 2, len(burst_info) - skipEnd + 1)
#	write_overlap(FileNameOverlapOut,burstsList,timeBurstCutOut)
#if overlapType == 'None' :
FileNameOverlapOut = os.path.join(outdir, prefix+"_Overlap.txt")
if fileOrder != 'Append':
#	burstsList = range (fileGlobalBurstIndex + skipBeg + 2, fileGlobalBurstIndex + len(burst_info) - skipEnd + 1)
	burstsList = range (fileGlobalBurstIndex + 2, fileGlobalBurstIndex + len(burst_info) - skipEnd - skipBeg + 1)
else:
#	burstsList = range (fileGlobalBurstIndex + skipBeg + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd + 1 )
	burstsList = range (fileGlobalBurstIndex + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd - skipBeg + 1)
if verbose:
	print 'burstsList %s' % burstsList
	print 'fileGlobalBurstIndex %s / skipBeg %s / len(burst_info) %s / skipEnd %s' % (fileGlobalBurstIndex, skipBeg, len(burst_info), skipEnd)
	print 'overlapTopFirstLine %s' % overlapTopFirstLine
#write_overlap(FileNameOverlapOut,burstsList,overlapTopFirstLine,overlapTopLastLine,overlapBotLastLine,invalidLinesTop,overlapFirstValidSample,overlapLastValidSample,fileOrder)
write_overlap(FileNameOverlapOut,burstsList,overlapTopFirstLine,overlapTopLastLine,overlapBotLastLine,overlapFirstValidSample,overlapLastValidSample,fileOrder)


# Write mean of kt for each burst
FileNameKtmeanOut = os.path.join(outdir, prefix+"_ktMean.txt")
#burstsList = range (fileGlobalBurstIndex + skipBeg + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd + 1)
burstsList = range (fileGlobalBurstIndex + 1, fileGlobalBurstIndex + len(burst_info) - skipEnd - skipBeg + 1)
write_ktmean(FileNameKtmeanOut, burstsList, ktMean,fileOrder)

# 6. Fill the metadata

# Update the medatada
#dst_md = dst_ds.GetMetadata("ROI_PAC")
dst_md = dst_ds.GetMetadata("ENVI")
dst_md["XMIN"] = "0"
dst_md["XMAX"] = str(dst_ds.RasterXSize-1)
dst_md["YMIN"] = "0"
dst_md["YMAX"] = str(dst_ds.RasterYSize-1)
dst_md["PLATFORM"] = t.find("adsHeader/missionId").text
dst_md["POLARIZATION"] = "/".join(list(t.find("adsHeader/polarisation").text))
dst_md["ORBIT_NUMBER"] = t.find("adsHeader/absoluteOrbitNumber").text
dst_md["ORBIT_DIRECTION"] = "ascending" if t.find("generalAnnotation/productInformation/pass").text == "Ascending" else "descending"
dst_md["HEADING"] = t.find("generalAnnotation/productInformation/platformHeading").text
dst_md["WAVELENGTH"] = str(C / float(t.find("generalAnnotation/productInformation/radarFrequency").text))
dst_md["PRF"] = str(1.0 / float(t.find("imageAnnotation/imageInformation/azimuthTimeInterval").text))
dst_md["DELTA_LINE_UTC"] = t.find("imageAnnotation/imageInformation/azimuthTimeInterval").text
dst_md["ANTENNA_LENGTH"] = "12.3"
dst_md["PULSE_LENGTH"] = t.find("generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/txPulseLength").text
dst_md["CHIRP_SLOPE"] = t.find("generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/txPulseRampRate").text
dst_md["STARTING_RANGE"] = str(C / 2 * float(t.find("imageAnnotation/imageInformation/slantRangeTime").text))

if fileOrder != 'Append': # first file => just write everything from the .xml
    dst_md["FIRST_LINE_YEAR"] = str(firstLineYYMMDD.year)
    dst_md["FIRST_LINE_MONTH_OF_YEAR"] = str(firstLineYYMMDD.month)
    dst_md["FIRST_LINE_DAY_OF_MONTH"] = str(firstLineYYMMDD.day)
    dst_md["FIRST_LINE_HOUR_OF_DAY"] = str(firstLineYYMMDD.hour)
    dst_md["FIRST_LINE_MN_OF_HOUR"] = str(firstLineYYMMDD.minute)
    dst_md["FIRST_LINE_S_OF_MN"] = str(firstLineYYMMDD.second)
    dst_md["FIRST_LINE_MS_OF_S"] = str(firstLineYYMMDD.microsecond / 1000)
    dst_md["FIRST_FRAME_SCENE_CENTER_TIME"] = clt.strftime("%Y%m%d%H%M%S")
    dst_md["DATE"]= clt.strftime("%Y%m%d")
    dst_md["FIRST_LINE_UTC"] = str(firstLineYYMMDD.hour*3600+firstLineYYMMDD.minute*60+firstLineYYMMDD.second+firstLineYYMMDD.microsecond/1000000.0)
    dst_md["CENTER_LINE_UTC"] = str(centerLineYYMMDD.hour*3600+centerLineYYMMDD.minute*60+centerLineYYMMDD.second+centerLineYYMMDD.microsecond/1000000.0)
    dst_md["LAST_LINE_UTC"] = str(lastLineYYMMDD.hour*3600+lastLineYYMMDD.minute*60+lastLineYYMMDD.second+lastLineYYMMDD.microsecond/1000000.0)
    if verbose:
        print "Writing timing parameters in metadata:"
        print "firstLine", dst_md["FIRST_LINE_UTC"], firstLineYYMMDD
        print "centerLine", dst_md["CENTER_LINE_UTC"], centerLineYYMMDD
        print "lastLine", dst_md["LAST_LINE_UTC"], lastLineYYMMDD
else : # not the first file => update centre / last time
    #flt = datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productFirstLineUtcTime").text,
    #                             "%Y-%m-%dT%H:%M:%S.%f")
    #llt = datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productLastLineUtcTime").text,
    #                             "%Y-%m-%dT%H:%M:%S.%f")
    #clt = flt + (llt - flt)/2
    #dst_md["FIRST_FRAME_SCENE_CENTER_TIME"] = clt.strftime("%Y%m%d%H%M%S")
    #dst_md["DATE"]= clt.strftime("%Y%m%d")
    #dst_md["CENTER_LINE_UTC"] = str(clt.hour*3600+clt.minute*60+clt.second+clt.microsecond/1000000.0)
    # Get time of first line in the SLC
    firstLineUTCGlobal = float(dst_md["FIRST_LINE_UTC"])
    #firstLineUTCGlobal = float(firstLineYYMMDD.hour*3600+firstLineYYMMDD.hour.minute*60+firstLineYYMMDD.second+firstLineYYMMDD.microsecond/1000000.0)
    lastLineUTCGlobal = float(lastLineYYMMDD.hour*3600+lastLineYYMMDD.minute*60+lastLineYYMMDD.second+lastLineYYMMDD.microsecond/1000000.0)
    centerLineUTCGlobal = ( firstLineUTCGlobal + lastLineUTCGlobal)/2
    dst_md["CENTER_LINE_UTC"] = str(centerLineUTCGlobal)

    # Convert centre time back to YYMMDD format
    centerLineYYMMDD = UTC2YYMMDD(centerLineUTCGlobal, clt)
    # update center time
    dst_md["FIRST_FRAME_SCENE_CENTER_TIME"] = centerLineYYMMDD.strftime("%Y%m%d%H%M%S")
    # update last line
    dst_md["LAST_LINE_UTC"] = str(lastLineYYMMDD.hour*3600+lastLineYYMMDD.minute*60+lastLineYYMMDD.second+lastLineYYMMDD.microsecond/1000000.0)
    if verbose:
        print "Updating timing parameters in metadata:"
        print "centerLine", dst_md["CENTER_LINE_UTC"], centerLineYYMMDD
        print "lastLine", dst_md["LAST_LINE_UTC"], lastLineYYMMDD
    

dst_md["RANGE_PIXEL_SIZE"] = t.find("imageAnnotation/imageInformation/rangePixelSpacing").text
dst_md["AZIMUTH_PIXEL_SIZE"] = t.find("imageAnnotation/imageInformation/azimuthPixelSpacing").text
dst_md["RANGE_SAMPLING_FREQUENCY"] = t.find("generalAnnotation/productInformation/rangeSamplingRate").text
dst_md["EQUATORIAL_RADIUS"] = t.find("imageAnnotation/processingInformation/ellipsoidSemiMajorAxis").text
dst_md["EARTH_RADIUS"] = t.find("imageAnnotation/processingInformation/ellipsoidSemiMinorAxis").text
dst_md["ECCENTRICITY_SQUARED"] = str(float(dst_md["EARTH_RADIUS"])/float(dst_md["EQUATORIAL_RADIUS"]))
dst_md["PLANET_GM"] = "3.98618328e+14"
dst_md["PLANET_SPINRATE"] = "7.29211573052e-05"
dst_md["RAW_DOPPLER_RANGE0"] = "0"
dst_md["DOPPLER_RANGE0"] = "0"
dst_md["DOPPLER_RANGE1"] = "0"
dst_md["DOPPLER_RANGE2"] = "0"
dst_md["DOPPLER_RANGE3"] = "0"
dst_md["ALOOKS"] = "1"
dst_md["RLOOKS"] = "1"
dst_md["HEIGHT_TOP"] = "%.9f" % height_top
dst_md["HEIGHT"] = "%.9f" % height_mid
dst_md["HEIGHT_DT"] ="%.14f" % ((height_mid-height_top)/(float(dst_md["CENTER_LINE_UTC"])-float(dst_md["FIRST_LINE_UTC"])))
dst_md["LATITUDE"] = "%.13f" % np.degrees(lat_mid)
dst_md["START_LATITUDE"] = "%.13f" % np.degrees(lat_top)
dst_md["STOP_LATITUDE"] = "%.13f" % np.degrees(lat_bot)
dst_md["START_LONGITUDE"] = "%.13f" % np.degrees(lon_top)
dst_md["LONGITUDE"] = "%.13f" % np.degrees(lon_mid)
dst_md["STOP_LONGITUDE"] = "%.13f" % np.degrees(lon_bot)
dst_md["HEADING"] = "%.13f" % np.degrees(hdg_mid)
#dst_ds.SetMetadata(dst_md, "ROI_PAC")
dst_ds.SetMetadata(dst_md, "ENVI")


# That will close the opened datasets, thus ensuring writing the info
del src_ds
del dst_ds
#if WriteIncidence:
    #del inc_ds
if verbose:
    print "processing done"




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


