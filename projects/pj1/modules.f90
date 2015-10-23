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
        ! Grid points, see cooridinate rotaion equations in problem statement
        REAL(KIND=8) :: xp(1:IMAX, 1:JMAX), yp(1:IMAX, 1:JMAX), x(1:IMAX, 1:JMAX), y(1:IMAX, 1:JMAX)
        ! Temperature at each point, temporary variable to hold temperature sum
        REAL(KIND=8) :: T(1:IMAX, 1:JMAX), Ttmp(1:IMAX, 1:JMAX)
        ! Iteration Parameters: timestep, secondary cell volume,
                                    ! equation constant term
        REAL(KIND=8) :: dt(1:IMAX, 1:JMAX), V2nd(1:IMAX, 1:JMAX), term(1:IMAX, 1:JMAX)
    END TYPE MESHTYPE

CONTAINS
    SUBROUTINE init_mesh(mesh)
        ! Mesh points (derived data type)
        TYPE(MESHTYPE) :: mesh
        INTEGER :: i, j

        DO j = 1, JMAX
            DO i = 1, IMAX
                ! MAKE SQUARE GRID
                mesh%xp(i, j) = COS( 0.5D0 * pi * DFLOAT(IMAX - i) / DFLOAT(IMAX - 1) )
                mesh%yp(i, j) = COS( 0.5D0 * pi * DFLOAT(JMAX - j) / DFLOAT(JMAX - 1) )
                ! ROTATE GRID
                mesh%x(i, j) = mesh%xp(i, j) * COS(rot) + (1.D0 - mesh%yp(i, j) ) * SIN(rot)
                mesh%y(i, j) = mesh%yp(i, j) * COS(rot) + (mesh%xp(i, j)) * SIN(rot)
            END DO
        END DO
    END SUBROUTINE init_mesh

    SUBROUTINE init_temp(mesh)
        ! Initialize temperature across mesh
        ! mesh --> mesh data type
        TYPE(MESHTYPE), INTENT(INOUT) :: mesh
        INTEGER :: i, j

        !PUT DEBUG BC HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ! INITIALIZE TEMPERATURE WITH DIRICHLET B.C.
        DO j = 1, JMAX
            mesh%T(1,j) = 3.D0 * mesh%yp(1,j) + 2.D0
            mesh%T(IMAX,j) = 3.D0 * mesh%yp(IMAX,j) + 2.D0
        END DO
        DO i = 1, IMAX
            mesh%T(i,1) = ABS(COS(pi * mesh%xp(i,1))) + 1.D0
            mesh%T(i,JMAX) = 5.D0 * (SIN(pi * mesh%xp(i,JMAX)) + 1.D0)
        END DO
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
        REAL(KIND=8) :: V(1:IMAX-1,1:JMAX-1)
        ! Second-derivative weighting factors for alternative distribution scheme
        REAL(KIND=8) :: yPP(1:IMAX-1,1:JMAX-1), yNP(1:IMAX-1,1:JMAX-1), yNN(1:IMAX-1,1:JMAX-1), yPN(1:IMAX-1,1:JMAX-1)
        REAL(KIND=8) :: xNN(1:IMAX-1,1:JMAX-1), xPN(1:IMAX-1,1:JMAX-1), xPP(1:IMAX-1,1:JMAX-1), xNP(1:IMAX-1,1:JMAX-1)
    END TYPE CELLTYPE

