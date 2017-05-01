#!/bin/bash

#PBS -l walltime=00:40:00
#PBS -l nodes=1:ppn=20

module load openmpi/1.8.3/gnu/4.9.2

cd P2.10_seed/Day3/input

mpirun -np 16 ../src/simplemd.x in0 in1 in2 in3 in4 in5 in6 in7 in8 in9 in10 in11 in12 in13 in14 in15
