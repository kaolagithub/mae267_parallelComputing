!     PLOT3D (2D FORMAT)
      IXYZ  = 20
      ITEMP = 21
!     WRITE OUT THE SOLUTION FOR POST-PROCESSING IN PLOT3D FORMAT
      OPEN(UNIT=IXYZ,FILE='XYZ.DAT',FORM='FORMATTED')
      WRITE(IXYZ,10) NBLOCKS
 10   FORMAT(I10)
      WRITE(IXYZ,20) (IMAX(N),JMAX(N),N=1,NBLOCKS)
 20   FORMAT(10I10)
      DO N = 1,NBLOCKS
        WRITE(IXYZ,30) ((X(I,J,N),I=1,IMAX(N)),J=1,JMAX(N)), 
     &                 ((Y(I,J,N),I=1,IMAX(N)),J=1,JMAX(N))
      ENDDO
 30   FORMAT(10E15.8)

      OPEN(UNIT=IFLO,FILE='TEMP.DAT',FORM='FORMATTED')
      WRITE(IFLO,10) NBLOCKS
      WRITE(IFLO,20) (IMAX(N),JMAX(N),N=1,NBLOCKS)
      DO N = 1,NBLOCKS
        WRITE(IFLO,30) TREF,DUM,DUM,DUM
        WRITE(IFLO,30) ((T(N,I,J),I=1,IMAX(N)),J=1,JMAX(N)),
     &                 ((T(N,I,J),I=1,IMAX(N)),J=1,JMAX(N)),
     &                 ((T(N,I,J),I=1,IMAX(N)),J=1,JMAX(N)),
     &                 ((T(N,I,J),I=1,IMAX(N)),J=1,JMAX(N))
      ENDDO
!     CLOSE THE SOLUTION FILES
      CLOSE(IXYZ)
      CLOSE(IFLO)



