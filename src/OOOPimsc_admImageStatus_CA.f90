! https://github.com/MichaelSiehl/Atomic_Subroutines-Part_5a--Image_Failure--Design_A_Recovery_Process

module OOOPimsc_admImageStatus_CA
!************************************************
! Namespace: OOOP - Parallel
!************************************************
! Abstact Data Type Short Name: OOOPimsc
!********************************************************
! Abstract Data Type (ADT):         OOOPimsc_adtImageStatus_CA
! Abstract Data Type Module (adm):  OOOPimsc_admImageStatus_CA.f90
!********************************************************
! Purpose:                    ImageStatus_CA-Object
! Language:                   mainly Fortran 95 with Fortran 2018 coarrays
! Programmer:                 Michael Siehl
! Date:                       October 2018
!********************************************************
! Naming Conventions:
!
!  for scalar members:
!                             m: object member
!                             S: setter, G: getter,
!                             S_atomic: the setter operates on atomic values using atomic_define and SYNC MEMORY
!                             G_check_atomic: the getter only checks local PGAS memory for specific values atomically
!
!  for array members:
!                             A: array
!                             mA: array member
!                             SA: set array, GA: get array,
!
!  for elements of array members:
!                             SAElement: set only one array element
!                             GAElement: get only one array element
!
!                             99: signals a static array member which has an upper array bound
!                                 larger than necessary; the upper bound is given by a global parameter
!
!  other naming conventions:
!                             _CA: coarray routine / coarray declaration
!                             SYNC_: synchronization routine
!
!                             Enum: enumeration
!
!                             OO: public (outer) scope (the two leading namespace letters)
!                             II: private (inner) scope
!                             UU: sub-object
!********************************************************
!___________________________________________________________

use OOOGglob_Globals
use OOOEerro_admError
use, intrinsic :: iso_fortran_env
!___________________________________________________________

implicit none
!___________________________________________________________

private
!__________________________________________________________
!
public :: OOOPimsc_AllocateCoarrayObject
! for recovery from corrupted data transfer channels:
public :: OOOPimsc_ReAllocateCoarrayObject
! *****
!
! service routines for (integer-based) enumeration handling:
public :: OOOPimsc_PackEnumValue, OOOPimsc_UnpackEnumValue
! *****
!
! access and synchronization routines for atomic scalar
! and atomic static array members:
public :: OOOPimscSAElement_atomic_intImageActivityFlag99_CA, & ! set array element
          OOOPimscEventPostScalar_intImageActivityFlag99_CA, & ! customized EventPost plus optional Scalar
          OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA, & ! get (check) array element
          OOOPimscEventWaitScalar_intImageActivityFlag99_CA ! customized EventWait plus optional scalar
!
! *****
!
! Encapsulate access to the SYNC MEMORY statement herein,
! counting/tracking of the execution segments on each image locally
! and access routines for the mA_atomic_intImageSyncMemoryCount99 member:
public :: OOOPimsc_subSyncMemory, OOOPimscSAElement_atomic_incr_intImageSyncMemoryCount99_CA, &
          OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA
!
! *****
! A (nonsensical) parallel algorithm example:
! (logic codes for segment order restoring)
public :: OOOPimsc_RestoreSegmentOrder_CA
private :: OOOPimsc_ControlSegmentSynchronization_CA
private :: OOOPimsc_ExecuteSegmentSynchronization_CA
!
!*****
! coarray ADT management:
public :: OOOPimsc_StructureConstructor_CA
!___________________________________________________________
!
!***************************
!****  Error Handling:  ****
!***************************
!***
! local ADT:
private :: IIimsc_ErrorHandler
!***
! coarray ADT:
private :: IIimsc_ImageNumberBoundError_CA
!___________________________________________________________
!
!************************
!****  Enumerations:  ***
!************************
!
!***  ImageActivityFlag:
type, private :: OOOPimsc_DontUse1
  integer(kind=OOOGglob_kint) :: Enum_StepWidth ! = 1000000 ! always required
  !
  integer(kind=OOOGglob_kint) :: InitialWaiting ! = 2000000
  integer(kind=OOOGglob_kint) :: TryToSynchronize ! = 3000000
  integer(kind=OOOGglob_kint) :: TryWasSuccessful ! = 4000000
  integer(kind=OOOGglob_kint) :: ExecutionFinished ! = 5000000
  integer(kind=OOOGglob_kint) :: InitiateSegmentSynchronization ! = 6000000
  integer(kind=OOOGglob_kint) :: WaitForSegmentSynchronization ! = 7000000
  integer(kind=OOOGglob_kint) :: ContinueSegmentSynchronization ! = 8000000
  integer(kind=OOOGglob_kint) :: SendetCurrentSegmentNumber ! = 9000000
  integer(kind=OOOGglob_kint) :: DoSegmentSynchronization ! = 10000000
  integer(kind=OOOGglob_kint) :: FinishedSegmentSynchronization ! = 11000000
  integer(kind=OOOGglob_kint) :: InitiateTestArrayTransfer ! = 12000000
  integer(kind=OOOGglob_kint) :: WaitForTestArrayTransfer ! = 13000000
  integer(kind=OOOGglob_kint) :: ResetTheTestArray ! = 14000000
  integer(kind=OOOGglob_kint) :: LocalTestArrayResetDone ! = 15000000
  integer(kind=OOOGglob_kint) :: TestArrayRemoteTransferDone ! = 16000000
  integer(kind=OOOGglob_kint) :: InitiateASynchronization ! = 17000000
  ! always required:
  integer(kind=OOOGglob_kint) :: WaitingForEventPost ! = 18000000
  integer(kind=OOOGglob_kint) :: DoSynchronizationAbort ! = 19000000
  integer(kind=OOOGglob_kint) :: Enum_MaxValue ! = 20000000
end type OOOPimsc_DontUse1
!
type (OOOPimsc_DontUse1), public, parameter :: OOOPimscEnum_ImageActivityFlag &
     = OOOPimsc_DontUse1 (1000000,2000000,3000000,4000000,5000000, &
            6000000,7000000,8000000,9000000,10000000,11000000, &
            12000000,13000000,14000000,15000000,16000000,17000000,18000000,19000000,20000000)
!
!**************************
!___________________________________________________________
!
!***************************************
!***  Type Definition: *****************
!***************************************
type, public :: OOOPimsc_adtImageStatus_CA
  private
  !*****
  integer(atomic_int_kind), dimension (1:OOOGglob_NumImages_UpperBound) :: &
                  mA_atomic_intImageActivityFlag99 != OOOPimscEnum_ImageActivityFlag % InitialWaiting
  !*****
  integer(atomic_int_kind), dimension (1:OOOGglob_NumImages_UpperBound) :: mA_atomic_intImageSyncMemoryCount99 = 0
  !*****
  type (OOOEerroc_colError) :: m_UUerrocError ! error collection
  !
end type OOOPimsc_adtImageStatus_CA
!___________________________________________________________
!
!*************************************
!*** Coarray Declaration:  ***********
!*************************************
!***
type (OOOPimsc_adtImageStatus_CA), public, allocatable, codimension[*], save :: OOOPimscImageStatus_CA_1 [:]
!___________________________________________________________





contains


