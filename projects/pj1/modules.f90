! MAE 267
! PROJECT 1
! LOGAN HALSTROM
! 12 OCTOBER 2015

! DESCRIPTION:  Modules used for solving heat conduction of steel plate.
! Initialize and store constants used in all subroutines.

! CONTENTS:
! CONSTANTS --> Initializes constants for simulation.  Sets grid size.
! CLOCK --> Calculates clock wall-time of a process.
! MAKEGRID --> Initialize grid with correct number of points and rotation,
!                 set boundary conditions, etc.
! CELLS -->  Initialize finite volume cells and do associated calculations
! TEMPERATURE --> Calculate and store new temperature distribution
!                     for given iteration

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! CONSTANTS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE CONSTANTS
    ! Initialize constants for simulation.  Set grid size.
    IMPLICIT NONE
    ! CFL number, for convergence (D0 is double-precision, scientific notation)
    REAL(KIND=8), PARAMETER :: CFL = 0.95D0
    ! Material constants (steel): thermal conductivity [W/(m*K)],
                                ! density [kg/m^3],
                                ! specific heat ratio [J/(kg*K)]
    REAL(KIND=8), PARAMETER :: k = 18.8D0, rho = 8000.D0, cp = 500.D0
    ! Thermal diffusivity [m^2/s]
    REAL(KIND=8), PARAMETER :: alpha = k / (cp * rho)
    ! Pi, grid rotation angle (30 deg)
    REAL(KIND=8), PARAMETER :: pi = 3.141592654D0, rot = 30.D0*pi/180.D0
    ! CPU Wall Times
    REAL(KIND=8) :: wall_time_total, wall_time_solve, wall_time_iter(1:5)
    ! Grid size
    INTEGER :: IMAX, JMAX

END MODULE CONSTANTS

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! INITIALIZE GRID !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE MESHMOD
    ! Initialize grid with correct number of points and rotation,
    ! set boundary conditions, etc.
    USE CONSTANTS

    IMPLICIT NONE
    PUBLIC

    TYPE MESHTYPE
        ! DERIVED DATA TYPE
        INTEGER :: i, j
        ! Grid points, see cooridinate rotaion equations in problem statement
        REAL(KIND=8) :: xp, yp, x, y
        ! Temperature at each point, temporary variable to hold temperature sum
        REAL(KIND=8) :: T, Ttmp
        ! Iteration Parameters: timestep, secondary cell volume,
                                    ! equation constant term
        REAL(KIND=8) :: dt, V2nd, term
    END TYPE MESHTYPE

CONTAINS
    SUBROUTINE init_mesh(mesh)
        ! Mesh points (derived data type)
        TYPE(MESHTYPE) :: mesh(1:IMAX, 1:JMAX)
        INTEGER :: i, j

        DO j = 1, JMAX
            DO i = 1, IMAX
                ! MAKE SQUARE GRID
                mesh(i, j)%i = i
                mesh(i, j)%j = j
                ! ROTATE GRID
                mesh(i, j)%xp = COS( 0.5D0 * pi * DFLOAT(IMAX - i) / DFLOAT(IMAX - 1) )
                mesh(i, j)%yp = COS( 0.5D0 * pi * DFLOAT(JMAX - j) / DFLOAT(JMAX - 1) )

                mesh(i, j)%x = mesh(i, j)%xp * COS(rot) + (1.D0 - mesh(i, j)%yp ) * SIN(rot)
                mesh(i, j)%y = mesh(i, j)%yp * COS(rot) + (mesh(i, j)%xp) * SIN(rot)
            END DO
        END DO
    END SUBROUTINE init_mesh

    SUBROUTINE init_temp(m, T)
        ! Initialize temperature across mesh
        ! m --> mesh vector
        ! T --> initial temperature profile
        TYPE(MESHTYPE), INTENT(INOUT) :: m
        REAL(KIND=8) :: T
        ! SET MESH POINTS WITH INITIAL TEMPERATURE PROFILE
        m%T = T
    END SUBROUTINE init_temp
END MODULE MESHMOD

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! CELLS !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE CELLMOD
    ! Initialize finite volume cells and do associated calculations
    USE MESHMOD

    IMPLICIT NONE
    PUBLIC

    TYPE CELLTYPE
        ! Cell volumes
        REAL(KIND=8) :: V
        ! Second-derivative weighting factors for alternative distribution scheme
        REAL(KIND=8) :: yPP, yNP, yNN, yPN
        REAL(KIND=8) :: xNN, xPN, xPP, xNP
    END TYPE CELLTYPE

