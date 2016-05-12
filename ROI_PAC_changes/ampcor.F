c****************************************************************

      Program ampcor
      
c****************************************************************
c**   
c**   FILE NAME: ampcor.f
c**   
c**   DATE WRITTEN: /10/10/92
c**   
c**   PROGRAMMER: Scott Hensley / Scott Shaffer
c**   
c**   FUNCTIONAL DESCRIPTION: This program will perform an amplitude
c**   normalized cross correlation and will give an estimate of the
c**   quality ls of the match.
c**   
c**   ROUTINES CALLED: correlate,fourn
c**   
c**   NOTES: 
c**   
c**   x = samples , y = lines   , i = reference , j = search
c**   
c**   UPDATE LOG:
c*****************************************************************
c**      minor mods to format statements for g95 compatibility, larger offsets
c**         EJF 2005/5/12 
c** 
c**      another change to format statement to allow az. offsets more negative
c**          than -100000 EJF 2005/7/6
c**
c**      increased parameters i_idx, i_idy and i_maxlines to allow larger search radius EJF 2007/8/20
c**     
c**      changed read statements to return and check error flag value EJF 2007/8/23
c**
c**      changed i_idx, i_idy in correlate subroutine to match main EJF 2007/8/27
c**
c**      added scale factor and list feature SH 2007/10/29
c**
c**      added scale factor and list feature SH 2007/10/29
CPOD      
CPOD=pod
CPOD
CPOD=head1 USAGE
CPOD
CPOD ampcor input_file RDF
CPOD
CPODwhere input_file is the name of the RDF formatted input file
CPOD
CPOD
CPOD=head1 FUNCTION
CPOD
CPODThis program will perform an amplitude
CPODnormalized cross correlation and will give an estimate of the
CPODquality of the match.
CPOD
CPODThe program cross correlates image chips throughout the file.
CPODThe ampcor output file contains the  parameters
CPODfor each chip match.  Specifically it contains: the
CPODlocation of the chip, the shifts along and across track
CPODbetween the chips, the signal to noise ratio, and
CPODthe covariance of the cross correlation.
CPOD
CPOD=head1 ROUTINES CALLED
CPOD
CPOD cfft1d_jpl, 
CPOD nextpower, 
CPOD rdflen, rdfval, 
CPOD rdf_clear, rdf_init, rdf_read
CPOD
CPOD=head1 CALLED BY
CPOD
CPOD
CPOD
CPOD=head1 FILES USED
CPOD
CPODProgram reads in an RDF command file.
CPOD
CPODProgram reads in two flat, binary, image files.
CPODEach pixel in the image files are generally, but not always,
CPOD8 byte complex numbers.  Code also allows input files to be 4 
CPODbyte real numbers.
CPODThe files contain the images to be matched to each other.
CPOD
CPOD=head1 FILES CREATED
CPOD
CPODOnly output file is a formatted ASCII columnar file which contains 1
CPODline per match.  For each match the line contains the following
CPODinformation:
CPOD1) the across track reference image center pixel number,
CPOD2) the across track shift in pixels between images,
CPOD3) the along track reference image center pixel number,
CPOD4) the along track shift in pixels between images,
CPOD5) the SNR match quality indicator, and
CPOD6) the three components of the match covariance.
CPOD
CPODA good fit has a large signal to noise ratio and
CPODsmall covariances.  
CPODWell registered data has small values for the
CPODrange and azimuth offsets.
CPOD
CPODNote that the ampcor output file is written with
CPODa FORTRAN formatted write statement.
CPODThe key point to note about this is the the formatting
CPODlimits the largest and smallest value that can possibly
CPODbe written.  For example, if one of the covariance terms
CPODis less than -99.999999 or greater than 999.999999 then
CPODwhat is written into the file for that number is asterisks.
CPOD
CPOD=head1 DIAGNOSTIC FILES
CPOD
CPODCode has option to dump image chips for diagnostic
CPODpurposes in addition to the normal ampcor output files.
CPOD
CPOD=head1 HISTORY
CPOD
CPODOriginal Routines: Scott Hensley and Scott Shaffer
CPODEditted over the Years repeatedly
CPOD
CPOD=head1 LAST UPDATE
CPOD
CPODElaine Chapin, 19 Nov. 2003
CPOD
CPOD=cut
      
      implicit none

c     PARAMETER STATEMENTS:

      integer i_idx,i_idy,i_maxlines,i_maxsamp
      integer i_ovs,i_srchpp,i_covsm,i_cwm
      parameter(i_idx=2048) ! was 512
      parameter(i_idy=2048) ! was 512
c      parameter(i_maxsamp=25000)
      parameter(i_maxsamp=30000)
      parameter(i_maxlines=2048)
      parameter(i_ovs=2)
      parameter(i_srchpp=4)
      parameter(i_covsm=64)     !64
      parameter(i_cwm=16)       !4

      integer i_dump_images,i_sinc_fourier,i_sinc,i_fourier
      parameter(i_dump_images=0,i_sinc=1,i_fourier=2) !i_dump_images=1 means dump debug feature is on
      parameter(i_sinc_fourier=i_sinc)

      integer i_new,i_old,i_rdf,i_rds,i_real,i_complex,i_rmg1,i_rmg2
      parameter(i_new=1,i_old=2,i_rdf=3,i_rds=4,i_real=1,i_complex=2,i_rmg1=3,i_rmg2=4)

      integer i_sinc_window
      parameter(i_sinc_window=2)

      integer MAXDECFACTOR      ! maximum lags in interpolation kernels
      parameter(MAXDECFACTOR=4096)                        
      
      integer MAXINTKERLGH      ! maximum interpolation kernel length
      parameter (MAXINTKERLGH=256)
      
      integer MAXINTLGH         ! maximum interpolation kernel array size
      parameter (MAXINTLGH=MAXINTKERLGH*MAXDECFACTOR)

      integer i_list,i_nolist              !match location in a list file
      parameter(i_list=1,i_nolist=0)

      integer i_listonly,i_xtlist,i_atlist,i_pairlist
      parameter(i_listonly=1,i_xtlist=2,i_atlist=3,i_pairlist=4)

      integer MAXPNTS
      parameter(MAXPNTS=5000000)
      
      integer i_log             ! LFN for log file/screen as appropriate
      parameter (i_log=6)

c     INPUT VARIABLES:

      integer i_wsyi,i_wsxi,i_wsyj,i_wsxj,i_avgy,i_avgx,i_srchx,i_srchy
      integer i_index,i_indexi
      integer i_grossx,i_grossy,i_strtsamp,i_ovss
      integer i_endsamp,i_skipsamp,i_samples(2),i_strtline
      integer i_endline,i_skipline,i_srchp,i_centeryip
      real*4 r_covth,r_snrth
      character*120 a_cmdfile,a_imgfile1,a_imgfile2,a_outfile

c     OUTPUT VARIABLES:

      integer i_shiftx,i_shifty
      real*4 r_shfty,r_shftx,r_peak,r_meani,r_meanj
      real*4 r_stdvi,r_stdvj,r_noise,r_cov(3),r_eval1
      real*4 r_eval2,r_evec1(2),r_evec2(2)
      integer i_flag,i_edge(2)

c     LOCAL VARIABLES:

      character*255 a_rdfbuf,a_rdtmp
      character*120 a_debugfile

      integer i_x,i_xx
      integer i_y,i_yy,i_covs,i_cw,i_data_off(2),i_rmg(2)

      real r_imgi,r_imgj,r_imgc,r_snr,r_outside
      real r_offsetx,r_offsety,r_peakk(2)
      real r_a0,r_b0,r_c0
      complex c_refimg,c_srchimg
      real r_refimg,r_srchimg
      dimension r_imgi(i_idx,i_idy)
      dimension r_imgj(i_idx,i_idy)
      dimension r_imgc(i_idx,i_idy)
      dimension c_refimg(i_maxsamp,i_maxlines)      
      dimension c_srchimg(i_maxsamp,i_maxlines)
      dimension r_refimg(i_maxsamp,i_maxlines)      
      dimension r_srchimg(i_maxsamp,i_maxlines)
      integer i_wxd,i_wyd,i_q,i_qq,i_centerxj,i_centeryj
      integer i,j,k,l,i_centerxi,i_centeryi,i_cnta,i_xp,i_yp
      logical l_debug,l_display
      complex c_chipref(i_idx*i_idy)
      complex c_chipsch(i_idx*i_idy)
      complex c_ossch(i_ovs*i_idx*i_ovs*i_idy)
      complex c_osref(i_ovs*i_idx*i_ovs*i_idy)
      integer i_nn(2),i_dem,i_dir,i_shiftxos,i_shiftyos,i_inarg,i_nnphy(2),i_unit
      real r_peakos,r_shftxos,r_shftyos,r_covos(3),r_snros
      real r_shftxosc,r_shftyosc,r_mean_cor
      integer i_wsxios,i_wsyios,i_wsxjos,i_wsyjos,i_wsox,i_wsoy,i_status
      real r_maxi,r_maxj
      integer ncr,i_wsxjp,i_wsyjp,i_n2wsxi,i_n2wsyi,i_n2wsxj,i_n2wsyj
      byte b_imgi(i_idx,i_idy),b_imgj(i_idx,i_idy)
      integer i_input_style,i_datatype(2)
      character*3 a_style
      character*10 a_datatype(2)

      integer i_iout,i_jout,i_frac,i_index2,i_index3
      real r_iout,r_jout,r_sincwgt,r_frac

      real    r_corr(i_covsm*i_cwm,i_covsm*i_cwm)
      complex c_corr(i_covsm*i_cwm*i_covsm*i_cwm),c_dataout(i_covsm*i_cwm*i_cwm),c_dataout2(i_covsm*i_cwm*i_covsm*i_cwm)
      complex c_corrt(i_cwm*i_cwm)

      integer i_cpeak(2),iargc,i_px,i_py,i_p1,i_p2
      real r_max,r_oscoroff(2)
      real r_csrchx,r_csrchy

      integer i_select,i_weight
      integer i_numset
      integer i_err

      integer i_decfactor       ! Range migration decimation Factor
      integer i_intplength      ! Range migration interpolation kernel length
      real*4  r_fdelay          ! Range migration filter delay
      real*4 r_fintp(0:MAXINTLGH) ! interpolation kernel values
      real*8 r_relfiltlen,r_pedestal,r_beta      

      integer*4 ii, jj
      logical ll

      character*120 a_listfile,a_list,a_listtype
      integer i_listfile,i_pixlocation

      integer i_xtloc(MAXPNTS),i_atloc(MAXPNTS),i_locpnts,i_kx,i_ky,i_atpnts,i_xtpnts
      integer i_xtloc2(MAXPNTS),i_atloc2(MAXPNTS)

      integer i_keyindex,i_xlu,i_ylu
      real*4 r_scalex,r_scaley

c     SAVE STATEMENTS:

      save r_imgi,r_imgj,r_imgc,c_refimg,c_srchimg,r_refimg,r_srchimg
      save c_chipref,c_chipsch,c_osref,c_ossch,r_corr,c_corr,c_corrt,c_dataout,c_dataout2
      save i_xtloc,i_atloc,i_xtloc2,i_atloc2

c     FUNCTION STATEMENTS:

      integer nextpower
      integer*4     rdflen,rdfindx
      character*255 rdfval,rdfcullsp,rdfdata,rdflower

c     PROCESSING STEPS:

      write(6,*) '  '
      write(6,*) '   <<  Amplitude Cross Correlation of Complex or Real Data >>   '
      write(6,*) '  '

      i_datatype(1) = i_complex
      i_datatype(2) = i_complex
      i_data_off(1) = 0
      i_data_off(2) = 0
      i_input_style = i_rdf
      i_covs = 32
      i_cw = 16
      a_datatype(1) = 'complex'
      a_datatype(2) = 'complex'
      i_listfile = i_nolist
      i_pixlocation = i_nolist