!##################################################################################################
!##################################################################################################
!##################################################################################################
!____________________________________________________________
!**********
subroutine OOOPimsc_AllocateCoarrayObject
  ! does only allocate if it is not already allocated
  ! (this procedure must be executed on all images of the current team)
  !
                                                                call OOOGglob_subSetProcedures &
                                                                   ("OOOPimsc_AllocateCoarrayObject")
  !
  if (.not.allocated (OOOPimscImageStatus_CA_1) ) then
    allocate (OOOPimscImageStatus_CA_1 [*])
  end if
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_AllocateCoarrayObject
!**********
subroutine OOOPimsc_ReAllocateCoarrayObject
  ! the purpose is to recover from corrupted (atomic) coarray data transfer channels
  ! and to newly establish segment ordering
  ! (this procedure must be executed on all images of the current team)
  !
                                                                call OOOGglob_subSetProcedures &
                                                                   ("OOOPimsc_ReAllocateCoarrayObject")
  !
  if (allocated (OOOPimscImageStatus_CA_1) ) then
    deallocate (OOOPimscImageStatus_CA_1)
  end if
  !
  allocate (OOOPimscImageStatus_CA_1 [*])
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_ReAllocateCoarrayObject
!
!**********
!____________________________________________________________
!
! **************************************************************
! Pack and unpack an enumeration value with an additional value.
! (Store two distinct (reduced-size integer) values into a
!  single integer to allow for atomic synchronizations):
! **************************************************************
! **********
subroutine OOOPimsc_PackEnumValue (Object_CA, intEnumValue, intAdditionalValue, &
                                                intPackedEnumValue, intEnum_StepWidth)
  ! pack the both integer input arguments into a single integer scalar
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intEnumValue
  integer(OOOGglob_kint), intent (in) :: intAdditionalValue
  integer(OOOGglob_kint), intent (out) :: intPackedEnumValue
  integer(OOOGglob_kint), optional, intent(in) :: intEnum_StepWidth ! only for error checking
  integer(OOOGglob_kint) :: status
  !
                                                                call OOOGglob_subSetProcedures &
                                                              ("OOOPimsc_PackEnumValue")
  !
  if (present(intEnum_StepWidth)) then ! do error checking
                                                                ! check if intAdditionalValue argument is to large:
                                                                ! ToDo: check if it is negative
                                                                if (intAdditionalValue >= intEnum_StepWidth) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "intAdditionalValue is to large", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
  end if
  !
  intPackedEnumValue = intEnumValue + intAdditionalValue
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_PackEnumValue
!
!**********
subroutine OOOPimsc_UnpackEnumValue (intPackedEnumValue, intEnum_StepWidth, &
                             intUnpackedEnumValue, intUnpackedAdditionalValue)
  ! unpack the packed integer enum value into two integer scalars
  integer(OOOGglob_kint), intent (in) :: intPackedEnumValue
  integer(OOOGglob_kint), intent (in) :: intEnum_StepWidth
  integer(OOOGglob_kint), intent (out) :: intUnpackedEnumValue
  integer(OOOGglob_kint), intent (out) :: intUnpackedAdditionalValue
  !
                                                                call OOOGglob_subSetProcedures &
                                                                   ("OOOPimsc_UnpackEnumValue")
  !
  intUnpackedAdditionalValue = mod(intPackedEnumValue, intEnum_StepWidth)
  !
  intUnpackedEnumValue = intPackedEnumValue - intUnpackedAdditionalValue
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_UnpackEnumValue
!
!**********
!____________________________________________________________
!
! *****************************************************
! access routines and synchronization routines for the
! mA_atomic_intImageActivityFlag99 member:
! *****************************************************
!
subroutine OOOPimscSAElement_atomic_intImageActivityFlag99_CA (Object_CA, intSyncValue, &
                            intImageNumber, intArrayIndex, logExecuteSyncMemory, intAtomicDefineStatus)
  ! setter: set an array element atomically
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intSyncValue ! enum value for the synchronization
  integer(OOOGglob_kint), intent (in) :: intImageNumber ! the (remote) image number
  integer(OOOGglob_kint), optional, intent (in) :: intArrayIndex
  integer(OOOGglob_kint) :: intArrIndex
  integer(OOOGglob_kint) :: intMaxVal
  logical(OOOGglob_klog), optional, intent (in) :: logExecuteSyncMemory
  logical(OOOGglob_klog) :: logSyncMemoryExecution
  integer(OOOGglob_kint), optional, intent (out) :: intAtomicDefineStatus
  !
  integer(OOOGglob_kint) :: status = 0 ! error status
                                                                call OOOGglob_subSetProcedures &
                                                                 ("OOOPimscSAElement_atomic_intImageActivityFlag99_CA")
  !
  if (present(intArrayIndex)) then
                                                                ! check if intArrayIndex argument is to large:
                                                                ! ToDo: check if it is negative
                                                                intMaxVal = OOOGglob_NumImages_UpperBound
                                                                if (intArrayIndex .gt. intMaxVal) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "intArrayIndex is to large", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
    intArrIndex = intArrayIndex
  else ! default:
    intArrIndex = intImageNumber
  end if
  !
  !
  if (present(logExecuteSyncMemory)) then
    logSyncMemoryExecution = logExecuteSyncMemory
  else ! default:
    logSyncMemoryExecution = .false.
  end if
  !
  !****************
  !
  if (intImageNumber == this_image()) then ! local atomic define
    ! don't execute sync memory for local atomic_define:
      call atomic_define(Object_CA % mA_atomic_intImageActivityFlag99(intArrIndex), intSyncValue) !, &
      !STAT = intAtomicDefineStatus) ! STAT is Fortran 2018 syntax
  !
  else ! remote atomic define
                                                                ! check if the image number is valid:
                                                                if (IIimsc_ImageNumberBoundError_CA &
                                                                (Object_CA, intImageNumber)) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "no valid image number", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
    ! execute sync memory for remote atomic_define:
    if (logSyncMemoryExecution) call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
    !
      call atomic_define(Object_CA [intImageNumber] % mA_atomic_intImageActivityFlag99(intArrIndex), intSyncValue) !, &
      !STAT = intAtomicDefineStatus) ! STAT is Fortran 2018 syntax
    !
  end if
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimscSAElement_atomic_intImageActivityFlag99_CA
!
!************************************************************
!
subroutine OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSyncValue, &
                                intImageNumber, intArrayIndex, logExecuteSyncMemory, &
                                intAdditionalAtomicValue, intEnumStepWidth)
  ! customized Event Post plus Scalar:
  ! An optional (limited size integer) scalar value (AdditionalAtomicValue)
  ! will be packed with the intImageActivityFlag for remote data transfer through atomic_define.
  !
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intSyncValue ! enum value for the synchronization
  integer(OOOGglob_kint), intent (in) :: intImageNumber ! the (remote) image number
  integer(OOOGglob_kint), optional, intent (in) :: intArrayIndex
  integer(OOOGglob_kint) :: intArrIndex
  integer(OOOGglob_kint) :: intMaxVal
  logical(OOOGglob_klog), optional, intent (in) :: logExecuteSyncMemory
  logical(OOOGglob_klog) :: logSyncMemoryExecution
  integer(OOOGglob_kint), optional, intent (in) :: intAdditionalAtomicValue
  integer(OOOGglob_kint) :: intAddAtomicValue
  integer(OOOGglob_kint), optional, intent (in) :: intEnumStepWidth
  integer(OOOGglob_kint) :: intPackedEnumValue
  !
  integer(OOOGglob_kint) :: status = 0 ! error status
                                                                call OOOGglob_subSetProcedures &
                                                                 ("OOOPimscEventPostScalar_intImageActivityFlag99_CA")
  !****
  if (present(intArrayIndex)) then
                                                                ! check if intArrayIndex argument is to large:
                                                                ! ToDo: check if it is negative
                                                                intMaxVal = OOOGglob_NumImages_UpperBound
                                                                if (intArrayIndex .gt. intMaxVal) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "intArrayIndex is to large", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
    intArrIndex = intArrayIndex
  else ! default:
    intArrIndex = intImageNumber
  end if
  !****
  if (present(logExecuteSyncMemory)) then
    logSyncMemoryExecution = logExecuteSyncMemory
  else ! default:
    logSyncMemoryExecution = .false.
  end if
  !****
  if (present(intAdditionalAtomicValue)) then
    intAddAtomicValue = intAdditionalAtomicValue
  else ! default:
    intAddAtomicValue = 0
  end if
  !****
  if (present(intEnumStepWidth)) then ! only for error checking
    call OOOPimsc_PackEnumValue (Object_CA, intSyncValue, intAddAtomicValue, intPackedEnumValue, &
                                        intEnumStepWidth)
  else ! default: (without error checking)
    call OOOPimsc_PackEnumValue (Object_CA, intSyncValue, intAddAtomicValue, intPackedEnumValue)
  end if
  !****
  !
  ! do a customized EventPost (atomic_define):
    call OOOPimscSAElement_atomic_intImageActivityFlag99_CA (Object_CA, intPackedEnumValue, &
                 intImageNumber, intArrIndex, logExecuteSyncMemory=logSyncMemoryExecution)
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimscEventPostScalar_intImageActivityFlag99_CA
!
!************************************************************
!
logical(OOOGglob_klog) function OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA (Object_CA, intCheckSyncValue, &
                                                          intArrayIndex, intAdditionalAtomicValue, logExecuteSyncMemory, &
                                                          intAtomicRefStatus)
  ! getter: get (check) an array element atomically:
  ! in order to hide the sync memory statement herein, this getter does not allow
  ! to access the member directly, but instead does only allow to check the atomic member
  ! for specific values (this getter is intented for synchronizations)
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intCheckSyncValue ! enum value for the synchronization
  integer(OOOGglob_kint), optional, intent (in) :: intArrayIndex
  integer(OOOGglob_kint) :: intArrIndex
  integer(OOOGglob_kint) :: intMaxVal
  integer(OOOGglob_kint), optional, intent (out) :: intAdditionalAtomicValue
  integer(OOOGglob_kint) :: intSyncValue
  integer(OOOGglob_kint) :: intPackedEnumValue
  integer(OOOGglob_kint) :: intEnum_StepWidth
  integer(OOOGglob_kint) :: intUnpackedEnumValue
  integer(OOOGglob_kint) :: intUnpackedAdditionalValue
  logical(OOOGglob_klog), optional, intent (in) :: logExecuteSyncMemory
  logical(OOOGglob_klog) :: logSyncMemoryExecution
  integer(OOOGglob_kint), optional, intent (out) :: intAtomicRefStatus
  !
  integer(OOOGglob_kint) :: status = 0 ! error status
                                                                call OOOGglob_subSetProcedures &
                                                                 ("OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA")
  !
  OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA = .false.
  !
  if (present(intArrayIndex)) then
                                                                ! check if intArrayIndex argument is to large:
                                                                ! ToDo: check if it is negative
                                                                intMaxVal = OOOGglob_NumImages_UpperBound
                                                                if (intArrayIndex .gt. intMaxVal) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "intArrayIndex is to large", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
    intArrIndex = intArrayIndex
  else ! default:
    intArrIndex = this_image()
  end if
  !
  if (present(logExecuteSyncMemory)) then
    logSyncMemoryExecution = logExecuteSyncMemory
  else ! default:
    logSyncMemoryExecution = .false.
  end if
  !
      ! access an array element in local PGAS memory atomically:
      call atomic_ref(intSyncValue, Object_CA % mA_atomic_intImageActivityFlag99(intArrIndex))
        !STAT = intAtomicRefStatus) ! STAT is Fortran 2018 syntax
  !
  ! unpack the intImageActivityFlag value:
  intPackedEnumValue = intSyncValue
  intEnum_StepWidth = OOOPimscEnum_ImageActivityFlag % Enum_StepWidth
  call OOOPimsc_UnpackEnumValue (intPackedEnumValue, intEnum_StepWidth, &
                             intUnpackedEnumValue, intUnpackedAdditionalValue)
  intSyncValue = intUnpackedEnumValue
  !
  if (intCheckSyncValue == intSyncValue) then
    if (logSyncMemoryExecution) call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
    OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA = .true.
  end if
  !
  if (present(intAdditionalAtomicValue)) then
    intAdditionalAtomicValue = intUnpackedAdditionalValue
  end if
  !
                                                                call OOOGglob_subResetProcedures
