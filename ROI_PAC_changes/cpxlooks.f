c  cpxlooks -  average complex looks
c      complex a(20480),b(20480),sum,pha,phd
      complex a(28000),b(28000),sum,pha,phd
      character*120 fin,fout
      integer ierr

      print '(a,$)',' Input file? '
      read '(a)',fin
      print '(a,$)',' Output file? '
      read '(a)',fout

      print '(a,$)',' Complex pixels across, down in input: '
      read *,na,nd
      print '(a,$)',' Looks across, down: '
      read *,la,ld
      print '(a,$)',' Delta phase across, down: '
      read *,pa,pd
      pha=cmplx(cos(pa),sin(pa))
      phd=cmplx(cos(pd),sin(pd))

      open(21,file=fin,form='unformatted',access='direct',recl=na*8)
      open(22,file=fout,form='unformatted',access='direct',recl=na/la*8)
      
      lineout=0
      do line=1,nd,ld
         if(mod(line,64).eq.1)print *,line
         lineout=lineout+1
         do j=1,na
            b(j)=cmplx(0.,0.)
         end do

c  take looks down
         do i=0,ld-1
            read(21,rec=line+i,iostat=ierr)(a(k),k=1,na)
            if(ierr .ne. 0) goto 99
            do j=1,na
               b(j)=b(j)+a(j)*pha**j*phd**(line+i)
            end do
         end do
c  take looks across
         jpix=0
         do j=1,na,la
            jpix=jpix+1
            sum=cmplx(0.,0.)
            do k=0,la-1
               sum=sum+b(j+k)
            end do
            b(jpix)=sum
         end do
         write(22,rec=lineout)(b(k),k=1,na/la)
      end do
 99   end
CPOD      
CPOD=pod
CPOD
CPOD=head1 USAGE
CPOD
CPOD cpxlooks: takes (average) complex looks
CPOD 
CPOD usage: cpxlooks prompts for the following inputs:
CPOD        Input file / Output file / Complex pixels across, down in input/ Looks across, down /
CPOD        Delta phase across, down (radians)
CPOD
CPOD=head1 FUNCTION
CPOD
CPOD FUNCTIONAL DESCRIPTION: takes complex looks and applies a linear across/down phase screen
CPOD
CPOD=head1 ROUTINES CALLED
CPOD
CPOD ROUTINES CALLED: 
CPOD
CPOD=head1 CALLED BY
CPOD
CPOD=head1 FILES USED
CPOD
CPOD reads in a binary complex/c*8 input file (width/length)
CPOD
CPOD=head1 FILES CREATED
CPOD
CPOD write a binary complex/c*8 output file (width/#across looks)(Length/#down looks)
CPOD
CPOD=head1 DIAGNOSTIC FILES
CPOD
CPOD=head1 HISTORY
CPOD
CPOD DATE WRITTEN: 
CPOD
CPOD PROGRAMMER: ??
CPOD
CPOD=head1 LAST UPDATE
CPOD  Date Changed        Reason Changed 
CPOD  ------------       ----------------
CPOD
CPOD: CPOD comments V0.1: trm Feb 13th '04
CPOD
CPOD=cut