c     sinc interploation kernel

      i_decfactor = 4096
      i_weight = 1
      r_pedestal = 0.0
      r_beta = .75
      r_relfiltlen = 6.0

      call fill_sinc(r_beta,r_relfiltlen,i_decfactor,i_weight,r_pedestal,i_intplength,r_fdelay,r_fintp) 

      i_inarg = iargc()
      if(i_inarg .eq. 0)then
         write(6,'(a)') 'Usage: ampcor input_file [input style] [-l list_file]'
         write(6,'(a)') '   If input style = old then uses old ASCII input file (default).'
         write(6,'(a)') '   If input style = new then uses old ASCII input file plus oversample input data.'
         write(6,'(a)') '   If input style = rdf then uses RDF input file.'
         write(6,'(a)') '   If input style = rds then uses RDF input file with matching scale option.'
         write(6,'(a)') '   If input style = tmp then writes a template file into input_file'
         write(6,'(a)') '   If supply list file then used to determine match locations - only for RDF input file'
         write(6,*) ' '
         stop
      endif

      do i=3,14
         k=2**i
         call cfft1d_jpl(k,c_osref,0)
      end do

      call getarg(1,a_cmdfile)
      if(iargc() .gt. 1)then
         call getarg(2,a_style)
         if(index(a_style,'-l') .ne. 0)then
            call getarg(3,a_listfile)
            i_listfile = i_list
         else
            if(index(a_style,'old') .ne. 0)then
               i_input_style = i_old
            elseif(index(a_style,'new') .ne. 0)then
               i_input_style = i_new
            elseif(index(a_style,'rdf') .ne. 0)then
               i_input_style = i_rdf
            elseif(index(a_style,'rds') .ne. 0)then
               i_input_style = i_rds
            elseif(index(a_style,'tmp') .ne. 0)then
               i_unit = 12
            endif
         endif
      endif

      if(iargc() .gt. 2)then
         call getarg(3,a_list)
         if(index(a_list,'-l') .ne. 0)then
            call getarg(4,a_listfile)
            i_listfile = i_list
         endif
      endif

      if(index(a_style,'tmp') .ne. 0)then
         i_unit = 12
         open(i_unit,file=a_cmdfile,status='unknown')
         call write_template(i_unit,i_listfile)
         stop
      endif

 100  format(x,a,$) 
 101  format(a)

      if(i_input_style .eq. i_old .or. i_input_style .eq. i_new)then

         open(12,file=a_cmdfile,status='old')
         
         read(12,101) a_imgfile1
         read(12,101) a_imgfile2
         read(12,101) a_outfile
         read(12,*) i_samples(1),i_samples(2)
         read(12,*) i_strtline,i_endline,i_skipline
         read(12,*) i_strtsamp,i_endsamp,i_skipsamp
         read(12,*) i_wsxi,i_wsyi
         read(12,*) i_srchx,i_srchy
         read(12,*) i_avgx,i_avgy
         read(12,*) i_grossx,i_grossy
         read(12,*) r_snrth,r_covth
         read(12,*) l_debug,l_display

         if(i_input_style .eq. i_new)then
            read(12,*) i_covs,i_cw
            read(12,'(a)') a_datatype(1)
            read(12,'(a)') a_datatype(2)
         else
            i_covs = 32
            i_cw = 16
         endif

      elseif(i_input_style .ge. i_rdf)then

         call rdf_clear()
         
         call rdf_init('ERROR_SCREEN=ON')
         call rdf_init('ERROR_OUTPUT=rdf_errors.log')
         call rdf_read(a_cmdfile)

         a_rdfbuf = rdfval('Data Type for Reference Image Real or Complex','-')
         read(unit=a_rdfbuf,fmt='(a)') a_datatype(1)
         a_rdfbuf = rdfval('Data Type for Search  Image Real or Complex','-')
         read(unit=a_rdfbuf,fmt='(a)') a_datatype(2)

         a_rdfbuf = rdfval('Reference Image Input File','-')
         read(unit=a_rdfbuf,fmt='(a)') a_imgfile1
         a_rdfbuf = rdfval('Search Image Input File','-')
         read(unit=a_rdfbuf,fmt='(a)') a_imgfile2
         a_rdfbuf = rdfval('Match Output File','-')
         read(unit=a_rdfbuf,fmt='(a)') a_outfile

         if(i_listfile .eq. i_list)then
            a_rdfbuf = rdfval('List File Type','-')
            read(unit=a_rdfbuf,fmt='(a)') a_listtype
            if(index(a_listtype,'Ref Only') .ne. 0)then
               i_pixlocation = i_listonly
            elseif(index(a_listtype,'XT Only') .ne. 0)then
               i_pixlocation = i_xtlist
            elseif(index(a_listtype,'AT Only') .ne. 0)then
               i_pixlocation = i_atlist
            elseif(index(a_listtype,'Pair List') .ne. 0)then
               i_pixlocation = i_pairlist
            endif
         endif

         a_rdfbuf = rdfval('Number of Samples in Reference/Search Images','-')
         read(unit=a_rdfbuf,fmt=*) i_samples(1),i_samples(2)
         a_rdfbuf = rdfval('Start, End and Skip Lines in Reference Image','-')
         read(unit=a_rdfbuf,fmt=*) i_strtline,i_endline,i_skipline
         a_rdfbuf = rdfval('Start, End and Skip Samples in Reference Image','-')
         read(unit=a_rdfbuf,fmt=*) i_strtsamp,i_endsamp,i_skipsamp

         a_rdfbuf = rdfval('Reference Window Size Samples/Lines','-')
         read(unit=a_rdfbuf,fmt=*) i_wsxi,i_wsyi
         a_rdfbuf = rdfval('Search Pixels Samples/Lines','-')
         read(unit=a_rdfbuf,fmt=*) i_srchx,i_srchy
         a_rdfbuf = rdfval('Pixel Averaging Samples/Lines','-')
         read(unit=a_rdfbuf,fmt=*) i_avgx,i_avgy
         a_rdfbuf = rdfval('Covariance Surface Oversample Factor and Window Size','-')
         read(unit=a_rdfbuf,fmt=*) i_covs,i_cw
         a_rdfbuf = rdfval('Mean Offset Between Reference and Search Images Samples/Lines','-')
         read(unit=a_rdfbuf,fmt=*) i_grossx,i_grossy

         r_scalex = 1.0
         r_scaley = 1.0

         if(i_input_style .ge. i_rds)then
            i_keyindex = 0
            i_keyindex = rdfindx('Matching Scale for Sample/Line Directions')
            if(i_keyindex .gt. 0)then
               a_rdtmp = rdfval('Matching Scale for Sample/Line Directions','-')
               read(unit=a_rdtmp,fmt=*) r_scalex,r_scaley
            else
               r_scalex = 1.0
               r_scaley = 1.0
            endif
         endif
            
         a_rdfbuf = rdfval('SNR and Covariance Thresholds','-')
         read(unit=a_rdfbuf,fmt=*) r_snrth,r_covth
         a_rdfbuf = rdfval('Debug and Display Flags T/F','-')
         read(unit=a_rdfbuf,fmt=*) l_debug,l_display

      endif

      if(index(a_datatype(1),'complex') .ne. 0 .or. index(a_datatype(1),'Complex') .ne. 0)then
         i_datatype(1) = i_complex
         i_rmg(1) = 1   
      elseif(index(a_datatype(1),'real') .ne. 0 .or. index(a_datatype(1),'Real') .ne. 0)then
         i_datatype(1) = i_real
         i_data_off(1) = 0
         i_rmg(1) = 1   
      elseif(index(a_datatype(1),'RMG1') .ne. 0 .or. index(a_datatype(1),'rmg1') .ne. 0)then
         i_datatype(1) = i_real
         i_data_off(1) = 0
         i_rmg(1) = 2   
      elseif(index(a_datatype(1),'RMG2') .ne. 0 .or. index(a_datatype(1),'rmg2') .ne. 0)then
         i_datatype(1) = i_real
         i_data_off(1) = i_samples(1)
         i_rmg(1) = 2   
      endif

      if(index(a_datatype(2),'complex') .ne. 0 .or. index(a_datatype(2),'Complex') .ne. 0)then
         i_datatype(2) = i_complex
         i_rmg(2) = 1   
      elseif(index(a_datatype(2),'real') .ne. 0 .or. index(a_datatype(2),'Real') .ne. 0)then
         i_datatype(2) = i_real
         i_data_off(2) = 0
         i_rmg(2) = 1   
      elseif(index(a_datatype(2),'RMG1') .ne. 0 .or. index(a_datatype(2),'rmg1') .ne. 0)then
         i_datatype(2) = i_real
         i_data_off(2) = 0
         i_rmg(2) = 2   
      elseif(index(a_datatype(2),'RMG2') .ne. 0 .or. index(a_datatype(2),'rmg2') .ne. 0)then
         i_datatype(2) = i_real
         i_data_off(2) = i_samples(2)
         i_rmg(2) = 2   
      endif
      
      i_srchx = max(i_srchx,1)
      i_srchy = max(i_srchy,1)

      i_wsxj = i_wsxi+2*i_srchx
      i_wsyj = i_wsyi+2*i_srchy

      i_srchp = min(i_srchy,i_srchx,i_srchpp) 

      i_wsxjp = i_wsxi + 2*i_srchp
      i_wsyjp = i_wsyi + 2*i_srchp

      i_n2wsxi = 2**(nextpower(i_wsxi))
      i_n2wsyi = 2**(nextpower(i_wsyi))

      i_n2wsxj = 2**(nextpower(i_wsxjp))
      i_n2wsyj = 2**(nextpower(i_wsyjp))

c-------------------------------
c        begin ruggedize ... a bunch of input checking

         if(i_datatype(1).ne.i_complex .and. i_datatype(1).ne.i_real)then
           write(i_log,'(a)') 'WARNING - Do not understand data type for reference image'
           write(i_log,'(a,i1,a,i1,a)') 'Expecting flag to be real (',i_real,') or complex (',i_complex,')'
           write(i_log,'(a,i10)') 'Data type flag set to ',i_datatype(1)
           i_datatype(1) = i_complex
          write(i_log,'(a,i1,a)') 'Resetting type flag to be complex (',i_complex,')' 
          write(i_log,'(a)') ' '
         endif
         if(i_datatype(2).ne.i_complex .and. i_datatype(2).ne.i_real)then
           write(i_log,'(a)') 'WARNING - Do not understand data type for search image'
           write(i_log,'(a,i1,a,i1,a)') 'Expecting flag to be real (',i_real,') or complex (',i_complex,')'
           write(i_log,'(a,i10)') 'Data type flag set to ',i_datatype(2)
           i_datatype(2) = i_complex
          write(i_log,'(a,i1,a)') 'Resetting type flag to be complex (',i_complex,')' 
          write(i_log,'(a)') ' '
         endif

         inquire(file=a_imgfile1,iostat=ii,exist=ll)
         if(.not.ll .or. ii.ne.0)then
           write(i_log,'(a)') 'ERROR - Reference Image File Does Not Exist'
           write(i_log,'(a)') 'Looked for file '//a_imgfile1
           stop
         endif
         inquire(file=a_imgfile2,iostat=ii,exist=ll)
         if(.not.ll .or. ii.ne.0)then
           write(i_log,'(a)') 'ERROR - Search Image File Does Not Exist'
           write(i_log,'(a)') 'Looked for file '//a_imgfile2
           stop
         endif


         if(i_samples(1).gt.i_maxsamp)then
           write(i_log,'(a)') 'ERROR - Requesting processing of too wide a file'
           write(i_log,'(a,1x,i10,a)') '             Image 1 width is ',i_samples(1),' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed file width is ',i_maxsamp   ,' pixels'
           stop
         endif
         if(i_samples(2).gt.i_maxsamp)then
           write(i_log,'(a)') 'ERROR - Requesting processing of too wide a file'
           write(i_log,'(a,1x,i10,a)') '             Image 2 width is ',i_samples(2),' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed file width is ',i_maxsamp   ,' pixels'
           stop
         endif



c        read in i_wsyi lines of data into the refimg buffer for each chip
c        read in i_wsyj=i_wsyi+2*i_srchy lines of data into the srchimg buffer for each chip
c        read in i_wsxi samples of data into the refimg buffer for each chip
c        read in i_wsxj=i_wsxi+2*i_srchx samples of data into the srchimg buffer for each chip

         if(i_wsxi.gt.i_idx)then
           write(i_log,'(a)') 'ERROR - Requesting too wide a reference image chip'
           write(i_log,'(a,1x,i10,a)') 'Reference image real chip length is ',i_wsxi,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed real chip length is ',i_idx ,' pixels'
           stop
         endif

         if(i_wsxj.gt.i_idx)then
           write(i_log,'(a)') 'ERROR - Requesting too wide a search image chip'
           write(i_log,'(a,1x,i10,a)') 'Search    image real chip length is ',i_wsxj,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed real chip length is ',i_idx ,' pixels'
           write(i_log,'(a)') 'Search image chip is (Ref Window Size)+(2*Search Pixels)'
           write(i_log,'(a,1x,i10,a)') 'Reference Window Size is            ',i_wsxi ,' sample pixels'
           write(i_log,'(a,1x,i10,a)') 'Number of Search Pixels is          ',i_srchx ,' sample pixels'
           stop
         endif

         if(i_srchx.lt.5)then
           write(i_log,'(a)') 'CAUTION - Requesting very small search window pull in'
           write(i_log,'(a,1x,i10,a)') 'Reference Window Size is             ',i_wsxi ,' sample pixels'
           write(i_log,'(a,1x,i10,a)') 'Number of Search Pixels is           ',i_srchx ,' sample pixels'
           write(i_log,'(a)') 'The rule of thumb is that the search window pull in is at least 5'
           write(i_log,'(a)') 'pixels and is less than the reference window size divided by 5. '
           jj = max(5,nint(float(i_wsxi)/6.0))
           write(i_log,'(a,1x,i10,a)') 'Suggested Number of Search Pixels is ',jj,' sample pixels'
           write(i_log,'(a)') ' '
         endif

         ii = nint(float(i_wsxi)/float(i_srchx))
         if(ii.lt.5)then
           write(i_log,'(a)') 'CAUTION - Requesting very large search window pull in'
           write(i_log,'(a,1x,i10,a)') 'Reference Window Size is             ',i_wsxi ,' sample pixels'
           write(i_log,'(a,1x,i10,a)') 'Number of Search Pixels is           ',i_srchx ,' sample pixels'
           write(i_log,'(a)') 'The rule of thumb is that the search window pull in is at least 5'
           write(i_log,'(a)') 'pixels and is less than the reference window size divided by 5. '
           jj = max(5,nint(float(i_wsxi)/6.0))
           write(i_log,'(a,1x,i10,a)') 'Suggested Number of Search Pixels is ',jj,' sample pixels'
           write(i_log,'(a)') ' '
           write(i_log,'(a)') ' '
         endif

         if(i_srchy.lt.5)then
           write(i_log,'(a)') 'CAUTION - Requesting very small search window pull in'
           write(i_log,'(a,1x,i10,a)') 'Reference Window Size is             ',i_wsyi ,' line pixels'
           write(i_log,'(a,1x,i10,a)') 'Number of Search Pixels is           ',i_srchy ,' line pixels'
           write(i_log,'(a)') 'The rule of thumb is that the search window pull in is at least 5'
           write(i_log,'(a)') 'pixels and is less than the reference window size divided by 5. '
           jj = max(5,nint(float(i_wsyi)/6.0))
           write(i_log,'(a,1x,i10,a)') 'Suggested Number of Search Pixels is ',jj,' line pixels'
           write(i_log,'(a)') ' '
         endif

         ii = nint(float(i_wsyi)/float(i_srchy))
         if(ii.lt.5)then
           write(i_log,'(a)') 'CAUTION - Requesting very large search window pull in'
           write(i_log,'(a,1x,i10,a)') 'Reference Window Size is             ',i_wsyi ,' line pixels'
           write(i_log,'(a,1x,i10,a)') 'Number of Search Pixels is           ',i_srchy ,' line pixels'
           write(i_log,'(a)') 'The rule of thumb is that the search window pull in is at least 5'
           write(i_log,'(a)') 'pixels and is less than the reference window size divided by 5. '
           jj = max(5,nint(float(i_wsyi)/6.0))
           write(i_log,'(a,1x,i10,a)') 'Suggested Number of Search Pixels is ',jj,' line pixels'
           write(i_log,'(a)') ' '
           write(i_log,'(a)') ' '
         endif

         if(i_wsyi.gt.i_maxlines .or.i_wsyi.gt.i_idy)then
           write(i_log,'(a)') 'ERROR - Requesting too long a reference image chip'
           write(i_log,'(a,1x,i10,a)') 'Reference image chip length is ',i_wsyi     ,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed complex chip length is ',i_maxlines,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed real chip length is ',i_idy,' pixels'
           stop
         endif
         if(i_wsyj.gt.i_maxlines .or. i_wsyj.gt.i_idy)then
           write(i_log,'(a)') 'ERROR - Requesting too long a search image chip'
           write(i_log,'(a,1x,i10,a)') 'Reference image chip length is ',i_wsyi    ,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Search pull in on each side is ',i_srchy   ,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Search    image chip length is ',i_wsyj    ,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed complex chip length is ',i_maxlines,' pixels'
           write(i_log,'(a,1x,i10,a)') 'Maximum allowed real chip length is ',i_idy,' pixels'
           stop
         endif

         if(i_cw.lt.8)then
           write(i_log,'(a)') 'WARNING - Covariance Surface Window Size Very Small'
           write(i_log,'(a)') 'It is the number of pixels in the Correlation Surface to oversample.'
           write(i_log,'(a)') 'Minimum Recommended Value for the Covariance Surface Window Size is 8.'
           write(i_log,'(a,1x,i3,a)') 'Requested covariance surface window size of ',i_cw,' pixels'
           write(i_log,'(a)') ' '
         endif

         if(i_covs*i_cw.gt.i_covsm*i_cwm)then
           write(i_log,'(a)')         'WARNING - Requesting too much oversampling of covariance'
           write(i_log,'(a,1x,i3)')   'Requested covariance surface oversample factor of ',i_covs
           write(i_log,'(a,1x,i3,a)') 'Requested covariance surface window size of       ',i_cw,' pixels'
           write(i_log,'(a,1x,i4,a)') 'Implies resolving shifts to 1/',i_covs*2,' of a pixel'
           write(i_log,'(a,1x,i10,a)')'Requested total array of dimension         ',i_covs*i_cw  ,' pixels'
           write(i_log,'(a,1x,i10,a)')'Maximum total array of dimension is        ',i_covsm*i_cwm,' pixels'
           write(i_log,'(a)')         'Resetting the covariance oversampling'
           ii = 8                      ! assume minimum surface window size
           jj = (i_covsm*i_cwm)/ii     ! calculate best possible oversample factor
           i_covs = min(jj,i_covs)     ! min that with requested factor
           i_cw = i_covsm*i_cwm/i_covs ! figure out the new box size
           write(i_log,'(a,1x,i4,a)') 'Now resolving shifts to 1/',i_covs*2,' of a pixel'
           write(i_log,'(a,1x,i3,a)') 'Updated covariance surface window size of         ',i_cw,' pixels'
           write(i_log,'(a,1x,i10,a)')'Now total array of dimension               ',i_covs*i_cw  ,' pixels'
           write(i_log,'(a)') ' '
         else
           write(i_log,'(a,1x,i4,a)') 'Requested resolving shifts to 1/',i_covs*2,' of a pixel'
           write(i_log,'(a)') ' '
         endif

         i_strtsamp = max(i_strtsamp,1)
         i_endsamp  = min(i_endsamp,i_samples(1))

         if(i_skipline.lt.i_wsyi .or. i_skipsamp.lt.i_wsxi)then
           write(i_log,'(a)') 'INFORMATION - you choose skips which are small for your window sizes'
           write(i_log,'(a)') 'Normally the skip size is bigger than the box size'
           write(i_log,'(a,i10,a,i10)') 'Across your skip is ',i_skipsamp,' but your window is ',i_wsxi
           write(i_log,'(a,i10,a,i10)') 'Down   your skip is ',i_skipline,' but your window is ',i_wsyi
           write(i_log,'(a)') 'This means that the image chips are larger than the separation between chips'
           write(i_log,'(a)') ' '
         endif

         if(i_wsxi*i_ovs.gt.i_idx)then