end function OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA
!
!************************************************************
!
subroutine OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intCheckSyncValue, &
                  intNumberOfImages, intA_RemoteImageNumbers, logArrayIndexIsThisImage, &
                  intA_RemoteImageAndItsAdditionalAtomicValue, logExecuteSyncMemory, &
                  logSynchronizationAbortDidOccur, intRemoteImageThatDidTheAbort, &
                  intNumberOfSuccessfulRemoteSynchronizations, intA_TheSuccessfulImageNumbers, &
                  intNumberOfFailedRemoteSynchronizations, intA_TheFailedImageNumbers, &
                  logActivateTimeLimitAbort, reaTimeLimitInSeconds, &
                  logTimeLimitAbortDidOccur, reaAbortTimeInSeconds)
  ! customized Event Wait plus Scalar:
  ! (An optional (limited size integer) scalar value will be unpacked in the intA_RemoteImageAndItsAdditionalAtomicValue(:,2)
  ! optional output argument)
  !
  ! This routine is for atomic bulk synchronization (among the executing image and one or more remote images)
  ! using a spin-wait loop synchronizaton. Thus, the procedure implements a customized synchronization
  ! using atomic subroutines and the sync memory statement internally. Ordered execution segments among the involved images
  ! are only required with additional data transfer.
  !
  ! Remote data transfer through atomic_define can be faulty. Thus, this procedure implements a way to allow aborting the
  ! synchronization from another coarray image (that image is usually not involved with the synchronization itself),
  ! through the intCheckRemoteAbortOfSynchronization argument. Further, and in case of such a synchronization abort,
  ! this routine gives a synchronization diagnostic (through its logRemoteAbortOfSynchronization, intRemoteImageThatDidTheAbort,
  ! intNumberOfSuccessfulRemoteSynchronizations, and intA_TheSuccessfulImageNumbers optional arguments).
  !
  ! This procedure also implements an abort timer (time limit) for the spin-wait synchronization that allows to detect
  ! failures or inefficient execution of a parallel algorithm. The abort timer can be deactivated through the
  ! logActivateTimeLimitAbort optional argument (default is true).
  !
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intCheckSyncValue ! enum value for the synchronization
  integer(OOOGglob_kint), intent (in) :: intNumberOfImages ! these are the number of involved remote images
  integer(OOOGglob_kint), dimension (1:intNumberOfImages), intent (in) :: intA_RemoteImageNumbers
  logical(OOOGglob_klog), optional, intent (in) :: logArrayIndexIsThisImage
  logical(OOOGglob_klog) :: logArrIndexIsThisImage
  integer(OOOGglob_kint) :: intArrIndex
  integer(OOOGglob_kint), optional, dimension (1:intNumberOfImages, 1:2), intent (out) :: &
                                                       intA_RemoteImageAndItsAdditionalAtomicValue
  integer(OOOGglob_kint) :: intCount ! do loop counter variable
  integer(OOOGglob_kint) :: intImageNumber
  logical(OOOGglob_klog), dimension (1:intNumberOfImages) :: logA_CheckImageStates
  integer(OOOGglob_kint) :: intAtomicValue = 0
  logical(OOOGglob_klog), optional, intent (in) :: logExecuteSyncMemory
  logical(OOOGglob_klog) :: logSyncMemoryExecution
  integer(OOOGglob_kint) :: intMaxVal
  !
  integer(OOOGglob_kint) :: intCheckValueForSynchronizationAbort
  logical(OOOGglob_klog), optional, intent (out) :: logSynchronizationAbortDidOccur
  integer(OOOGglob_kint), optional, intent (out) :: intRemoteImageThatDidTheAbort
  integer(OOOGglob_kint), optional, intent (out) :: intNumberOfSuccessfulRemoteSynchronizations
  integer(OOOGglob_kint) :: intNumOfSuccessfulRemoteSynchronizations
  integer(OOOGglob_kint), optional, dimension (1:intNumberOfImages), intent (out) :: intA_TheSuccessfulImageNumbers
  integer(OOOGglob_kint), dimension (1:intNumberOfImages) :: intA_TheSuccessfulImageNums
  integer(OOOGglob_kint) :: intCurrentPosition
  !
  integer(OOOGglob_kint), optional, intent (out) :: intNumberOfFailedRemoteSynchronizations
  integer(OOOGglob_kint), optional, dimension (1:intNumberOfImages), intent (out) :: intA_TheFailedImageNumbers
  integer(OOOGglob_kint) :: intCountTheFailedImages ! do loop counter variable
  !
  ! abort timer for the spin-wait loop
  ! (using system_clock):
  real(OOOGglob_krea) :: reaCountRate = 0.0
  integer(OOOGglob_kint) :: intTime1 = 0
  integer(OOOGglob_kint) :: intTime2 = 0
  real(OOOGglob_krea) :: reaTimeShift = 0.0
  !
  logical(OOOGglob_klog), optional, intent (in) :: logActivateTimeLimitAbort ! default is .true.
  logical(OOOGglob_klog) :: logActivateTimeLimitAbor
  real(OOOGglob_krea), optional, intent (in) :: reaTimeLimitInSeconds ! time limit for the customized EventWait sync
  logical(OOOGglob_klog), optional, intent (out) :: logTimeLimitAbortDidOccur
  real(OOOGglob_krea), optional, intent (out) :: reaAbortTimeInSeconds ! abort time in seconds
  real(OOOGglob_krea) :: reaTimeLimitInSec
  !
  integer(OOOGglob_kint) :: status = 0 ! error status
  !
                                                                call OOOGglob_subSetProcedures &
                                            ("OOOPimscEventWaitScalar_intImageActivityFlag99_CA")
  !
  !****
  intCheckValueForSynchronizationAbort = OOOPimscEnum_ImageActivityFlag % DoSynchronizationAbort
  !****
  if (present(intA_RemoteImageAndItsAdditionalAtomicValue)) &
                              intA_RemoteImageAndItsAdditionalAtomicValue(:,:) = 0 ! initial value
  !****
  if (present(logArrayIndexIsThisImage)) then
    logArrIndexIsThisImage = logArrayIndexIsThisImage
  else ! default:
    logArrIndexIsThisImage = .false.
  end if
  !****
  if (present(logExecuteSyncMemory)) then
    logSyncMemoryExecution = logExecuteSyncMemory
  else ! default:
    logSyncMemoryExecution = .false.
  end if
  !****
  if (present(logSynchronizationAbortDidOccur)) then
    logSynchronizationAbortDidOccur = .false. ! initial value
  end if
  !****
  if (present(intRemoteImageThatDidTheAbort)) then
    intRemoteImageThatDidTheAbort = 0 ! initial value
  end if
  !****
  if (present(intNumberOfSuccessfulRemoteSynchronizations)) then
    intNumberOfSuccessfulRemoteSynchronizations = 0 ! initial value
  end if
  intNumOfSuccessfulRemoteSynchronizations = 0 ! initial value
  !****
  if (present(intA_TheSuccessfulImageNumbers)) intA_TheSuccessfulImageNumbers = 0 ! initial value
  intA_TheSuccessfulImageNums = 0 ! initial value
  !****
  if (present(intNumberOfFailedRemoteSynchronizations)) intNumberOfFailedRemoteSynchronizations = 0 ! initial value
  if (present(intA_TheFailedImageNumbers)) intA_TheFailedImageNumbers = 0 ! initial value
  !****
  if (present(logActivateTimeLimitAbort)) then
    logActivateTimeLimitAbor = logActivateTimeLimitAbort
  else ! default:
    logActivateTimeLimitAbor = .true.
  end if
  !****
  ! initiate the timer:
  if (present(reaTimeLimitInSeconds)) then
    reaTimeLimitInSec = reaTimeLimitInSeconds
    call system_clock(count_rate = reaCountRate)
    call system_clock(count = intTime1) ! initiate the timer
  else ! default:
    reaTimeLimitInSec = OOOGglob_reaTimeLimitInSec_small
    call system_clock(count_rate = reaCountRate)
    call system_clock(count = intTime1) ! initiate the timer
  end if
  !****
  if (present(logTimeLimitAbortDidOccur)) then
    logTimeLimitAbortDidOccur = .false. ! initial value
  end if
  !****
  if (present(reaAbortTimeInSeconds)) then
    reaAbortTimeInSeconds = 0.0 ! initial value, no abort
  end if
  !****
  ! initialize the array elements with .false.:
  logA_CheckImageStates = .false.
  !
  !***********************************************************************
  ! wait until all the involved remote image(s) do signal that they are in state intCheckImageActivityFlag
  ! spin-wait loop synchronization:
  spin_wait: do
    each_image: do intCount = 1, intNumberOfImages
      !
      intImageNumber = intA_RemoteImageNumbers(intCount)
      intArrIndex = intImageNumber ! but:
        if (logArrIndexIsThisImage) intArrIndex = this_image()
      if (intImageNumber .ne. this_image()) then ! (synchronization is only required between distinct images)
        if (.not. logA_CheckImageStates(intCount)) then ! check is only required if the remote image is not already
                                                        ! in state intCheckImageActivityFlag:
          ! atomic_ref:
          if (OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA (Object_CA, &
                           intCheckSyncValue, intArrayIndex = intArrIndex, &
                           intAdditionalAtomicValue = intAtomicValue, logExecuteSyncMemory = .false.)) then
            ! the synchronization was successful:
            !
            logA_CheckImageStates(intCount) = .true. ! the remote image is in state intCheckImageActivityFlag
            !
            if (present(intA_RemoteImageAndItsAdditionalAtomicValue)) then
            ! save the remote image number together with its sent AdditionalAtomicValue:
              intA_RemoteImageAndItsAdditionalAtomicValue(intCount,1) = intImageNumber
              intA_RemoteImageAndItsAdditionalAtomicValue(intCount,2) = intAtomicValue
            end if
            !
            ! record the remote image numbers that did complete the synchronization successfully:
            ! count how many images completed the synchronization successfully so far:
            ! (to determine the current positon)
            intCurrentPosition = count(logA_CheckImageStates)
            ! save the successful remote image number:
            intA_TheSuccessfulImageNums(intCurrentPosition) = intImageNumber
          !
          end if
        end if
      else ! (intImageNumber .eq. this_image())
        ! raise an error:
                                                                call IIimsc_ErrorHandler (Object_CA, &
                                                            "the executing image can't synchronize with itself yet", &
                                                                  OOOGglob_error, status)
                                                                !
        logA_CheckImageStates(intCount) = .true. ! otherwise the outer do loop would turn into an endless loop
      end if
    end do each_image
    !
    if (all(logA_CheckImageStates)) then ! all involved remote images are in state intCheckImageActivityFlag
      if (logSyncMemoryExecution) call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
      !
      intNumOfSuccessfulRemoteSynchronizations = count(logA_CheckImageStates)
      if (present(intNumberOfSuccessfulRemoteSynchronizations)) then
        intNumberOfSuccessfulRemoteSynchronizations = intNumOfSuccessfulRemoteSynchronizations
      end if
      if (present(intA_TheSuccessfulImageNumbers)) then
        intA_TheSuccessfulImageNumbers = intA_TheSuccessfulImageNums
      end if
         !
      exit spin_wait ! exit the do loop if all involved remote images are in state
                     ! intCheckImageActivityFlag (the synchronization was successful)
    end if
    !
    !*********
    ! local abort timer (time limit) for the spin-wait synchronization:
    if (logActivateTimeLimitAbor) then ! default is .true.
      call system_clock(count = intTime2)
      reaTimeShift = real(intTime2 - intTime1) / reaCountRate
      if (reaTimeShift > reaTimeLimitInSec) then ! the time limit for the spin-wait loop has been exceeded
        ! do a local EventPost to terminate the spin-wait loop:
        ! (the abort will then be done in the below code section 'for leaving a fault
        !  synchronization')
        call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, &
                    intCheckValueForSynchronizationAbort, & ! here, that value is used for local abord
                    intImageNumber = this_image(), logExecuteSyncMemory = .false., &
                    intAdditionalAtomicValue = this_image() )
        if (present(logTimeLimitAbortDidOccur)) logTimeLimitAbortDidOccur = .true.
        if (present(reaAbortTimeInSeconds)) reaAbortTimeInSeconds = reaTimeShift
      end if
    end if
    !
    !*********
    ! for leaving a fault synchronization do the following check:
    if (OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA (Object_CA, &
        intCheckSyncValue = intCheckValueForSynchronizationAbort, &
        intArrayIndex = this_image(), intAdditionalAtomicValue = intAtomicValue, &
        logExecuteSyncMemory = .false.) ) then
      !
      if (logSyncMemoryExecution) call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
      !
      if (present(logSynchronizationAbortDidOccur)) then
        logSynchronizationAbortDidOccur = .true.
      end if
      !
      if (present(intRemoteImageThatDidTheAbort)) then
        intRemoteImageThatDidTheAbort = intAtomicValue
      end if
      !
      intNumOfSuccessfulRemoteSynchronizations = count(logA_CheckImageStates)
      if (present(intNumberOfSuccessfulRemoteSynchronizations)) then
        intNumberOfSuccessfulRemoteSynchronizations = intNumOfSuccessfulRemoteSynchronizations
      end if
      !
      if (present(intA_TheSuccessfulImageNumbers)) then
        intA_TheSuccessfulImageNumbers = intA_TheSuccessfulImageNums
      end if
      !
      if (present(intNumberOfFailedRemoteSynchronizations)) then
        intNumberOfFailedRemoteSynchronizations = intNumberOfImages - intNumOfSuccessfulRemoteSynchronizations
        if (present(intA_TheFailedImageNumbers)) then
          if (intNumberOfFailedRemoteSynchronizations > 0) then
            intCountTheFailedImages = 0
            do intCount = 1, intNumberOfImages
              intImageNumber = intA_RemoteImageNumbers(intCount)
              if (all(intA_TheSuccessfulImageNums /= intImageNumber)) then ! ImageNumber was not successfully synchronized
                intCountTheFailedImages = intCountTheFailedImages + 1
                intA_TheFailedImageNumbers(intCountTheFailedImages) = intImageNumber
              end if
            end do
          end if
        end if
      end if
      !
      !
      exit spin_wait ! exit the do loop if the status is 'intCheckValueForSynchronizationAbort'
               ! (i.e. a(nother) remote image does signal to abort the synchronization process)
    end if
  !
  end do spin_wait
  !
  !**********************************************************************
  !
                                                                call OOOGglob_subResetProcedures
  !
