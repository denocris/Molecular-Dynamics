#!/bin/bash

#PBS -l walltime=00:15:00
#PBS -l nodes=1:ppn=20

module load openmpi/1.8.3/gnu/4.9.2

cd P2.10_seed/input
rm -f ../data/timing_A.dat
rm -f ../data/timing_A_clean.dat

for nprocs in 1 2 4 8 16 20;
do
    /usr/bin/time -p mpirun -np $nprocs ../src/simplemd.x in >> ../data/timing_A.dat
done

cat ../timing_A.dat | grep real | awk '{print $2}' > timing_A_clean.dat
