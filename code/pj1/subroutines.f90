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
    USE MAKEGRID
    USE MAKECELL
    USE TEMPERATURE
    USE CLOCK

    IMPLICIT NONE

CONTAINS
    SUBROUTINE init(mesh, cells)
        ! Initialize the solution with dirichlet B.C.s
        TYPE(GRID), TARGET :: mesh(1:IMAX, 1:JMAX)
        TYPE(CELL), TARGET :: cells(1:IMAX-1, 1:JMAX-1)
        INTEGER :: i, j

        ! INITIALIZE MESH
        write(*,*) 'init_mesh'
        CALL init_mesh(mesh)
        ! INITIALIZE CELLS
        CALL init_cells(mesh, cells)
        ! CALC SECONDARY AREAS OF INTEGRATION
        CALL calc_2nd_areas(mesh, cells)
        ! CALC CONSTANTS OF INTEGRATION
        CALL calc_constants(mesh, cells)

        ! INITIALIZE TEMPERATURE WITH DIRICHLET B.C.
        !PUT DEBUG BC HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        DO j = 1, JMAX
          CALL init_temp(mesh(1,j), 3.D0 * mesh(1,j)%yp + 2.D0)
          CALL init_temp(mesh(IMAX,j), 3.D0 * mesh(IMAX,j)%yp + 2.D0)
        END DO

        DO i = 1, IMAX
          CALL init_temp(mesh(i,1), ABS(COS(pi * mesh(i,1)%xp)) + 1.D0)
          CALL init_temp(mesh(i,JMAX), 5.D0 * (SIN(pi * mesh(i,JMAX)%xp) + 1.D0))
        END DO
    END SUBROUTINE init

    SUBROUTINE solve(mesh, cells, min_res, max_iter, iter)
        ! Solve heat conduction equation with finite volume scheme
        TYPE(GRID) :: mesh(1:IMAX, 1:JMAX)
        TYPE(CELL) :: cells(1:IMAX-1, 1:JMAX-1)
        ! Minimum residual criteria for iteration, actual residual
        REAL(KIND=8) :: min_res, res = 1000.D0
        ! iteration number, maximum number of iterations
        ! iter in function inputs so it can be returned to main
        INTEGER :: iter, max_iter
        INTEGER :: i, j

        iter_loop: DO WHILE (res >= min_res .AND. iter <= max_iter)
            ! Iterate FV solver until residual becomes less than cutoff or
            ! iteration count reaches given maximum

            ! INCREMENT ITERATION COUNT
            iter = iter + 1
            ! CALC NEW TEMPERATURE AT ALL POINTS
            CALL derivatives(mesh, cells)
            ! SAVE NEW TEMPERATURE DISTRIBUTION
            DO j = 2, JMAX - 1
                DO i = 2, IMAX - 1
                    mesh(i,j)%T = mesh(i,j)%T + mesh(i,j)%Ttmp
                END DO
            END DO
            ! CALC RESIDUAL
            res = MAXVAL(ABS(mesh(2:IMAX-1, 2:JMAX-1)%Ttmp))
        END DO iter_loop

        ! SUMMARIZE OUTPUT
        IF (iter > max_iter) THEN
          WRITE(*,*) 'DID NOT CONVERGE (NUMBER OF ITERATIONS:', iter, ')'
        ELSE
          WRITE(*,*) 'CONVERGED (NUMBER OF ITERATIONS:', iter, ')'
        END IF
    END SUBROUTINE solve

    SUBROUTINE output(mesh, iter)
        ! Save solution parameters to file
        TYPE(GRID), TARGET :: mesh(1:IMAX, 1:JMAX)
        REAL(KIND=8), POINTER :: Temperature(:,:), tempTemperature(:,:)
        INTEGER :: iter, i, j

        Temperature => mesh(2:IMAX-1, 2:JMAX-1)%T
        tempTemperature => mesh(2:IMAX-1, 2:JMAX-1)%Ttmp
        ! Let's find the last cell to change temperature and write some output.
        ! Write down the 'steady state' configuration.
        OPEN(UNIT = 1, FILE = "SteadySoln.dat")
        DO i = 1, IMAX
            DO j = 1, JMAX
                WRITE(1,'(F10.7, 5X, F10.7, 5X, F10.7, I5, F10.7)'), mesh(i,j)%x, mesh(i,j)%y, mesh(i,j)%T
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
        WRITE (2,*), "For a ", IMAX, " by ", JMAX, "size grid, we ran for: "
        WRITE (2,*), iter, "iterations"
        WRITE (2,*), wall_time, "seconds"
        WRITE (2,*)
        WRITE (2,*), "Found max residual of ", MAXVAL(tempTemperature)
        WRITE (2,*), "At ij of ", MAXLOC(tempTemperature)
        CLOSE (2)
    END SUBROUTINE output
END MODULE subroutines


