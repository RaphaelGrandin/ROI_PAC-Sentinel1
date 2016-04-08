c****************************************************************

      Program resamp_roi 

c****************************************************************
c**     
c**   FILE NAME: resamp_roi.F
c**     
c**   DATE WRITTEN: Long, long ago. (March 16, 1992)
c**     
c**   PROGRAMMER: Charles Werner, Paul Rosen and Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: Interferes two SLC images 
c**   range, azimuth interpolation with a quadratic or sinc interpolator 
c**   no circular buffer is used, rather a batch algorithm is implemented
c**   The calculation of the range and azimuth offsets is done for
c**   each of the data sets in the offset data file. As soon as the
c**   current line number exceeds the range line number for one of the
c**   data sets in the offset data file, the new lsq coefficients are
c**   to calculate the offsets for any particular range pixel. 
c**     
c**   ROUTINES CALLED:
c**     
c**   NOTES: 
c**     
c**   UPDATE LOG:
c**
c**   Date Changed        Reason Changed 
c**   ------------       ----------------
c**     20-apr-92    added removal/reinsertion of range phase slope to 
c**                  improve correlation
c**     11-may-92    added code so that the last input block of data is processed
c**                  even if partially full
c**     9-jun-92     modified maximum number of range pixels
c**     17-nov-92    added calculation of the range phase shift/pixel
c**     29-mar-93    write out multi-look images (intensity) of the two files 
c**     93-99        Stable with small enhancements changes
c**     Dec 99       Modified range interpolation to interpret (correctly)
c**                  the array indices to be those of image 2 coordinates.  
c**                  Previous code assumed image 1, and therefore used 
c**                  slightly wrong offsets for range resampling depending
c**                  on the gross offset between images.  Mods involve computing
c**                  the inverse mapping
c**     Aug 16, 04   This version uses MPI (Message Passing Interface)
c**                  to parallelize the resamp_roi sequential computations.
c**                  File Name is changed to resamp_roi.F in order to use
c**                  the Fortran compiler pre-processor to do conditional
c**                  compiling (#ifdef etc).  This code can be compiled for
c**                  either sequential or parallel uses. Compiler flag 
c**                  -DMPI_PARA is needed in order to pick up the MPI code.
c**
c*****************************************************************

      implicit none

#ifdef MPI_PARA
      include 'mpif.h'
#endif

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

      integer    NPP,MP
      parameter (NPP=10)

      real*8   PI
      integer  NP, NAZMAX, N_OVER, NBMAX, NLINESMAX
      parameter (PI=3.1415926535d0)
      parameter (NP=40000)	!maximum number of range pixels
      parameter (NLINESMAX=200000) ! maximum number of SLC lines
      parameter (NAZMAX=8)	        !number of azimuth looks
      parameter (N_OVER=2000)  !overlap between blocks
      parameter (NBMAX=200*NAZMAX+2*N_OVER) !number of lines in az interpol

      integer MINOFFSSAC, MINOFFSSDN, OFFDIMAC, OFFDIMDN
      parameter (MINOFFSSAC=100, MINOFFSSDN=500)
      parameter (OFFDIMAC=NP/MINOFFSSAC, OFFDIMDN=NLINESMAX/MINOFFSSDN)
      parameter (MP=OFFDIMAC*OFFDIMDN)

      integer FL_LGT
      parameter (FL_LGT=8192*8)

      integer MAXDECFACTOR      ! maximum lags in interpolation kernels
      parameter(MAXDECFACTOR=8192)                        
      
      integer MAXINTKERLGH      ! maximum interpolation kernel length
      parameter (MAXINTKERLGH=8)
      
      integer MAXINTLGH         ! maximum interpolation kernel array size
      parameter (MAXINTLGH=MAXINTKERLGH*MAXDECFACTOR)

c     INPUT VARIABLES:
	
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

      logical ex
      character*120 f(5),a_cmdfile,a_offfile,a_temp
      character*120 as
      
      integer ierr, istats, l1, l2, lr, lc, line, iargc, iflatten
      integer ist, istoff, iaz, npl, npl2, nplo, nr, naz, nl, i_numpnts
      integer ibs, ibe, irec, i_a1, i_r1, jrec, jrecp
      integer i, j, k, ii, ix, nb
      integer int_az_off
      integer int_rd(0:NP-1)
      integer int_az(0:NP-1)
      integer i_na, ibfcnt,i_ma       

      real*4  fintp(0:FL_LGT-1),f_delay
      real am(0:NP-1,0:NAZMAX-1),amm(0:NP-1)
      real bm(0:NP-1,0:NAZMAX-1),bmm(0:NP-1)
      complex abmm(0:NP-1)
      
      real*8 fr_rd(0:NP-1),fr_az(0:NP-1)

      real*8 wvl, cpp, rphs, aa1, rphs1, r_ro, r_ao, rsq, asq, rmean
      real*8 amean, slr, azsum, azoff1, r_st, rd, azs
      real*8 r_rt,r_at, azmin
c      real*8 prf1, prf2

      complex cm(0:NP-1)
      complex dm(0:NP-1)
      complex em(0:NP-1)
      real*8 fd(0:NP-1)
      
      complex a(0:NP-1),b(0:NP-1,0:NBMAX-1),tmp(0:NP-1)
      complex cc(0:NP-1),c(0:NP-1,0:NAZMAX-1),dddbuff(0:NP-1)
      complex rph(0:NP-1,0:NAZMAX-1)               !range phase correction
      complex sinc_eval

      real*8 ph1, phc, r_q
      real*8 f0,f1,f2,f3           !doppler centroid function of range poly file 1
      real*8 r_ranpos(MP),r_azpos(MP),r_sig(MP),r_ranoff(MP)
      real*8 r_azoff(MP),r_rancoef(NPP),r_azcoef(NPP)
      real*8 r_v(NPP,NPP),r_u(MP,NPP),r_w(NPP),r_chisq
      real*8 r_ranpos2(MP),r_azpos2(MP),r_sig2(MP),r_ranoff2(MP)
      real*8 r_azoff2(MP),r_rancoef2(NPP),r_azcoef2(NPP)
      real*8 r_rancoef12(NPP)

      real*8 r_beta,r_relfiltlen,r_filter(0:MAXINTLGH),r_pedestal
      real*4 r_delay
      integer i_decfactor,i_weight,i_intplength,i_filtercoef

      real*4 t0, t1, t2, t3, t4, t5, t6
      real*4 seconds
      external seconds

c     COMMON BLOCKS:

      integer i_fitparam(NPP),i_coef(NPP)
      common /fred/ i_fitparam,i_coef 

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

      integer rdflen
      external funcs
      character*255 rdfval,rdftmp

c     SAVE STATEMENTS:

      save b,c,am,bm,rph, r_ranpos,r_azpos,r_sig,r_ranoff, r_azoff, r_u
      save     r_ranpos2,r_azpos2,r_sig2,r_ranoff2, r_azoff2

#ifdef MPI_PARA
cc--   variables for MPI parallel code
      integer MAX_PROC
      parameter(MAX_PROC=2048)
      integer ierror
      integer*4 mpiMyNode, mpiNumNodes
      integer n_lines_p
      integer p_lines(MAX_PROC,2)   ! lines processed by each node
      integer i_x, i_y, residual, num_nodes_used
      integer complex_size, count
      integer(KIND=MPI_OFFSET_KIND) view_disp, offset
cc      integer*8 view_disp, offset
      integer status(MPI_STATUS_SIZE)
      character*4  ROMIO
#endif

c     PROCESSING STEPS:

cc      write(6,*) ' XXX start timer'
      t0 = seconds(0.0)

cc--   MPI setup
#ifdef MPI_PARA
      call MPI_INIT(ierror)
cc      write(6,*) 'ierror: ', ierror
      if (ierror .ne. 0) then
         print *,'Error - Cannot initialize MPI!'
         stop
      end if

      call MPI_COMM_RANK(MPI_COMM_WORLD, mpiMyNode, ierror)
      call MPI_COMM_SIZE(MPI_COMM_WORLD, mpiNumNodes, ierror)

      write(6,*) 'mpiMyNode, mpiNumNodes: ', mpiMyNode, mpiNumNodes
#endif

#ifdef MPI_PARA
      if(mpiMyNode .eq. 0) then
#endif
      write(6,*) ' '       
      write(6,*)  ' << RTI Interpolation and Cross-correlation (quadratic) v1.0 >>'
      write(6,*) ' ' 
#ifdef MPI_PARA
      endif
#endif

#ifdef MPI_PARA
      write(6,*) '***** mpiMyNode: ',mpiMyNode, ' iargc() ', iargc()
      if(mpiMyNode .eq. 0) then
        if(iargc() .lt. 2)then
          write(6,'(a)') 'Usage: mpi_resamp_roi cmd_file ROMIO'
          write(6,*) ' '
          stop
        endif

        call getarg(1,a_cmdfile)
        ROMIO = "no"
        call getarg(2,ROMIO)
      end if

      write(6,*) '***** before bcast, mpiMyNode: ', mpiMyNode
      call MPI_BCAST(a_cmdfile,120,MPI_CHARACTER,0,MPI_COMM_WORLD,ierror)
      call MPI_BCAST(ROMIO,4,MPI_CHARACTER,0,MPI_COMM_WORLD,ierror)
      write(6,*) '***** after bcast, mpiMyNode: ', mpiMyNode
cc      write(6,*) '***** On ', mpiMyNode, ', a_cmdfile: ', a_cmdfile
cc      write(6,*) '***** ROMIO: ', ROMIO, ' on ', mpiMyNode
      call MPI_TYPE_SIZE(MPI_COMPLEX, complex_size, ierror)
      write(6,*) '***** complex_size: ', complex_size, mpiMyNode
#else
        if(iargc() .lt. 1)then
          write(6,'(a)') 'Usage: resamp_roi cmd_file'
          write(6,*) ' '
          stop
        endif

        call getarg(1,a_cmdfile)
#endif
      
      call rdf_init('ERRFILE=SCREEN')
      call rdf_init('ERROR_SCREEN=ON')
      call rdf_init('ERROR_OUTPUT=rdf_errors.log')
      call rdf_init('COMMENT= ! ! !')
      write(6,'(a)') 'Reading command file data...'
      call rdf_read(a_cmdfile)

c     read parameters from command file

      rdftmp=rdfval('Image Offset File Name','-')
      read(unit=rdftmp,fmt='(a)') a_offfile
      rdftmp=rdfval('Display Fit Statistics to Screen','-')
      read(unit=rdftmp,fmt='(a)') a_temp
      if(index(a_temp,'Show Fit Stats') .ne. 0)then
         istats = 1
      elseif(index(a_temp,'No Fit Stats') .ne. 0)then
         istats = 0
      endif
      rdftmp=rdfval('Number of Fit Coefficients','-')
      read(unit=rdftmp,fmt=*) i_ma
      rdftmp=rdfval('SLC Image File 1','-')
      read(unit=rdftmp,fmt='(a)') f(1)
      rdftmp=rdfval('Number of Range Samples Image 1','-')
      read(unit=rdftmp,fmt=*) npl
      rdftmp=rdfval('SLC Image File 2','-')
      read(unit=rdftmp,fmt='(a)') f(2)
      rdftmp=rdfval('Number of Range Samples Image 2','-')
      read(unit=rdftmp,fmt=*) npl2
      if((npl .gt. NP) .or. (npl2 .gt. NP)) then
         write(6,*) 'ERROR:number of pixels greater than array in resamp_roi'
         stop
      end if
      rdftmp=rdfval('Output Interferogram File','-')
      read(unit=rdftmp,fmt='(a)') f(3)
      rdftmp=rdfval('Multi-look Amplitude File','-')
      read(unit=rdftmp,fmt='(a)') f(4)
      rdftmp=rdfval('Starting Line, Number of Lines, and First Line Offset','-')
      read(unit=rdftmp,fmt=*) ist, nl, istoff
      rdftmp=rdfval('Doppler Cubic Fit Coefficients - PRF Units','-')
      read(unit=rdftmp,fmt=*) f0,f1,f2,f3
      rdftmp=rdfval('Radar Wavelength','m')
      read(unit=rdftmp,fmt=*) WVL
      rdftmp=rdfval('Slant Range Pixel Spacing','m')
      read(unit=rdftmp,fmt=*) SLR
      rdftmp=rdfval('Number of Range and Azimuth Looks','-')
      read(unit=rdftmp,fmt=*) NR,NAZ
      rdftmp=rdfval('Flatten with offset fit?','-')
      read(unit=rdftmp,fmt='(a)') a_temp

      iflatten = 2
      if(index(a_temp,'Yes') .ne. 0)then
         iflatten = 1
      elseif(index(a_temp,'No') .ne. 0)then
         iflatten = 0
      endif

c     open offset file

      write(6,*) ' '
      write(6,'(a,x,i5,x,i5)') 'Interferogram formed from lines: ',ist,ist+nl

      write(6,*) ' '
      write(6,'(a)') 'Opening file '//a_offfile(1:rdflen(a_offfile))

      open(13,file='resid.dat')
      open(unit=20,file=a_offfile, status='old',iostat=ierr)
      
      if (ierr .ne. 0) then 
         write(6,*) 'ERROR...correlation offsets file does not exist !'
         stop
      end if
      
      if(istats .eq. 1)then
         write(6,*) ' '
         write(6,*) ' Range    R offset     Azimuth    Az offset     SNR '
         write(6,*) '++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
         write(6,*) ' '
      endif

c     reading offsets data file (note NS*NPM is maximal number of pixels)
      
      i_numpnts = 0
      i_na = 0
      do j=0,MP-1           !read the offset data file

         read(unit=20,FMT='(a)',end=50) as

         if(istats .eq. 1) write(6,'(a)') as
         
 3       if (as .ne. ' ')then

            i_numpnts = i_numpnts + 1
            read(as,*) lr,r_rt,iaz,r_at,r_st

            i_na = max(i_na,iaz)

c     stuff for two dimensional fits

            r_ranpos(i_numpnts) = float(lr)
            r_azpos(i_numpnts) = float(iaz)
            r_azoff(i_numpnts) = r_at
            r_ranoff(i_numpnts) = r_rt
            r_sig(i_numpnts) = 1.0 + 1.d0/r_st
            r_ranpos2(i_numpnts) = float(lr) + r_rt
            r_azpos2(i_numpnts) = float(iaz) + r_at
            r_azoff2(i_numpnts) = r_at
            r_ranoff2(i_numpnts) = r_rt
            r_sig2(i_numpnts) = 1.0 + 1.d0/r_st

         else

 5          read(unit=20,FMT='(a)',end=50) as    
            if(istats .eq. 1) write(6,'(a)') as
            if(as .eq. ' ') then  !read until non-blank line
               goto 5
            else
               goto 3
            end if
            
            if(istats .eq. 1) write(6,*) ' '
            
         end if
         
      end do

      write(6,*) 'ERROR: reached offset array size. '
      write(6,*) 'Number of offset points allowed =  ',MP
      stop 'Increase offset array size in program parameters'

 50   close(unit=20)            !close the file

      write(6,*) ' '
      write(6,*) 'Finished reading offset file...'
      write(6,*) 'Number of points read    =  ',i_numpnts
      write(6,*) 'Number of points allowed =  ',MP

c     find average int az off

      azsum = 0.
      azmin = r_azpos(1)
      do j=1,i_numpnts
         azsum = azsum + r_azoff(j)
         azmin = min(azmin,r_azpos(j))
      enddo
      azoff1 = azsum/i_numpnts
      int_az_off = nint(azoff1)
      write(6,*) ' '
      write(6,*) 'Average azimuth offset = ',azoff1,int_az_off
      
      do i = 1 , i_numpnts
         r_azpos(i) = r_azpos(i) - azmin
         r_azpos2(i) = r_azpos2(i) - int_az_off - azmin
      end do

c     make two two dimensional quadratic fits for the offset fields 
c     one of the azimuth offsets and the other for the range offsets

      do i = 1 , NPP
         r_rancoef(i) = 0.
         r_rancoef2(i) = 0.
         r_rancoef12(i) = 0.
         r_azcoef(i) = 0.
         r_azcoef2(i) = 0.
         i_coef(i) = 0
      end do

      do i=1,i_ma
         i_coef(i) = i
      enddo

c     azimuth offsets as a function range and azimuth

      call svdfit(r_ranpos,r_azpos,r_azoff,r_sig,i_numpnts,
     +     r_azcoef,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Azimuth sigma = ',sqrt(r_chisq/i_numpnts)

c     inverse mapping azimuth offsets as a function range and azimuth

      call svdfit(r_ranpos2,r_azpos2,r_azoff2,r_sig2,i_numpnts,
     +     r_azcoef2,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Azimuth sigma = ',sqrt(r_chisq/i_numpnts)

c     range offsets as a function of range and azimuth

      call svdfit(r_ranpos,r_azpos,r_ranoff,r_sig,i_numpnts,
     +     r_rancoef,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Range sigma = ',sqrt(r_chisq/i_numpnts)

c     Inverse range offsets as a function of range and azimuth

      call svdfit(r_ranpos2,r_azpos2,r_ranoff2,r_sig2,i_numpnts,
     +     r_rancoef2,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Range sigma = ',sqrt(r_chisq/i_numpnts)

c     Inverse range offsets as a function of range and azimuth

      call svdfit(r_ranpos,r_azpos2,r_ranoff2,r_sig2,i_numpnts,
     +     r_rancoef12,i_ma,r_u,r_v,r_w,MP,NPP,r_chisq)

      write(6,*) 'Inverse Range sigma = ',sqrt(r_chisq/i_numpnts)

      write(6,*) ' ' 
      write(6,*) 'Range offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_rancoef(1) 
      write(6,*) 'Range Slope term =         ',r_rancoef(2) 
      write(6,*) 'Azimuth Slope =            ',r_rancoef(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_rancoef(4) 
      write(6,*) 'Range quadratic term =     ',r_rancoef(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_rancoef(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_rancoef(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_rancoef(8) 
      write(6,*) 'Range cubic term =         ',r_rancoef(9) 
      write(6,*) 'Azimuth cubic term =       ',r_rancoef(10) 
       
      write(6,*) ' ' 
      write(6,*) 'Azimuth offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_azcoef(1) 
      write(6,*) 'Range Slope term =         ',r_azcoef(2) 
      write(6,*) 'Azimuth Slope =            ',r_azcoef(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_azcoef(4) 
      write(6,*) 'Range quadratic term =     ',r_azcoef(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_azcoef(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_azcoef(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_azcoef(8) 
      write(6,*) 'Range cubic term =         ',r_azcoef(9) 
      write(6,*) 'Azimuth cubic term =       ',r_azcoef(10) 

      write(6,*)
      write(6,*) 'Comparison of fit to actuals'
      write(6,*) ' '
      write(6,*) '   Ran       AZ    Ranoff    Ran fit  Rand Diff  Azoff    Az fit   Az Diff'
      rmean= 0.
      amean= 0.
      rsq= 0.
      asq= 0.
      do i=1,i_numpnts
         r_ro = r_rancoef(1) + r_azpos(i)*(r_rancoef(3) +
     +        r_azpos(i)*(r_rancoef(6) + r_azpos(i)*r_rancoef(10))) +   
     +        r_ranpos(i)*(r_rancoef(2) + r_ranpos(i)*(r_rancoef(5) +
     +        r_ranpos(i)*r_rancoef(9))) +
     +        r_ranpos(i)*r_azpos(i)*(r_rancoef(4) + r_azpos(i)*r_rancoef(7) +
     +        r_ranpos(i)*r_rancoef(8)) 
         r_ao = r_azcoef(1) + r_azpos(i)*(r_azcoef(3) +
     +        r_azpos(i)*(r_azcoef(6) + r_azpos(i)*r_azcoef(10))) +   
     +        r_ranpos(i)*(r_azcoef(2) + r_ranpos(i)*(r_azcoef(5) +
     +        r_ranpos(i)*r_azcoef(9))) +
     +        r_ranpos(i)*r_azpos(i)*(r_azcoef(4) + r_azpos(i)*r_azcoef(7) +
     +        r_ranpos(i)*r_azcoef(8)) 
         rmean = rmean + (r_ranoff(i)-r_ro)
         amean = amean + (r_azoff(i)-r_ao)
         rsq = rsq + (r_ranoff(i)-r_ro)**2
         asq = asq + (r_azoff(i)-r_ao)**2
         if(istats .eq. 1) write(6,150)  r_ranpos(i),r_azpos(i),r_ranoff(i),r_ro,r_ranoff(i)-r_ro,
     .        r_azoff(i),r_ao,r_azoff(i)-r_ao
 150     format(2(1x,f8.1),1x,f8.3,1x,f12.4,1x,f12.4,2x,f8.3,1x,f12.4
     $        ,1xf12.4,1x1x)

         write(13,269) int(r_ranpos(i)),r_ranoff(i)-r_ro,int(r_azpos(i))
     $        ,r_azoff(i)-r_ao,10.,1.,1.,0.

 269     format(i6,1x,f10.3,1x,i6,f10.3,1x,f10.5,3(1x,f10.6))

      enddo 
      rmean = rmean / i_numpnts
      amean = amean / i_numpnts
      rsq = sqrt(rsq/i_numpnts - rmean**2)
      asq = sqrt(asq/i_numpnts - amean**2)
      write(6,*) ' '
      write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma range   offset residual (pixels): ',rmean, rsq
      write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma azimuth offset residual (pixels): ',amean, asq
      
      write(6,*) ' ' 
      write(6,*) 'Range offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_rancoef2(1) 
      write(6,*) 'Range Slope term =         ',r_rancoef2(2) 
      write(6,*) 'Azimuth Slope =            ',r_rancoef2(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_rancoef2(4) 
      write(6,*) 'Range quadratic term =     ',r_rancoef2(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_rancoef2(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_rancoef2(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_rancoef2(8) 
      write(6,*) 'Range cubic term =         ',r_rancoef2(9) 
      write(6,*) 'Azimuth cubic term =       ',r_rancoef2(10) 
       
      write(6,*) ' ' 
      write(6,*) 'Azimuth offset fit parameters'
      write(6,*) ' '
      write(6,*) 'Constant term =            ',r_azcoef2(1) 
      write(6,*) 'Range Slope term =         ',r_azcoef2(2) 
      write(6,*) 'Azimuth Slope =            ',r_azcoef2(3) 
      write(6,*) 'Range/Azimuth cross term = ',r_azcoef2(4) 
      write(6,*) 'Range quadratic term =     ',r_azcoef2(5) 
      write(6,*) 'Azimuth quadratic term =   ',r_azcoef2(6) 
      write(6,*) 'Range/Azimuth^2   term =   ',r_azcoef2(7) 
      write(6,*) 'Azimuth/Range^2 =          ',r_azcoef2(8) 
      write(6,*) 'Range cubic term =         ',r_azcoef2(9) 
      write(6,*) 'Azimuth cubic term =       ',r_azcoef2(10) 

      write(6,*)
      write(6,*) 'Comparison of fit to actuals'
      write(6,*) ' '
      write(6,*) '   Ran       AZ    Ranoff    Ran fit  Rand Diff  Azoff    Az fit   Az Diff'
      rmean= 0.
      amean= 0.
      rsq= 0.
      asq= 0.
      do i=1,i_numpnts
         r_ro = r_rancoef2(1) + r_azpos2(i)*(r_rancoef2(3) +
     +        r_azpos2(i)*(r_rancoef2(6) + r_azpos2(i)*r_rancoef2(10))) +   
     +        r_ranpos2(i)*(r_rancoef2(2) + r_ranpos2(i)*(r_rancoef2(5) +
     +        r_ranpos2(i)*r_rancoef2(9))) +
     +        r_ranpos2(i)*r_azpos2(i)*(r_rancoef2(4) + r_azpos2(i)*r_rancoef2(7) +
     +        r_ranpos2(i)*r_rancoef2(8)) 
         r_ao = r_azcoef2(1) + r_azpos2(i)*(r_azcoef2(3) +
     +        r_azpos2(i)*(r_azcoef2(6) + r_azpos2(i)*r_azcoef2(10))) +   
     +        r_ranpos2(i)*(r_azcoef2(2) + r_ranpos2(i)*(r_azcoef2(5) +
     +        r_ranpos2(i)*r_azcoef2(9))) +
     +        r_ranpos2(i)*r_azpos2(i)*(r_azcoef2(4) + r_azpos2(i)*r_azcoef2(7) +
     +        r_ranpos2(i)*r_azcoef2(8)) 
         rmean = rmean + (r_ranoff2(i)-r_ro)
         amean = amean + (r_azoff2(i)-r_ao)
         rsq = rsq + (r_ranoff2(i)-r_ro)**2
         asq = asq + (r_azoff2(i)-r_ao)**2
         if(istats .eq. 1) write(6,150)  r_ranpos2(i),r_azpos2(i),r_ranoff(i),r_ro,r_ranoff2(i)-r_ro,
     .        r_azoff2(i),r_ao,r_azoff2(i)-r_ao
         write(13,269) int(r_ranpos2(i)),r_ranoff2(i)-r_ro,int(r_azpos2(i))
     $        ,r_azoff2(i)-r_ao,10.,1.,1.,0.


       enddo 
       rmean = rmean / i_numpnts
       amean = amean / i_numpnts
       rsq = sqrt(rsq/i_numpnts - rmean**2)
       asq = sqrt(asq/i_numpnts - amean**2)
       write(6,*) ' '
       write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma range   offset residual (pixels): ',rmean, rsq
       write(6,'(a,x,f15.6,x,f15.6)') 'mean, sigma azimuth offset residual (pixels): ',amean, asq

       
c     read in data files

      inquire(file=f(1),exist=ex)
      if (.not.ex) then 
         write(6,*) 'ERROR...file does not exist !'
         stop
      end if

      inquire(file=f(2),exist=ex)
      if (.not.ex) then 
         write(6,*) 'ERROR...file does not exist !'
         stop
      end if		

      write(6,*) 'XXX unit=21, file=(1): ', f(1)
      write(6,*) 'XXX unit=22, file=(2): ', f(2)
#ifdef MPI_PARA
      if(ROMIO .eq. "yes") then
cc--    Use ROMIO so processors can read from a file in parallel
      call MPI_FILE_OPEN(MPI_COMM_WORLD, f(1),
     &  MPI_MODE_RDONLY, MPI_INFO_NULL, 21, ierror)
      call MPI_FILE_OPEN(MPI_COMM_WORLD, f(2),
     &  MPI_MODE_RDONLY, MPI_INFO_NULL, 22, ierror)
      else
        open(unit=21,file=f(1),form='unformatted',status='old',access='direct',recl=8*npl)
        open(unit=22,file=f(2),form='unformatted',status='old',access='direct',recl=8*npl2)
      endif
#else
      open(unit=21,file=f(1),form='unformatted',status='old',access='direct',recl=8*npl)
      open(unit=22,file=f(2),form='unformatted',status='old',access='direct',recl=8*npl2)
#endif
      
      nplo = min(npl,npl2)
      write(6,*) ' '
      write(6,'(a,x,i5)') 'Number samples in interferogram: ',nplo/NR

      write(6,*) 'XXX unit=23, file=(3): ', f(3)
      write(6,*) 'XXX unit=24, file=(4): ', f(4)
#ifdef MPI_PARA
      if(ROMIO .eq. "yes") then
        call MPI_FILE_OPEN(MPI_COMM_WORLD, f(3),
     &    MPI_MODE_WRONLY + MPI_MODE_CREATE, MPI_INFO_NULL, 23, ierror)
        if(ierror .ne. 0) then
          write(6,*) '***** MPI_FILE_OPEN() failed on ', mpiMyNode,
     &               ', ierror: ',ierror
          stop
        endif

        call MPI_FILE_OPEN(MPI_COMM_WORLD, f(4),
     &    MPI_MODE_WRONLY + MPI_MODE_CREATE, MPI_INFO_NULL, 24, ierror)
        if(ierror .ne. 0) then
          write(6,*) '***** MPI_FILE_OPEN() failed on ', mpiMyNode,
     &               ', ierror: ',ierror
          stop
        endif
      else
cc XXX This is the .int file
        open(unit=23, file=f(3), form='unformatted', status='unknown', access='direct',recl=(nplo/NR)*8)
cc XXX This is the .amp file
        open(unit=24, file=f(4), form='unformatted', status='unknown', access='direct',recl=(nplo/NR)*8)
      endif
#else
        open(unit=23, file=f(3), form='unformatted', status='unknown', access='direct',recl=(nplo/NR)*8)
        open(unit=24, file=f(4), form='unformatted', status='unknown', access='direct',recl=(nplo/NR)*8)
#endif

      CPP=SLR/WVL

      i_a1 = i_na - azmin
      i_r1 = npl/2.
      rphs  = 360. * 2. * CPP * (r_rancoef(2) + i_a1*(r_rancoef(4) + 
     +     r_rancoef(7)*i_a1) + i_r1*(2.*r_rancoef(5) +
     $     3.*r_rancoef(9)*i_r1 + 2.*r_rancoef(8)*i_a1))

      write(6,*) ' '
      write(6,'(a,x,3(f15.6,x))') 'Pixel shift/pixel in range    = ',rphs/(CPP*360.),aa1,sngl(r_rancoef(2))
      write(6,'(a,x,3(f15.6,x))') 'Degrees per pixel range shift = ',rphs,rphs1,2.*sngl(r_rancoef(2)*CPP*360.)

      if(f0 .eq. -99999.)then
         write(6,*) ' '
         write(6,*) 'Estimating Doppler from imagery...' 
         l1 = 1
         l2 = nb
         do j=l1-1,l2-1
            if(mod(j,100) .eq. 0)then
               write(6,*) 'Reading file at line = ',j
            endif
#ifdef MPI_PARA
           if(ROMIO .eq. "yes") then
            offset = (j+1-1)*npl*complex_size
            write(6,*) '***** 21 offset: ', offset, mpiMyNode
            call MPI_FILE_READ_AT(21,offset,b(0,j),npl,MPI_COMPLEX, status, ierr)
            call MPI_GET_COUNT(status, MPI_COMPLEX, count, ierr)
cc            write(6,*) 'XXX at j:', j, 'read ',count,' bytes (in resamp_roi)'
           else
            read(21,rec=j+1) (b(i,j),i=0,npl-1)
           endif
#else
            read(21,rec=j+1) (b(i,j),i=0,npl-1)
#endif
         enddo 
         call doppler(npl,l1,l2,b,fd,dddbuff)
         do j=0,npl-1
            write(66,*) j,fd(j)
         enddo
      endif

c     compute resample coefficients 
      
      r_beta = 1.d0
      r_relfiltlen = 8.d0
      i_decfactor = 8192
      r_pedestal = 0.d0
      i_weight = 1
      
      write(6,*) ' '
      write(6,'(a)') 'Computing sinc coefficients...'
      write(6,*) ' '
      
      call sinc_coef(r_beta,r_relfiltlen,i_decfactor,r_pedestal,i_weight,
     +     i_intplength,i_filtercoef,r_filter)
      
      r_delay = i_intplength/2.d0
      f_delay = r_delay
      
      do i = 0 , i_intplength - 1
         do j = 0 , i_decfactor - 1
            fintp(i+j*i_intplength) = r_filter(j+i*i_decfactor)
         enddo
      enddo

      nb = NBMAX
      ibfcnt = (NBMAX-2*N_OVER)/NAZ
      ibfcnt = ibfcnt * NAZ
      nb = ibfcnt + 2*N_OVER

      if(nb .ne. NBMAX) then
         write(6,*) 'Modified buffer max to provide sync-ed overlap'
         write(6,*) 'Max buffer size = ',NBMAX
         write(6,*) 'Set buffer size = ',nb
      end if

c     begin interferogram formation

      write(6,'(a)') 'Beginning interferogram formation...'
      write(6,*) ' '
      
      ibfcnt = nb-2*N_OVER

#ifdef MPI_PARA

cc    get num. of lines that each node would process
      write(6,*) 'Total num of lines: ', nl/NAZ
      do i_x = 1, MAX_PROC
        p_lines(i_x, 1) = 0
        p_lines(i_x, 2) = 0
      end do

      n_lines_p = nl/NAZ/mpiNumNodes
      residual = nl/NAZ - n_lines_p*mpiNumNodes

cc    number lines each node handles
      do i_x = 1, mpiNumNodes
        p_lines(i_x, 2) = n_lines_p
      end do

      do i_x = 1, residual
cc      At this point, p_lines(i_x,2) stores the num of lines node i_x has.
        p_lines(i_x, 2) = p_lines(i_x, 2) + 1
      end do

cc    compute each node's starting line
      num_nodes_used = mpiNumNodes
      do i_x = 1, mpiNumNodes
        p_lines(i_x, 1) = 0
        if (p_lines(i_x, 2) .gt. 0) then
          if(i_x .eq. 1) then
            p_lines(i_x, 1) = 0
          else
            p_lines(i_x, 1) = p_lines(i_x-1, 1) + p_lines(i_x-1, 2)
          end if
        else
cc        count the actual num of nodes used in case there are more
cc        processors than there are lines
          num_nodes_used = num_nodes_used - 1
        end if
      end do

      if(num_nodes_used .lt. mpiNumNodes) then
        write(6,*) ' ***** Warning: You are using ', mpiNumNodes, ' processors,'
        write(6,*) '       but you only need ', num_nodes_used, ','
        write(6,*) '       because there are only this many lines. Rerun mpi_roi'
        write(6,*) '       with ', num_nodes_used, ' or less processors!'

        call MPI_FINALIZE(ierror)
        stop
      end if

cc    compute each node's ending line
      do i_y = 1, mpiNumNodes
cc      Now p_lines(i_x,2) stores the ending line node i_x has.
        p_lines(i_y, 2) = p_lines(i_y, 1) + p_lines(i_y, 2) - 1
        write(6,*) 'XXX node: ', i_y, 'p_start: ', p_lines(i_y, 1),
     &             ', p_end: ', p_lines(i_y, 2), ' on ', mpiMyNode
      end do

cc    the displacement of this node's starting line from the start of the file
      view_disp = p_lines(mpiMyNode+1, 1)
      write(6,*) '***** 1 view_disp: ', view_disp, mpiMyNode
      view_disp = view_disp * nplo/NR
      write(6,*) '***** 2 view_disp: ', view_disp, mpiMyNode
      view_disp = view_disp * complex_size
      write(6,*) '***** 3 view_disp: ', view_disp, mpiMyNode

      call MPI_FILE_SET_VIEW(23,view_disp,
     &           MPI_COMPLEX,MPI_COMPLEX,'native',MPI_INFO_NULL,ierror)
      if(ierror .ne. 0) then
        write(6,*) '***** MPI_FILE_SET_VIEW() failed on ', 
     &                  mpiMyNode,' ierror: ',ierror
        stop
      endif

      call MPI_FILE_SET_VIEW(24,view_disp,
     &           MPI_COMPLEX,MPI_COMPLEX,'native',MPI_INFO_NULL,ierror)
      if(ierror .ne. 0) then
        write(6,*) '***** MPI_FILE_SET_VIEW() failed on ', 
     &                  mpiMyNode,' ierror: ',ierror
        stop
      endif

      do line=p_lines(mpiMyNode+1,1), p_lines(mpiMyNode+1,2)
#else

cc XXX Start of line loop
      do line=0,nl/NAZ-1
#endif

         lc = line*NAZ
         ibfcnt = ibfcnt + NAZ
         
         if(ibfcnt .ge. nb-2*N_OVER) then

            ibfcnt = 0
            ibs = ist+int_az_off-N_OVER+lc/(nb-2*N_OVER)*(nb-2*N_OVER)
            ibe = ibs+nb-1

            write(6,'(a,x,i5,x,i5,x,i5,x,i5,x,i5)') 
     +           'int line, slc line, buffer #, line start, line end: ',
     +           line,lc,lc/(nb-2*N_OVER)+1,ibs,ibe
            write(6,'(a,i5,a)') 'Reading ',nb,' lines of data'

            do i=0, nb-1        !load up  buffer

               if(mod(i+1,128) .eq. 0)then
                  write(6,'(a,x,i10)') 'At line: ',i+1
               endif

               irec = i + ibs
               jrec = irec + istoff - 1  ! irec,jrec = image 2 coordinates
               jrecp = jrec - int_az_off - azmin ! subtract big constant for fit

               if(irec .gt. 0)then       !in the data?

                  if(irec .gt. nl+ist+int_az_off)then
                     go to 900
                  endif
#ifdef MPI_PARA
                  if(ROMIO .eq. "yes") then
                    offset = (irec-1)*npl2
                    offset = offset*complex_size
                    write(6,*) '***** 22 offset: ', offset, mpiMyNode
                    call MPI_FILE_READ_AT(22,offset,tmp(0),npl2,MPI_COMPLEX,
     &                            status, ierr)
                    call MPI_GET_COUNT(status, MPI_COMPLEX, count, ierr)
                    write(6,*) 'XXX read from 22 count:', count,' bytes'
                    if(count .eq. 0) goto 900
                  else
                    read(UNIT=22,REC=irec,iostat=ierr) (tmp(ii),ii=0,npl2-1) 
                    if(ierr .ne. 0) goto 900
                  endif
#else
                  read(UNIT=22,REC=irec,iostat=ierr) (tmp(ii),ii=0,npl2-1) 
                  if(ierr .ne. 0) goto 900
#endif
                  
c*    calculate range interpolation factors, which depend on range and azimuth
c*    looping over IMAGE 2 COORDINATES.

                  do j=0,nplo-1 
                     r_ro = r_rancoef12(1) + jrecp*(r_rancoef12(3) +
     +                    jrecp*(r_rancoef12(6) + jrecp*r_rancoef12(10))) +   
     +                    j*(r_rancoef12(2) + j*(r_rancoef12(5) +
     +                    j*r_rancoef12(9))) +
     +                    j*jrecp*(r_rancoef12(4) + jrecp*r_rancoef12(7) +
     +                    j*r_rancoef12(8)) 
                     rd = r_ro + j 
                     int_rd(j)=int(rd+f_delay)
                     fr_rd(j)=rd+f_delay-int_rd(j)
                  end do
                  do j=0,nplo-1  !range interpolate
                     b(j,i)= sinc_eval(tmp,npl2,fintp,8192,8,int_rd(j),fr_rd(j))
                  end do

               else

                  do j=0,nplo-1  !fill with 0, no data yet
                     b(j,i)=(0.,0.)
                  end do

               end if  !have data in image 2 corresponding to image 1

            end do     !i loop

            goto 901            !jump around this code to fill

 900        write(6,'(a,x,i5)') 'Filling last block, line: ',i

            do ii=i,nb-1
               do j=0,nplo-1
                  b(j,ii)=(0.,0.)
               end do
            end do

 901        continue

         end if

c range phase (in cycles) per pixel 

c         i_a1 = ist + istoff - 1 + line*NAZ + NAZ/2
c         i_r1 = nplo/2.
c         rphs  = 2. * CPP * (r_rancoef(2) + i_a1*(r_rancoef(4) + 
c     +        r_rancoef(7)*i_a1) + i_r1*(2.*r_rancoef(5) +
c     $        3.*r_rancoef(9)*i_r1 + 2.*r_rancoef(8)*i_a1))

c         rphs  = 2. * CPP * (r_rancoef(2) + i_a1*(r_rancoef(4)/2. + 
c     +        (r_rancoef(7)/3.)*i_a1) + nplo*(r_rancoef(5) +
c     $        r_rancoef(9)*nplo) + r_rancoef(8)*(i_a1/2.)*nplo )

         do k=0,NAZ-1
            irec = ist + line*NAZ + k
            jrec = irec + istoff - azmin - 1

c note: this is only half the phase! Some for each channel

            do j=0,nplo-1
               r_ro = r_rancoef(1) + jrec*(r_rancoef(3) +
     +              jrec*(r_rancoef(6) + jrec*r_rancoef(10))) +   
     +              j*(r_rancoef(2) + j*(r_rancoef(5) +
     +              j*r_rancoef(9))) +
     +              j*jrec*(r_rancoef(4) + jrec*r_rancoef(7) +
     +              j*r_rancoef(8)) 
               r_ao = r_azcoef(1) + jrec*(r_azcoef(3) +
     +              jrec*(r_azcoef(6) + jrec*r_azcoef(10))) +   
     +              j*(r_azcoef(2) + j*(r_azcoef(5) +
     +              j*r_azcoef(9))) +
     +              j*jrec*(r_azcoef(4) + jrec*r_azcoef(7) +
     +              j*r_azcoef(8)) 

c*    !calculate azimuth offsets

               azs = irec + r_ao 
c               int_az(j) = nint(azs)
               if(azs .ge. 0.d0) then
                  int_az(j) = int(azs)
               else
                  int_az(j) = int(azs) - 1
               end if
               fr_az(j) = azs - int_az(j)
               rph(j,k)=cmplx(cos(sngl(2.*pi*r_ro*CPP)),-sin(sngl(2.*pi*r_ro*CPP)))

            end do

#ifdef MPI_PARA
           if(ROMIO .eq. "yes") then
            offset = (irec-1)*npl
            offset = offset*complex_size
            write(6,*) '***** 21 offset: ', offset, mpiMyNode
            call MPI_FILE_READ_AT(21,offset,tmp,npl,MPI_COMPLEX, status, ierr)
            call MPI_GET_COUNT(status, MPI_COMPLEX, count, ierr)
            if(count .eq. 0) goto 1000
cc            write(6,*) 'XXX at j:', j, 'read ',count,' bytes (in rcpatch)'
            else
              read(unit=21,rec=irec,iostat=ierr) (tmp(ii),ii=0,npl-1)
              if(ierr .ne. 0) goto 1000
            endif
#else
            read(unit=21,rec=irec,iostat=ierr) (tmp(ii),ii=0,npl-1)
            if(ierr .ne. 0) goto 1000
#endif

            do j=0,npl-1
               a(j) = tmp(j)*rph(j,k)
            end do
            
            do j=0,nplo-1        !azimuth interpolation
               ix = int_az(j)-ibs
               r_q  = (f0  + f1*j  + f2*j**2 + f3*j**3) 
c               write(*,*) 'r_q 1', r_q
               r_q = (((f3 * j + f2) * j) + f1) * j + f0
c               write(*,*) 'r_q 2', r_q
               ph1 = (r_q)*2.0*PI
               phc = fr_az(j) * ph1
               do ii = -3, 4
                  tmp(ii+3) = b(j,ix+ii) * cmplx(cos(ii*ph1),-sin(ii*ph1
     $                 ))
               end do
               cm(j) = sinc_eval(tmp,8,fintp,8192,8,7,fr_az(j))
               cm(j) = cm(j) * conjg(rph(j,k)) * cmplx(cos(phc),
     $              +sin(phc))

c               am1 = b(j,ix-1) * cmplx(cos(ph1),+sin(ph1))
c               a0 = b(j,ix)
c               ap1 = b(j,ix+1) * cmplx(cos(ph1),-sin(ph1))

c               a1 =  a0
c               b1 = (ap1 - am1)/2.
c               c1 =  (ap1 - a1 - b1)
               
c               az1= (a1+(c1*fr_az(j)+b1)*fr_az(j)) * cmplx(cos(phc),+sin(phc))

c               cm(j) = az1 * conjg(rph(j))

            end do
            dm(nplo-1) = a(nplo-1)
            dm(0) = a(0)
            em(nplo-1) = cm(nplo-1)
            em(0) = cm(0)
            do j = 1, nplo-2
               dm(j) = .23*a(j-1)+a(j)*.54+a(j+1)*.23
               em(j) = .23*cm(j-1)+cm(j)*.54+cm(j+1)*.23
            end do
            
            do j = 0, nplo -1
               c(j,k)  =       dm(j)*   conjg(em(j))    !1-look correlation
               am(j,k) = real(dm(j))**2+aimag(dm(j))**2 !intensity of a
               bm(j,k) = real(em(j))**2+aimag(em(j))**2 !intensity of b
            end do

         end do

c     take looks

         if(iflatten .eq. 1) then
            
            do j=0, nplo/NR-1   !sum over NR*NAZ looks
               cc(j)=(0.,0.)    !intialize sums
               amm(j)=0.
               bmm(j)=0.
               do k=0,NAZ-1
                  do i=0,NR-1
                     cc(j)=cc(j)+c(j*NR+i,k)
                     amm(j)=amm(j)+am(j*NR+i,k)
                     bmm(j)=bmm(j)+bm(j*NR+i,k)
                  end do
               end do
            end do
         else
            do j=0, nplo/NR-1   !sum over NR*NAZ looks
               cc(j)=(0.,0.)    !intialize sums
               amm(j)=0.
               bmm(j)=0.
               do k=0,NAZ-1
                  do i=0,NR-1
                     cc(j)=cc(j)+c(j*NR+i,k)
                     amm(j)=amm(j)+am(j*NR+i,k)
                     bmm(j)=bmm(j)+bm(j*NR+i,k)
                  end do
               end do
               cc(j)=cc(j)*conjg(rph(NR*j,NAZ/2)*rph(NR*j,NAZ/2)) !reinsert range phase
               abmm(j)=cmplx(sqrt(amm(j)),sqrt(bmm(j)))
            end do
         end if

#ifdef MPI_PARA
          if(ROMIO .eq. "yes") then
            call MPI_FILE_WRITE(23,cc,nplo/NR,MPI_COMPLEX,
     &                          MPI_STATUS_IGNORE,ierror)
cc            write(6,*) 'XXX ', mpiMyNode, ' after MPI_FILE_WRITE ',ierror

            call MPI_FILE_WRITE(24,abmm,nplo/NR,MPI_COMPLEX,
     &                          MPI_STATUS_IGNORE,ierror)
cc            write(6,*) 'XXX ', mpiMyNode, ' after MPI_FILE_WRITE ',ierror
          else
            write(UNIT=23,rec=line+1)(cc(ii),ii=0,nplo/NR-1) !write out
            write(UNIT=24,rec=line+1)(cmplx(sqrt(amm(ii)),sqrt(bmm(ii))),
     .           ii=0,nplo/NR-1)    !alternate recs.
          end if
#else
         write(UNIT=23,rec=line+1)(cc(ii),ii=0,nplo/NR-1) !write out
         write(UNIT=24,rec=line+1)(cmplx(sqrt(amm(ii)),sqrt(bmm(ii))),
     .        ii=0,nplo/NR-1)    !alternate recs.
#endif

      end do
cc XXX End of line loop

      t1 = seconds(t0)
      write(6,*) 'XXX time: ', t1-t0

#ifdef MPI_PARA
 1000 call MPI_BARRIER(MPI_COMM_WORLD, ierror)
      if(ROMIO .eq. "yes") then
        call MPI_FILE_CLOSE(21,ierror)
        call MPI_FILE_CLOSE(22,ierror)
        call MPI_FILE_CLOSE(23,ierror)
        call MPI_FILE_CLOSE(24,ierror)
      else 
        close(UNIT=21)
        close(UNIT=22)
        close(UNIT=23)
        close(UNIT=24)
      endif
#else
 1000 close(UNIT=21)
      close(UNIT=22)
      close(UNIT=23)
      close(UNIT=24)
#endif

#ifdef MPI_PARA
      call MPI_BARRIER(MPI_COMM_WORLD, ierror)
      if(mpiMyNode .eq. 0) then
        t2=seconds(t0)
        write(6,*) '***** Elapsed time (parallel) =', t2, ' seconds.'
      endif

      call MPI_FINALIZE(ierror)
#endif

      end
      

      subroutine funcs(x,y,afunc,ma)
      
      real*8 afunc(ma),x,y
      real*8 cf(10)
      integer i_fitparam(10),i_coef(10)
      
      common /fred/ i_fitparam,i_coef
      
      data cf /10*0./
      
      do i=1,ma
         cf(i_coef(i))=1.
         afunc(i) = cf(1) + x*(cf(2) + x*(cf(5) + x*cf(9))) + 
     +        y*(cf(3) + y*(cf(6) + y*cf(10))) +
     +        x*y*(cf(4) + y*cf(7) + x*cf(8))  
c         afunc(i)= cf(1) + cf(2)*x + cf(3)*y + cf(4)*x*y + cf(5)*x*x +
c     +        cf(6)*y*y + cf(7)*y*y*x + cf(8)*x*x*y + cf(9)*x*x*x + cf(10)*y*y*y
         cf(i_coef(i))=0.
      end do
      
      return
      end    

      subroutine intp_coefg(psfilename,dec_fac,intp_lgt,f_delay,fintp)
      
      implicit none
      
      integer fl_lgt
      parameter (fl_lgt=8*8192)

      real*8        yintp(0:FL_LGT-1)
      real*4        fintp(0:FL_LGT-1),f_delay
      integer*4     i,j
      integer*4     dec_fac, intp_lgt, k
      real*8        av,dc_max,dc_min
      character*(*) psfilename

      if(dec_fac*intp_lgt .gt. FL_LGT) then
         write(6,*)
     $        'intp_coefg: insufficient space allocated for filter'
         stop
      end if

      open(88,file=psFilename,recl=8*dec_fac*intp_lgt,access='direct')
      read(88,rec=1) (yintp(k),k = 1,dec_fac*intp_lgt)
      close(88)

      do i=0,intp_lgt-1
         do j=0,dec_fac-1
            fintp(i + j*intp_lgt) = yintp(j + i*dec_fac)
         end do
      end do

c f_delay is chosen below "incorrectly" because of the bias introduced
c in the code by choosing the integer index smaller than the actual index
c i.e. ifrac = int(frac*dec_fac)  biases the delay downward
c
c      f_delay =  (float(dec_fac*intp_lgt)/2.-0.5)/float(dec_fac)
c
      f_delay =  (float(dec_fac*intp_lgt)/2.)/float(dec_fac)

c      write(6,*) 'f_delay    = ',f_delay
      
      dc_max = 0.0
      dc_min = 9.9
      do j = 0,dec_fac-1
         av = 0.0
         do i = 0,intp_lgt-1
            av = av + fintp(i + j*intp_lgt)
         enddo
         dc_min = min(dc_min,av)
         dc_max = max(dc_max,av)
      enddo
      av = 0.5 * (dc_max+dc_min)
      do j=0,dec_fac*intp_lgt-1
         fintp(j) = fintp(j)/av
      end do
      
c      write(6,*) 'dc_min   = ',dc_min/av
c      write(6,*) 'dc_max   = ',dc_max/av
      
      return
      end
      
      complex*8 function sinc_eval(arrin,nsamp,intarr,idec,ilen,intp,frp)
      
      integer ilen,idec,intp, nsamp
      real*8 frp
      complex arrin(0:nsamp-1)
      real*4 intarr(0:idec*ilen-1)

      sinc_eval = cmplx(0.,0.)
      if(intp .ge. ilen-1 .and. intp .lt. nsamp ) then
         ifrac= min(max(0,int(frp*idec)),idec-1)
         do k=0,ilen-1
            sinc_eval = sinc_eval + arrin(intp-k)*
     +           intarr(k + ifrac*ilen)
         enddo
      end if

      end


c****************************************************************

      subroutine sinc_coef(r_beta,r_relfiltlen,i_decfactor,r_pedestal,
     +     i_weight,i_intplength,i_filtercoef,r_filter)

c****************************************************************
c**     
c**   FILE NAME: sinc_coef.f
c**     
c**   DATE WRITTEN: 10/15/97
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: The number of data values in the array 
c**   will always be the interpolation length * the decimation factor, 
c**   so this is not returned separately by the function.
c**     
c**   ROUTINES CALLED:
c**     
c**   NOTES: 
c**     
c**   UPDATE LOG:
c**
c**   Date Changed        Reason Changed                  CR # and Version #
c**   ------------       ----------------                 -----------------
c**     
c*****************************************************************

      implicit none

c     INPUT VARIABLES:

      real*8 r_beta             !the "beta" for the filter
      real*8 r_relfiltlen       !relative filter length
      integer i_decfactor       !the decimation factor
      real*8 r_pedestal         !pedestal height
      integer i_weight          !0 = no weight , 1=weight
	
c     OUTPUT VARIABLES:
      
      integer i_intplength      !the interpolation length
      integer i_filtercoef      !number of coefficients
      real*8 r_filter(*)        !an array of data values 

c     LOCAL VARIABLES:

      real*8 r_alpha,pi,r_wgt,r_s,r_fct,r_wgthgt,r_soff,r_wa
      integer i_psfl,i,j,ii

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

C     FUNCTION STATEMENTS:

c     PROCESSING STEPS:

      pi = 4.d0*atan(1.d0)

c     number of coefficients

      i_intplength = nint(r_relfiltlen/r_beta)
      i_filtercoef = i_intplength*i_decfactor
      r_wgthgt = (1.d0 - r_pedestal)/2.d0
      r_soff = (i_filtercoef - 1.d0)/2.d0
      
      do i=0,i_filtercoef-1
         r_wa = i - r_soff
         r_wgt = (1.d0 - r_wgthgt) + r_wgthgt*cos((pi*r_wa)/r_soff)
         j = i - (i_filtercoef - 1.d0)/2.d0
         r_s = dble(j)*r_beta/dble(i_decfactor)
         if(r_s .ne. 0.0)then
            r_fct = sin(pi*r_s)/(pi*r_s)
         else
            r_fct = 1.0
         endif
         if(i_weight .eq. 1)then
            r_filter(i+1) = r_fct*r_wgt
         else
            r_filter(i+1) = r_fct
         endif
      enddo

      end

cc-------------------------------------------

      real*4 function seconds(t0)
      real*4 t0
      real*8 secondo

      seconds = secondo(-1) - t0

      return
      end

CPOD      
CPOD=pod
CPOD
CPOD=head1 USAGE
CPOD
CPOD Usage: resamp_rti cmd_file 
CPOD
CPOD where cmd_file is the name of the command file (= RDF ascii formatted file).
CPOD
CPOD
CPOD=head1 FUNCTION
CPOD
CPOD FUNCTIONAL DESCRIPTION: Interferes two SLC images 
CPOD range, azimuth interpolation with a quadratic or sinc interpolator 
CPOD no circular buffer is used, rather a batch algorithm is implemented
CPOD The calculation of the range and azimuth offsets is done for
CPOD each of the data sets in the offset data file. As soon as the
CPOD current line number exceeds the range line number for one of the
CPOD data sets in the offset data file, the new lsq coefficients are
CPOD to calculate the offsets for any particular range pixel. 
CPOD Looks are taken in azimuth and range as requested.
CPOD
CPOD=head1 ROUTINES CALLED
CPOD
CPOD funcs, intp_coefg, sinc_coef
CPOD
CPOD=head1 CALLED BY
CPOD
CPOD
CPOD=head1 FILES USED
CPOD
CPOD Program reads in an RDF command file
CPOD
CPOD Command file Listing:
CPOD =====================
CPOD Image Offset File Name                                (-) =    cull.out
CPOD Display Fit Statistics to Screen                      (-) =    Show Fit Stats     ![Show Fit Stats , No Fit Stats]
CPOD Number of Fit Coefficients                            (-) =        3
CPOD SLC Image File 1                                      (-) =  /u/argus0/er/IFSAR_LASER/SIRC_DATA/MAHANT_1/mah_1.shh 
CPOD Number of Range Samples Image 1                       (-) =   1160
CPOD SLC Image File 2                                      (-) =   /u/argus0/er/IFSAR_LASER/SIRC_DATA/MAHANT_2/mah_2.shh   
CPOD Number of Range Samples Image 2                       (-) =   1160
CPOD Output Interferogram File                             (-) = mah_Lhh.int              
CPOD Multi-look Amplitude File                             (-) = mah_Lhh.amp
CPOD Starting Line, Number of Lines, and First Line Offset (-) =  1    2000    3107
CPOD Doppler Quadractic Fit Coefficients - PRF Units       (-) = -0.06   0     0  
CPOD Radar Wavelength                                      (m) =  0.2400894        
CPOD Slant Range Pixel Spacing                             (m) =  6.66212409  
CPOD Number of Range and Azimuth Looks                     (-) =  1   4
CPOD
CPOD
CPOD Program reads in two flat, binary, image files;
CPOD each pixel in the image files are 8 byte complex numbers:
CPOD "SLC Image File 1" and "SLC Image File 2".
CPOD Record length: "Number of Range Samples Image 1/2"
CPOD 
CPOD Program reads in an ascii-formatted correlation offset file
CPOD "Image Offset File Name" (cull.out in RDF above)
CPOD  with entries: 
CPOD  Range    R offset     Azimuth    Az offset     SNR
CPOD
CPOD=head1 FILES CREATED
CPOD
CPOD "Output Interferogram File"  (cull.out in RDF above) 
CPOD "Multi-look Amplitude File"  (cull.out in RDF above)
CPOD
CPOD=head1 DIAGNOSTIC FILES
CPOD
CPOD Code has option to dump image chip
CPOD purposes in addition to the normal
CPOD
CPOD=head1 HISTORY
CPOD
CPOD Original Routines: Charles Werner, Paul Rosen and Scott Hensley, Soren(?)
CPOD
CPOD=head1 LAST UPDATE
CPOD  Date Changed        Reason Changed 
CPOD  ------------       ----------------
CPOD    20-apr-92    added removal/reinsertion of range phase slope to 
CPOD                 improve correlation
CPOD    11-may-92    added code so that the last input block of data is processed
CPOD                 even if partially full
CPOD    9-jun-92     modified maximum number of range pixels
CPOD    17-nov-92    added calculation of the range phase shift/pixel
CPOD    29-mar-93    write out multi-look images (intensity) of the two files 
CPOD    93-99        Stable with small enhancements changes
CPOD    Dec 99       Modified range interpolation to interpret (correctly)
CPOD                 the array indices to be those of image 2 coordinates.  
CPOD                 Previous code assumed image 1, and therefore used 
CPOD                 slightly wrong offsets for range resampling depending
CPOD                 on the gross offset between images.  Mods involve computing
CPOD                 the inverse mapping
CPOD
CPOF CPOD: trm Nov 24th '03
CPOD=cut

