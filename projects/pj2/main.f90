! MAE 267
! PROJECT 2
! LOGAN HALSTROM
! 23 OCTOBER 2015


! DESCRIPTION:  Solve heat conduction equation for single block of steel.
! To compile: mpif90 -o main -O3 modules.f90 plot3D_module.f90 subroutines.f90 main.f90
    ! makes executable file 'main'
    ! 'rm *.mod' afterward to clean up unneeded compiled files
! To run: ./main or ./run.sh or sbatch run.sh on hpc1


PROGRAM heatTrans
!     USE CLOCK
    USE CONSTANTS
    USE subroutines
    USE plot3D_module

    IMPLICIT NONE

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! INITIALIZE VARIABLES !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    ! GRID
!     TYPE(MESHTYPE), TARGET, ALLOCATABLE :: mesh(:,:)
!     TYPE(CELLTYPE), TARGET, ALLOCATABLE :: cell(:,:)
    TYPE(MESHTYPE) :: mesh
    ! ITERATION PARAMETERS
    ! Minimum Residual
    REAL(KIND=8) :: min_res = 0.00001D0
    ! Maximum number of iterations
    INTEGER :: I, nx, N, M, max_iter = 1000000, iter = 0

    INCLUDE "mpif.h"
    REAL(KIND=8) :: start_total, end_total
    REAL(KIND=8) :: start_solve, end_solve
    ! CLOCK TOTAL TIME OF RUN
    start_total = MPI_Wtime()

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! READ INPUTS FROM FILE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    OPEN (UNIT = 1, FILE = 'config.in')
    DO I = 1, 3
        ! Skip header lines
        READ(1,*)
    END DO
    ! READ GRIDSIZE (4th line)
    READ(1,*) nx
    ! READ BLOCKS (6th and 8th line)
    READ(1,*)
    READ(1,*) M
    READ(1,*)
    READ(1,*) N


    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! INITIALIZE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    ! Set grid size
    IMAX = nx
    JMAX = nx
!     ALLOCATE(mesh(1:IMAX, 1:JMAX))
!     ALLOCATE(cell(1:IMAX-1, 1:JMAX-1))

    ! INIITIALIZE SOLUTION

    WRITE(*,*) 'Making mesh...'
    CALL init(mesh)

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! SOLVER !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    WRITE(*,*) 'Solving heat conduction...'
    CALL solve(mesh, min_res, max_iter, iter)

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! SAVE RESULTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    WRITE(*,*) 'Writing results...'
    ! SAVE SOLUTION AS PLOT3D FILES
    CALL plot3D(mesh)
    ! CALC TOTAL WALL TIME
    end_total = MPI_Wtime()
    wall_time_total = end_total - start_total
    ! SAVE SOLVER PERFORMANCE PARAMETERS
    CALL output(mesh, iter)

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!! CLEAN UP !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    DEALLOCATE( mesh%xp   )
    DEALLOCATE( mesh%yp   )
    DEALLOCATE( mesh%x    )
    DEALLOCATE( mesh%y    )
    DEALLOCATE( mesh%T    )
    DEALLOCATE( mesh%Ttmp )
    DEALLOCATE( mesh%dt   )
    DEALLOCATE( mesh%V  )
    DEALLOCATE( mesh%V2nd )
    DEALLOCATE( mesh%term )
    DEALLOCATE( mesh%yPP)
    DEALLOCATE( mesh%yNP)
    DEALLOCATE( mesh%yNN)
    DEALLOCATE( mesh%yPN)
    DEALLOCATE( mesh%xNN)
    DEALLOCATE( mesh%xPN)
    DEALLOCATE( mesh%xPP)
    DEALLOCATE( mesh%xNP)

    WRITE(*,*) 'Done!'


END PROGRAM heatTrans
