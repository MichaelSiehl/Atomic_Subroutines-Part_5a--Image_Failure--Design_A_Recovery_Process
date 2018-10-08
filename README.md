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