c          problem with the oversampled data (see second call to correlate)
           write(i_log,'(a)') 'ERROR - X Reference Window Samples Too Big'
           ii = i_idx/i_ovs
           write(i_log,'(a,i10)') 'Maximum value is    ',ii
           write(i_log,'(a,i10)') 'Your input value is ',i_wsxi
           write(i_log,'(a,i10)') 'Resetting Ref Window Samples to ',ii
           write(i_log,'(a)') ' '
           i_wsxi = ii
           i_wsxjp = i_wsxi + 2*i_srchp
           i_n2wsxi = 2**(nextpower(i_wsxi))
           i_n2wsxj = 2**(nextpower(i_wsxjp))
         endif
         if(i_wsyi*i_ovs.gt.i_idy)then
c          problem with the oversampled data (see second call to correlate)
           write(i_log,'(a)') 'ERROR - Y Reference Window Lines Too Big'
           ii = i_idy/i_ovs
           write(i_log,'(a,i10)') 'Maximum value is    ',ii
           write(i_log,'(a,i10)') 'Your input value is ',i_wsyi
           write(i_log,'(a,i10)') 'Resetting Ref Window Lines to ',ii
           write(i_log,'(a)') ' '
           i_wsyi = ii
           i_wsyjp = i_wsyi + 2*i_srchp
           i_n2wsyi = 2**(nextpower(i_wsyi))
           i_n2wsyj = 2**(nextpower(i_wsyjp))
         endif

         if(i_wsxjp*i_ovs.gt.i_idx)then
c          problem with the oversampled data (see second call to correlate)
c          i_idx >= (i_wsxi + 2*i_srchp)*i_ovs
           write(i_log,'(a)') 'ERROR - X Reference Window Samples Too Big'
           write(i_log,'(a)')'or Search Pixels Too Big for Oversampling'
           write(i_log,'(a,i10)') 'Your Input Ref Window Sample Value = ',i_wsxi
           write(i_log,'(a,i10)') 'Your Input Search Pixel Max = ',i_srchp
           write(i_log,'(a,i10)') 'Compiled Oversampling Factor = ',i_ovs
           ii = (i_idx/i_ovs)-(2*i_srchp)
           write(i_log,'(a,i10)') 'Resetting Ref Window Samples to ',ii
           write(i_log,'(a)') ' '
           i_wsxi = ii
           i_wsxjp = i_wsxi + 2*i_srchp
           i_n2wsxi = 2**(nextpower(i_wsxi))
           i_n2wsxj = 2**(nextpower(i_wsxjp))
           write(i_log,'(a)') ' '
         endif
         if(i_wsyjp*i_ovs.gt.i_idy)then
c          problem with the oversampled data (see second call to correlate)
c          i_idy >= (i_wsyi + 2*i_srchp)*i_ovs
           write(i_log,'(a)') 'ERROR - Y Reference Window Lines Too Big'
           write(i_log,'(a)')'or Search Pixels Too Big for Oversampling'
           write(i_log,'(a,i10)') 'Your Input Ref Window Sample Value = ',i_wsyi
           write(i_log,'(a,i10)') 'Your Input Search Pixel Max = ',i_srchp
           write(i_log,'(a,i10)') 'Compiled Oversampling Factor = ',i_ovs
           ii = (i_idy/i_ovs)-(2*i_srchp)
           write(i_log,'(a,i10)') 'Resetting Ref Window Samples to ',ii
           write(i_log,'(a)') ' '
           i_wsyi = ii
           i_wsyjp = i_wsyi + 2*i_srchp
           i_n2wsyi = 2**(nextpower(i_wsyi))
           i_n2wsyj = 2**(nextpower(i_wsyjp))
           write(i_log,'(a)') ' '
         endif

c        formatted write statement 151 has SNR as an f10.5
c        and the covariance as a f10.6.  This effectively
c        sets a range of covariance that can be written as
c        -99.999999 to 999.999999
c        write(15,151) i_centerxi,r_shftxosc,i_centeryi,r_shftyosc,
c    &                    r_snr,r_cov(1),r_cov(2),r_cov(3)
c151     format(x,i7,x,f10.3,x,i7,x,f10.3,x,f10.5,x,f10.6,x,f10.6,x,f10.6)
c        0987654321
c        i7:       9999999 is maximum lines or samples
c        f10.3:     -99999.999 is minimum shift
c        f10.5:       9999.99999
c        f10.6         999.999999
c        the covariance and SNR should always be greater than zero.

         r_covth = min(r_covth,999.999998)

c        in general, you want to be very lite on using the
c        SNR and Covariance thresholds.  The job of excluding
c        bad  matches is better done by the culling routine.


         if(i_data_off(1).ne.0 .and. i_data_off(1).ne.i_samples(1) .or.
     &     (i_data_off(1).ne.0 .and. i_rmg(1).lt.2)) then
           write(i_log,'(a)') 'WARNING - Do not understand band interleaved by layer offset'
           write(i_log,'(a,i10)') 'Expecting offset to be 0 or ',i_samples(1)
           write(i_log,'(a,i10)') 'Number of reference image layers set to ',i_rmg(1)
           write(i_log,'(a)') 'If only one layer then there can not be an offset'
           i_data_off(1) = 0
           write(i_log,'(a,i1)') 'Resetting offset to be ',i_data_off(1)
           write(i_log,'(a)') ' '
         endif
         if(i_rmg(1).ne.1 .and. i_rmg(1).ne.2)then
           write(i_log,'(a)') 'WARNING - Do not understand number of band interleaved by layer layers'
           write(i_log,'(a)') 'Expecting layers to be 1 or 2'
           write(i_log,'(a,i10)') 'Number of reference image layers set to ',i_rmg(1)
           i_rmg(1) = 1
           write(i_log,'(a,i1)') 'Resetting layers to be ',i_rmg(1)
           write(i_log,'(a)') ' '
         endif

         if(i_data_off(2).ne.0 .and. i_data_off(2).ne.i_samples(2) .or.
     &     (i_data_off(2).ne.0 .and. i_rmg(2).lt.2)) then
           write(i_log,'(a)') 'WARNING - Do not understand band interleaved by layer offset'
           write(i_log,'(a,i10)') 'Expecting offset to be 0 or ',i_samples(2)
           write(i_log,'(a,i10)') 'Number of search image layers set to ',i_rmg(2)
           write(i_log,'(a)') 'If only one layer then there can not be an offset'
           i_data_off(2) = 0
           write(i_log,'(a,i1)') 'Resetting offset to be ',i_data_off(2)
           write(i_log,'(a)') ' '
         endif
         if(i_rmg(2).ne.1 .and. i_rmg(2).ne.2)then
           write(i_log,'(a)') 'WARNING - Do not understand number of band interleaved by layer layers'
           write(i_log,'(a)') 'Expecting layers to be 1 or 2'
           write(i_log,'(a,i10)') 'Number of search image layers set to ',i_rmg(2)
           i_rmg(2) = 1
           write(i_log,'(a,i1)') 'Resetting layers to be ',i_rmg(2)
           write(i_log,'(a)') ' '
         endif

         i_avgx = max(1,i_avgx)
         i_avgy = max(1,i_avgy)
         if(i_avgx.gt.1 .or. i_avgy.gt.1)then
           write(i_log,'(a)')    'INFORMATION - You are looking down the data before cross correlation.'
           write(i_log,'(a,i4)') 'Averaging the samples across the file by a factor of ',i_avgx
           write(i_log,'(a,i4)') 'Averaging the lines   down   the file by a factor of ',i_avgy
           write(i_log,'(a)')    ' '
         endif

c        end ruggedize
c---------------------------------------------------------

c     open image files

      open(13,file=a_imgfile1,form='unformatted',recl=4*i_rmg(1)*i_datatype(1)*i_samples(1),access='direct')
      open(14,file=a_imgfile2,form='unformatted',recl=4*i_rmg(2)*i_datatype(2)*i_samples(2),access='direct')
      open(15,file=a_outfile,status='unknown')

c     read list file if specified

      if(i_listfile .eq. i_list)then
         
         open(20,file=a_listfile,status='old')
         
         if(i_pixlocation .eq. i_listonly)then
            
            i_locpnts = 1
            do while(i_locpnts .le. MAXPNTS)
               read(20,*,err=999) i_xtloc(i_locpnts),i_atloc(i_locpnts)
               i_locpnts = i_locpnts + 1
               if(i_locpnts .gt. MAXPNTS)then
                  write(6,*) ' '
                  write(6,'(a,i10)') '*** WARNING: EXCEEDED MAXIMUM POINTS ALLOWED - TRUNCATING LIST AT: ',MAXPNTS
               endif
            enddo
            
 999        i_locpnts = i_locpnts - 1

            write(6,*) ' '
            write(6,'(a,x,i10)') 'Number of points in list file: ',i_locpnts
            
         elseif(i_pixlocation .eq. i_atlist)then
            
            i_locpnts = 1
            do while(i_locpnts .le. MAXPNTS)
               read(20,*,err=998) i_atloc(i_locpnts)
               i_locpnts = i_locpnts + 1
               if(i_locpnts .gt. MAXPNTS)then
                  write(6,*) ' '
                  write(6,'(a,i10)') '*** WARNING: EXCEEDED MAXIMUM POINTS ALLOWED - TRUNCATING LIST AT: ',MAXPNTS
               endif
            enddo
            
 998        i_locpnts = i_locpnts - 1

            write(6,*) ' '
            write(6,'(a,x,i10)') 'Number of points in list file: ',i_locpnts
            
         elseif(i_pixlocation .eq. i_xtlist)then
            
            i_locpnts = 1
            do while(i_locpnts .le. MAXPNTS)
               read(20,*,err=997) i_xtloc(i_locpnts)
               i_locpnts = i_locpnts + 1
               if(i_locpnts .gt. MAXPNTS)then
                  write(6,*) ' '
                  write(6,'(a,i10)') '*** WARNING: EXCEEDED MAXIMUM POINTS ALLOWED - TRUNCATING LIST AT: ',MAXPNTS
               endif
            enddo
            
 997        i_locpnts = i_locpnts - 1

            write(6,*) ' '
            write(6,'(a,x,i10)') 'Number of points in list file: ',i_locpnts

         elseif(i_pixlocation .eq. i_pairlist)then
            
            i_locpnts = 1
            do while(i_locpnts .le. MAXPNTS)
               read(20,*,err=996) i_xtloc(i_locpnts),i_atloc(i_locpnts),i_xtloc2(i_locpnts),i_atloc2(i_locpnts)
               i_locpnts = i_locpnts + 1
               if(i_locpnts .gt. MAXPNTS)then
                  write(6,*) ' '
                  write(6,'(a,i10)') '*** WARNING: EXCEEDED MAXIMUM POINTS ALLOWED - TRUNCATING LIST AT: ',MAXPNTS
               endif
            enddo
            
 996        i_locpnts = i_locpnts - 1

            write(6,*) ' '
            write(6,'(a,x,i10)') 'Number of points in list file: ',i_locpnts
            
         endif 
         
      endif    !list file

