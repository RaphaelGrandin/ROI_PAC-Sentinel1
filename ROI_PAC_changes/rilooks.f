c  rilooks -  average real,imaginary looks
c      complex a(20480),b(20480)
c      real b1(20480),b2(20480)
      complex a(28000),b(28000)
      real b1(28000),b2(28000)
      character*120 fin,fout
      integer ierr

      print '(a,$)',' Input file? '
      read(*,'(a)') fin
      print '(a,$)',' Output file? '
      read(*,'(a)') fout

      print '(a,$)',' Complex pixels across, down in input: '
      read *,na,nd
      print '(a,$)',' Looks across, down: '
      read *,la,ld

      open(21,file=fin,form='unformatted',access='direct',recl=na*8)
      open(22,file=fout,form='unformatted',access='direct',recl=na/la*8)
      
      lineout=0
      do line=1,nd,ld
         if(mod(line,64).eq.1)print *,line
         lineout=lineout+1
         do j=1,na
            b1(j)=0.
            b2(j)=0.
         end do

c  take looks down
         do i=0,ld-1
            read(21,rec=line+i,iostat=ierr)(a(k),k=1,na)
            if(ierr .ne. 0) go to 99
            do j=1,na
               b1(j)=b1(j)+real(a(j))**2
               b2(j)=b2(j)+aimag(a(j))**2
            end do
         end do
c  take looks across
         jpix=0
         do j=1,na,la
            jpix=jpix+1
            sum1=0.
            sum2=0.
            do k=0,la-1
               sum1=sum1+b1(j+k)
               sum2=sum2+b2(j+k)
            end do
            b(jpix)=cmplx(sqrt(sum1),sqrt(sum2))
         end do
         write(22,rec=lineout)(b(k),k=1,na/la)
      end do
 99   end
CPOD      
CPOD=pod
CPOD
CPOD=head1 USAGE
CPOD
CPOD rilooks: takes real and imaginary looks of a complex input rater file
CPOD 
CPOD usage: rilooks prompts for the following inputs:
CPOD        Input file / Output file / Complex pixels across, down in input/ Looks across, down 
CPOD
CPOD=head1 FUNCTION
CPOD
CPOD FUNCTIONAL DESCRIPTION: takes <re>,<im> looks 
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
