#!/usr/bin/python

####################################################
###   Sentinel-1 pre-processor for ROI_PAC
###   Raphael Grandin (IPGP) -- V2.4 -- Feb. 2016
###   grandin@ipgp.fr
###   Author        : Raphael Grandin (IPGP)
####################################################
### Spectral diversity for Sentinel-1
### Computes the time lag using cross-interferogram
####################################################

# # Imports
import sys,os
import array
import numpy
import matplotlib.pyplot as plt
import cmath as cm
import mpmath
from colorsys import hls_to_rgb

# # # # # # # # # # # # # #
# # Define a few variables
# # # # # # # # # # # # # #
factorSumOvl=1e9
factorSlopeOvl=1e-4
nLooksAz=4
nLooksRa=16
seuilAmp=30000
scaleColorize=100000
seuilAmp=0.6
facteurSeuilAmp=0.9
scaleColorize=1

# # # # # # # # # # # # # #
# # Define a few functions
# # # # # # # # # # # # # #

# # Produces nice plots
def colorize(z,scale):
    n,m = z.shape
    c = numpy.zeros((n,m,3))
    c[numpy.isinf(z)] = (1.0, 1.0, 1.0)
    c[numpy.isnan(z)] = (0.5, 0.5, 0.5)
    idx = ~(numpy.isinf(z) + numpy.isnan(z))
    A = (numpy.angle(z[idx]) + numpy.pi) / (2*numpy.pi)
    # A = (A + 0.5) % 1.0
    A = (A) % 1.0
#    B = 1.0 - 1.0/(1.0+(abs(z[idx]))**0.01)
#    B = 1.0 - 1.0/(1.0+(abs(z[idx])/scale)**0.6)
    B = 1.0 - 1.0/(1.0+(abs(z[idx])/scale)**1.0)
#    B = 0.5 - 1.0/(1.0+(abs(z[idx])/scale)**1.0)
    c[idx] = [hls_to_rgb(a, b, 0.8) for a,b in zip(A,B)]
    return c

# # Read interferogram
def read_complex_array2(filename, M, N):
    result = []
    with open(filename, "rb" ) as input:
        for row in xrange(N):
            for col in xrange(M):
                reals = array.array('f')
                reals.fromfile(input, 1)
                # reals.byteswap()  # if necessary
                imags = array.array('f')
                imags.fromfile(input, 1)
                # imags.byteswap()  # if necessary
                cmplx = [complex(r,i) for r,i in zip(reals, imags)]
                result.append(cmplx)               
    #print len(result)
    result=numpy.asarray(result).reshape(N,M)
    return result

# # Model
def model(x,p0,N):
    #  bilinear trend
    fitPlane=numpy.exp(1j*(numpy.dot(x,numpy.array(p0[0:2]))*factorSlopeOvl+p0[2]).reshape(-1,N))
    #  simple offset
    # fitPlane=numpy.exp(1j*(numpy.dot(x,numpy.array(p0[0:2]))*factorSlopeOvl*0+p0[2]).reshape(-1,N))
    return fitPlane

# # Residual distribution
def residuals(p,y,x):
    N=y.shape[1]
    fitPlane=model(x,p,N)
    residue=y*(fitPlane.conjugate())
    return residue

# # Cost function
def fun(p,y,x):
    residue=residuals(p,y,x)
    return max(1/((numpy.sum(residue)).real)*factorSumOvl,0)


# # # # # # # # # #
# #    MAIN   # # # 
# # # # # # # # # #

# # # # # # # # # # # # # #
# # Read arguments passed to python script
args = sys.argv
# print args
width = int(args[1])
length = int(args[2])
SpectralOverlapInputFile = args[3]
OverlapIndexInputFile = args[4]

# # # # # # # # # # # # # #
# define output file names
outputRoot=os.path.splitext(os.path.basename(OverlapIndexInputFile))[0]
outputDir=os.path.dirname(OverlapIndexInputFile)
outputFigureFileName=os.path.join(outputDir,outputRoot+'_sdFit.pdf')
outputFitFileName=os.path.join(outputDir,outputRoot+'_sdFit.rsc')

# # # # # # # # # # # # # #
# # Read the interferogram
myCpxArray=read_complex_array2(SpectralOverlapInputFile,width,length)

# # # # # # # # # # # # # #
# # Read start/stop line indexes of overlap regions
f = open(OverlapIndexInputFile, 'r')
ovlList=[]
for line in f:
   line = line.strip()
   columns = numpy.array(line.split())
   columns = [i for i in columns]
   ovlList.append(columns)