c     set cross track and along track pixel locations

      if(i_pixlocation .eq. i_atlist)then

         i_xtpnts = 0
         do i_x=i_strtsamp+i_srchx,i_endsamp+i_srchx,i_skipsamp
            i_xtpnts = i_xtpnts + 1
            i_xtloc(i_xtpnts) = i_x
         enddo

         i_atpnts = i_locpnts
         do i_y=1,i_atpnts
            i_atloc(i_y) = i_atloc(i_y) - (i_wsyi-1)/2.
         enddo
         
      elseif(i_pixlocation .eq. i_xtlist)then

         i_atpnts = 0
         do i_y=i_strtline+i_srchy,i_endline+i_srchy,i_skipline
            i_atpnts = i_atpnts + 1
            i_atloc(i_atpnts) = i_y 
         enddo

         i_xtpnts = i_locpnts
         do i_x=1,i_xtpnts
            i_xtloc(i_x) = i_xtloc(i_x) - (i_wsxi-1)/2.
         enddo

      elseif(i_pixlocation .eq. i_listonly .or. i_pixlocation .eq. i_pairlist)then

         i_atpnts = i_locpnts
         i_xtpnts = 1
         do i_x=1,i_locpnts
            i_xtloc(i_x) = i_xtloc(i_x) - (i_wsxi-1)/2.
            i_atloc(i_x) = i_atloc(i_x) - (i_wsyi-1)/2.
            i_xtloc2(i_x) = i_xtloc2(i_x) - (i_wsxi-1)/2.
            i_atloc2(i_x) = i_atloc2(i_x) - (i_wsyi-1)/2.
         enddo

      elseif(i_pixlocation .eq. i_nolist)then

         i_atpnts = 0
         do i_y=i_strtline+i_srchy,i_endline+i_srchy,i_skipline
            i_atpnts = i_atpnts + 1
            i_atloc(i_atpnts) = i_y
         enddo

         i_xtpnts = 0
         do i_x=i_strtsamp+i_srchx,i_endsamp+i_srchx,i_skipsamp
            i_xtpnts = i_xtpnts + 1
            i_xtloc(i_xtpnts) = i_x
         enddo

      endif
      
c     begin loop over data

      write(6,*) ' '

      i_centeryip = -MAXPNTS

      do i_ky=1,i_atpnts

c     write(6,*) ' '
c     write(6,*) 'At line = ',i_y-i_srchy

         i_y = i_atloc(i_ky)
         i_centeryi = i_y + (i_wsyi-1)/2.

         i_ylu = nint(i_y*r_scaley)

c     write(6,'(x,a,$)') 'Reading in data.... '

         if(i_centeryip .ne. i_centeryi)then

            if(i_datatype(1) .eq. i_complex)then
               
               do i_yy = 1,i_wsyi
                  call readimg(13,i_status,i_y+i_yy-1,i_samples(1),c_refimg(1,i_yy))
                  if(i_status .eq. 1)then
                     goto 489
                  endif
               end do
               
            elseif(i_datatype(1) .eq. i_real)then
               
               do i_yy = 1,i_wsyi
                  call readimg_real(13,i_status,i_y+i_yy-1,i_samples(1),i_data_off(1),r_refimg(1,i_yy))
                  if(i_status .eq. 1)then
                     goto 489
                  endif
                  do i_xx=1,i_samples(1)
                     c_refimg(i_xx,i_yy) = cmplx(r_refimg(i_xx,i_yy),0.0)
                  enddo
               end do
               
            endif
            
            if(i_datatype(2) .eq. i_complex)then
               
               if(i_pixlocation .eq. i_pairlist)then
                  i_grossy = i_atloc2(i_ky) - i_atloc(i_ky)
               endif
               
               do i_yy = 1,i_wsyj
                  call readimg(14,i_status,i_ylu+i_yy-1-i_srchy+i_grossy,i_samples(2),c_srchimg(1,i_yy))
                  if(i_status .eq. 1)then
                     goto 489
                  endif
               end do
               
            elseif(i_datatype(2) .eq. i_real)then
               
               do i_yy = 1,i_wsyj
                  call readimg_real(14,i_status,i_ylu+i_yy-1-i_srchy+i_grossy,i_samples(2),i_data_off(2),
     +                 r_srchimg(1,i_yy))
                  if(i_status .eq. 1)then
                     goto 489
                  endif
                  do i_xx=1,i_samples(2)
                     c_srchimg(i_xx,i_yy) = cmplx(r_srchimg(i_xx,i_yy),0.0)
                  enddo
               end do
               
            endif
            
            i_centeryip = i_centeryi
            
         endif                  !same row of data
         
         do i_kx=1,i_xtpnts

            if(i_pixlocation .ne. i_listonly)then
               i_x = i_xtloc(i_kx)
            else 
               i_x = i_xtloc(i_ky)
            endif
            i_xlu = nint(i_x*r_scalex)
            i_centerxi = i_x + (i_wsxi-1)/2.

c     get the reference image and search images 

            do i_yy = 1,i_wsyi
               do i_xx = 1,i_wsxi
                  r_imgi(i_xx,i_yy) = cabs(c_refimg(i_x+i_xx-1,i_yy))
               end do
            end do

            if(i_pixlocation .eq. i_pairlist)then
               i_grossx = i_xtloc2(i_ky) - i_xtloc(i_ky)
            endif
            
            do i_yy = 1, i_wsyj
               do i_xx = 1 , i_wsxj
                  r_imgj(i_xx,i_yy) = cabs(c_srchimg(i_xlu+i_xx-1-i_srchx+i_grossx,i_yy))
               end do
            end do

c     dump the reference and serach images

            if(i_dump_images .eq. 1)then
               a_debugfile = 'refimg_input.dat'
               call dump_chip_r4(a_debugfile,r_imgi,1,i_wsxi,1,i_wsyi,i_idx,i_idy)
               a_debugfile = 'srchimg_input.dat'
               call dump_chip_r4(a_debugfile,r_imgj,1,i_wsxj,1,i_wsyj,i_idx,i_idy)
            endif

c     correlate the subimages

            call correlate(r_imgi,r_imgj,i_wsxi,i_wsyi,i_wsxj,
     &           i_wsyj,i_avgx,i_avgy,1,r_meani,r_stdvi,r_meanj,
     &           r_stdvj,r_peak,r_noise,r_cov,r_eval1,
     &           r_eval2,r_evec1,r_evec2,r_imgc,i_shiftx,i_shifty,i_edge,
     &           i_flag,l_debug)

            r_shftx = float(i_shiftx*i_avgx) - i_srchx + i_grossx
            r_shfty = float(i_shifty*i_avgy) - i_srchy + i_grossy

c     decide with points are good matches and print out the match values

            if(i_flag .eq. 0 .and. i_edge(1) .eq. 0 .and.
     &           i_edge(2) .eq. 0)then !found a potentially good data point

c     compute the "snr"

               if(l_display)then
                  write(6,*) ' '
                  write(6,*) 'Correlation Surface at ',i_centerxi,
     &                 i_centeryi
                  do l=max(i_shifty-3,1),min(i_shifty+5,i_wsyj-i_wsyi)
                     write(6,178) (r_imgc(k,l)**2./r_peak**2.,
     &                    k=max(i_shiftx-3,1),min(i_shiftx+5,i_wsxj-i_wsxi))
 178                 format(x,9(f6.3,x))
                  enddo
               endif

               r_outside = 0.0
               i_cnta = 0
               do l=max(i_shifty-9,1),min(i_shifty+11,i_wsyj-i_wsyi)
                  do k=max(i_shiftx-9,1),min(i_shiftx+11,i_wsxj-i_wsxi)
                     i_cnta = i_cnta + 1
                     r_outside = r_outside + r_imgc(k,l)**2
                  enddo
               enddo
               r_outside = r_outside - r_peak**2
               r_outside = r_outside/(i_cnta-1)

               r_snr = r_peak**2/max(r_outside,1.e-10)
               write(6,'(a,x,2(f20.10,x))') 'Peak/SNR = ',r_peak,r_snr
               
               if(r_snr .gt. r_snrth .and. r_cov(1) .lt. r_covth .and. r_cov(2) .lt. r_covth)then

c     oversample the region around the peak 2 to 1 to estimate the fractional offset 

