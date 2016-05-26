#!/usr/bin/env python
# -*- coding: utf-8 -*-

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
###   Author        : Matthieu Volat (ISTerre)
###                   Raphael Grandin (IPGP)
####################################################
### Parser for Sentinel-1 metadata
####################################################

import collections
import datetime, getopt, glob, os, sys, math
import xml.etree.ElementTree
import numpy as np
#from matplotlib.pyplot import *

# set a few numbers    
C = 299792458.0 # Speed of light
EARTH_GM=3.98618328e+14 # Earth's mass multiplied by G
EARTH_SPINRATE=7.29211573052e-05 # Earth's spin rate

# set a few variables    
lenExtrapOrbit=200 # duration of extrapolation of orbit state vectors before and after given segment

# list of parameters that should share the same value among the different files
listOfValsToCheck=["IPFVERSION","WIDTH","XMAX", \
	"ORBIT_NUMBER","PLATFORM","POLARIZATION","ORBIT_DIRECTION", \
	"WAVELENGTH","PRF","PULSE_LENGTH","CHIRP_SLOPE","STARTING_RANGE"]	
listOfBurstValsToCheck=["linesPerBurst","samplesPerBurst","azimuthTimeInterval","azimuthSteeringRate", \
	"rangeSamplingRate","slantRangeTime","radarFrequency"]

# function to convert from ISO to seconds since midnight
def convIsoToSecond(iterable):
    result = []
    for element in iterable:
        # works with Python version >= 2.7
        # result.append((element-element.replace(hour=0, minute=0, second=0, microsecond=0)).total_seconds())
        # for Python version < 2.7
        t = element.time()
        result.append(t.hour*3600 + t.minute*60 + t.second + t.microsecond/1000000.0)
    return result

# Combine info from multiple XML files into a single element tree
def myXMLmerge(tree1, tree2):
	
	return file1

def checkFieldIsEqual(tree1, tree2, fieldName):
	fieldValue1 = tree1.find(fieldName).text
	fieldValue2 = tree2.find(fieldName).text
	if fieldValue1 != fieldValue2:
		sys.stderr.write("Warning : %s different!" % fieldName)
	
    
# # # # # # # # # # # # # # # # # #
# 0. Read arguments passed to python script
mode = None
polarization = None
opts, args = getopt.getopt(sys.argv[1:], "m:p:f")
for o, a in opts:
    # sub-swath (can be iw1, iw2 or iw3)
    if o == "-m":
        mode = a.lower()
    # polarization (can be vv, vh, hh or hv)
    elif o == "-p":
        polarization = a.lower()
    #elif o == "-f":
        #fileMode = a.lower()

# Handling of multiple files?       
#try:
	#fileMode
#except:
	#fileAppend = False
#else:
	#if fileMode is "multi":
		#fileAppend = True
	#else:
		#fileAppend = False

valsMerge = collections.OrderedDict()
burstValsMerge = collections.OrderedDict()

# # # # # # # # # # # # # # # # # #
# 1. Find the XML annotation file
# number of files provided by user
numOfFiles = len(args)
# initialize lists
safepath = []
manifestfile = []
annoxmlfiles = []
measurementPath = []
measurementTime = []
print numOfFiles
for fileNumber in range(numOfFiles):
	safepath.append(args[fileNumber])
	globpattern = os.path.join(safepath[fileNumber],"manifest.safe")
	# Manifest file
	manifestfile.append(glob.glob(os.path.join(globpattern))[0])
	# Create list of xml files corresponding to parameters given
	globpattern = os.path.join(safepath[fileNumber],
                           "annotation",
                            "*-%s-slc-%s-*.xml" % (mode or "*",
                                                   polarization or "*"))
	annoxmlfiles.append(glob.glob(os.path.join(globpattern))[0])
	basenameFile = os.path.basename(annoxmlfiles[fileNumber])
	measurementTimeTempo = basenameFile.split("-")[4]
	measurementTimeHour = np.int(measurementTimeTempo[9:11])
	measurementTimeMin = np.int(measurementTimeTempo[11:13])
	measurementTimeSec = np.int(measurementTimeTempo[13:15])
	measurementTime.append( measurementTimeHour*3600 + measurementTimeMin*60 + measurementTimeSec )
	measurementPath.append(os.path.join(safepath[fileNumber],"measurement","%s.tiff" % os.path.splitext(basenameFile)[0] ))
	sys.stderr.write("Using measurement file : %s\n" % os.path.basename(measurementPath[fileNumber]))

# Reorder files according to increasing acquisition time
listOrderFiles = np.argsort(measurementTime)

