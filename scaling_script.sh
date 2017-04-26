#!/bin/bash

#PBS -l walltime=00:30:00
#PBS -l nodes=1:ppn=20

module load openmpi/1.8.3/gnu/4.9.2

cd $PBS_O_WORKDIR

for numprocs in 1 2 4 8 16 20
do

    /usr/bin/time -p mpirun -np $numprocs src/simplemd.x in >> timing.dat

done

cat timing.dat | grep real | awk '{print $2}' > timing_plot.dat
