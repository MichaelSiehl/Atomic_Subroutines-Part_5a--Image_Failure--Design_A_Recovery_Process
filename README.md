# Atomic_Subroutines-Part_5a--Image_Failure--Design_A_Recovery_Process
Fortran 2018 coarray programming with customized synchronization procedures - Atomic Subroutines - Part 5a: How to cope with unreliable data transfers at low-level PGAS programming - Image failure: Design a recovery process. 

# A simple example program – How to make safe, efficient, and sophisticated use of atomic subroutines

The small example program herein may give sufficient proof that we can make safe, efficient, and even highly sophisticated use of atomic subroutines with current Fortran Compilers already (ifort, OpenCoarrays/gfortran). And all this with quite low effort. The program does all the data transfers and (most of the) synchronizations among coarray images through atomic subroutines exclusively.<br />

This works mainly because the programmer can store two (reduced-size) integer values into a single integer variable and because the compilers do support the use of (derived type coarrays with) integer array components (only one array element at a time of course) together with atomic subroutines. (It is especially this support for arrays and array syntax that can become very helpful for sophisticated handling of upcoming parallel machines. Thus, the topic is not just Fortran but also hardware related).<br />

To recover from corrupted coarray data transfer channels, we can simply reallocate them with the ALLOCATE statement (we use allocatable coarrays of derived type) to newly establish that coarray on all images of the current team (Fortran 2018).<br />

The example program does already offer detection and handling of (many kinds of) errors with the parallel execution, as well as detection and handling of slow running parallel algorithms (but that's not used here). <br />

To allow this, the program does implement a customized synchronization consisting of two procedures: A customized Event Post procedure and a customized Event Wait procedure. The customized Event Wait procedure does offer synchronization diagnostics that allows to detect runtime failures and also gives (optional) information about which coarray image(s) did cause the failure and which images did succeed with the execution so far. Thus, it is easily possible to continue execution with only those images that did not fail, or to abort and restart on all images (the example program does it that way), for example.<br />

For parallel runtime error detection, the customized Event Wait procedure implements an (local) abort timer (time limit) for the spin-wait synchronization. With that, we can even detect and handle errors due to corrupted (atomic) data transfer channels with coarrays or, with other words, we can detect and handle atomic data transfer failures themselves.<br />

To do so requires a certain design strategy for the parallel algorithm too: For instance, in the example program we use two distinct procedures for the parallel algorithm, each getting executed on one or more distinct coarray images, that do constantly (within the time limit of the abort timer) 'communicate' in a circular way. If the 'communication' doesn't occur successfully within that time limit, we consider this to be a signal for a runtime failure (either a runtime error, a slow running parallel algorithm, a corrupted data transfer channel, etc.).<br />

# How it works: Main.f90

The program implements a simple (nonsensical) fast running parallel algorithm: Restoring segment ordering among coarray images by executing Sync Memory a required number of times. (I don't think anymore we should do it that way in a real world application, but use the ALLOCATE statement instead – the example is only for illustrating sophisticated use of atomic subroutines).<br />

The OOOPimsc_admImageStatus_CA.f90 source code file contains all the logic codes. Public access to the parallel algorithm is available through the OOOPimsc_RestoreSegmentOrder_CA procedure. (The algorithm requires one coarray image that executes code for controlling the execution of the algorithm and a number of remote images that are used for restoring the segment order among them).<br />

We call that algorithm successive two times from Main.f90. With our first call (A) to the  OOOPimsc_RestoreSegmentOrder_CA procedure we use the optional 'logRaiseAnError = .true.' argument to intentionally raise a runtime failure. (On my laptop computer, it was already enough not to execute the algorithm on one of the involved remote images to completely corrupt the remote data transfer channels of the atomic component of the derived type coarray on all involved images). The output from such is then:<br />
```fortran
RestoreSegmentOrder A failed on image           3
RestoreSegmentOrder A failed on image           4
RestoreSegmentOrder A failed on image           6
RestoreSegmentOrder A failed on image           2
RestoreSegmentOrder A failed on image           5
RestoreSegmentOrder A failed on image           1
```

With our second call  (B)  to the  OOOPimsc_RestoreSegmentOrder_CA procedure we use the optional 'logReAllocateCoarrayObject = .true.' argument to repair (restore or newly establish) those corrupted data transfer channels by simply reallocating them. The output after successful repair is then:<br />
```fortran
RestoreSegmentOrder B successful on image           2
RestoreSegmentOrder B successful on image           3
RestoreSegmentOrder B successful on image           5
RestoreSegmentOrder B successful on image           6
RestoreSegmentOrder B successful on image           4
RestoreSegmentOrder B successful on image           1
```

# How it works: The codes in OOOPimsc_admImageStatus_CA.f90:

This code file contains all the required codes. The relevant codes are:<br />

- OOOPimscEnum_ImageActivityFlag: An integer-based enumeration that we use to pack it's integer values with another reduced-size integer value for use with atomic subroutines within the parallel algorithm.
- OOOPimsc_adtImageStatus_CA: A derived type definition mainly containing an atomic integer array component.
- OOOPimscImageStatus_CA_1: Our (only) allocatable coarray declaration.
- Two simple procedures to allocate and reallocate (newly allocate to repair corrupted data transfer channels) our derived type coarray object.
- Two simple procedures to pack and unpack an integer-based enumeration value with an additional integer value.
- OOOPimscSAElement_atomic_intImageActivityFlag99_CA: This setter procedure does encapsulate access to the atomic_define intrinsic subroutine for our main atomic derived type component.
- OOOPimscEventPostScalar_intImageActivityFlag99_CA: Our customized Event Post procedure. It does allow to pack an optional (limited size integer) scalar value with the integer-based enumeration value.
- OOOPimscGAElement_check_atomic_intImageActivityFlag99_CA: This getter procedure does encpsulate access to the atomic_ref intrinsic subroutine. (This getter does not allow to access the member directly, but instead does only allow to check the atomic member for specific values since it's intention is to be used for synchronizations).
- OOOPimscEventWaitScalar_intImageActivityFlag99_CA: Our customized Event Wait procedure. It's core is a sophisticated spin-wait loop synchronization. This procedure is for atomic bulk synchronizations (among the executing image and one or more remote images). The procedure also implements an abort timer (time limit) for the spin-wait synchronization that allows to detect failures or inefficient execution of a parallel algorithm. In case of such a synchronization abort, the procedure gives synchronization diagnostics through optional arguments.
- OOOPimsc_RestoreSegmentOrder_CA: This procedure encapsulates access to our parallel algorithm and is called from our Main.f90.
- OOOPimsc_ControlSegmentSynchronization_CA and OOOPimsc_ExecuteSegmentSynchronization_CA: These both procedures comprise our simple parallel algorithm for restoring segment ordering among the involved coarray images. To allow for parallel error checking, the both procedures do constantly switch with their calls to the customized Event Wait and Event Post procedures. After each call of the customized Event Wait a check for error detection is performed. In case of an parallel error, the both procedures do immediately abort further execution with a RETURN statement.