# Initialize orbital info
orbTime = []
orbPosX = []
orbPosY = []
orbPosZ = []
orbVelX = []
orbVelY = []
orbVelZ = []
orbTimeSeconds = []

# Initialize Doppler info
dcAzimuthTime = []
dcT0 = []
dataDcPolynomialOrder0 = []
dataDcPolynomialOrder1 = []
dataDcPolynomialOrder2 = []
dataDcPolynomialOrder3 = []
dataDcPolynomialOrder4 = []
geometryDcPolynomialOrder0 = []
geometryDcPolynomialOrder1 = []
geometryDcPolynomialOrder2 = []
geometryDcPolynomialOrder3 = []
geometryDcPolynomialOrder4 = []
dcAzimuthTimeSeconds = []

# Initialize azimuth FM rate info
azFMRateTime = []
azFMRatet0 = []
azFMRatec0 = []
azFMRatec1 = []
azFMRatec2 = []
azFMRateTimeSeconds = []

# Initialize burst info
burstAzimuthTime = []
burstAzimuthAnxTime = []
burstByteOffset = []
burstFirstValidSample = []
burstLastValidSample = []
burstAzimuthTimeSeconds = []

# Initialize antenna pattern info
antennaPatternAzimuthTime = []
antennaPatternSlantRangeTime = []
antennaPatternIncidenceAngle = []
antennaPatternTimeSeconds = []


