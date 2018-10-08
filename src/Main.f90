! https://github.com/MichaelSiehl/Atomic_Subroutines-Part_5a--Image_Failure--Design_A_Recovery_Process
!
program Main
  !
  ! A simple test-case to show how to repair the
  ! corrupted (atomic) data transfer channels of a Fortran 2018 coarray program.
  ! The example uses a simple fast running (nonsensical) parallel algorithm:
  ! restore segment ordering among coarray images.
  ! All data transfers are through atomic subroutines.
  !
  ! Please compile and run this coarray
  ! program with 6 coarray images.
  !
  use OOOGglob_Globals
  use OOOEerro_admError
  use OOOPimsc_admImageStatus_CA
  implicit none
  !
  integer(OOOGglob_kint) :: intCount1, intCount2 !, i
  integer(OOOGglob_kint) :: intNumberOfRemoteImages
  integer(OOOGglob_kint), dimension (1:5) :: intA_RemoteImageNumbers ! please compile and run this coarray
                                                                     ! program with 6 coarray images
  logical(OOOGglob_klog) :: logSynchronizationFailure = .false.
  integer(OOOGglob_kint) :: intControlImageNumber
  integer(OOOGglob_kint) :: intNumberOfSuccessfulRemoteImages
  integer(OOOGglob_kint), dimension (1:5) :: intA_TheSuccessfulRemoteImageNumbers
  !
  if (num_images() < 6) then
    write(*,*) 'please run the program with 6 coarray images'
    error stop
  end if
  !
  intControlImageNumber = 1
  intNumberOfRemoteImages = 5
  intA_RemoteImageNumbers = (/2,3,4,5,6/) ! the involved remote image numbers
  !************************************************************************************************
  ! A. First execution of the parallel algorithm:
  call OOOPimsc_RestoreSegmentOrder_CA (OOOPimscImageStatus_CA_1, intControlImageNumber, intNumberOfRemoteImages, &
                                      intA_RemoteImageNumbers, &
                                      logSynchronizationFailure, intNumberOfSuccessfulRemoteImages, &
                                      intA_TheSuccessfulRemoteImageNumbers, &
                                      logRaiseAnError = .true.) ! to raise an error that may corrupt the
                                                                ! atomic data transfer channels
  !
  if (logSynchronizationFailure) then
      write(*,*)'RestoreSegmentOrder A failed on image', this_image()
    else ! no failure
      write(*,*)'RestoreSegmentOrder A successful on image', this_image()
  end if
  !
sync all
  !************************************************************************************************
  ! B. Second execution of the parallel algorithm:
  call OOOPimsc_RestoreSegmentOrder_CA (OOOPimscImageStatus_CA_1, intControlImageNumber, intNumberOfRemoteImages, &
                                      intA_RemoteImageNumbers, &
                                      logSynchronizationFailure, intNumberOfSuccessfulRemoteImages, &
                                      intA_TheSuccessfulRemoteImageNumbers, &
                                      logReAllocateCoarrayObject = .true.) ! to repair the corrupted
                                                                           ! data transfer channels
  !
  if (logSynchronizationFailure) then
    write(*,*)'RestoreSegmentOrder B failed on image', this_image()
  else ! no failure
    write(*,*)'RestoreSegmentOrder B successful on image', this_image()
  end if
    !
end program Main