end subroutine OOOPimscEventWaitScalar_intImageActivityFlag99_CA
!
!____________________________________________________________
!
!
! *************************************************************************
! Encapsulate access to the SYNC MEMORY statement herein,
! counting/tracking of the execution segments on each image locally,
! and access routines for the mA_atomic_intImageSyncMemoryCount99 member:
! *************************************************************************
!
!**********
subroutine OOOPimsc_subSyncMemory (Object_CA)
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  ! encapsulates access to SYNC MEMORY
                                                                call OOOGglob_subSetProcedures &
                                                                 ("OOOPimsc_subSyncMemory")
  sync memory
  ! increment the ImageSyncMemoryCount to track the execution segment order
  ! on the executing image:
  call OOOPimscSAElement_atomic_incr_intImageSyncMemoryCount99_CA (Object_CA)
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_subSyncMemory
!
!**********
! private:
subroutine OOOPimscSAElement_atomic_incr_intImageSyncMemoryCount99_CA (Object_CA)
  ! increment (by 1) the ImageSyncMemoryCount member atomically on the executing image
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint) :: intTemp
  integer(OOOGglob_kint) :: status = 0 ! error status
!integer(OOOGglob_kint) :: test
  !
                                                                call OOOGglob_subSetProcedures &
                                                            ("OOOPimscSAElement_atomic_incr_intImageSyncMemoryCount99_CA")
  !
  ! increment (by 1) the ImageSyncMemoryCount member atomically on the executing image only:
  ! every image uses its own array index (this_image())
  !
  ! Fortran 2018 syntax:
  !call atomic_add(Object_CA % mA_atomic_intImageSyncMemoryCount99(this_image()), 1)
  !
  ! Fortran 2008 syntax:
  call atomic_ref(intTemp, Object_CA % mA_atomic_intImageSyncMemoryCount99 (this_image()))
  intTemp = intTemp + 1
  ! don't execute sync memory for local atomic_define:
  call atomic_define(Object_CA % mA_atomic_intImageSyncMemoryCount99 (this_image()), intTemp)