# Loop over files
for fileNumber in listOrderFiles:
	
	vals = collections.OrderedDict()
	burstVals = collections.OrderedDict()

	# Read IPF version in manifest (grep)
	for line in open(manifestfile[fileNumber]):
		if "software name=\"Sentinel-1 IPF\" version=" in line:
			vals["IPFVERSION"] = float(line.split("\"")[-2])
			#print "IPF version = %.2f" % vals["IPFVERSION"]
			break

	# # # # # # # # # # # # # # # # # #
	# 2. Open & parse
	t = xml.etree.ElementTree.ElementTree()
	print "Parsing", annoxmlfiles[fileNumber]
	t.parse(annoxmlfiles[fileNumber])
	
	
	# # # # # # # # # # # # # # # # # #
	# 3. Extract the wanted values from xml
	vals["WIDTH"] = t.find("swathTiming/samplesPerBurst").text
	vals["XMIN"] = "0"
	vals["XMAX"] = t.find("swathTiming/samplesPerBurst").text
	vals["ORBIT_NUMBER"] = t.find("adsHeader/absoluteOrbitNumber").text
	vals["PLATFORM"] = t.find("adsHeader/missionId").text
	vals["POLARIZATION"] = "/".join(list(t.find("adsHeader/polarisation").text))
	vals["ORBIT_DIRECTION"] = "ascending" if t.find("generalAnnotation/productInformation/pass").text == "Ascending" else "descending"
	vals["HEADING"] = float(t.find("generalAnnotation/productInformation/platformHeading").text)
	#vals["radarFrequency"] = t.find("generalAnnotation/productInformation/radarFrequency").text
	vals["WAVELENGTH"] = C / float(t.find("generalAnnotation/productInformation/radarFrequency").text)


	# # The PRF provided in the XML does not yield the actual azimuth pixel size according to ROI_PAC's formula
	# vals["PRF"] = 1.0 / float(t.find("generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/pri").text)

	# PRF fix : we cheat by altering the PRF value so that ROI_PAC finds the right azimuth pixel size
	vals["PRF"] = 1.0 / float(t.find("imageAnnotation/imageInformation/azimuthTimeInterval").text)

	vals["PULSE_LENGTH"] = float(t.find("generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/txPulseLength").text)
	vals["CHIRP_SLOPE"] = float(t.find("generalAnnotation/downlinkInformationList/downlinkInformation/downlinkValues/txPulseRampRate").text)
	vals["STARTING_RANGE"] = C / 2 * float(t.find("imageAnnotation/imageInformation/slantRangeTime").text)

	firstLineTime=(datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productFirstLineUtcTime").text, "%Y-%m-%dT%H:%M:%S.%f" ))
	vals["FIRST_LINE_YEAR"] = firstLineTime.year
	vals["FIRST_LINE_MONTH_OF_YEAR"] = firstLineTime.month
	vals["FIRST_LINE_DAY_OF_MONTH"] = firstLineTime.day
	vals["FIRST_LINE_HOUR_OF_DAY"] = firstLineTime.hour
	vals["FIRST_LINE_MN_OF_HOUR"] = firstLineTime.minute
	vals["FIRST_LINE_S_OF_MN"] = firstLineTime.second
	vals["FIRST_LINE_MS_OF_S"] = firstLineTime.microsecond / 1000
	
	lastLineTime=(datetime.datetime.strptime(t.find("imageAnnotation/imageInformation/productLastLineUtcTime").text, "%Y-%m-%dT%H:%M:%S.%f" ))

	vals["FIRST_LINE_STRING"] = firstLineTime
	vals["LAST_LINE_STRING"] = lastLineTime
	vals["FIRST_LINE_UTC"] = convIsoToSecond([firstLineTime])[0]
	vals["LAST_LINE_UTC"] = convIsoToSecond([lastLineTime])[0]

	vals["RANGE_PIXEL_SIZE"] = float(t.find("imageAnnotation/imageInformation/rangePixelSpacing").text)
	vals["AZIMUTH_PIXEL_SIZE"] = float(t.find("imageAnnotation/imageInformation/azimuthPixelSpacing").text)

	vals["RANGE_SAMPLING_FREQUENCY"] = float(t.find("generalAnnotation/productInformation/rangeSamplingRate").text)

	vals["EQUATORIAL_RADIUS"] = float(t.find("imageAnnotation/processingInformation/ellipsoidSemiMajorAxis").text)
	vals["EARTH_RADIUS"] = float(t.find("imageAnnotation/processingInformation/ellipsoidSemiMinorAxis").text)
	vals["ECCENTRICITY_SQUARED"] = 1.0 - float(vals["EARTH_RADIUS"])/float(vals["EQUATORIAL_RADIUS"])

	vals["PLANET_GM"] = EARTH_GM
	vals["PLANET_SPINRATE"] = EARTH_SPINRATE

	# The SLCs are processed to Zero Doppler
	vals["DOPPLER_RANGE0"]=0
	vals["DOPPLER_RANGE1"]=0
	vals["DOPPLER_RANGE2"]=0
	vals["DOPPLER_RANGE3"]=0


	# # # # # # # # # # # # # # # # # #
	# 4. Read orbit information
	orbit_list = t.find("generalAnnotation/orbitList")
	for orbit in t.findall("generalAnnotation/orbitList/orbit"):
		orbTime.append(datetime.datetime.strptime(orbit.find('time').text, "%Y-%m-%dT%H:%M:%S.%f" ))
		orbPosX.append(float(orbit.find('position/x').text))
		orbPosY.append(float(orbit.find('position/y').text))
		orbPosZ.append(float(orbit.find('position/z').text))
		orbVelX.append(float(orbit.find('velocity/x').text))
		orbVelY.append(float(orbit.find('velocity/y').text))
		orbVelZ.append(float(orbit.find('velocity/z').text))
	
	
	# # # # # # # # # # # # # # # # # #
	# 5. Read doppler centroid polynomials
	dcEstimate_list = t.find("dopplerCentroid/dcEstimateList")
	for dcEstimate in t.findall("dopplerCentroid/dcEstimateList/dcEstimate"):
	    dcAzimuthTime.append(datetime.datetime.strptime(dcEstimate.find('azimuthTime').text, "%Y-%m-%dT%H:%M:%S.%f" ))
	    dcT0.append(float(dcEstimate.find('t0').text))
	    # data
	    myDataDcPolynomial=dcEstimate.find('dataDcPolynomial').text
	    myDataDcPolynomial = myDataDcPolynomial.split()
	    dataDcPolynomialOrder0.append(float(myDataDcPolynomial[0]))
	    dataDcPolynomialOrder1.append(float(myDataDcPolynomial[1]))
	    dataDcPolynomialOrder2.append(float(myDataDcPolynomial[2]))
	    dataDcPolynomialOrder3.append(float(0))
	    dataDcPolynomialOrder4.append(float(0))
	    # geometry
	    myGeometryDcPolynomial=dcEstimate.find('geometryDcPolynomial').text
	    myGeometryDcPolynomial = myGeometryDcPolynomial.split()
	    geometryDcPolynomialOrder0.append(float(myGeometryDcPolynomial[0]))
	    geometryDcPolynomialOrder1.append(float(myGeometryDcPolynomial[1]))
	    geometryDcPolynomialOrder2.append(float(myGeometryDcPolynomial[2]))
	    geometryDcPolynomialOrder3.append(float(0))
	    geometryDcPolynomialOrder4.append(float(0))
	# print dcAzimuthTime[0],dcAzimuthTimeSeconds[0]
	# print dataDcPolynomialOrder0
	

	# # # # # # # # # # # # # # # # # #
	# 6. Read azimuth FM rate polynomial
	for azFMRate in t.findall("generalAnnotation/azimuthFmRateList/azimuthFmRate"):	
	    azFMRateTime.append(datetime.datetime.strptime(azFMRate.find('azimuthTime').text, "%Y-%m-%dT%H:%M:%S.%f" ))
	    azFMRatet0.append(float(azFMRate.find('t0').text))
		# Decoding depends on IPF version
	    if(float(vals["IPFVERSION"]) >= 2.43):
			### <safe:software name="Sentinel-1 IPF" version="002.43"/>
			azFMRatePoly= (azFMRate.find('azimuthFmRatePolynomial').text).split()
			azFMRatec0.append(float(azFMRatePoly[0]))
			azFMRatec1.append(float(azFMRatePoly[1]))
			azFMRatec2.append(float(azFMRatePoly[2]))
	    else:
			### <safe:software name="Sentinel-1 IPF" version="002.36"/>
			azFMRatec0.append(float(azFMRate.find('c0').text))
			azFMRatec1.append(float(azFMRate.find('c1').text))
			azFMRatec2.append(float(azFMRate.find('c2').text))
	# print azFMRateTime[0],azFMRateTimeSeconds[0]
	# print azFMRateTime
	# print azFMRatet0
	# print azFMRatec0
	

	# # # # # # # # # # # # # # # # # #
	# 7. Read burst time
	for burst in t.findall("swathTiming/burstList/burst"):
	    burstAzimuthTime.append(datetime.datetime.strptime(burst.find('azimuthTime').text, "%Y-%m-%dT%H:%M:%S.%f" ))
	    burstAzimuthAnxTime.append(float(burst.find('azimuthAnxTime').text))
	    burstByteOffset.append(burst.find('byteOffset').text)
	    burstFirstValidSample.append((burst.find('firstValidSample').text).split())
	    burstLastValidSample.append((burst.find('lastValidSample').text).split())
	# print burstFirstValidSample
	# print len(burstFirstValidSample[1])
	# print burstAzimuthTime
	# print burstByteOffset
	
	
	# # # # # # # # # # # # # # # # # #
	# 8. Read incidence angles
	for antennaPattern in t.findall("antennaPattern/antennaPatternList/antennaPattern"):
	    antennaPatternAzimuthTime.append(datetime.datetime.strptime(antennaPattern.find('azimuthTime').text, "%Y-%m-%dT%H:%M:%S.%f" ))
	    antennaPatternSlantRangeTime.append((antennaPattern.find('slantRangeTime').text).split())
	    antennaPatternIncidenceAngle.append((antennaPattern.find('incidenceAngle').text).split())
	#print antennaPatternSlantRangeTime
	#print len(antennaPatternSlantRangeTime[1])
	#print len(antennaPatternSlantRangeTime)
	# print burstAzimuthTime
	# print burstByteOffset
	

	# # # # # # # # # # # # # # # # # #
	# 9. Read remaining information
	
	burstVals["linesPerBurst"] = t.find("swathTiming/linesPerBurst").text
	burstVals["samplesPerBurst"] = t.find("swathTiming/samplesPerBurst").text
	burstVals["azimuthTimeInterval"] = float(t.find("imageAnnotation/imageInformation/azimuthTimeInterval").text)
	burstVals["azimuthSteeringRate"] = float(t.find("generalAnnotation/productInformation/azimuthSteeringRate").text)
	burstVals["rangeSamplingRate"] = float(t.find("generalAnnotation/productInformation/rangeSamplingRate").text)
	burstVals["slantRangeTime"] = float(t.find("imageAnnotation/imageInformation/slantRangeTime").text)
	burstVals["radarFrequency"] = float(t.find("generalAnnotation/productInformation/radarFrequency").text)
	#burstVals["zeroDopMinusAcqTime"] = float(t.find("imageAnnotation/imageInformation/zeroDopMinusAcqTime").text)

	
	# # # # # # # # # # # # # # # # # #
	# Initialize / update / check metadata 
	
	if fileNumber == 0:
		valsMerge = vals
		burstValsMerge = burstVals
		
	else:
		# Update last line time
		valsMerge["LAST_LINE_UTC"] = vals["LAST_LINE_UTC"]
		valsMerge["LAST_LINE_STRING"] = vals["LAST_LINE_STRING"]
		
		# Check consistency
		for parameter in listOfValsToCheck:
			if valsMerge[parameter] != vals[parameter]:
				sys.stderr.write("Warning : parameter %s not identical in the files!\n" % (parameter))
				sys.stderr.write("Conflicting values : %s / %s\n" % (valsMerge[parameter], vals[parameter]))
				
		for parameter in listOfBurstValsToCheck:
			if burstValsMerge[parameter] != burstVals[parameter]:
				sys.stderr.write("Warning : parameter %s not identical in the files!\n" % (parameter))
				sys.stderr.write("Conflicting values : %s / %s\n" % (burstValsMerge[parameter], burstVals[parameter]))

# # # # # # # # # # # # # # # # # #
# Convert times

orbTimeSeconds=convIsoToSecond(orbTime)
dcAzimuthTimeSeconds=convIsoToSecond(dcAzimuthTime)
azFMRateTimeSeconds=convIsoToSecond(azFMRateTime)
burstAzimuthTimeSeconds=convIsoToSecond(burstAzimuthTime)
antennaPatternTimeSeconds=convIsoToSecond(antennaPatternAzimuthTime)

# # # # # # # # # # # # # # # # # #
# Compute centre time

firstLineTime = valsMerge["FIRST_LINE_STRING"]
lastLineTime = valsMerge["LAST_LINE_STRING"]
centerLineTime=firstLineTime+(lastLineTime - firstLineTime)/2
valsMerge["CENTER_LINE_UTC"] = convIsoToSecond([centerLineTime])[0]
valsMerge["FIRST_FRAME_SCENE_CENTER_TIME"] = centerLineTime.strftime("%Y%m%d%H%M%S")
valsMerge["DATE"] = centerLineTime.strftime("%Y%m%d")


# # # # # # # # # # # # # # # # # # # # # # #
# Interpolate / extrapolate state vectors
# # # # # # # # # # # # # # # # # # # # # # # 

# calculate scalar velocity in the middle of the orbit

#we need to sort orbit state vectors first
orbVelX = [x for (y,x) in sorted(zip(orbTime,orbVelX))]
orbVelY = [x for (y,x) in sorted(zip(orbTime,orbVelY))]
orbVelZ = [x for (y,x) in sorted(zip(orbTime,orbVelZ))]
orbTimeSeconds = [x for (y,x) in sorted(zip(orbTime,orbTimeSeconds))]
orbTime = sorted(orbTime)

# extract velocity middle index
indexOrbMiddle=int(round(len(orbTime)/2))
orbVelocity=math.sqrt(math.pow(orbVelX[indexOrbMiddle],2)+math.pow(orbVelY[indexOrbMiddle],2)+math.pow(orbVelZ[indexOrbMiddle],2))
valsMerge["VELOCITY"] = orbVelocity

# # extrapolate orbits using third degree polynomial
# positions
orbPosXExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbPosX, deg=3))
orbPosYExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbPosY, deg=3))
orbPosZExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbPosZ, deg=3))
# velocities
orbVelXExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbVelX, deg=3))
orbVelYExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbVelY, deg=3))
orbVelZExtrapPoly = np.poly1d(np.polyfit(orbTimeSeconds, orbVelZ, deg=3))

