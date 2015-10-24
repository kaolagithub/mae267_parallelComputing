! MAE 267
! PROJECT 1
! LOGAN HALSTROM
! 12 OCTOBER 2015

! DESCRIPTION:  Subroutines used for solving heat conduction of steel plate.
! Utilizes modules from 'modules.f90'
! CONTENTS:
! init --> Initialize the solution with dirichlet B.C.s
! solve --> Solve heat conduction equation with finite volume scheme
! output --> Save solution parameters to file

MODULE subroutines
    USE CONSTANTS
    USE MESHMOD
    USE CELLMOD
    USE TEMPERATURE
!     USE CLOCK

    IMPLICIT NONE

CONTAINS
    SUBROUTINE init(mesh, cell)
        ! Initialize the solution with dirichlet B.C.s
        TYPE(MESHTYPE), TARGET :: mesh
        TYPE(CELLTYPE), TARGET :: cell

        ! INITIALIZE MESH
        CALL init_mesh(mesh)
        ! INITIALIZE CELLS
        CALL init_cells(mesh, cell)
        ! CALC SECONDARY AREAS OF INTEGRATION
        CALL calc_2nd_areas(mesh, cell)
        ! CALC CONSTANTS OF INTEGRATION
        CALL calc_constants(mesh, cell)
        ! INITIALIZE TEMPERATURE WITH DIRICHLET B.C.
        CALL init_temp(mesh)
    END SUBROUTINE init

    SUBROUTINE solve(mesh, cell, min_res, max_iter, iter)
        ! Solve heat conduction equation with finite volume scheme
        TYPE(MESHTYPE) :: mesh
        TYPE(CELLTYPE) :: cell
        ! Minimum residual criteria for iteration, actual residual
        REAL(KIND=8) :: min_res, res = 1000.D0
        ! iteration number, maximum number of iterations
        ! iter in function inputs so it can be returned to main
        INTEGER :: iter, max_iter
        INTEGER :: i, j

        INCLUDE "mpif.h"
        REAL(KIND=8) :: start_solve, end_solve
        WRITE(*,*) 'Starting clock for solver...'
        start_solve = MPI_Wtime()

        iter_loop: DO WHILE (res >= min_res .AND. iter <= max_iter)
            ! Iterate FV solver until residual becomes less than cutoff or
            ! iteration count reaches given maximum

            ! INCREMENT ITERATION COUNT
            iter = iter + 1
            ! CALC NEW TEMPERATURE AT ALL POINTS
            CALL derivatives(mesh, cell)
            ! SAVE NEW TEMPERATURE DISTRIBUTION
            DO j = 2, JMAX - 1
                DO i = 2, IMAX - 1
                    mesh%T(i,j) = mesh%T(i,j) + mesh%Ttmp(i,j)
                END DO
            END DO

            ! CALC RESIDUAL
            res = MAXVAL( ABS( mesh%Ttmp(2:IMAX-1, 2:JMAX-1) ) )
        END DO iter_loop

        ! CACL SOLVER WALL CLOCK TIME
        end_solve = MPI_Wtime()
        wall_time_solve = end_solve - start_solve

        ! SUMMARIZE OUTPUT
        IF (iter > max_iter) THEN
          WRITE(*,*) 'DID NOT CONVERGE (NUMBER OF ITERATIONS:', iter, ')'
        ELSE
          WRITE(*,*) 'CONVERGED (NUMBER OF ITERATIONS:', iter, ')'
        END IF
    END SUBROUTINE solve

    SUBROUTINE output(mesh, iter)
        ! Save solution parameters to file
        TYPE(MESHTYPE), TARGET :: mesh
        REAL(KIND=8), POINTER :: Temperature(:,:), tempTemperature(:,:)
        INTEGER :: iter, i, j

        Temperature => mesh%T(2:IMAX-1, 2:JMAX-1)
        tempTemperature => mesh%Ttmp(2:IMAX-1, 2:JMAX-1)
        ! Let's find the last cell to change temperature and write some output.
        ! Write down the 'steady state' configuration.
        OPEN(UNIT = 1, FILE = "SteadySoln.dat")
        DO i = 1, IMAX
            DO j = 1, JMAX
                WRITE(1,'(F10.7, 5X, F10.7, 5X, F10.7, I5, F10.7)'), mesh%x(i,j), mesh%y(i,j), mesh%T(i,j)
            END DO
        END DO
        CLOSE (1)

        ! Output to the screen so we know something happened.
        WRITE (*,*), "IMAX/JMAX", IMAX, JMAX
        WRITE (*,*), "iters", iter
        WRITE (*,*), "residual", MAXVAL(tempTemperature)
        WRITE (*,*), "ij", MAXLOC(tempTemperature)

        ! Write down info for project
        OPEN (UNIT = 2, FILE = "SolnInfo.dat")
        WRITE (2,*), "Running a", IMAX, "by", JMAX, "grid took:"
        WRITE (2,*), iter, "iterations"
        WRITE (2,*), wall_time_total, "seconds (Total CPU walltime)"
        WRITE (2,*), wall_time_solve, "seconds (Solver CPU walltime)"
!         WRITE (2,*), wall_time_iter, "seconds (Iteration CPU walltime)"
        WRITE (2,*)
        WRITE (2,*), "Found max residual of ", MAXVAL(tempTemperature)
        WRITE (2,*), "At ij of ", MAXLOC(tempTemperature)
        CLOSE (2)
    END SUBROUTINE output
END MODULE subroutines