!
! test:
!call atomic_ref(test, Object_CA % mA_atomic_intImageSyncMemoryCount99 (this_image()))
!write(*,*) 'entering execution segment', test, 'on image', this_image()
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimscSAElement_atomic_incr_intImageSyncMemoryCount99_CA
!**********
! private:
subroutine OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intSyncMemoryCount, intArrayIndex)
  ! get only one array element on the executing image
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (out) :: intSyncMemoryCount
  integer(OOOGglob_kint), optional, intent (in) :: intArrayIndex
  integer(OOOGglob_kint) :: intArrIndex
  integer(OOOGglob_kint) :: intMaxVal
  integer(OOOGglob_kint) :: status = 0 ! error status
  !
                                                                call OOOGglob_subSetProcedures &
                                                                  ("OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA")
  if (present(intArrayIndex)) then
                                                                ! check if intArrayIndex argument is to large:
                                                                ! ToDo: check if it is negative
                                                                intMaxVal = OOOGglob_NumImages_UpperBound
                                                                if (intArrayIndex .gt. intMaxVal) then
                                                                  call IIimsc_ErrorHandler (Object_CA, &
                                                                       "intArrayIndex is to large", &
                                                                    OOOGglob_error, status)
                                                                  call OOOGglob_subResetProcedures
                                                                  return
                                                                end if
                                                                !
    intArrIndex = intArrayIndex
  else ! default:
    intArrIndex = this_image() ! ToDo: this subroutine should only be used with this default
  end if
  ! get the array element:
  call atomic_ref(intSyncMemoryCount, Object_CA % mA_atomic_intImageSyncMemoryCount99 (intArrIndex))
  ! no SYNC MEMORY statement here, because this call to atomic_ref is not used for synchronization and
  ! thus, this is not an atomic checker routine
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA
!*************
!___________________________________________________________
!
!___________________________________________________________
!##############################################################################################
! Parallel logic codes for restoring ordered execution segments among a number of images  #####
!##############################################################################################
!
!___________________________________________________________
!
! public
subroutine OOOPimsc_RestoreSegmentOrder_CA (Object_CA, intControlImageNumber, intNumberOfRemoteImages, &
                                        intA_RemoteImageNumbers, &
                                        logSynchronizationFailure, intNumberOfSuccessfulRemoteImages, &
                                        intA_TheSuccessfulRemoteImageNumbers, logReAllocateCoarrayObject, &
                                        logRaiseAnError)
  ! This procedure encapsulates access to the both parallel algorithm procedures
  ! OOOPimsc_ControlSegmentSynchronization_CA and OOOPimsc_ExecuteSegmentSynchronization_CA below.
  !
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intControlImageNumber ! the image number that controls the parallel algorithm execution
  integer(OOOGglob_kint), intent (in) :: intNumberOfRemoteImages ! number of images for use with the parallel algorithm
  integer(OOOGglob_kint), dimension (intNumberOfRemoteImages), intent (in) :: intA_RemoteImageNumbers ! these images
                                                                                  ! do execute the parallel algorithm
  !
  logical(OOOGglob_klog), intent (out) :: logSynchronizationFailure
  integer(OOOGglob_kint), optional, intent (out) :: intNumberOfSuccessfulRemoteImages
  integer(OOOGglob_kint) :: intNumberOfSuccessfulRemoteImages_
  integer(OOOGglob_kint), optional, dimension (intNumberOfRemoteImages), intent (out) :: &
                                                                       intA_TheSuccessfulRemoteImageNumbers
  integer(OOOGglob_kint), dimension (intNumberOfRemoteImages) :: intA_TheSuccessfulRemoteImageNumbers_
  !
  logical(OOOGglob_klog), optional, intent (in) :: logReAllocateCoarrayObject
  logical(OOOGglob_klog) :: logReAllocateCoarrayObject_
  !
  logical(OOOGglob_klog), optional, intent (in) :: logRaiseAnError
  logical(OOOGglob_klog) :: logRaiseAnError_
  !
  integer(OOOGglob_kint) :: intCount1, intCount2
  !