# # sample extrapolated orbit at appropriate rate
# # build list of dates before first line
orbTimeSecondsBef=np.linspace(orbTimeSeconds[0]-lenExtrapOrbit,orbTimeSeconds[0],num=lenExtrapOrbit,endpoint=False)
# # build list of dates between first line and last line
orbTimeSecondsAll=np.linspace(orbTimeSeconds[0]-lenExtrapOrbit,orbTimeSeconds[len(orbTimeSeconds)-1]+lenExtrapOrbit,
	num=int(orbTimeSeconds[len(orbTimeSeconds)-1]-orbTimeSeconds[0]+(lenExtrapOrbit*2)),
	endpoint=False)
# # build list of dates after last line
orbTimeSecondsAft=np.linspace(orbTimeSeconds[len(orbTimeSeconds)-1]+1,orbTimeSeconds[len(orbTimeSeconds)-1]+lenExtrapOrbit,num=lenExtrapOrbit)

# # do the sampling
# positions
orbPosXExtrapValBef=np.polyval(orbPosXExtrapPoly,orbTimeSecondsBef)
orbPosYExtrapValBef=np.polyval(orbPosYExtrapPoly,orbTimeSecondsBef)
orbPosZExtrapValBef=np.polyval(orbPosZExtrapPoly,orbTimeSecondsBef)