f.close() 
#overlapLength=numpy.mean(numpy.diff(ovlList))

# # # # # # # # # # # # # #
# # Restrict the analysis to the overlap regions
myCpxArrayOvl = numpy.array([], dtype=int).reshape(-1,width)
myCpxArrayXCoord = numpy.array([], dtype=int).reshape(-1,width)
myCpxArrayYCoord = numpy.array([], dtype=int).reshape(-1,width)
for Noverlap in range(len(ovlList)):
    burstNum=int(ovlList[Noverlap][0])
    indexTop=int(round(float(ovlList[Noverlap][1])/nLooksAz))
    indexBot=int(round(float(ovlList[Noverlap][2])/nLooksAz))
    # Noverlap][3] not used
    
    ## Find with zeros the invalid values to the left and to the right of overlap region
    #myCpxArrayOvl = numpy.vstack((myCpxArrayOvl,myCpxArray[indexTop:indexBot,0:width
    indexLeft=int(round(float(ovlList[Noverlap][4])/nLooksRa))
    indexRight=int(round(float(ovlList[Noverlap][5])/nLooksRa))
    # the above seems to yield bad left / right indexes... abandon
    indexLeft=int(0)
    indexRight=int(width)
    print burstNum, indexTop, indexBot, indexLeft, indexRight
    heightOverlap = indexBot - indexTop
    tmpCpxArrayOvlLeft = numpy.zeros((heightOverlap,indexLeft), dtype=complex)
    tmpCpxArrayOvlRight = numpy.zeros((heightOverlap,width-indexRight), dtype=complex)
    
    # Forget about the rest of the interferogram (should be zero everywhere)
    myCpxArrayOvl = numpy.vstack((myCpxArrayOvl,numpy.hstack((tmpCpxArrayOvlLeft,myCpxArray[indexTop:indexBot,indexLeft:indexRight],tmpCpxArrayOvlRight))))
    
    tmpArray=numpy.mgrid[indexTop:indexBot,0:width]    
    myCpxArrayXCoord=numpy.vstack((myCpxArrayXCoord,tmpArray[1]))
    myCpxArrayYCoord=numpy.vstack((myCpxArrayYCoord,tmpArray[0]))

# # # # # # # # # # # # # #
# # Cleanup
del myCpxArray, tmpArray, tmpCpxArrayOvlLeft, tmpCpxArrayOvlRight 

# # # # # # # # # # # # # #
# # Matrix containing pixel coordinates
coordMat=numpy.hstack((myCpxArrayXCoord.reshape(-1,1),myCpxArrayYCoord.reshape(-1,1)))

# # # # # # # # # # # # # #
# Guess the average offset by calculating argument of complex sum
guessOffset=numpy.angle(numpy.sum(myCpxArrayOvl))
p0 = [0,0,guessOffset]
# Calculate residual distribution
fitPlaneForward=model(coordMat,p0,myCpxArrayOvl.shape[1])
residueForward=residuals(p0,myCpxArrayOvl,coordMat)
myCpxArrayOvlRes=residueForward
myCpxArrayOvlPhs=numpy.angle(myCpxArrayOvlRes).reshape(-1,1)
myCpxArrayOvlAmp=numpy.absolute(myCpxArrayOvlRes).reshape(-1,1)
myCpxArrayOvlAmpMedian=numpy.median(myCpxArrayOvlAmp)
myCpxArrayOvlAmpMean=numpy.mean(myCpxArrayOvlAmp)
seuilAmp = facteurSeuilAmp * myCpxArrayOvlAmpMedian

# # # # # # # # # # # # # #
# only consider pixels with an amplitude exceeding a certain threshold
# and a phase different from exactly 0.0
# seuilAmp=numpy.percentile(myCpxArrayOvlAmp, 90) # alternatively, remove 90% of pixels with smallest amplitude
myCpxArrayOvlAmpSeuil=[ i for (i,j) in zip(myCpxArrayOvlAmp,myCpxArrayOvlPhs) if i >= seuilAmp and j != numpy.float(0.0)]
myCpxArrayOvlPhsSeuil=[ j for (i,j) in zip(myCpxArrayOvlAmp,myCpxArrayOvlPhs) if i >= seuilAmp and j != numpy.float(0.0) ]
coordMatSeuil=[ k for (i,j,k) in zip(myCpxArrayOvlAmp,myCpxArrayOvlPhs,coordMat.T[0]) if i >= seuilAmp and j != numpy.float(0.0) ]
coordMatSeuil=numpy.vstack((coordMatSeuil,[ k for (i,j,k) in zip(myCpxArrayOvlAmp,myCpxArrayOvlPhs,coordMat.T[1]) if i >= seuilAmp and j != numpy.float(0.0) ]))
coordMatSeuil=coordMatSeuil.T