!  integer(OOOGglob_kint) :: status = 0 ! error status
  !
                                                                call OOOGglob_subSetProcedures &
                                                            ("OOOPimsc_RestoreSegmentOrder_CA")
  !**********************************************
  if (present(logReAllocateCoarrayObject)) then
    logReAllocateCoarrayObject_ = logReAllocateCoarrayObject
  else
    logReAllocateCoarrayObject_ = .false. ! default
  end if
  !
  call OOOPimsc_AllocateCoarrayObject ! does allocate only if it is not already allocated
  !
  if (logReAllocateCoarrayObject_) then
    call OOOPimsc_ReAllocateCoarrayObject ! to repair the coarray data transfer channels
  end if
  !**********************************************
  if (present(logRaiseAnError)) then
    logRaiseAnError_ = logRaiseAnError
  else
    logRaiseAnError_ = .false. ! default
  end if
  !**********************************************
  ! a simple trick to generate unordered execution segments:
  do intCount1 = 1, num_images()
    if (this_image() == intCount1) then
      do intCount2 = 1, (6-this_image()) ! works only for image numbers <= 6
        call OOOPimsc_subSyncMemory (OOOPimscImageStatus_CA_1) ! execute sync memory to
                                                               ! enter a new execution segment
      end do
    end if
  end do
  !**********************************************
  logSynchronizationFailure = .false. ! initial value
  !**********************************************
  if (present(intNumberOfSuccessfulRemoteImages)) then
    intNumberOfSuccessfulRemoteImages = intNumberOfRemoteImages ! initial value
  end if
  if (present(intA_TheSuccessfulRemoteImageNumbers)) then
    intA_TheSuccessfulRemoteImageNumbers = intA_RemoteImageNumbers ! initial value
  end if
  !****
  !**********************************************
  !
  if (logRaiseAnError_) then ! raise an error:
    if (this_image() == intControlImageNumber) then
      !
      ! start the control routine on the control image:
      call OOOPimsc_ControlSegmentSynchronization_CA (OOOPimscImageStatus_CA_1, intNumberOfRemoteImages, &
                  intA_RemoteImageNumbers(1:intNumberOfRemoteImages), logSynchronizationFailure, &
                  intNumberOfSuccessfulRemoteImages_, intA_TheSuccessfulRemoteImageNumbers)
    else
      if (this_image() /= 3) then ! don't execute on image 3 to raise an error
        ! on other images execute the parallel algorithm:
        call OOOPimsc_ExecuteSegmentSynchronization_CA (OOOPimscImageStatus_CA_1, intControlImageNumber, &
                    logSynchronizationFailure)
      else ! (this_image() == 3)
        logSynchronizationFailure = .true. ! because we do not execute the algorithm on image 3
      end if
    end if
  else ! don't raise an error:
    if (this_image() == intControlImageNumber) then
      !
      ! start the control routine on the control image:
      call OOOPimsc_ControlSegmentSynchronization_CA (OOOPimscImageStatus_CA_1, intNumberOfRemoteImages, &
                  intA_RemoteImageNumbers(1:intNumberOfRemoteImages), logSynchronizationFailure, &
                  intNumberOfSuccessfulRemoteImages_, intA_TheSuccessfulRemoteImageNumbers)
    else
      ! on other images execute the parallel algorithm:
      call OOOPimsc_ExecuteSegmentSynchronization_CA (OOOPimscImageStatus_CA_1, intControlImageNumber, &
                  logSynchronizationFailure)
    end if
  end if
    !
  !**********************************************
  !
  if (logSynchronizationFailure) then
    if (present(intNumberOfSuccessfulRemoteImages)) then
      intNumberOfSuccessfulRemoteImages = intNumberOfSuccessfulRemoteImages_
    end if
    if (present(intA_TheSuccessfulRemoteImageNumbers)) then
      intA_TheSuccessfulRemoteImageNumbers = intA_TheSuccessfulRemoteImageNumbers_
    end if
  end if
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_RestoreSegmentOrder_CA
!___________________________________________________________
!
! private
subroutine OOOPimsc_ControlSegmentSynchronization_CA (Object_CA, intNumberOfImages,intA_RemoteImageNumbers, &
                                        logSynchronizationFailure, intNumberOfSuccessfulRemoteImages, &
                                        intA_TheSuccessfulRemoteImageNumbers)
  ! This routine is for controlling the executing segment synchronization (i.e. restoring of segment ordering)
  ! among a number of involved remote images. To do so, this routine gets executed on a separate coarray image
  ! (called the control image) that will not be part of the execution segment restoring process itself.
  ! (counterpart synchronization routine is OOOPimsc_ExecuteSegmentSynchronization_CA)
  !
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intNumberOfImages ! these are the number of involved remote images
  integer(OOOGglob_kint), dimension (intNumberOfImages), intent (in) :: intA_RemoteImageNumbers
  logical(OOOGglob_klog), intent (out) :: logSynchronizationFailure
  integer(OOOGglob_kint), optional, intent (out) :: intNumberOfSuccessfulRemoteImages
  integer(OOOGglob_kint), optional, dimension (intNumberOfImages), intent (out) :: intA_TheSuccessfulRemoteImageNumbers
  !
  logical(OOOGglob_klog) :: logSynchronizationAbortDidOccur
  integer(OOOGglob_kint) :: intRemoteImageThatDidTheAbort
  integer(OOOGglob_kint) :: intNumberOfSuccessfulRemoteSynchronizations
  integer(OOOGglob_kint), dimension (1:intNumberOfImages) :: intA_TheSuccessfulImageNumbers
  integer(OOOGglob_kint) :: intNumberOfFailedRemoteSynchronizations
  integer(OOOGglob_kint), dimension (1:intNumberOfImages) :: intA_TheFailedImageNumbers
  logical(OOOGglob_klog) :: logTimeLimitAbortDidOccur
  real(OOOGglob_krea) :: reaAbortTimeInSeconds
  !
  integer(OOOGglob_kint) :: intSegmentSyncStatus
  integer(OOOGglob_kint) :: intCount
  integer(OOOGglob_kint) :: intImageNumber
  integer(OOOGglob_kint), dimension (1:intNumberOfImages, 1:2) :: intA_RemoteImageAndSegmentCounts
  integer(OOOGglob_kint) :: intMaxSegmentCount
  integer(OOOGglob_kint), dimension (1) :: intA_MaxSegmentCountLocation ! the array index
  integer(OOOGglob_kint), dimension (1) :: intA_ImageNumberWithMaxSegmentCount
  integer(OOOGglob_kint) :: intLocalSyncMemoryCount
  !