orbPosXExtrapValAll=np.polyval(orbPosXExtrapPoly,orbTimeSecondsAll)
orbPosYExtrapValAll=np.polyval(orbPosYExtrapPoly,orbTimeSecondsAll)
orbPosZExtrapValAll=np.polyval(orbPosZExtrapPoly,orbTimeSecondsAll)

orbPosXExtrapValAft=np.polyval(orbPosXExtrapPoly,orbTimeSecondsAft)
orbPosYExtrapValAft=np.polyval(orbPosYExtrapPoly,orbTimeSecondsAft)
orbPosZExtrapValAft=np.polyval(orbPosZExtrapPoly,orbTimeSecondsAft)
# velocities
orbVelXExtrapValBef=np.polyval(orbVelXExtrapPoly,orbTimeSecondsBef)
orbVelYExtrapValBef=np.polyval(orbVelYExtrapPoly,orbTimeSecondsBef)
orbVelZExtrapValBef=np.polyval(orbVelZExtrapPoly,orbTimeSecondsBef)

orbVelXExtrapValAll=np.polyval(orbVelXExtrapPoly,orbTimeSecondsAll)
orbVelYExtrapValAll=np.polyval(orbVelYExtrapPoly,orbTimeSecondsAll)
orbVelZExtrapValAll=np.polyval(orbVelZExtrapPoly,orbTimeSecondsAll)

