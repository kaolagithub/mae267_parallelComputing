#!/bin/bash
echo "Compiling..."
mpif90 -o main -O3 modules.f90 inout.f90 subroutines.f90 main.f90
#Remove module files
rm *.mod