# # # # # # # # # # # # # #
# solve the linear problem
A=numpy.hstack((coordMatSeuil*factorSlopeOvl,numpy.ones((len(coordMatSeuil),1))))
b=myCpxArrayOvlPhsSeuil
print "A", A.shape
b=numpy.array(b)
print "b", b.shape
res_lstsqSeuil = numpy.linalg.lstsq(A,b)[0] # computing the numpy solution

# # # # # # # # # # # # # #
# compute some statistics
NpointsOrig=len(myCpxArrayOvlAmp)
Npoints=len(myCpxArrayOvlAmpSeuil)
PercentUsedPoints=float(Npoints)/NpointsOrig*100
RMS=numpy.sqrt(numpy.mean(numpy.square((A*(res_lstsqSeuil.T)-b))))

# # # # # # # # # # # # # #
# add back the guessed offset
res_lstsqSeuilOffset=(res_lstsqSeuil.T+p0).T

# # # # # # # # # # # # # #
# extract slope of best-fitting phase plane 
LagSlopeX=res_lstsqSeuilOffset[0]*factorSlopeOvl/nLooksRa
LagSlopeY=res_lstsqSeuilOffset[1]*factorSlopeOvl/nLooksAz
LagConst=res_lstsqSeuilOffset[2]

# # # # # # # # # # # # # #
# verbose
print("GUESS_OFFSET  %-6.5f" % (guessOffset))
print("SD_CONSTANT   %-6.5f" % (LagConst))
print("SD_SLOPE_X    %-14.12f" % (LagSlopeX))
print("SD_SLOPE_Y    %-14.12f" % (LagSlopeY))
print("RMS           %-14.12f" % (RMS))
print("NPOINTS       %-d" % (Npoints))
print("PERCENTUSED   %-14.12f" % (PercentUsedPoints))
print("THRESH_AMP    %-14.12f" % (seuilAmp))

# # # # # # # # # # # # # #
# compute best-fitting plane and residuals
fitPlaneInv=model(coordMat,res_lstsqSeuilOffset,myCpxArrayOvl.shape[1])
residueInv=residuals(res_lstsqSeuilOffset,myCpxArrayOvl,coordMat)
numpy.angle(numpy.sum(residueInv))

# # # # # # # # # # # # # #
# save results to file
f = open(outputFitFileName, 'w')
f.write("SD_CONSTANT   %-6.5f\n" % (LagConst))
f.write("SD_SLOPE_X    %-14.12f\n" % (LagSlopeX))
f.write("SD_SLOPE_Y    %-14.12f\n" % (LagSlopeY))
f.write("RMS           %-14.12f\n" % (RMS))
f.write("NPOINTS       %-d\n" % (Npoints))
f.write("PERCENTUSED   %-14.12f\n" % (PercentUsedPoints))
f.write("THRESH_AMP    %-14.12f\n" % (seuilAmp))
f.write("GUESS_OFFSET  %-14.12f\n" % (guessOffset))
f.close()

# # # # # # # # # # # # # #
# make a plot into a PDF
fig = plt.figure()
ax = fig.add_subplot(3,1,1)
#plt.imshow(colorize(myCpxArrayOvl,scaleColorize), interpolation='nearest',vmin=-1*numpy.pi, vmax=1*numpy.pi)
plt.imshow(colorize(myCpxArrayOvl,myCpxArrayOvlAmpMedian*5), interpolation='nearest',vmin=-1*numpy.pi, vmax=1*numpy.pi)
plt.colorbar()
ax = fig.add_subplot(3,1,2)
plt.imshow(colorize(fitPlaneInv,1), interpolation='nearest',vmin=-1*numpy.pi, vmax=1*numpy.pi)
plt.colorbar()
ax = fig.add_subplot(3,1,3)
#plt.imshow(colorize(residueInv,scaleColorize), interpolation='nearest',vmin=-1*numpy.pi, vmax=1*numpy.pi)
plt.imshow(colorize(residueInv,myCpxArrayOvlAmpMedian*5), interpolation='nearest',vmin=-1*numpy.pi, vmax=1*numpy.pi)
plt.colorbar()
# plt.show()
plt.savefig(outputFigureFileName)





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