!  integer(OOOGglob_kint) :: status = 0 ! error status
  !
                                                                call OOOGglob_subSetProcedures &
                                                            ("OOOPimsc_ControlSegmentSynchronization_CA")
  !
  logSynchronizationFailure = .false. ! initial value
  if (present(intNumberOfSuccessfulRemoteImages)) then
    intNumberOfSuccessfulRemoteImages = intNumberOfImages ! initial value
  end if
  if (present(intA_TheSuccessfulRemoteImageNumbers)) then
    intA_TheSuccessfulRemoteImageNumbers = intA_RemoteImageNumbers ! initial value
  end if
  !****
  !************************************************
  ! (1) initiate segment synchronization on the involved remote images:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % InitiateSegmentSynchronization
  call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
  do intCount = 1, intNumberOfImages
    intImageNumber = intA_RemoteImageNumbers(intCount)
    if (intImageNumber .ne. this_image()) then ! (synchronization is only required between distinct images)
      ! initiate the segment synchronization on the involved remote images:
      call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                         intImageNumber, logExecuteSyncMemory = .false., &
                         intAdditionalAtomicValue = this_image(), intEnumStepWidth = &
                         OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
      !
    end if
  end do
  !
  !************************************************
  ! (2) wait until all the involved remote image(s) do signal that they are in state WaitForSegmentSynchronization:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % WaitForSegmentSynchronization
  !
  call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
            intNumberOfImages, intA_RemoteImageNumbers, &
            logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur, &
            intNumberOfSuccessfulRemoteSynchronizations = intNumberOfSuccessfulRemoteSynchronizations, &
            intA_TheSuccessfulImageNumbers = intA_TheSuccessfulImageNumbers)
  !
  if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
    logSynchronizationFailure = .true.
    if (present(intNumberOfSuccessfulRemoteImages)) then
      intNumberOfSuccessfulRemoteImages = intNumberOfSuccessfulRemoteSynchronizations
    end if
    if (present(intA_TheSuccessfulRemoteImageNumbers)) then
      intA_TheSuccessfulRemoteImageNumbers = intA_TheSuccessfulImageNumbers
    end if
    !
    return
  end if
  !
  !**********************************************************************
  ! (3) set the involved remote images to state ContinueSegmentSynchronization:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % ContinueSegmentSynchronization
  call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
  do intCount = 1, intNumberOfImages
    intImageNumber = intA_RemoteImageNumbers(intCount)
    if (intImageNumber .ne. this_image()) then ! (synchronization is only required between distinct images)
    ! to continue the segment synchronization on the involved remote images:
      !
      call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                         intImageNumber, logExecuteSyncMemory = .false., &
                         intAdditionalAtomicValue = this_image(), intEnumStepWidth = &
                         OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
      !
    end if
  end do
  !
  !**********************************************************************
  ! (4) wait until all the involved remote image(s) do signal that they are in state SendetCurrentSegmentNumber:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % SendetCurrentSegmentNumber
  !
  call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
            intNumberOfImages, intA_RemoteImageNumbers, &
            intA_RemoteImageAndItsAdditionalAtomicValue = intA_RemoteImageAndSegmentCounts, &
            logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur, &
            intNumberOfSuccessfulRemoteSynchronizations = intNumberOfSuccessfulRemoteSynchronizations, &
            intA_TheSuccessfulImageNumbers = intA_TheSuccessfulImageNumbers)
  !
  if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
    logSynchronizationFailure = .true.
    if (present(intNumberOfSuccessfulRemoteImages)) then
      intNumberOfSuccessfulRemoteImages = intNumberOfSuccessfulRemoteSynchronizations
    end if
    if (present(intA_TheSuccessfulRemoteImageNumbers)) then
      intA_TheSuccessfulRemoteImageNumbers = intA_TheSuccessfulImageNumbers
    end if
    !
    return
  end if
  !
  !**********************************************************************
  ! (5) get the max segment (sync memory) count (only the remote images):
  intMaxSegmentCount = maxval(intA_RemoteImageAndSegmentCounts(:,2))
!write(*,*)'MaxSegmentCount (MaxSyncMemoryCount): ', intMaxSegmentCount
  intA_MaxSegmentCountLocation = maxloc(intA_RemoteImageAndSegmentCounts(:,2))
  intA_ImageNumberWithMaxSegmentCount = intA_RemoteImageAndSegmentCounts (intA_MaxSegmentCountLocation,1)
!write(*,*)'ImageNumberWithMaxSegmentCount: ', intA_ImageNumberWithMaxSegmentCount
  !
  !**********************************************************************
  ! (5a) get the segment (sync memory) count on this image (not required for this example program):
  call OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intLocalSyncMemoryCount)
  !
  !**********************************************************************
  ! (6) initiate that the remote images do restore segment ordering:
  ! (restore the segment order among the involved remote images)
  ! to do so, set the involved remote images to state DoSegmentSynchronization:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % DoSegmentSynchronization
  ! increment intMaxSegmentCount by 1 because the remote images will execute an
  ! additional sync memory statement when receiving the atomic value from the do loop below:
  intMaxSegmentCount = intMaxSegmentCount + 1
  call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
  do intCount = 1, intNumberOfImages
    intImageNumber = intA_RemoteImageNumbers(intCount)
    if (intImageNumber .ne. this_image()) then ! (synchronization is only required between distinct images)
    ! to execute the segment synchronization on the involved remote images:
    !
      call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                         intImageNumber, logExecuteSyncMemory = .false., &
                         intAdditionalAtomicValue = intMaxSegmentCount, intEnumStepWidth = &
                         OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
      !
    end if
  end do
  !
  !**********************************************************************
  ! (7) wait until all the involved remote images do signal that they are in state FinishedSegmentSynchronization:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % FinishedSegmentSynchronization
  !
  call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
            intNumberOfImages, intA_RemoteImageNumbers, &
            intA_RemoteImageAndItsAdditionalAtomicValue = intA_RemoteImageAndSegmentCounts, &
            logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur, &
            intNumberOfSuccessfulRemoteSynchronizations = intNumberOfSuccessfulRemoteSynchronizations, &
            intA_TheSuccessfulImageNumbers = intA_TheSuccessfulImageNumbers)
  !
  if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
    logSynchronizationFailure = .true.
    if (present(intNumberOfSuccessfulRemoteImages)) then
      intNumberOfSuccessfulRemoteImages = intNumberOfSuccessfulRemoteSynchronizations
    end if
    if (present(intA_TheSuccessfulRemoteImageNumbers)) then
      intA_TheSuccessfulRemoteImageNumbers = intA_TheSuccessfulImageNumbers
    end if
    !
    return
  end if
  !
!write(*,*) 'remote image number and its CurrentSegmentCount:',intA_RemoteImageAndSegmentCounts(:,1:2)
  !**********************************************************************
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_ControlSegmentSynchronization_CA
!___________________________________________________________
!
! private
subroutine OOOPimsc_ExecuteSegmentSynchronization_CA (Object_CA, intControlImageNumber, &
                                                    logSynchronizationFailure)
  ! this routine does the segment synchronization (restoring) on the involved inages
  ! (the involved images will execute this)
  ! (counterpart synchronization routine is OOOPimsc_ControlSegmentSynchronization_CA)
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  integer(OOOGglob_kint), intent (in) :: intControlImageNumber ! this is the remote image number
                                                               ! which controls the synchronization
  logical(OOOGglob_klog), intent (out) :: logSynchronizationFailure
  !
  integer(OOOGglob_kint) :: intRemoteImageNumber
  integer(OOOGglob_kint) :: intSegmentSyncStatus
  integer(OOOGglob_kint) :: intNumberOfImages
  integer(OOOGglob_kint), dimension (1) :: intA_RemoteImageNumbers
  logical(OOOGglob_klog) :: logSynchronizationAbortDidOccur
  integer(OOOGglob_kint) :: intRemoteImageThatDidTheAbort
  integer(OOOGglob_kint) :: intNumberOfSuccessfulRemoteSynchronizations
  integer(OOOGglob_kint), dimension (1:1) :: intA_TheSuccessfulImageNumbers
  integer(OOOGglob_kint) :: intNumberOfFailedRemoteSynchronizations
  integer(OOOGglob_kint), dimension (1:1) :: intA_TheFailedImageNumbers
  logical(OOOGglob_klog) :: logTimeLimitAbortDidOccur
  real(OOOGglob_krea) :: reaAbortTimeInSeconds
  !
  integer(OOOGglob_kint) :: intSyncMemoryCount
  integer(OOOGglob_kint), dimension (1:1, 1:2) :: intA_RemoteImageAndMaxSegmentCount
  integer(OOOGglob_kint) :: intMaxSegmentCount
  integer(OOOGglob_kint) :: intNumberOfSyncMemoryStatementsToExecute
  integer(OOOGglob_kint) :: intCount
  !
  real(OOOGglob_krea) :: reaTime1 = 0.0
  real(OOOGglob_krea) :: reaTime2 = 0.0
  real(OOOGglob_krea) :: reaTimeShift = 0.0
  !
  integer(OOOGglob_kint) :: status = 0 ! error status
  !
                                                                call OOOGglob_subSetProcedures &
                                                            ("OOOPimsc_ExecuteSegmentSynchronization_CA")
  !
  logSynchronizationFailure = .false. ! initial value
  !****
  !**********************************************************************
  ! (1) wait until image state is remotely set (by the control image)
  ! to value InitiateSegmentSynchronization
  intNumberOfImages = 1
  intRemoteImageNumber = intControlImageNumber
  intA_RemoteImageNumbers(1) = intRemoteImageNumber
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % InitiateSegmentSynchronization
    !
    call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                intNumberOfImages, intA_RemoteImageNumbers, logArrayIndexIsThisImage = .true., &
                logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur)
    !
    if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
      logSynchronizationFailure = .true.
      !
      return
    end if
    !