orbVelXExtrapValAft=np.polyval(orbVelXExtrapPoly,orbTimeSecondsAft)
orbVelYExtrapValAft=np.polyval(orbVelYExtrapPoly,orbTimeSecondsAft)
orbVelZExtrapValAft=np.polyval(orbVelZExtrapPoly,orbTimeSecondsAft)

orbVelocity=[]
orbTimeSecondsConcat=[]
orbPosXConcat=[]
orbPosYConcat=[]
orbPosZConcat=[]
orbVelXConcat=[]
orbVelYConcat=[]
orbVelZConcat=[]

# # Concatenate the orbits into a single list of state vectors
# # 1 : State vectors before first line (extrapolated)
# # 2 : State vectors during acquisition (given by the .xml file)
# # 3 : State vectors after last line (extrapolated)

###print "Before :"
#lenOrbBef=len(orbTimeSecondsBef)
#for stateVecNum in range(0,lenOrbBef):
#    velocCurrent=math.sqrt(math.pow(orbVelXExtrapValBef[stateVecNum],2)+math.pow(orbVelYExtrapValBef[stateVecNum],2)+math.pow(orbVelZExtrapValBef[stateVecNum],2))
#    orbVelocity.append(float(velocCurrent))
#    orbTimeSecondsConcat.append(float(orbTimeSecondsBef[stateVecNum]))
#    orbPosXConcat.append(float(orbPosXExtrapValBef[stateVecNum]))
#    orbPosYConcat.append(float(orbPosYExtrapValBef[stateVecNum]))
#    orbPosZConcat.append(float(orbPosZExtrapValBef[stateVecNum]))
#    orbVelXConcat.append(float(orbVelXExtrapValBef[stateVecNum]))
#    orbVelYConcat.append(float(orbVelYExtrapValBef[stateVecNum]))
#    orbVelZConcat.append(float(orbVelZExtrapValBef[stateVecNum]))
#    # print orbTimeSecondsBef[stateVecNum],orbPosXExtrapValBef[stateVecNum],orbPosYExtrapValBef[stateVecNum],orbPosZExtrapValBef[stateVecNum],orbVelXExtrapValBef[stateVecNum],orbVelYExtrapValBef[stateVecNum],orbVelZExtrapValBef[stateVecNum],velocCurrent
#
###print "Given :"
#lenOrbGiven=len(orbTimeSeconds)
#for stateVecNum in range(0,lenOrbGiven):
#    velocCurrent=math.sqrt(math.pow(orbVelX[stateVecNum],2)+math.pow(orbVelY[stateVecNum],2)+math.pow(orbVelZ[stateVecNum],2))
#    orbVelocity.append(float(velocCurrent))
#    orbTimeSecondsConcat.append(float(orbTimeSeconds[stateVecNum]))
#    orbPosXConcat.append(float(orbPosX[stateVecNum]))
#    orbPosYConcat.append(float(orbPosY[stateVecNum]))
#    orbPosZConcat.append(float(orbPosZ[stateVecNum]))
#    orbVelXConcat.append(float(orbVelX[stateVecNum]))
#    orbVelYConcat.append(float(orbVelY[stateVecNum]))
#    orbVelZConcat.append(float(orbVelZ[stateVecNum]))
#    # print orbTimeSeconds[stateVecNum],orbPosX[stateVecNum],orbPosY[stateVecNum],orbPosZ[stateVecNum],orbVelX[stateVecNum],orbVelY[stateVecNum],orbVelZ[stateVecNum],velocCurrent
#
###print "After :"
#lenOrbAft=len(orbTimeSecondsAft)
#for stateVecNum in range(0,lenOrbAft):
#    velocCurrent=math.sqrt(math.pow(orbVelXExtrapValAft[stateVecNum],2)+math.pow(orbVelYExtrapValAft[stateVecNum],2)+math.pow(orbVelZExtrapValAft[stateVecNum],2))
#    orbVelocity.append(float(velocCurrent))
#    orbTimeSecondsConcat.append(float(orbTimeSecondsAft[stateVecNum]))
#    orbPosXConcat.append(float(orbPosXExtrapValAft[stateVecNum]))
#    orbPosYConcat.append(float(orbPosYExtrapValAft[stateVecNum]))
#    orbPosZConcat.append(float(orbPosZExtrapValAft[stateVecNum]))
#    orbVelXConcat.append(float(orbVelXExtrapValAft[stateVecNum]))
#    orbVelYConcat.append(float(orbVelYExtrapValAft[stateVecNum]))
#    orbVelZConcat.append(float(orbVelZExtrapValAft[stateVecNum]))
#    # print orbTimeSecondsAft[stateVecNum],orbPosXExtrapValAft[stateVecNum],orbPosYExtrapValAft[stateVecNum],orbPosZExtrapValAft[stateVecNum],orbVelXExtrapValAft[stateVecNum],orbVelYExtrapValAft[stateVecNum],orbVelZExtrapValAft[stateVecNum],velocCurrent
#