CONTAINS
    SUBROUTINE init_cells(mesh, cell)
        ! cell --> derived data type containing cell info
        ! mesh --> derived data type containing mesh point info
        TYPE(MESHTYPE) :: mesh(1:IMAX, 1:JMAX)
        TYPE(CELLTYPE) :: cell(1:IMAX-1,1:JMAX-1)
        INTEGER :: i, j

        DO j = 1, JMAX-1
            DO i = 1, IMAX-1
                ! CALC CELL VOLUMES
                    ! (length in x-dir times length in y-dir)
                cell(i,j)%V = ( (mesh(i+1,j)%xp - mesh(i,j)%xp) ) &
                                    * ( mesh(i,j+1)%yp - mesh(i,j)%yp )
            END DO
        END DO
    END SUBROUTINE init_cells

    SUBROUTINE calc_2nd_areas(m, c)
        ! calculate areas for secondary fluxes.
        ! c --> derived data type with cell data, target for c
        ! m --> mesh points
        TYPE(MESHTYPE) :: m(1:IMAX, 1:JMAX)
        TYPE(CELLTYPE) :: c(1:IMAX-1, 1:JMAX-1)
        INTEGER :: i, j
        ! Areas used in alternative scheme to get fluxes for second-derivative
        REAL(KIND=8) :: Ayi, Axi, Ayj, Axj
        ! Areas used in counter-clockwise trapezoidal integration to get
        ! x and y first-derivatives for center of each cell (Green's thm)
        REAL(KIND=8) :: Ayi_half, Axi_half, Ayj_half, Axj_half

        ! CALC CELL AREAS
        Axi(i,j) = m(i,j+1)%x - m(i,j)%x
        Axj(i,j) = m(i+1,j)%x - m(i,j)%x
        Ayi(i,j) = m(i,j+1)%y - m(i,j)%y
        Ayj(i,j) = m(i+1,j)%y - m(i,j)%y

        Axi_half(i,j) = ( Axi(i+1,j) + Axi(i,j) ) * 0.25D0
        Axj_half(i,j) = ( Axj(i,j+1) + Axj(i,j) ) * 0.25D0
        Ayi_half(i,j) = ( Ayi(i+1,j) + Ayi(i,j) ) * 0.25D0
        Ayj_half(i,j) = ( Ayj(i,j+1) + Ayj(i,j) ) * 0.25D0

        ! Actual finite-volume scheme equation parameters
        DO j = 1, JMAX-1
            DO i = 1, IMAX-1
                ! (NN = 'negative-negative', PN = 'positive-negative',
                    ! see how fluxes are summed)
                c(i, j)%xNN = ( -Axi_half(i,j) - Axj_half(i,j) )
                c(i, j)%xPN = (  Axi_half(i,j) - Axj_half(i,j) )
                c(i, j)%xPP = (  Axi_half(i,j) + Axj_half(i,j) )
                c(i, j)%xNP = ( -Axi_half(i,j) + Axj_half(i,j) )

                c(i, j)%yPP = (  Ayi_half(i,j) + Ayj_half(i,j) )
                c(i, j)%yNP = ( -Ayi_half(i,j) + Ayj_half(i,j) )
                c(i, j)%yNN = ( -Ayi_half(i,j) - Ayj_half(i,j) )
                c(i, j)%yPN = (  Ayi_half(i,j) - Ayj_half(i,j) )
            END DO
        END DO
    END SUBROUTINE calc_2nd_areas

    SUBROUTINE calc_constants(mesh, cell)
        ! Calculate constants for a given iteration loop.  This way,
        ! they don't need to be calculated within the loop at each iteration
        TYPE(MESHTYPE), TARGET :: mesh(1:IMAX, 1:JMAX)
        TYPE(CELLTYPE), TARGET :: cell(1:IMAX-1, 1:JMAX-1)
        INTEGER :: i, j
        DO j = 2, JMAX - 1
            DO i = 2, IMAX - 1
                ! CALC TIMESTEP FROM CFL
                mesh(i,j)%dt = ((CFL * 0.5D0) / alpha) * cell(i,j)%V ** 2 &
                                / ( (mesh(i+1,j)%xp - mesh(i,j)%xp)**2 &
                                    + (mesh(i,j+1)%yp - mesh(i,j)%yp)**2 )
                ! CALC SECONDARY VOLUMES
                ! (for rectangular mesh, just average volumes of the 4 cells
                !  surrounding the point)
                mesh(i,j)%V2nd = ( cell(i,j)%V &
                                    + cell(i-1,j)%V + cell(i,j-1)%V &
                                    + cell(i-1,j-1)%V ) * 0.25D0
                ! CALC CONSTANT TERM
                ! (this term remains constant in the equation regardless of
                !  iteration number, so only calculate once here,
                !  instead of in loop)
                mesh(i,j)%term = mesh(i,j)%dt * alpha / mesh(i,j)%V2nd
            END DO
        END DO
    END SUBROUTINE calc_constants
END MODULE CELLMOD

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! CALCULATE TEMPERATURE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE TEMPERATURE
    ! Calculate and store new temperature distribution for given iteration
    USE MESHMOD
    USE CELLMOD

    IMPLICIT NONE
    PUBLIC

CONTAINS
    SUBROUTINE derivatives(m, c)
        ! Calculate first and second derivatives for finite-volume scheme
        TYPE(MESHTYPE), INTENT(INOUT) :: m(1:IMAX, 1:JMAX)
        TYPE(CELLTYPE), INTENT(INOUT) :: c(1:IMAX-1, 1:JMAX-1)
        ! Areas for first derivatives
        REAL(KIND=8) :: Ayi, Axi, Ayj, Axj
        ! First partial derivatives of temperature in x and y directions
        REAL(KIND=8) :: dTdx, dTdy
        INTEGER :: i, j

        ! CALC CELL AREAS
        Axi(i,j) = m(i,j+1)%x - m(i,j)%x
        Axj(i,j) = m(i+1,j)%x - m(i,j)%x
        Ayi(i,j) = m(i,j+1)%y - m(i,j)%y
        Ayj(i,j) = m(i+1,j)%y - m(i,j)%y

        ! RESET SUMMATION
        m%Ttmp = 0.D0

        DO j = 1, JMAX - 1
            DO i = 1, IMAX - 1
                ! CALC FIRST DERIVATIVES
                dTdx = + 0.5d0 &
                            * (( m(i+1,j)%T + m(i+1,j+1)%T ) * Ayi(i+1,j) &
                            -  ( m(i,  j)%T + m(i,  j+1)%T ) * Ayi(i,  j) &
                            -  ( m(i,j+1)%T + m(i+1,j+1)%T ) * Ayj(i,j+1) &
                            +  ( m(i,  j)%T + m(i+1,  j)%T ) * Ayj(i,  j) &
                                ) / c(i,j)%V
                dTdy = - 0.5d0 &
                            * (( m(i+1,j)%T + m(i+1,j+1)%T ) * Axi(i+1,j) &
                            -  ( m(i,  j)%T + m(i,  j+1)%T ) * Axi(i,  j) &
                            -  ( m(i,j+1)%T + m(i+1,j+1)%T ) * Axj(i,j+1) &
                            +  ( m(i,  j)%T + m(i+1,  j)%T ) * Axj(i,  j) &
                                ) / c(i,j)%V

                ! Alternate distributive scheme second-derivative operator.
                m(i+1,  j)%Ttmp = m(i+1,  j)%Ttmp + m(i+1,  j)%term * ( c(i,j)%yNN * dTdx + c(i,j)%xPP * dTdy )
                m(i,    j)%Ttmp = m(i,    j)%Ttmp + m(i,    j)%term * ( c(i,j)%yPN * dTdx + c(i,j)%xNP * dTdy )
                m(i,  j+1)%Ttmp = m(i,  j+1)%Ttmp + m(i,  j+1)%term * ( c(i,j)%yPP * dTdx + c(i,j)%xNN * dTdy )
                m(i+1,j+1)%Ttmp = m(i+1,j+1)%Ttmp + m(i+1,j+1)%term * ( c(i,j)%yNP * dTdx + c(i,j)%xPN * dTdy )
            END DO
        END DO
    END SUBROUTINE derivatives
END MODULE TEMPERATURE