CONTAINS
    SUBROUTINE init_cells(mesh, cell)
        ! cell --> derived data type containing cell info
        ! mesh --> derived data type containing mesh point info
        TYPE(MESHTYPE) :: mesh
        TYPE(CELLTYPE) :: cell
        INTEGER :: i, j

        DO j = 1, JMAX-1
            DO i = 1, IMAX-1
                ! CALC CELL VOLUMES
                    ! (length in x-dir times length in y-dir)
                cell%V(i,j) = ( (mesh%xp(i+1,j) - mesh%xp(i,j)) ) &
                                    * ( mesh%yp(i,j+1) - mesh%yp(i,j) )
            END DO
        END DO
    END SUBROUTINE init_cells

    SUBROUTINE calc_2nd_areas(m, c)
        ! calculate areas for secondary fluxes.
        ! c --> derived data type with cell data, target for c
        ! m --> mesh points
        TYPE(MESHTYPE) :: m
        TYPE(CELLTYPE) :: c
        INTEGER :: i, j
        ! Areas used in alternative scheme to get fluxes for second-derivative
        REAL(KIND=8) :: Ayi, Axi, Ayj, Axj
        ! Areas used in counter-clockwise trapezoidal integration to get
        ! x and y first-derivatives for center of each cell (Green's thm)
        REAL(KIND=8) :: Ayi_half, Axi_half, Ayj_half, Axj_half

        ! CALC CELL AREAS
        Axi(i,j) = m%x(i,j+1) - m%x(i,j)
        Axj(i,j) = m%x(i+1,j) - m%x(i,j)
        Ayi(i,j) = m%y(i,j+1) - m%y(i,j)
        Ayj(i,j) = m%y(i+1,j) - m%y(i,j)

        Axi_half(i,j) = ( Axi(i+1,j) + Axi(i,j) ) * 0.25D0
        Axj_half(i,j) = ( Axj(i,j+1) + Axj(i,j) ) * 0.25D0
        Ayi_half(i,j) = ( Ayi(i+1,j) + Ayi(i,j) ) * 0.25D0
        Ayj_half(i,j) = ( Ayj(i,j+1) + Ayj(i,j) ) * 0.25D0

        ! Actual finite-volume scheme equation parameters
        DO j = 1, JMAX-1
            DO i = 1, IMAX-1
                ! (NN = 'negative-negative', PN = 'positive-negative',
                    ! see how fluxes are summed)
                c%xNN(i, j) = ( -Axi_half(i,j) - Axj_half(i,j) )
                c%xPN(i, j) = (  Axi_half(i,j) - Axj_half(i,j) )
                c%xPP(i, j) = (  Axi_half(i,j) + Axj_half(i,j) )
                c%xNP(i, j) = ( -Axi_half(i,j) + Axj_half(i,j) )

                c%yPP(i, j) = (  Ayi_half(i,j) + Ayj_half(i,j) )
                c%yNP(i, j) = ( -Ayi_half(i,j) + Ayj_half(i,j) )
                c%yNN(i, j) = ( -Ayi_half(i,j) - Ayj_half(i,j) )
                c%yPN(i, j) = (  Ayi_half(i,j) - Ayj_half(i,j) )
            END DO
        END DO
    END SUBROUTINE calc_2nd_areas

    SUBROUTINE calc_constants(mesh, cell)
        ! Calculate constants for a given iteration loop.  This way,
        ! they don't need to be calculated within the loop at each iteration
        TYPE(MESHTYPE), TARGET :: mesh
        TYPE(CELLTYPE), TARGET :: cell
        INTEGER :: i, j
        DO j = 2, JMAX - 1
            DO i = 2, IMAX - 1
                ! CALC TIMESTEP FROM CFL
                mesh%dt(i,j) = ((CFL * 0.5D0) / alpha) * cell%V(i,j) ** 2 &
                                / ( (mesh%xp(i+1,j) - mesh%xp(i,j))**2 &
                                    + (mesh%yp(i,j+1) - mesh%yp(i,j))**2 )
                ! CALC SECONDARY VOLUMES
                ! (for rectangular mesh, just average volumes of the 4 cells
                !  surrounding the point)
                mesh%V2nd(i,j) = ( cell%V(i,j) &
                                    + cell%V(i-1,j) + cell%V(i,j-1) &
                                    + cell%V(i-1,j-1) ) * 0.25D0
                ! CALC CONSTANT TERM
                ! (this term remains constant in the equation regardless of
                !  iteration number, so only calculate once here,
                !  instead of in loop)
                mesh%term(i,j) = mesh%dt(i,j) * alpha / mesh%V2nd(i,j)
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
        TYPE(MESHTYPE), INTENT(INOUT) :: m
        TYPE(CELLTYPE), INTENT(INOUT) :: c
        ! Areas for first derivatives
        REAL(KIND=8) :: Ayi, Axi, Ayj, Axj
        ! First partial derivatives of temperature in x and y directions
        REAL(KIND=8) :: dTdx, dTdy
        INTEGER :: i, j

        ! CALC CELL AREAS
        Axi(i,j) = m%x(i,j+1) - m%x(i,j)
        Axj(i,j) = m%x(i+1,j) - m%x(i,j)
        Ayi(i,j) = m%y(i,j+1) - m%y(i,j)
        Ayj(i,j) = m%y(i+1,j) - m%y(i,j)

        ! RESET SUMMATION
        m%Ttmp = 0.D0

        DO j = 1, JMAX - 1
            DO i = 1, IMAX - 1
                ! CALC FIRST DERIVATIVES
                dTdx = + 0.5d0 &
                            * (( m%T(i+1,j) + m%T(i+1,j+1) ) * Ayi(i+1,j) &
                            -  ( m%T(i,  j) + m%T(i,  j+1) ) * Ayi(i,  j) &
                            -  ( m%T(i,j+1) + m%T(i+1,j+1) ) * Ayj(i,j+1) &
                            +  ( m%T(i,  j) + m%T(i+1,  j) ) * Ayj(i,  j) &
                                ) / c(i,j)%V
                dTdy = - 0.5d0 &
                            * (( m%T(i+1,j) + m%T(i+1,j+1) ) * Axi(i+1,j) &
                            -  ( m%T(i,  j) + m%T(i,  j+1) ) * Axi(i,  j) &
                            -  ( m%T(i,j+1) + m%T(i+1,j+1) ) * Axj(i,j+1) &
                            +  ( m%T(i,  j) + m%T(i+1,  j) ) * Axj(i,  j) &
                                ) / c(i,j)%V

                ! Alternate distributive scheme second-derivative operator.
                m%Ttmp(i+1,  j) = m%Ttmp(i+1,  j) + m%term(i+1,  j) * ( c%yNN(i,j) * dTdx + c%xPP(i,j) * dTdy )
                m%Ttmp(i,    j) = m%Ttmp(i,    j) + m%term(i,    j) * ( c%yPN(i,j) * dTdx + c%xNP(i,j) * dTdy )
                m%Ttmp(i,  j+1) = m%Ttmp(i,  j+1) + m%term(i,  j+1) * ( c%yPP(i,j) * dTdx + c%xNN(i,j) * dTdy )
                m%Ttmp(i+1,j+1) = m%Ttmp(i+1,j+1) + m%term(i+1,j+1) * ( c%yNP(i,j) * dTdx + c%xPN(i,j) * dTdy )
            END DO
        END DO
    END SUBROUTINE derivatives
END MODULE TEMPERATURE


