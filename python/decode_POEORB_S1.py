#!/usr/bin/env python
# -*- coding: utf-8 -*-
####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
###   Author        : Raphael Grandin (IPGP)
####################################################
#
# Decode Sentinel-1 precise orbits
# and write them to hdr-XXX file
#
############################################################################


import datetime, getopt, glob, os, sys, xml.etree.ElementTree

import numpy as np

def open_orbitxml(orbitpath):
    g = glob.glob(os.path.join(orbitpath))
    if g == None:
        return None
    if len(g) != 1:
        return None
    doc = xml.etree.ElementTree.ElementTree()
    doc.parse(g[0])
    return doc

def read_time_range(doc):
    orbitInfo = doc.findall("Earth_Explorer_Header/Fixed_Header/Validity_Period")
    tminFile = datetime.datetime.strptime(orbitInfo[0].find("Validity_Start").text[4:],
        "%Y-%m-%dT%H:%M:%S")
    tmaxFile = datetime.datetime.strptime(orbitInfo[0].find("Validity_Stop").text[4:],
        "%Y-%m-%dT%H:%M:%S")
    return [tminFile, tmaxFile]

def read_orbit(doc):
    orbitList = doc.findall("Data_Block/List_of_OSVs/OSV")
    timeUTClist = []
    stateVectorList = np.ndarray((len(orbitList), 6))
    for i in range(len(orbitList)):
        stateVector = orbitList[i]
        timeUTC = datetime.datetime.strptime(stateVector.find("UTC").text[4:],
            "%Y-%m-%dT%H:%M:%S.%f")
        posX = float(stateVector.find("X").text)
        posY = float(stateVector.find("Y").text)
        posZ = float(stateVector.find("Z").text)
        velX = float(stateVector.find("VX").text)
        velY = float(stateVector.find("VY").text)
        velZ = float(stateVector.find("VZ").text)
        stateVectorList[i,:] = [posX, posY, posZ, velX, velY, velZ]
        timeUTClist.append(timeUTC)
    return [timeUTClist, stateVectorList]

# 0. Read arguments passed to python script
extension_orbit_seconds = 30 # extend orbit extraction by 30 seconds before tmin and after tmax
verbose = False
opts, argv = getopt.getopt(sys.argv[1:], "", ["tmin=", "tmax=", "outdir=", "verbose", "help"])
for o, a in opts:
    if   o == "--tmin":
        tmin = datetime.datetime.strptime(a,"%Y-%m-%dT%H:%M:%S") - datetime.timedelta(seconds=extension_orbit_seconds)
    elif   o == "--tmax":
        tmax = datetime.datetime.strptime(a,"%Y-%m-%dT%H:%M:%S") + datetime.timedelta(seconds=extension_orbit_seconds)
    elif o == "--verbose":
        verbose = True
    elif o == "--outdir":
	outdir = a
    elif o == "--help":
        print("%s [--verbose] [--tmin <tmin>] [--tmax <tmax>] [--outdir <outdir>] <ORBIT_FILE>" % (os.path.basename(sys.argv[0])))
        print("  time format should be : \"%Y-%m-%dT%H:%M:%S\" (e.g. 2015-09-17T22:04:22)")
        exit(0)
    else:
        pass
if len(argv) != 1:
    raise Exception("Wrong number of arguments")

try:
    outdir
except:
    outdir = os.getcwd()

# 1. Open the orbit file
orbitpath = argv[0]
prefix = os.path.basename(orbitpath)
if verbose:
    print "reading orbit file %s" % prefix
t = open_orbitxml(orbitpath)
if not t:
    raise Exception("Cannot open XML orbit file")

# 2. check nothing is wrong with the times
[tminFile,tmaxFile] =read_time_range(t)
if tmin < tminFile:
    raise Exception("Requested start time is before first orbit info!")
if tmax > tmaxFile:
    raise Exception("Requested stop time is after first orbit info!")
if tmin >= tmax:
    raise Exception("Requested stop time is before requested stop time!")
if verbose:
    print 'found orbits between '+str(tminFile)+' and '+str(tmaxFile)
    print 'processing orbits between '+str(tmin)+' and '+str(tmax)
dateString = tmin.strftime('%Y%m%d')

# 3. Read orbit data 
[timeUTClist, orbitData] = read_orbit(t)

# 4. Trim orbit data over the time range provided by user
orbitDataTrim = []
timeUTClistTrim = []
for i in range(len(orbitData)):
    if timeUTClist[i] >= tmin and timeUTClist[i] <= tmax:
        timeUTClistTrim.append(timeUTClist[i])
        orbitDataTrim.append(orbitData[i,:])
timelistTrim = np.ndarray((len(timeUTClistTrim),1))
orbitlistTrim = np.ndarray((len(timeUTClistTrim),6))
for i in range(len(timeUTClistTrim)):
    timelistTrim[i] = float(timeUTClistTrim[i].hour*3600+timeUTClistTrim[i].minute*60+timeUTClistTrim[i].second+timeUTClistTrim[i].microsecond/1000000.0)

# 5. Write orbit data
svectors = np.concatenate((timelistTrim, np.array(orbitDataTrim)),axis=1)
np.savetxt(os.path.join(outdir, "hdr_data_points_"+dateString+".rsc"),
           svectors, "%-15s")
if verbose:
    print 'written',len(svectors),'state vectors'





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