# full arc
lenOrbAll=len(orbTimeSecondsAll)
for stateVecNum in range(0,lenOrbAll):
    velocCurrent=math.sqrt(math.pow(orbVelXExtrapValAll[stateVecNum],2)+math.pow(orbVelYExtrapValAll[stateVecNum],2)+math.pow(orbVelZExtrapValAll[stateVecNum],2))
    orbVelocity.append(float(velocCurrent))
    orbTimeSecondsConcat.append(float(orbTimeSecondsAll[stateVecNum]))
    orbPosXConcat.append(float(orbPosXExtrapValAll[stateVecNum]))
    orbPosYConcat.append(float(orbPosYExtrapValAll[stateVecNum]))
    orbPosZConcat.append(float(orbPosZExtrapValAll[stateVecNum]))
    orbVelXConcat.append(float(orbVelXExtrapValAll[stateVecNum]))
    orbVelYConcat.append(float(orbVelYExtrapValAll[stateVecNum]))
    orbVelZConcat.append(float(orbVelZExtrapValAll[stateVecNum]))
    # print orbTimeSecondsAft[stateVecNum],orbPosXExtrapValAft[stateVecNum],orbPosYExtrapValAft[stateVecNum],orbPosZExtrapValAft[stateVecNum],orbVelXExtrapValAft[stateVecNum],orbVelYExtrapValAft[stateVecNum],orbVelZExtrapValAft[stateVecNum],velocCurrent

# print orbTime[0],orbTimeSeconds[0]
# print orbTime
# print orbPosX
# print orbVelY


# # # # # # # # # #
# Incidence angle
# # # # # # # # # #

# store time and incidence into 1D vectors
slantRange=(np.array(antennaPatternSlantRangeTime,np.float))
slantRange=slantRange.ravel()
incidenceAngle=(np.array(antennaPatternIncidenceAngle,np.float))
incidenceAngle=incidenceAngle.ravel()

# near range
slantRangeMin=min(slantRange)
#print slantRangeMin

# fit 2nd order polynomial
#print slantRange-slantRangeMin,incidenceAngle
poly_incidence = np.polyfit(slantRange-slantRangeMin,incidenceAngle, 2)
#print poly_incidence[0],poly_incidence[1],poly_incidence[2]

## Output incidence (for tests)
#f = open('TestIncidence.txt', 'w')
#for lineNumber in range(0,len(slantRange)):
#        f.write("%e %f\n" % (slantRange[lineNumber]-slantRangeMin,incidenceAngle[lineNumber]))
#f.close()




# # # # # # # # # # # # # # # # #
# # PREPARE OUTPUT FILE NAMES # #
# # # # # # # # # # # # # # # # #

prefix = str(valsMerge["DATE"]) + '_' + mode + '_' + polarization
svFile = 'hdr_data_points_' + prefix + '.rsc'
slcoutFilename = prefix + '.slc'
rscoutFileName = prefix + '.raw' + '.rsc'
dcDataFile = prefix + '_dopCentDataPolynom' + '.txt'
dcGeomFile = prefix + '_dopCentGeomPolynom' + '.txt'
azFMFile = prefix + '_azFM' + '.txt'
burstFile = prefix + '_burst' + '.txt'
validFile = prefix + '_valid' + '.txt'
incidenceFile = prefix + '_incidence' + '.txt'
paramFile = prefix + '_param' + '.rsc'
 
burstVals["ROOTNAME"] = prefix
burstVals["INDIR"] = os.path.join(os.getcwd(),safepath[0],"measurement")
burstVals["INFILETIF"] =  os.path.basename(measurementPath[0])
burstVals["OUTDIR"] = os.getcwd()
burstVals["OUTFILESLC"] = slcoutFilename
burstVals["SETLAGTOZERO"] = 'yes'