!write(*,*) '******** initiate segment synchronization on image', this_image()
  !
  ! *********************************************************************
  ! (2) signal to the remote control image that this image is now in state 'WaitForSegmentSychronization':
  intRemoteImageNumber = intControlImageNumber
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % WaitForSegmentSynchronization
  !
  call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                 intRemoteImageNumber, intArrayIndex = this_image(), logExecuteSyncMemory = .false., &
                 intAdditionalAtomicValue = this_image(), intEnumStepWidth = &
                 OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
  !
  !**********************************************************************
  ! (3) wait until image state is remotely set to value ContinueSegmentSynchronization
  intNumberOfImages = 1
  intA_RemoteImageNumbers(1) = intRemoteImageNumber
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % ContinueSegmentSynchronization
  !
  call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
              intNumberOfImages, intA_RemoteImageNumbers, logArrayIndexIsThisImage = .true., &
              logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur)
  !
  if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
    logSynchronizationFailure = .true.
    !
    return
  end if
  !
  !
  !**********************************************************************
  ! (4) send the current intSyncMemoryCount of this image to the remote control image:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % SendetCurrentSegmentNumber
  ! get the the current segment number (SyncMemoryCount) on this image:
  ! (a) get the SyncMemoryCount on this image:
  call OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intSyncMemoryCount)
  ! (b) increment it by one because of the following call to OOOPimscSAElement_atomic_intImageActivityFlag99_CA
  !     (which does execute SYNC MEMORY):
!  intSyncMemoryCount = intSyncMemoryCount + 1
  ! signal to the remote control image that this image is now in state 'SendetCurrentSegmentNumber'
  ! and transmit also the current SyncMemoryCount within the same packed enum value:
  !
  call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                 intRemoteImageNumber, intArrayIndex = this_image(), logExecuteSyncMemory = .false., &
                 intAdditionalAtomicValue = intSyncMemoryCount, intEnumStepWidth = &
                 OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
  !
  !**********************************************************************
  ! (5) wait until image state is remotely set to value 'DoSegmentSynchronization'
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % DoSegmentSynchronization
  !
  call OOOPimscEventWaitScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
              intNumberOfImages, intA_RemoteImageNumbers, logArrayIndexIsThisImage = .true., &
              intA_RemoteImageAndItsAdditionalAtomicValue = intA_RemoteImageAndMaxSegmentCount, &
              logSynchronizationAbortDidOccur = logSynchronizationAbortDidOccur)
  !
  if (logSynchronizationAbortDidOccur) then ! the EventWait did fail
    logSynchronizationFailure = .true.
    !
    return
  end if
  !
  intMaxSegmentCount = intA_RemoteImageAndMaxSegmentCount(1,2)
  !
  !
  !**********************************************************************
  ! (6) restore the segment order (sync memory count) on the involved images (this image):
  ! (a) get the SyncMemoryCount on this image:
  call OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intSyncMemoryCount)
  ! (b) change the segment order only if this_image has a lower sync memory count as intMaxSegmentCount:
  if (intMaxSegmentCount .gt. intSyncMemoryCount) then
    intNumberOfSyncMemoryStatementsToExecute = intMaxSegmentCount - intSyncMemoryCount
    ! restore the segment order (among the involved images) for this image:
    do intCount = 1, intNumberOfSyncMemoryStatementsToExecute
      call OOOPimsc_subSyncMemory (Object_CA) ! execute sync memory
    end do
!call OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intSyncMemoryCount)
!write(*,*) 'segment order restored to value x on image y:',intSyncMemoryCount ,this_image()
  end if
  !
  !************************************************************************
  ! (7) send the current intSyncMemoryCount on this image to the remote control image:
  intSegmentSyncStatus = OOOPimscEnum_ImageActivityFlag % FinishedSegmentSynchronization
  ! (a) get the SyncMemoryCount on this image:
  call OOOPimscGAElement_atomic_intImageSyncMemoryCount99_CA (Object_CA, intSyncMemoryCount)
  ! (b) increment it by 1 because of the follow call to EventPostScalar
  !     (which does execute SYNC MEMORY)
  intSyncMemoryCount = intSyncMemoryCount + 1
  ! signal to the remote control image that this image is now in state 'FinishedSegmentSynchronization'
  !
  call OOOPimscEventPostScalar_intImageActivityFlag99_CA (Object_CA, intSegmentSyncStatus, &
                 intRemoteImageNumber, intArrayIndex = this_image(), logExecuteSyncMemory = .false., &
                 intAdditionalAtomicValue = intSyncMemoryCount, intEnumStepWidth = &
                 OOOPimscEnum_ImageActivityFlag % Enum_StepWidth)
  !
  !**********************************************************************
                                                                !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_ExecuteSegmentSynchronization_CA
!__________________________________________________________


!##################################################################################################
!##################################################################################################
!##################################################################################################

!**************************
! coarray type management: *
!**************************
!___________________________________________________________
!
!
subroutine OOOPimsc_StructureConstructor_CA (Object_CA)
  type (OOOPimsc_adtImageStatus_CA), codimension[*], intent (inout) :: Object_CA
  !
                                                                call OOOGglob_subSetProcedures ("OOOPimsc_StructureConstructor_CA")
  call OOOPimsc_AllocateCoarrayObject
  !
                                                                call OOOGglob_subResetProcedures
end subroutine OOOPimsc_StructureConstructor_CA
!___________________________________________________________


!##################################################################################################
!##################################################################################################
!##################################################################################################

!**********************************************************
!*************  Error Handling:   *************************
!**********************************************************
!__________________________________________________________
!
!Private
subroutine IIimsc_ErrorHandler (Object, chrErrorDescription, &
  intErrorType, intErrorNumber)
  ! ErrorHandler for the ADT and CA routines
  type(OOOPimsc_adtImageStatus_CA), intent(inout) :: Object
  character(kind=1, len=*), intent(in) :: chrErrorDescription
  integer(OOOGglob_kint), intent(in) :: intErrorType ! 1=warning, 2=severe error
  integer(OOOGglob_kint), intent(in) :: intErrorNumber ! runtime error number (e.g. status)
  call OOOEerroc_AddObject (Object % m_UUerrocError, chrErrorDescription, &
    intErrorType)
end subroutine IIimsc_ErrorHandler
!__________________________________________________________
!
!Private
logical(OOOGglob_klog) function IIimsc_ImageNumberBoundError_CA (Object_CA, intImageNumber)
  ! error handling routine
  ! checks if the image number does exist
  type(OOOPimsc_adtImageStatus_CA), codimension[*], intent(inout) :: Object_CA
  integer(OOOGglob_kint), intent(in) :: intImageNumber
  !
  IIimsc_ImageNumberBoundError_CA = .false.
  !
  if (intImageNumber .lt. 1) then ! image number is too small
    IIimsc_ImageNumberBoundError_CA = .true.
  end if
  !
  if (intImageNumber .gt. num_images()) then ! image number is too large
    IIimsc_ImageNumberBoundError_CA = .true.
  end if
  !
end function IIimsc_ImageNumberBoundError_CA
!__________________________________________________________

end module OOOPimsc_admImageStatus_CA