c     write the reference image and search image around the peak into arrays

                  do i_yy=1,i_wsyi                        
                     do i_xx=1,i_wsxi
                        i_index = (i_yy-1)*i_n2wsxi + i_xx
                        if(i_x+i_xx-1 .ge. 1 .and. i_x+i_xx-1 .le. i_samples(1))then
                           c_chipref(i_index) = c_refimg(i_x+i_xx-1,i_yy)
                        else
                           c_chipref(i_index) = cmplx(0.0,0.0)
                        endif
                     enddo
                  enddo
                  
                  do i_yy=1,i_wsyi
                     do i_xx=i_wsxi+1,i_n2wsxi
                        i_index = (i_yy-1)*i_n2wsxi + i_xx
                        c_chipref(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo
                  
                  do i_yy=i_wsyi+1,i_n2wsyi
                     do i_xx=1,i_n2wsxi
                        i_index = (i_yy-1)*i_n2wsxi + i_xx
                        c_chipref(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo
                  
c     now the search image

                  do i_yy=1,i_wsyjp
                     do i_xx=1,i_wsxjp
                        i_index = (i_yy-1)*i_n2wsxj + i_xx
                        if(i_xlu+i_xx+i_shiftx*i_avgx-i_srchp+i_grossx - i_srchx .ge. 1 .and. 
     &                       i_xlu+i_xx+i_shiftx*i_avgx-i_srchp+i_grossx - i_srchx .le. i_samples(2) .and. 
     &                       i_yy+i_avgy*i_shifty-i_srchy+(i_srchy-i_srchp) .ge. 1 .and. 
     &                       i_yy+i_avgy*i_shifty-i_srchy+(i_srchy-i_srchp) .le. i_wsyj)then
                           c_chipsch(i_index) = c_srchimg(i_xlu+i_xx+i_shiftx*i_avgx-i_srchp+i_grossx-i_srchx-1,
     &                          i_yy+i_shifty*i_avgy-i_srchy+(i_srchy-i_srchp))
                        else
                           c_chipsch(i_index) = cmplx(0.0,0.0)
                        endif
                     enddo
                  enddo
                  
                  do i_yy=1,i_wsyjp
                     do i_xx=i_wsxjp+1,i_n2wsxj
                        i_index = (i_yy-1)*i_n2wsxj + i_xx
                        c_chipsch(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo
                  
                  do i_yy=i_wsyjp+1,i_n2wsyj                        
                     do i_xx=1,i_n2wsxj
                        i_index = (i_yy-1)*i_n2wsxj + i_xx
                        c_chipsch(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo

c     Dump the reference and search chip images to disk

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'chip_ref.dat'
                     call dump_chip_c8(a_debugfile,c_chipref,1,i_n2wsxi,1,i_n2wsyi,i_n2wsxi,i_n2wsyi)
                     a_debugfile = 'chip_srch.dat'
                     call dump_chip_c8(a_debugfile,c_chipsch,1,i_n2wsxj,1,i_n2wsyj,i_n2wsxj,i_n2wsyj)
                  endif

c     Deramp data prior to FFT
                  
                  call derampc(c_chipref,i_n2wsxi,i_n2wsyi)
                  call derampc(c_chipsch,i_n2wsxj,i_n2wsyj)
                  
c     forward fft the data
                  
                  i_nn(1) = i_n2wsxj
                  i_nn(2) = i_n2wsyj
                  
                  i_dem = 2
                  i_dir = 1
                  
                  call fourn(c_chipsch,i_nn,i_dem,i_dir)
                  
                  i_nn(1) = i_n2wsxi
                  i_nn(2) = i_n2wsyi
                  
                  call fourn(c_chipref,i_nn,i_dem,i_dir)

c     dump forward FFT of data

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'forwardfft_ref.dat'
                     call dump_chip_c8(a_debugfile,c_chipref,1,i_n2wsxi,1,i_n2wsyi,i_n2wsxi,i_n2wsyi)
                     a_debugfile = 'forwardfft_srch.dat'
                     call dump_chip_c8(a_debugfile,c_chipsch,1,i_n2wsxj,1,i_n2wsyj,i_n2wsxj,i_n2wsyj)
                  endif
                  
c     spread the spectral data out for inverse transforms
                  
                  i_nn(1) = i_n2wsxi*i_ovs
                  i_nn(2) = i_n2wsyi*i_ovs
                  
                  i_dem = 2
                  i_dir = -1
                  
                  do k=1,i_nn(2)                        
                     do l=1,i_nn(1)
                        i_index = l + (k-1)*i_nn(1)
                        c_osref(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo
                  
                  do k=1,i_n2wsyi/2                  
                     do l=1,i_n2wsxi/2
                        i_index = (k-1)*i_nn(1) + l
                        i_indexi = (k-1)*i_n2wsxi + l
                        c_osref(i_index) = c_chipref(i_indexi)
                        i_index = (i_nn(2) - i_n2wsyi/2 + k - 1)*i_nn(1) + l
                        i_indexi = (k + i_n2wsyi/2 - 1)*i_n2wsxi + l
                        c_osref(i_index) = c_chipref(i_indexi)
                        i_index = (k-1)*i_nn(1) + i_nn(1) - i_n2wsxi/2 + l
                        i_indexi = (k-1)*i_n2wsxi + i_n2wsxi/2 + l
                        c_osref(i_index) = c_chipref(i_indexi)
                        i_index = (i_nn(2) - i_n2wsyi/2 + k - 1)*i_nn(1) + i_nn(1) - i_n2wsxi/2 + l
                        i_indexi = (k + i_n2wsyi/2 - 1)*i_n2wsxi + l + i_n2wsxi/2
                        c_osref(i_index) = c_chipref(i_indexi)
                     enddo
                  enddo

c     dump zero-padded frequency domain data

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'osfreqdomain_ref.dat'
                     call dump_chip_c8(a_debugfile,c_osref,1,i_n2wsxi*i_ovs,1,i_n2wsyi*i_ovs,i_n2wsxi*i_ovs,i_n2wsyi*i_ovs)
                  endif
                  
                  call fourn(c_osref,i_nn,i_dem,i_dir)
                  
                  i_nn(1) = i_n2wsxj*i_ovs
                  i_nn(2) = i_n2wsyj*i_ovs
                  i_dem = 2
                  i_dir = -1
                  
                  do l=1,i_nn(1)
                     do k=1,i_nn(2)
                        i_index = l + (k-1)*i_nn(1)
                        c_ossch(i_index) = cmplx(0.0,0.0)
                     enddo
                  enddo
                  
                  do k=1,i_n2wsyj/2                  
                     do l=1,i_n2wsxj/2
                        i_index = (k-1)*i_nn(1) + l
                        i_indexi = (k-1)*i_n2wsxj + l
                        c_ossch(i_index) = c_chipsch(i_indexi)
                        i_index = (i_nn(2) - i_n2wsyj/2 + k - 1)*i_nn(1) + l
                        i_indexi = (k + i_n2wsyj/2 - 1)*i_n2wsxj + l
                        c_ossch(i_index) = c_chipsch(i_indexi)
                        i_index = (k-1)*i_nn(1) + i_nn(1) - i_n2wsxj/2 + l
                        i_indexi = (k-1)*i_n2wsxj + i_n2wsxj/2 + l
                        c_ossch(i_index) = c_chipsch(i_indexi)
                        i_index = (i_nn(2) - i_n2wsyj/2 + k - 1)*i_nn(1) + i_nn(1) - i_n2wsxj/2 + l
                        i_indexi = (k + i_n2wsyj/2 - 1)*i_n2wsxj + l + i_n2wsxj/2
                        c_ossch(i_index) = c_chipsch(i_indexi)
                     enddo
                  enddo

c     dump zero-padded frequency domain data

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'osfreqdomain_srch.dat'
                     call dump_chip_c8(a_debugfile,c_ossch,1,i_n2wsxj*i_ovs,1,i_n2wsyj*i_ovs,i_n2wsxj*i_ovs,i_n2wsyj*i_ovs)
                  endif

c     inverse transform
                  
                  call fourn(c_ossch,i_nn,i_dem,i_dir)

c     dump the oversampled complex image data
                  
                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'cmplx_os_ref.dat'
                     call dump_chip_c8(a_debugfile,c_osref,1,i_n2wsxi*i_ovs,1,i_n2wsyi*i_ovs,i_n2wsxi*i_ovs,i_n2wsyi*i_ovs)
                     a_debugfile = 'cmplx_os_srch.dat'
                     call dump_chip_c8(a_debugfile,c_ossch,1,i_n2wsxj*i_ovs,1,i_n2wsyj*i_ovs,i_n2wsxj*i_ovs,i_n2wsyj*i_ovs)
                  endif
                  
c     detect images and put into correlation arrays
                  
                  do i_yy=1,i_wsyi*i_ovs
                     do i_xx=1,i_wsxi*i_ovs
                        i_index = i_xx + (i_yy-1)*i_n2wsxi*i_ovs
                        r_imgi(i_xx,i_yy) = cabs(c_osref(i_index)/(i_n2wsxi*i_n2wsyi))
                     enddo
                  enddo
                  
                  do i_yy=1,i_wsyjp*i_ovs                        
                     do i_xx=1,i_wsxjp*i_ovs
                        i_index = i_xx + (i_yy-1)*i_n2wsxj*i_ovs
                        r_imgj(i_xx,i_yy) = cabs(c_ossch(i_index))/(i_n2wsxj*i_n2wsyj)
                     enddo
                  enddo

c     dump the detected image chips used for cross correlation 

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'detected_os_ref.dat'
                     call dump_chip_r4(a_debugfile,r_imgi,1,i_n2wsxi*i_ovs,1,i_n2wsyi*i_ovs,i_idx,i_idy)
                     a_debugfile = 'detected_os_srch.dat'
                     call dump_chip_r4(a_debugfile,r_imgj,1,i_n2wsxj*i_ovs,1,i_n2wsyj*i_ovs,i_idx,i_idy)
                  endif
                  
c     correlate the oversampled chips
                  
                  i_wsxios = i_wsxi*i_ovs
                  i_wsyios = i_wsyi*i_ovs
                  i_wsxjos = i_wsxjp*i_ovs 
                  i_wsyjos = i_wsyjp*i_ovs 
                  i_wsox = i_wsxjos - (i_wsxios-1)
                  i_wsoy = i_wsyjos - (i_wsyios-1)

                  i_ovss = 1
                  
                  call correlate(r_imgi,r_imgj,i_wsxios,i_wsyios,
     &                 i_wsxjos,i_wsyjos,1,1,i_ovss,r_meani,r_stdvi,
     &                 r_meanj,r_stdvj,r_peakos,
     &                 r_noise,r_covos,r_eval1,r_eval2,r_evec1,r_evec2,
     &                 r_imgc,i_shiftxos,i_shiftyos,i_edge,i_flag,l_debug)
                  
                  r_shftxos = float(i_shiftxos)/i_ovs - float((i_wsox-1)/2)/i_ovs + r_shftx
                  r_shftyos = float(i_shiftyos)/i_ovs - float((i_wsoy-1)/2)/i_ovs + r_shfty

c     display the correlation surface

                  if(l_display)then
                     write(6,*) ' '
                     write(6,*) 'Correlation Surface of oversamples image at ',i_centerxi,i_centeryi
                     do l= max(i_shiftyos-3,1),min(i_shiftyos+5,i_wsoy)
                        write(6,178) (r_imgc(k,l)**2/r_peakos**2,k=max(i_shiftxos-3,1),min(i_shiftxos+5,i_wsox))
                     enddo
                  endif

c     dump the correlation surface

                  if(i_dump_images .eq. 1)then
                     a_debugfile = 'correlation_surface.dat'
                     call dump_chip_r4(a_debugfile,r_imgc,1,i_wsox,1,i_wsoy,i_idx,i_idy)
                  endif

                  r_outside = 0.0
                  i_cnta = 0
                  do l=max(i_shiftyos-9,1),min(i_shiftyos+11,i_wsoy)
                     do k=max(i_shiftxos-9,1),min(i_shiftxos+11,i_wsox)
                        i_cnta = i_cnta + 1
                        r_outside = r_outside + r_imgc(k,l)**2
                     enddo
                  enddo
                  r_outside = r_outside - r_peakos**2
                  r_outside = r_outside/(i_cnta-1)
                  r_snros = r_peakos**2/min(r_outside,1.e10)
                  
                  r_snros = 10.
                  r_covos(1) = 0. 
                  r_covos(2) = 0. 

                  if(r_snros .gt. r_snrth .and. r_covos(1) .lt. r_covth .and. r_covos(2) .lt. r_covth)then

c     oversample the oversampled correlation surface

                     r_max = 0.0
                     r_mean_cor = 0.0
                     i_cnta = 0
                     i_px = i_shiftxos+1
                     i_py = i_shiftyos+1

                     do i_yy=-i_cw/2,i_cw/2-1
                        
                        do i_xx=-i_cw/2,i_cw/2-1
                           
                           i_index = (i_yy+i_cw/2)*i_cw + i_xx + i_cw/2 + 1
                           
                           if (i_xx+i_px .ge. 1 .and. i_xx+i_px .le. (2*i_srchp+1)*i_ovs .and.
     &                          i_yy+i_py .ge. 1 .and. i_yy+i_py .le. (2*i_srchp+1)*i_ovs )then
                              c_corrt(i_index) = cmplx(abs(r_imgc(i_xx+i_px,i_yy+i_py)/r_peakos),0.)
                              r_mean_cor = r_mean_cor + cabs(c_corrt(i_index))
                              i_cnta = i_cnta + 1
                           else
                              c_corrt(i_index) = cmplx(0.0, 0.0)
                           endif
                           
                           if(cabs(c_corrt(i_index)) .gt. r_max)then
                              r_max = cabs(c_corrt(i_index))
                              i_p1 = i_xx
                              i_p2 = i_yy
                           endif
                           
                        enddo
                        
                     enddo

c     substract off the mean

                     r_mean_cor = r_mean_cor/max(i_cnta,1)
                     r_mean_cor = 0.0
                     do i_yy=-i_cw/2,i_cw/2-1
                        do i_xx=-i_cw/2,i_cw/2-1
                           i_index = (i_yy+i_cw/2)*i_cw + i_xx + i_cw/2 + 1
                           c_corrt(i_index) = c_corrt(i_index) - cmplx(r_mean_cor,0.0)
                        enddo
                     enddo

c     dump the correlation around peak used for oversampling

                     if(i_dump_images .eq. 1)then
                        a_debugfile = 'corrsurf_peak.dat'
                        call dump_chip_c8(a_debugfile,c_corrt,1,i_cw,1,i_cw,i_cw,i_cw)
                     endif
                     
c     oversample the correlation surface
                     
                     if(i_sinc_fourier .eq. i_sinc)then
                        
c     Use SINC interpolation to oversample the correlation surface. Note will cheat and
c     and do a series of 1-d interpolations. Assume correlation function is periodic and
c     do a circular convolution.

                        do i_yy=-i_cw/2,i_cw/2-1

                           do i_xx=-i_sinc_window*i_covs,i_sinc_window*i_covs

                              i_index2 = (i_yy + i_cw/2)*i_covs*i_cw + i_xx + i_cw*i_covs/2 + 1

                              c_dataout(i_index2) = 0.
                              
                              r_jout = float(i_xx + i_cw*i_covs/2 + i_covs)/i_covs + r_fdelay
                              i_jout = int(r_jout)
                              
                              r_frac = r_jout - i_jout 
                              i_frac = int(r_frac*i_decfactor)
                              r_sincwgt = 0.0

                              do k=0,i_intplength-1
                                 if(i_jout-k .lt. 1)then
                                    i_index = (i_yy+i_cw/2)*i_cw + (i_jout-k+i_cw) 
                                 elseif(i_jout-k .gt. i_cw)then
                                    i_index = (i_yy+i_cw/2)*i_cw + (i_jout-k-i_cw) 
                                 else
                                    i_index = (i_yy+i_cw/2)*i_cw + (i_jout-k) 
                                 endif
                                 c_dataout(i_index2) = c_dataout(i_index2) +
     +                                c_corrt(i_index)*r_fintp(k + i_frac*i_intplength)
                                 r_sincwgt = r_sincwgt + r_fintp(k + i_frac*i_intplength) 
                              enddo
                              c_dataout(i_index2) = c_dataout(i_index2)/r_sincwgt
                           enddo
                           
                        enddo

                        if(i_dump_images .eq. 1)then
                           a_debugfile = 'sinc_stagext.dat'
                           call dump_chip_c8(a_debugfile,c_dataout,1,i_cw*i_covs,1,i_cw,i_cw*i_covs,i_cw)
                        endif                        

c     along track resample
                        
c                        do i_yy=(-i_cw/2)*i_covs,i_cw/2*i_covs-1
                           
c                           do i_xx=(-i_cw/2)*i_covs,i_cw/2*i_covs-1

                        do i_yy=-i_sinc_window*i_covs,i_sinc_window*i_covs
                           
                           do i_xx=-i_sinc_window*i_covs,i_sinc_window*i_covs
                              
                              i_index2 = (i_yy + i_cw*i_covs/2)*i_cw*i_covs + i_xx + i_cw*i_covs/2 + 1

                              c_dataout2(i_index2) = 0.
                              
                              r_iout = float(i_yy +i_cw*i_covs/2 + i_covs)/i_covs + r_fdelay
                              i_iout = int(r_iout)
                              
                              r_frac = r_iout - i_iout
                              i_frac = int(r_frac*i_decfactor)
                              r_sincwgt = 0.0

                              do k=0,i_intplength-1
                                 if(i_iout-k .lt. 1)then
                                    i_index = i_iout - k + i_cw 
                                 elseif(i_iout-k .gt. i_cw)then
                                    i_index = i_iout - k - i_cw 
                                 else
                                    i_index = i_iout - k 
                                 endif
                                 i_index3 = (i_index-1)*i_cw*i_covs + i_xx + i_cw*i_covs/2 + 1
                                 c_dataout2(i_index2) = c_dataout2(i_index2) +
     +                                c_dataout(i_index3)*r_fintp(k + i_frac*i_intplength)
                                 r_sincwgt = r_sincwgt + r_fintp(k + i_frac*i_intplength) 
                              enddo
                              c_dataout2(i_index2) = c_dataout2(i_index2)/r_sincwgt
                              c_corr(i_index2) = c_dataout2(i_index2)
                              
                           enddo
                           
                        enddo

                        if(i_dump_images .eq. 1)then
                           a_debugfile = 'sinc_stageat.dat'
                           call dump_chip_c8(a_debugfile,c_dataout2,1,i_cw*i_covs,1,i_cw*i_covs,i_cw*i_covs,i_cw*i_covs)
                        endif                        
                        
                     elseif(i_sinc_fourier .eq. i_fourier)then

c     oversample via Fourier transforms
                        
c     forward fft the data
                        
                        i_nn(1) = i_cw
                        i_nn(2) = i_cw
                        i_dem = 2
                        i_dir = 1
                        
                        call fourn(c_corrt,i_nn,i_dem,i_dir)
                        
c     dump the correlation around peak used for oversampling
                        
                        if(i_dump_images .eq. 1)then
                           a_debugfile = 'fowfft_corrsurf_peak.dat'
                           call dump_chip_c8(a_debugfile,c_corrt,1,i_cw,1,i_cw,i_cw,i_cw)
                        endif
                        
c     spread the spectral data out for inverse transforms
                        
                        i_nn(1) = i_cw*i_covs
                        i_nn(2) = i_cw*i_covs
                        i_dem = 2
                        i_dir = -1
                        
                        do k=1,i_nn(2)                           
                           do l=1,i_nn(1)
                              i_index = (k-1)*i_nn(1) + l
                              c_corr(i_index) = 0.0
                           enddo
                        enddo
                        
                        do l=1,i_cw/2
                           do k=1,i_cw/2
                              i_index = (k-1)*i_nn(1) + l
                              i_indexi = (k-1)*i_cw + l
                              c_corr(i_index) = c_corrt(i_indexi) 
                              i_index = l + (i_nn(2)-i_cw/2+k-1)*i_nn(1)
                              i_indexi = l + (k+i_cw/2-1)*i_cw
                              c_corr(i_index) = c_corrt(i_indexi) 
                              i_index = i_nn(1)-i_cw/2+l + (k-1)*i_nn(2)
                              i_indexi = l+i_cw/2 + (k-1)*i_cw
                              c_corr(i_index) = c_corrt(i_indexi) 
                              i_index = i_nn(1)-i_cw/2+l + (i_nn(2)-i_cw/2+k-1)*i_nn(1)
                              i_indexi = l+i_cw/2 + (k+i_cw/2-1)*i_cw
                              c_corr(i_index) = c_corrt(i_indexi) 
                           enddo
                        enddo
                        
c     dump the zero-padded correlation surface
                        
                        if(i_dump_images .eq. 1)then
                           a_debugfile = 'zpadded_corrsurf_peak.dat'
                           call dump_chip_c8(a_debugfile,c_corr,1,i_cw*i_covs,1,i_cw*i_covs,i_cw*i_covs,i_cw*i_covs)
                        endif
                        
c     inverse transform
                        
                        call fourn(c_corr,i_nn,i_dem,i_dir)
                        
c     dump the detected oversampled correlation surface
                        
                        if(i_dump_images .eq. 1)then
                           a_debugfile = 'corrsurf_os.dat'
                           call dump_chip_c8(a_debugfile,c_corr,1,i_cw*i_covs,1,i_cw*i_covs,i_cw*i_covs,i_cw*i_covs)
                        endif
                        
                     endif      !sinc vs fourier oversample
                     
c     detect the peak
                     
                     r_max=0.
                     do i_yy=1,i_cw*i_covs
                        do i_xx=1,i_cw*i_covs
                           i_index = (i_yy-1)*i_cw*i_covs + i_xx
                           if(i_sinc_fourier .eq. i_fourier)then
                              r_corr(i_xx,i_yy) = cabs(c_corr(i_index))/((i_cw**2)*(i_cw*i_covs)**2)
                           else
                              r_corr(i_xx,i_yy) = cabs(c_corr(i_index))
                           endif
                           if (abs(i_xx-i_cw*i_covs/2) .le. i_covs .and.
     &                          abs(i_yy-i_cw*i_covs/2) .le. i_covs) then
                              if (r_corr(i_xx,i_yy) .ge. r_max) then
                                 r_max = r_corr(i_xx,i_yy)
                                 i_cpeak(1) = i_xx - i_cw/2*i_covs
                                 i_cpeak(2) = i_yy - i_cw/2*i_covs
                              endif
                           endif
                        enddo
                     enddo
                     
c     dump the detected oversampled correlation surface
                     
                     if(i_dump_images .eq. 1)then
                        a_debugfile = 'detected_corrsurf.dat'
                        call dump_chip_r4(a_debugfile,r_corr,1,i_cw*i_covs,1,i_cw*i_covs,i_cw*i_covs,i_cw*i_covs)
                     endif
                     
                     r_oscoroff(1) = float(i_cpeak(1)-1)/float(i_covs) 
                     r_oscoroff(2) = float(i_cpeak(2)-1)/float(i_covs)
                     
                     r_shftxosc = r_oscoroff(1)/i_ovs + r_shftxos + i_xlu - i_x
                     r_shftyosc = r_oscoroff(2)/i_ovs + r_shftyos + i_ylu - i_y
                     
                     write(15,151) i_centerxi,r_shftxosc,i_centeryi,r_shftyosc,
     &                    r_snr,r_cov(1),r_cov(2),r_cov(3)
                     write(6,151) i_centerxi,r_shftxosc,i_centeryi,r_shftyosc,
     &                    r_snr,r_cov(1),r_cov(2),r_cov(3)
c                     write(6,150)  i_centerxi,r_shftx,r_shftxos,r_shftxosc,
c     &                    i_centeryi,r_shfty,r_shftyos,r_shftyosc,
c     &                    r_snr,sqrt(r_cov(1)),sqrt(r_cov(2))
 151                 format(1x,i7,1x,f9.3,1x,i7,1x,f11.3,1x,f10.5,1x,f10.6,1x,f10.6,1x,f10.6)
 150                 format(1x,i7,1x,f9.3,1x,f9.3,1x,f9.3,1x,i7,1x,f9.3,1x,f9.3,1x,f9.3,1x,
     &                    f10.5,1x,f10.3,1x,f10.3,1x,f10.3)
                     
                  else 
                     
                     write(6,*) 'Bad match at level 2'
                     
                  endif         !thresholds second pass
                  
               else 
                  
                  write(6,*) 'Bad match at level 1'
                  
               endif            !thresholds
               
            endif               !not edge point or no data point
            
            if(i_dump_images .eq. 1)then
               stop             
            endif
            
         enddo                  !samples loop (j)
         
      enddo                     !line loop (i)
      
 489  continue
      
      end

      subroutine readimg(i_unit,i_status,i_rec,i_samples,c_data)

        implicit none

        integer i_unit
        integer i_rec
        integer i_samples
        integer i_status
        integer i_err

        complex c_data(i_samples)

        i_status = 0

        read(i_unit,rec=i_rec,iostat=i_err) c_data
        if(i_err .ne. 0) then
           write(6,*) 'read error on record=',i_rec,'status=',i_err
           goto 121
        endif

        return

 121    i_status = 1

      end      

      subroutine readimg_real(i_unit,i_status,i_rec,i_samples,i_off,r_data)

        implicit none

        integer i_unit
        integer i_rec
        integer i_samples
        integer i_status
        integer i_off
        integer i
        integer i_err

        real r_data_read(i_samples+i_off),r_data(i_samples)

        i_status = 0

        read(i_unit,rec=i_rec,iostat=i_err) r_data_read
        if(i_err .ne. 0) then
           write(6,*) 'read error on record=',i_rec,'status=',i_err
           goto 121
        endif

        do i=1,i_samples
           r_data(i) = r_data_read(i+i_off)
        enddo

        return

 121    i_status = 1

      end      

c****************************************************************

      subroutine correlate(r_imgi,r_imgj,i_wsxi,i_wsyi,i_wsxj,
     &     i_wsyj,i_avgx,i_avgy,i_ovs,r_meani,r_stdvi,r_meanj,r_stdvj,
     &     r_peak,r_noise,r_cov,r_eval1,r_eval2,
     &     r_evec1,r_evec2,r_imgc,i_shftx,i_shfty,i_edge,i_flag,
     &     l_debug)
      
c****************************************************************
c**   
c**   FILE NAME: correlate.f
c**   
c**   DATE WRITTEN: /10/10/92
c**   
c**   PROGRAMMER:Scott Hensley / Scott Shaffer
c**   
c**   FUNCTIONAL DESCRIPTION: This routine will do amplitude correlation
c     
c**   on two specified input files.
c**   
c**   ROUTINES CALLED:none
c**   
c**   NOTES: none
c**   
c**   UPDATE LOG:
c**   
c**   Date      Description                              Person
c**   ----      -----------                              ------
c**   /12/12/94   Modified to work with real data.         SH
c**   /02/22/95   Modified to work oversampled data.      SS/SH
c**   
c*****************************************************************
      
      implicit none
      
c     INPUT VARIABLES:
      integer i_idx,i_idy
      parameter(i_idx=2048)
      parameter(i_idy=2048)

      integer i_wsyi,i_wsxi,i_wsyj,i_wsxj,i_ovs
      integer i_avgy,i_avgx,i_wsayi,i_wsaxi
      integer i_wsayj,i_wsaxj,i_wsaxyi,i_wsaxyj

      real r_imi,r_imgi,r_imgc
      real r_imj,r_imgj
      dimension r_imi(i_idx,i_idy)
      dimension r_imgc(i_idx,i_idy)
      dimension r_imj(i_idx,i_idy)
      dimension r_imgi(i_idx,i_idy)
      dimension r_imgj(i_idx,i_idy)      

c     OUTPUT VARIABLES:
      real*4 r_shfty,r_shftx,r_peak,r_shrp,r_meani,r_meanj
      real*4 r_stdvi,r_stdvj,r_noise,r_cov(3),r_eval1,r_sum
      real*4 r_eval2,r_evec1(2),r_evec2(2)
      
c     LOCAL VARIABLES:
      integer i,j,m,n,ix,iy,ixx,iyy,i_shfty,i_shftx,io
      integer i_cnti,i_cntj,i_cntai,i_cntaj,i_edge(2),i_flag

      real r_sumc,r_sumi,r_smqi
      real r_sumj(0:i_idx,0:i_idy)
      real r_smqj(0:i_idx,0:i_idy)
      real r_crpd(0:i_idx,0:i_idy)
      real r_corr(0:i_idx,0:i_idy)
      real r_corn(0:i_idx,0:i_idy)
      real r_denom

      real*4 r_dxx,r_dyy,r_dxy,r_n2,r_n4,r_u,r_u2

      logical l_init,l_debug
      
c     DATA STATEMENTS:
      data l_init /.false./
      
C     FUNCTION STATEMENTS:
      
c     PROCESSING STEPS:

      if(l_debug)then
         write(6,*) ' '
         write(6,*) ' Debug Statements ** Inputs ** '
         write(6,*) 'r_imgi(1,1),r_imgj(1,1) = ',
     &        r_imgi(1,1),r_imgj(1,1)
         write(6,*) 
     &        ' r_imgi(i_wsxi,i_wsyi),r_imgj(i_wsxj,i_wsyj) = ',
     &        r_imgi(i_wsxi,i_wsyi),r_imgj(i_wsxj,i_wsyj) 
         write(6,*) 'i_wsxi and i_wsyi = ',i_wsxi,i_wsyi
         write(6,*) 'i_wsxj and i_wsyj = ',i_wsxj,i_wsyj
         write(6,*) 'i_avgx and i_avgy = ',i_avgx,i_avgy
         write(6,*) 'r_meani and r_stdvi = ',r_meani,r_stdvi
         write(6,*) 'r_meanj and r_stdvj = ',r_meanj,r_stdvj
         write(6,*) 'r_peak and r_noise = ',r_peak,r_noise
         write(6,*) 'r_shftx and r_shfty = ',r_shftx,r_shfty
         write(6,*) 'i_edge and i_flag = ',i_edge(1),i_edge(2),i_flag
      endif

      i_edge(1)=0
      i_edge(2)=0
      if ( i_avgy .le. 0 ) i_avgy=1
      if ( i_avgx .le. 0 ) i_avgx=1
      i_wsayi=i_wsyi/i_avgy
      i_wsaxi=i_wsxi/i_avgx
      i_wsayj=i_wsyj/i_avgy
      i_wsaxj=i_wsxj/i_avgx
      i_wsaxyi=i_wsayi*i_wsaxi
      i_wsaxyj=i_wsayj*i_wsaxj/i_ovs

      r_cov(1)=0.
      r_cov(2)=0.
      r_cov(3)=0. 

c     compute mean and standard deviations on blocks 

      i_cntai = 0
      i_cntaj = 0
      r_sumi = 0.
      r_smqi = 0.
      do iy=1,i_wsayj
         do ix=1,i_wsaxj
            r_imgc(ix,iy) = 0.
            r_imi(ix,iy) = 0.
            r_imj(ix,iy) = 0.
            i_cnti=0
            i_cntj=0
            if(i_avgy .ne. 1 .or. i_avgx .ne. 1)then
               do iyy=(iy-1)*i_avgy+1,iy*i_avgy
                  do ixx=(ix-1)*i_avgx+1,ix*i_avgx
                     if ( iyy .le. i_wsyi .and. ixx .le. i_wsxi ) then
                        if ( r_imgi(ixx,iyy) .ne. 0. ) then
                           i_cnti = i_cnti+1
                           r_imi(ix,iy) = r_imi(ix,iy) + r_imgi(ixx,iyy)
                        endif
                     endif
                     if ( r_imgj(ixx,iyy) .ne. 0. ) then
                        i_cntj = i_cntj+1
                        r_imj(ix,iy) = r_imj(ix,iy) + r_imgj(ixx,iyy)
                     endif
                  enddo
               enddo
               if ( i_cnti .ne. 0 ) then
                  i_cntai = i_cntai+1
                  r_imi(ix,iy) = r_imi(ix,iy)/i_cnti
                  r_sumi = r_sumi + r_imi(ix,iy)
                  r_smqi = r_smqi + r_imi(ix,iy)**2
               endif
               if ( i_cntj .ne. 0 ) then
                  r_imj(ix,iy) = r_imj(ix,iy)/i_cntj
                  i_cntaj = i_cntaj+1
               endif
            else
               r_imj(ix,iy) = r_imgj(ix,iy)
               if(ix .le. i_wsxi .and. iy .le. i_wsyi)then
                  r_imi(ix,iy) = r_imgi(ix,iy)
                  if(r_imi(ix,iy) .ne. 0)then
                     i_cntai = i_cntai+1
                     r_sumi = r_sumi + r_imi(ix,iy)
                     r_smqi = r_smqi + r_imi(ix,iy)**2
                  endif
               endif
               if(r_imj(ix,iy) .ne. 0)then
                  i_cntaj = i_cntaj+1
               endif   
            endif               !no averaging
         enddo
      enddo


      if ( i_cntai .ne. 0 ) then
         r_meani = r_sumi/i_cntai
         r_stdvi = sqrt((r_smqi/i_cntai)-r_meani**2)
      else
         r_meani = 0.
      endif

      if (i_cntai .ge. 0.9*i_wsaxyi .and. 
     &     i_cntaj .ge. 0.9*i_wsaxyj ) then !have enough real estate

         do iy=0,i_wsayj-1
            r_sumj(0,iy) = 0.
            r_smqj(0,iy) = 0.
            do io = 1,i_ovs
               r_sumj(io,iy) = 0.
               r_smqj(io,iy) = 0.
               do ix=0,(i_wsaxi-1)*i_ovs,i_ovs
                  r_sumj(io,iy) = r_sumj(io,iy) + r_imj(ix+io,iy+1)
                  r_smqj(io,iy) = r_smqj(io,iy) + r_imj(ix+io,iy+1)**2
               enddo
            enddo

            do ix=i_ovs+1,i_wsaxj - (i_wsaxi-1)*i_ovs
               r_sumj(ix,iy) = r_sumj(ix-i_ovs,iy) - r_imj(ix-i_ovs,iy+1
     &              ) +r_imj(ix+(i_wsaxi-1)*i_ovs,iy+1)
               r_smqj(ix,iy) = r_smqj(ix-i_ovs,iy) - r_imj(ix-i_ovs,iy+1
     &              )**2 +r_imj(ix+(i_wsaxi-1)*i_ovs,iy+1)**2
            enddo
         enddo

         do ix=0,i_wsaxj - (i_wsaxi-1)*i_ovs-1
            do io=1,i_ovs
               r_sumj(ix,io-1)=0.
               r_smqj(ix,io-1)=0.
               do iy=0,(i_wsayi-1)*i_ovs,i_ovs
                  r_sumj(ix,io-1) = r_sumj(ix,io-1)+r_sumj(ix+1,iy+io-1)
                  r_smqj(ix,io-1) = r_smqj(ix,io-1)+r_smqj(ix+1,iy+io-1)
               enddo
            enddo

            do iy=i_ovs,i_wsayj - (i_wsayi-1)*i_ovs-1
               r_sumj(ix,iy) = r_sumj(ix,iy-i_ovs) - r_sumj(ix+1,iy
     &              -i_ovs)+r_sumj(ix+1,iy+(i_wsayi-1)*i_ovs)
               r_smqj(ix,iy) = r_smqj(ix,iy-i_ovs) - r_smqj(ix+1,iy
     &              -i_ovs)+r_smqj(ix+1,iy+(i_wsayi-1)*i_ovs)
            enddo
         enddo

c         type *,' '
c         do ix=0,i_wsaxj - (i_wsaxi-1)*i_ovs-1
c            do iy=0,i_wsayj - (i_wsayi-1)*i_ovs-1
c               r_sum=0.
c               do ixx=ix+1,ix+i_wsaxi*i_ovs,i_ovs
c                  do iyy=iy+1,iy+i_wsayi*i_ovs,i_ovs
c                     r_sum=r_sum+r_imj(ixx,iyy)
c                  enddo
c               enddo
c               type *,ix,iy,r_sumj(ix,iy),r_sum,r_sumj(ix,iy)-r_sum
c            enddo
c         enddo

         i_shftx = 0
         i_shfty = 0
         r_peak = -9.e27
         do m=0,i_wsaxj - (i_wsaxi-1)*i_ovs-1
            do n=0,i_wsayj - (i_wsayi-1)*i_ovs-1
               r_sumc = 0.
               do j=1,i_wsayi
                  do i=1,i_wsaxi
                     r_sumc = r_sumc + r_imi(i,j)*r_imj((i-1)*i_ovs+m+1,(j-1)*i_ovs+n+1)
                  enddo
               enddo
               r_crpd(m,n) = r_sumc
               r_corr(m,n) = r_sumc - r_meani*r_sumj(m,n)
               r_denom = (r_stdvi*sqrt((r_smqj(m,n)*i_wsaxyi)-
     &              (r_sumj(m,n))**2))
               if ( r_denom .gt. 0. ) then
                  r_corn(m,n) = r_corr(m,n)/r_denom
               else
                  r_corn(m,n) = 0.
               endif
               r_imgc(m+1,n+1) = r_corn(m,n)
c               if(i_wsxi .eq. 112)then
c                  type*, 'r_c = ',m,n,r_corn(m,n),r_crpd(m,n),r_meani*r_sumj(m,n),
c     +                 r_crpd(m,n)-r_meani*r_sumj(m,n),r_sumj(m,n),r_denom
c               endif
               if ( r_peak .lt. r_corn(m,n)) then
                  r_peak = r_corn(m,n)
                  i_shftx = m
                  i_shfty = n
               endif
            enddo
         enddo

c     commpute the curvature of the corrrelation surface to estimate the
c     goodness of the match

         if ( r_peak .gt. 0. ) then

            ix = i_shftx
            iy = i_shfty
            if ( iy .eq. 0 .or. iy .eq. i_wsayj - (i_wsayi-1)*i_ovs-1 )
     &           i_edge(1)=1
            if ( ix .eq. 0 .or. ix .eq. i_wsaxj - (i_wsaxi-1)*i_ovs-1 )
     &           i_edge(2)=1
            r_shftx = float(ix*i_avgx)/i_ovs
            r_shfty = float(iy*i_avgy)/i_ovs
            r_meanj = r_sumj(ix,iy)/i_wsaxyi
            r_stdvj = sqrt((r_smqj(ix,iy)/i_wsaxyi)-r_meanj**2)
            r_shrp = (r_peak-(r_corn(max(ix-1,1),iy)+
     &           r_corn(min(ix+1,i_wsaxj - (i_wsaxi-1)*i_ovs-1),iy))/2.)
            i_flag = 0

            if ( ix .eq. 0 ) then
               if ( iy .eq. 0 ) then
                  r_dxx = -(r_corn(ix+1,iy)+r_corn(ix+1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy+1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 0.
                  r_dxx = r_dxx/4 ! added emperically
                  r_dyy = r_dyy/4
                  r_dxy = r_dxy/4
                  r_peak = r_peak/4
               else if ( iy .eq. i_wsayj - (i_wsayi-1)*i_ovs-1 ) then
                  r_dxx = -(r_corn(ix+1,iy)+r_corn(ix+1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy-1)+r_corn(ix,iy-1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 0
                  r_dxx = r_dxx/4 ! added emperically
                  r_dyy = r_dyy/4
                  r_dxy = r_dxy/4
                  r_peak = r_peak/4
               else
                  r_dxx = -(r_corn(ix+1,iy)+r_corn(ix+1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy-1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 2*(r_corn(ix+1,iy+1)-
     &                 r_corn(ix+1,iy-1))/(4*i_avgx*i_avgy)
                  r_dxx = r_dxx/2 ! added emperically
                  r_dyy = r_dyy/2
                  r_dxy = r_dxy/2
                  r_peak = r_peak/2
               endif
            else if ( ix .eq. i_wsaxj - (i_wsaxi-1)*i_ovs-1 ) then
               if ( iy .eq. 0 ) then
                  r_dxx = -(r_corn(ix-1,iy)+r_corn(ix-1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy+1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 0
                  r_dxx = r_dxx/4 ! added emperically
                  r_dyy = r_dyy/4
                  r_dxy = r_dxy/4
                  r_peak = r_peak/4
               else if ( iy .eq. i_wsayj - (i_wsayi-1)*i_ovs-1 ) then
                  r_dxx = -(r_corn(ix-1,iy)+r_corn(ix-1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy-1)+r_corn(ix,iy-1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 0
                  r_dxx = r_dxx/4 ! added emperically
                  r_dyy = r_dyy/4
                  r_dxy = r_dxy/4
                  r_peak = r_peak/4
               else
                  r_dxx = -(r_corn(ix-1,iy)+r_corn(ix-1,iy)-
     &                 2*r_corn(ix,iy))/(i_avgx**2)
                  r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy-1)-
     &                 2*r_corn(ix,iy))/(i_avgy**2)
                  r_dxy = 2*(r_corn(ix-1,iy-1)-
     &                 r_corn(ix-1,iy+1))/(4*i_avgx*i_avgy)
                  r_dxx = r_dxx/2 ! added emperically
                  r_dyy = r_dyy/2
                  r_dxy = r_dxy/2
                  r_peak = r_peak/2
               endif
            else if ( iy .eq. 0 ) then
               r_dxx = -(r_corn(ix+1,iy)+r_corn(ix-1,iy)-
     &              2*r_corn(ix,iy))/(i_avgx**2)
               r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy+1)-
     &              2*r_corn(ix,iy))/(i_avgy**2)
               r_dxy = 2*(r_corn(ix+1,iy+1)-
     &              r_corn(ix-1,iy+1))/(4*i_avgx*i_avgy)
               r_dxx = r_dxx/2  ! added emperically
               r_dyy = r_dyy/2
               r_dxy = r_dxy/2
               r_peak = r_peak/2
            else if ( iy .eq. i_wsayj - (i_wsayi-1)*i_ovs-1 ) then
               r_dxx = -(r_corn(ix+1,iy)+r_corn(ix-1,iy)-
     &              2*r_corn(ix,iy))/(i_avgx**2)
               r_dyy = -(r_corn(ix,iy-1)+r_corn(ix,iy-1)-
     &              2*r_corn(ix,iy))/(i_avgy**2)
               r_dxy = 2*(r_corn(ix-1,iy-1)-
     &              r_corn(ix+1,iy-1))/(4*i_avgx*i_avgy)
               r_dxx = r_dxx/2  ! added emperically
               r_dyy = r_dyy/2
               r_dxy = r_dxy/2
               r_peak = r_peak/2
            else
               r_dxx = -(r_corn(ix+1,iy)+r_corn(ix-1,iy)-
     &              2*r_corn(ix,iy))/(i_avgx**2)
               r_dyy = -(r_corn(ix,iy+1)+r_corn(ix,iy-1)-
     &              2*r_corn(ix,iy))/(i_avgy**2)
               r_dxy = (r_corn(ix+1,iy+1)+
     &              r_corn(ix-1,iy-1)-r_corn(ix+1,iy-1)-
     &              r_corn(ix-1,iy+1))/(4*i_avgx*i_avgy)
            endif

            r_n2 = max(1.-r_peak,0.e0)
            r_noise = sqrt(r_n2)
            r_dxx = r_dxx*i_wsaxyi
            r_dyy = r_dyy*i_wsaxyi
            r_dxy = r_dxy*i_wsaxyi

            r_n4 = r_n2**2
            r_n2 = r_n2*2
            r_n4 = r_n4*.5*i_wsaxyi

            r_u = r_dxy**2-r_dxx*r_dyy
            r_u2 = r_u**2       !                    *i_avgx*i_avgy/i_wsaxyi
            if ( r_u .eq. 0 ) then
               r_cov(1)=99.
               r_cov(2)=99.
               r_cov(3)=0.
               i_flag=1
            else
               r_cov(1)=(-r_n2*r_u*r_dyy+r_n4*(r_dyy**2+r_dxy**2))
     &              /r_u2
               r_cov(2)=(-r_n2*r_u*r_dxx+r_n4*(r_dxx**2+r_dxy**2))
     &              /r_u2
               r_cov(3)=((r_n2*r_u      -r_n4*(r_dxx+r_dyy))*r_dxy)
     &              /r_u2
            endif
            r_u=sqrt((r_cov(1)+r_cov(2))**2.-4.*(r_cov(1)*r_cov(2)-
     &           r_cov(3)**2))
            r_eval1=(r_cov(1)+r_cov(2)+r_u)/2.
            r_eval2=(r_cov(1)+r_cov(2)-r_u)/2.
            if ( r_eval1 .le. 0 .or. r_eval2 .le. 0 ) then
            endif
            
            if ( r_cov(3) .eq. 0 ) then
               if ( r_cov(1) .ge. r_cov(2) ) then
                  r_evec1(1)=1.
                  r_evec1(2)=0.
                  r_evec2(1)=0.
                  r_evec2(2)=1.
               else
                  r_evec1(1)=0.
                  r_evec1(2)=1.
                  r_evec2(1)=1.
                  r_evec2(2)=0.
               endif
            else
               if ( r_cov(1)-r_eval1 .ne. 0. ) then
                  r_evec1(1)=-r_cov(3)/(r_cov(1)-r_eval1)
               else
                  write(6,*) 'e vector 1 error'
                  r_evec1(1)=999.
               endif
               r_evec1(2)=1.
               r_u=sqrt(r_evec1(1)**2+r_evec1(2)**2)
               r_evec1(1)=r_evec1(1)/r_u
               r_evec1(2)=r_evec1(2)/r_u

               if ( r_cov(1)-r_eval2 .ne. 0. ) then
                  r_evec2(1)=-r_cov(3)/(r_cov(1)-r_eval2)
               else
                  write(6,*) 'e vector 2 error'
                  r_evec2(1)=999.
               endif
               r_evec2(2)=1.
               r_u=sqrt(r_evec2(1)**2+r_evec2(2)**2)
               r_evec2(1)=r_evec2(1)/r_u
               r_evec2(2)=r_evec2(2)/r_u
            endif

            r_evec1(1)=r_evec1(1)*sqrt(abs(r_eval1)) 
            r_evec1(2)=r_evec1(2)*sqrt(abs(r_eval1)) 
            r_evec2(1)=r_evec2(1)*sqrt(abs(r_eval2)) 
            r_evec2(2)=r_evec2(2)*sqrt(abs(r_eval2)) 

         else

            r_shfty=0
            r_shftx=0
            r_shrp=0.
            i_flag=1
            write(6,*) 'correlation error'

         endif

      else

         r_shfty=0
         r_shftx=0
         r_shrp=0.
         i_flag=1

      endif


      if(l_debug)then
         write(6,*) ' '
         write(6,*) 'Exit values'
         write(6,*) 'i_wsxi and i_wsyi = ',i_wsxi,i_wsyi
         write(6,*) 'i_wsxj and i_wsyj = ',i_wsxj,i_wsyj
         write(6,*) 'i_avgx and i_avgy = ',i_avgx,i_avgy
         write(6,*) 'r_meani and r_stdvi = ',r_meani,r_stdvi
         write(6,*) 'r_meanj and r_stdvj = ',r_meanj,r_stdvj
         write(6,*) 'r_peak and r_noise = ',r_peak,r_noise
         write(6,*) 'r_cov = ',r_cov(1),r_cov(2),r_cov(3)
         write(6,*) 'r_eval1 and r_eval2 = ',r_eval1,r_eval2
         write(6,*) 'r_evec1 and r_evec2 = ',r_evec1(1),r_evec1(2),
     &        r_evec2(1), r_evec2(2)
         write(6,*) 'r_shftx and r_shfty = ',r_shftx,r_shfty
         write(6,*) 'i_edge and i_flag = ',i_edge(1),i_edge(2),i_flag
      endif
      
      return

      end

      SUBROUTINE FOURNNR(DATA,NN,NDIM,ISIGN)    !numerical recipes fft when don't have fast one
c      SUBROUTINE fourn(data,nn,ndim,isign)
      INTEGER isign,ndim,nn(ndim)
      REAL data(*)
      INTEGER i1,i2,i2rev,i3,i3rev,ibit,idim,ifp1,ifp2,ip1,ip2,ip3,k1,
     *k2,n,nprev,nrem,ntot
      REAL tempi,tempr
      DOUBLE PRECISION theta,wi,wpi,wpr,wr,wtemp
      ntot=1
      do 11 idim=1,ndim
        ntot=ntot*nn(idim)
11    continue
      nprev=1
      do 18 idim=1,ndim
        n=nn(idim)
        nrem=ntot/(n*nprev)
        ip1=2*nprev
        ip2=ip1*n
        ip3=ip2*nrem
        i2rev=1
        do 14 i2=1,ip2,ip1
          if(i2.lt.i2rev)then
            do 13 i1=i2,i2+ip1-2,2
              do 12 i3=i1,ip3,ip2
                i3rev=i2rev+i3-i2
                tempr=data(i3)
                tempi=data(i3+1)
                data(i3)=data(i3rev)
                data(i3+1)=data(i3rev+1)
                data(i3rev)=tempr
                data(i3rev+1)=tempi
12            continue
13          continue
          endif
          ibit=ip2/2
1         if ((ibit.ge.ip1).and.(i2rev.gt.ibit)) then
            i2rev=i2rev-ibit
            ibit=ibit/2
          goto 1
          endif
          i2rev=i2rev+ibit
14      continue
        ifp1=ip1
2       if(ifp1.lt.ip2)then
          ifp2=2*ifp1
          theta=isign*6.28318530717959d0/(ifp2/ip1)
          wpr=-2.d0*sin(0.5d0*theta)**2
          wpi=sin(theta)
          wr=1.d0
          wi=0.d0
          do 17 i3=1,ifp1,ip1
            do 16 i1=i3,i3+ip1-2,2
              do 15 i2=i1,ip3,ifp2
                k1=i2
                k2=k1+ifp1
                tempr=sngl(wr)*data(k2)-sngl(wi)*data(k2+1)
                tempi=sngl(wr)*data(k2+1)+sngl(wi)*data(k2)
                data(k2)=data(k1)-tempr
                data(k2+1)=data(k1+1)-tempi
                data(k1)=data(k1)+tempr
                data(k1+1)=data(k1+1)+tempi
15            continue
16          continue
            wtemp=wr
            wr=wr*wpr-wi*wpi+wr
            wi=wi*wpr+wtemp*wpi+wi
17        continue
          ifp1=ifp2
        goto 2
        endif
        nprev=n*nprev
18    continue
      return
      END
C  (C) Copr. 1986-92 Numerical Recipes Software $23#1yR.3Z9.

      subroutine derampc(c_img,i_dimx,i_dimy)
 
      implicit none
      integer i_dimx,i_dimy,i,j
      complex c_img(i_dimx,i_dimy),c_phdn,c_phac
      real r_phac,r_phdn
 
      c_phdn = cmplx(0.,0.)
      c_phac = cmplx(0.,0.)
 
      do i=1,i_dimx-1
         do j=1,i_dimy
            c_phac = c_phac + c_img(i,j)*conjg(c_img(i+1,j))
         enddo
      enddo
 
      do i=1,i_dimx
         do j=1,i_dimy-1
            c_phdn = c_phdn + c_img(i,j)*conjg(c_img(i,j+1))
         enddo
      enddo
 
      if(cabs(c_phdn) .eq. 0)then
         r_phdn = 0.0
      else
         r_phdn = atan2(aimag(c_phdn),real(c_phdn))
      endif
 
      if(cabs(c_phac) .eq. 0)then
         r_phac = 0.0
      else
         r_phac = atan2(aimag(c_phac),real(c_phac))
      endif
 
c       write(6,*) 'Phase across, down = ',r_phac,r_phdn
      
      do i=1,i_dimx
         do j=1,i_dimy
            c_img(i,j) = c_img(i,j)*cmplx(cos(r_phac*i+r_phdn*j),
     &           sin(r_phac*i+r_phdn*j))
         enddo
      enddo
 
      end
            
c      subroutine fourn_jpl(data,nn,ndim,isign)
      subroutine fourn(data,nn,ndim,isign)

      complex data(*), d(16384)
      integer nn(2),n,ndim,is

      is = -isign
      n = nn(1)
      do i = 1,nn(2)
         call cfft1d_jpl(nn(1),data(1+nn(1)*(i-1)),is)
      end do

      do i = 1,nn(1)

         do j = 1,nn(2)
            d(j) = data(i+nn(1)*(j-1))
         end do

         call cfft1d_jpl(nn(2),d,is)

         do j = 1 , nn(2)
            if(is .eq. 1)then
               d(j) = d(j)*nn(1)*nn(2)
           endif
           data(i+nn(1)*(j-1)) = d(j)
         end do

      end do

      return
      end

c****************************************************************

            integer function nextpower(i_num)

c****************************************************************
c**     
c**   FILE NAME: nextpower.f
c**     
c**   DATE WRITTEN: 6/1/97
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: Computes the closest number which is a 
c**   power of two and returns the exponent of two for the number that 
c**   is the first power of two exceeding the input number.
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

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

c     INPUT VARIABLES:

      integer i_num
        
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

      real*8 r_num,r_log2,r_log2numm1
      integer i_temp

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

      data r_log2 /.301029995664d0/

c     FUNCTION STATEMENTS:

c     SAVE STATEMENTS:

      save r_log2

c     PROCESSING STEPS:

      r_num = i_num

      r_log2numm1 = dlog10(r_num - .5d0)/r_log2

      nextpower = int(r_log2numm1)+1
        
      end  

c****************************************************************

      subroutine dump_chip_c8(a_filename,c_data,i_startsamp,
     +     i_endsamp,i_startline,i_endline,i_physical_samps,
     +     i_physical_lines)

c****************************************************************
c**     
c**   FILE NAME: dump_chip_c8.f
c**     
c**   DATE WRITTEN: 7/3/2002
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: This routine will take data
c**   in a 2-D array and output into a direct access file. 
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

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

      integer i_unit
      parameter(i_unit=99)

c     INPUT VARIABLES:

      character*(*) a_filename
      integer i_physical_samps,i_physical_lines
      complex*8 c_data(i_physical_samps,i_physical_lines)
      integer i_startline,i_endline
      integer i_startsamp,i_endsamp
        
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

      integer i_samples,i,j,i_sl

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

c     SAVE STATEMENTS:

c     PROCESSING STEPS:

c     open file 

      i_samples = i_endsamp - i_startsamp + 1
      i_sl = index(a_filename,' ') - 1

      write(6,*) ' '
      write(6,'(a)') 'Opening direct access complex file: '//a_filename(1:i_sl)
      write(6,'(a,x,i10)') 'Record length: ',i_samples

      open(i_unit,file=a_filename,form='unformatted',access='direct',recl=8*i_samples)

      do i=i_startline,i_endline
         write(i_unit,rec=i-i_startline+1) (c_data(j,i),j=i_startsamp,i_endsamp)
      enddo

      close(i_unit)
        
      end  

c****************************************************************

      subroutine dump_chip_r4(a_filename,r_data,i_startsamp,
     +     i_endsamp,i_startline,i_endline,i_physical_samps,
     +     i_physical_lines)

c****************************************************************
c**     
c**   FILE NAME: dump_chip_r4.f
c**     
c**   DATE WRITTEN: 7/3/2002
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: This routine will take data
c**   in a 2-D array and output into a direct access file. 
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

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

      integer i_unit
      parameter(i_unit=99)

c     INPUT VARIABLES:

      character*(*) a_filename
      integer i_physical_samps,i_physical_lines
      real*4 r_data(i_physical_samps,i_physical_lines)
      integer i_startline,i_endline
      integer i_startsamp,i_endsamp
        
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

      integer i_samples,i,j,i_sl

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

c     SAVE STATEMENTS:

c     PROCESSING STEPS:

c     open file 

      i_samples = i_endsamp - i_startsamp + 1
      i_sl = index(a_filename,' ') - 1

      write(6,*) ' '
      write(6,'(a)') 'Opening direct access real*4 file: '//a_filename(1:i_sl)
      write(6,'(a,x,i10)') 'Record length: ',i_samples

      open(i_unit,file=a_filename,form='unformatted',access='direct',recl=4*i_samples)

      do i=i_startline,i_endline
         write(i_unit,rec=i-i_startline+1) (r_data(j,i),j=i_startsamp,i_endsamp)
      enddo

      close(i_unit)
        
      end  

c****************************************************************

      subroutine fill_sinc(r_beta,r_relfiltlen,i_decfactor,i_weight,
     +     r_pedestal,i_intplength,r_fdelay,r_fintp)

c****************************************************************
c**     
c**   FILE NAME: fill_sinc.f
c**     
c**   DATE WRITTEN: 2/2/98
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: This routine computes the sinc interpolation
c**   coefficients needed by the processor for various range and azimuth
c**   interpolations.
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

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:
      
      integer MAXDECFACTOR      ! maximum lags in interpolation kernels
      parameter(MAXDECFACTOR=4096)                        
      
      integer MAXINTKERLGH      ! maximum interpolation kernel length
      parameter (MAXINTKERLGH=256)
      
      integer MAXINTLGH         ! maximum interpolation kernel array size
      parameter (MAXINTLGH=MAXINTKERLGH*MAXDECFACTOR)

c     INPUT VARIABLES:

      integer i_decfactor,i_weight
      real*8 r_beta,r_relfiltlen,r_pedestal
        
c     OUTPUT VARIABLES:

      integer i_intplength      ! Range migration interpolation kernel length
      real*4  r_fdelay          ! Range migration filter delay
      real*4 r_fintp(0:MAXINTLGH) ! interpolation kernel values

c     LOCAL VARIABLES:

      real*8 r_filter(0:MAXINTLGH)
      integer i,j,i_filtercoef

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

c     SAVE STATEMENTS:

c     PROCESSING STEPS:

c     get sinc 
      
      call sinc_coef(r_beta,r_relfiltlen,i_decfactor,r_pedestal,
     +     i_weight,i_intplength,i_filtercoef,r_filter(0))
      
      r_fdelay = i_intplength/2.d0
      
      do i = 0 , i_intplength - 1
         do j = 0 , i_decfactor - 1
            r_fintp(i+j*i_intplength) = r_filter(j+i*i_decfactor)
         enddo
      enddo
      
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
      integer i_psfl,i,ii

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
         r_s = r_wa*r_beta/dble(i_decfactor)
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

c****************************************************************

      subroutine write_template(i_unit,i_listfile)

c****************************************************************
c**     
c**   FILE NAME: ampcor.f
c**     
c**   DATE WRITTEN: 8/15/02
c**     
c**   PROGRAMMER: Scott Hensley
c**     
c**   FUNCTIONAL DESCRIPTION: Write a template file for user.
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

c     INCLUDE FILES:

c     PARAMETER STATEMENTS:

      integer i_list,i_nolist              !match location in a list file
      parameter(i_list=1,i_nolist=0)

c     INPUT VARIABLES:

      integer i_unit 
      integer i_listfile
	
c     OUTPUT VARIABLES:

c     LOCAL VARIABLES:

c     COMMON BLOCKS:

c     EQUIVALENCE STATEMENTS:

c     DATA STATEMENTS:

c     FUNCTION STATEMENTS:

c     SAVE STATEMENTS:

c     PROCESSING STEPS:

      write(i_unit,'(a)') '                             AMPCOR RDF INPUT FILE'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Data Type for Reference Image Real or Complex                   (-)    =  Complex   ![Complex , '//
     +     'Real , RMG1 , RMG2]'
      write(i_unit,'(a)') 'Data Type for Search Image Real or Complex                      (-)    =  Complex   ![Complex , '//
     +     'Real , RMG1 , RMG2]'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !If file is a line '//
     +     'interleaved (i.e. RMG)'
      write(i_unit,'(a)') '                                                                          !file then RMG1 one '//
     +     'uses the first data' 
      write(i_unit,'(a)') '                                                                          !layer and RMG2 uses '//
     +     'the secoond data layer'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'INPUT/OUTPUT FILES'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Reference Image Input File                                      (-)    =  file1'
      write(i_unit,'(a)') 'Search Image Input File                                         (-)    =  file2'
      write(i_unit,'(a)') 'Match Output File                                               (-)    =  outfile'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'MATCH REGION'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Number of Samples in Reference/Search Images                    (-)    =  width_ref width_srch'//
     +     '   !Must be less than 18000'
      write(i_unit,'(a)') 'Start, End and Skip Lines in Reference Image                    (-)    =  firstline lastline skip_y'
      write(i_unit,'(a)') 'Start, End and Skip Samples in Reference Image                  (-)    =  firstpix width skip_x'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !Provides location of '//
     +     'match windows in'
      write(i_unit,'(a)') '                                                                          !imagery. Note it is '//
     +     'possible to match with' 
      write(i_unit,'(a)') '                                                                          !skip setting less '//
     +     'than the window size, of' 
      write(i_unit,'(a)') '                                                                          !course the matches '//
     +     'will NOT be independent.'
      write(i_unit,*) ' '
      if(i_listfile .eq. i_list)then
c         write(i_unit,'(a)') 'Match Point List File                                           (-)    =  list_file'
         write(i_unit,'(a)') 'List File Type                                                  (-)    =  list_type ![List Only , '//
     +        'XT Only , AT Only, Pair List]'
         write(i_unit,*) ' '                                                    
      endif
      write(i_unit,'(a)') 'MATCH PARAMETERS'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Reference Window Size Samples/Lines                             (-)    =  window_size_x window_size_y'
      write(i_unit,'(a)') 'Search Pixels Samples/Lines                                     (-)    =  search_x search_y'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !window size plus '//
     +     '2*(search window size)'
      write(i_unit,'(a)') '                                                                          !must be less than '//
     +     '512. Note to get best'
      write(i_unit,'(a)') '                                                                          !oversampling of the '//
     +     'correlation surface should'
      write(i_unit,'(a)') '                                                                          !set the search '//
     +     'window to 5 or greater, otherwise'
      write(i_unit,'(a)') '                                                                          !sinc interpolator '//
     +     'does not have enough support.'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Pixel Averaging Samples/Lines                                   (-)    =  pix_ave_x pix_ave_y'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !If you expect '//
     +     'subpixel matching accuracy'
      write(i_unit,'(a)') '                                                                          !then this '//
     +     'SHOULD BE SET TO ONE!'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Covariance Surface Oversample Factor and Window Size            (-)    =  oversample_fact window_size'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !oversample factor '//
     +     'determine how much'
      write(i_unit,'(a)') '                                                                          !oversampling via '//
     +     'sinc interpolation is done'
      write(i_unit,'(a)') '                                                                          !for the covarinance '//
     +     'surface. Two times this'
      write(i_unit,'(a)') '                                                                          !number is the '//
     +     'quantization level of the matches,'
      write(i_unit,'(a)') '                                                                          !e.g. if '//
     +     'oversample = 64 the 128 of a pixel'
      write(i_unit,'(a)') '                                                                          !quantization '//
     +     'error. Window size is how many pixels'
      write(i_unit,'(a)') '                                                                          !in the '//
     +     'CORRELATION SURFACE to oversample. Best'
      write(i_unit,'(a)') '                                                                          !results '//
     +     'should have number > 8.'
      write(i_unit,*) ' '                                                      
      write(i_unit,'(a)') 'Mean Offset Between Reference and Search Images Samples/Lines   (-)    =  iX0 iY0'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !Convention used '//
     +     'that position in ref image plus'
      write(i_unit,'(a)') '                                                                          !offset is equal '//
     +     'to position in image 2.'  
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'Matching Scale for Sample/Line Directions                       (-)    =  ScaleX ScaleY'
      write(i_unit,'(a)') '                                                                          !Default is '//
     +     'that the scale is one in both directions'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'MATCH THRESHOLDS AND DEBUG DATA'
      write(i_unit,*) ' '
      write(i_unit,'(a)') 'SNR and Covariance Thresholds                                   (-)    =  snr_thresh cov_thresh'
      write(i_unit,*) ' '
      write(i_unit,'(a)') '                                                                          !Eliminates matches '//
     +     'based on SNR threshold (SNR must be'
      write(i_unit,'(a)') '                                                                          !greater than '//
     +     'this threshold) and Covariance threshold'
      write(i_unit,'(a)') '                                                                          !(cross track '//
     +     'and along track SQRT(COV) must be LESS THAN'
      write(i_unit,'(a)') '                                                                          !than this '//
     +     'threshold in PIXELS. Typical values depend'
      write(i_unit,'(a)') '                                                                          !on type of '//
     +     'imagery being matched.' 
      write(i_unit,*) ' '                     
      write(i_unit,'(a)') 'Debug and Display Flags T/F                                     (-)    =  f t'

      close(i_unit)
	
      end  