print str('Date : ') + str(valsMerge["DATE"])
print str('Mode : ') + mode
print str('Pola : ') + polarization
print str('First line : ') + str(firstLineTime)
print str('Last line  : ') + str(lastLineTime)


# # # # # # # # # # # # # # # # # #
# 10. Save state vectors to file
lenOrbit=len(orbTimeSecondsConcat)
print str('Number of State Vectors : ') + str(lenOrbit)
f = open(svFile, 'w')
for orbitNumber in range(0,lenOrbit):
    f.write("%-14.6f %-14.6f %-14.6f %-14.6f %-14.6f %-14.6f %-14.6f\n" % (float(orbTimeSecondsConcat[orbitNumber]), float(orbPosXConcat[orbitNumber]), float(orbPosYConcat[orbitNumber]), float(orbPosZConcat[orbitNumber]), float(orbVelXConcat[orbitNumber]), float(orbVelYConcat[orbitNumber]), float(orbVelZConcat[orbitNumber])))
f.close()


# # # # # # # # # # # # # # # # # #
# 11. Save RSC file
f = open(rscoutFileName, 'w')
for k, v in valsMerge.items():
    # print("%-40s %-30s" % (k, v))
    f.write("%-40s %-30s\n" % (k, v))
f.close()


# # # # # # # # # # # # # # # # # #
# 12. Save Doppler Centroid info to file
lenDC=len(dcAzimuthTime)
print str('Number of Doppler Centroid Polynomials : ') + str(lenDC)
f = open(dcDataFile, 'w')
for dcNumber in range(0,lenDC):
    f.write("%-15s %-15s %-15s %-15s %-15s %-15s %-15s\n" % (dcAzimuthTimeSeconds[dcNumber], dcT0[dcNumber],  dataDcPolynomialOrder0[dcNumber],  dataDcPolynomialOrder1[dcNumber],  dataDcPolynomialOrder2[dcNumber],  dataDcPolynomialOrder3[dcNumber],  dataDcPolynomialOrder4[dcNumber] ))
f.close()
f = open(dcGeomFile, 'w')
for dcNumber in range(0,lenDC):
    f.write("%-15s %-15s %-15s %-15s %-15s %-15s %-15s\n" % (dcAzimuthTimeSeconds[dcNumber], dcT0[dcNumber],  geometryDcPolynomialOrder0[dcNumber],  geometryDcPolynomialOrder1[dcNumber],  geometryDcPolynomialOrder2[dcNumber],  geometryDcPolynomialOrder3[dcNumber],  geometryDcPolynomialOrder4[dcNumber] ))
f.close()


# # # # # # # # # # # # # # # # # #
# 13. Save Azimuth FM rate info to file
lenAzFM=len(azFMRateTime)
print str('Number of Azimuth FM Rate estimations : ') + str(lenAzFM)
f = open(azFMFile, 'w')
for azFMNumber in range(0,lenAzFM):
    f.write("%-15s %-15s %-15s %-15s %-15s\n" % (azFMRateTimeSeconds[azFMNumber], azFMRatet0[azFMNumber], azFMRatec0[azFMNumber], azFMRatec1[azFMNumber], azFMRatec2[azFMNumber]))
f.close()


# # # # # # # # # # # # # # # # # #
# 14. Save general burst information
lenBurst=len(burstAzimuthTime)
print str('Number of bursts : ') + str(lenBurst)
f = open(burstFile, 'w')
for BurstNumber in range(0,lenBurst):
    f.write("%-15s %-15s %-15s\n" % (burstAzimuthTimeSeconds[BurstNumber], burstAzimuthAnxTime[BurstNumber], burstByteOffset[BurstNumber] ))
f.close()


# # # # # # # # # # # # # # # # # #
# 15. Save burst first / last valid sample
f = open(validFile, 'w')
for BurstNumber in range(0,lenBurst):
	for LineNumber in range(0,int(burstVals["linesPerBurst"])):
		f.write("%-6d" % int(burstFirstValidSample[BurstNumber][LineNumber]))
	f.write("\n")
	for LineNumber in range(0,int(burstVals["linesPerBurst"])):
		f.write("%-6d" % int(burstLastValidSample[BurstNumber][LineNumber]))
	f.write("\n")
f.close()


# # # # # # # # # # # # # # # # # #
# 16. Save parameters information
f = open(paramFile, 'w')
for k, v in burstVals.items():
    # print("%-40s %-30s" % (k, v))
    f.write("%-40s %-30s\n" % (k, v))
f.close()



# # # # # # # # # # # # # # # # # #
# 17. Save incidence angle polynomial
f = open(incidenceFile, 'w')
f.write("%e %e %e %e\n" % (slantRangeMin,poly_incidence[2],poly_incidence[1],poly_incidence[0]))
f.close()




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

