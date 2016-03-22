
Preamble
========

Take some time to familiarize with the `simplemd` code in `src/simplemd.cpp`. In particular, make sure you understand the functions `compute_forces()`, `compute_list()` and `check_list()`. You can compile `simplemd` typing `make all`.

Also try to use it to run short molecular dynamics (MD) simulations. Look in the `input/` directory, where you will find a sample input file. You can run `simplemd` by typing

     ../src/simplemd.x in

Keywords are explained in the comments that are included in the sample input file. The keyowrds that are relevant for these assignments are:

- `listcutoff`. An appropriate value for a calculation with neighbor lists is 3. Set it to a huge number (e.g. `1e6`) to disable neighbor list.
- `nsteps`. Use it to tune the length of the simulation.
Notice that benchmarks will typically need at least a few hundreds of steps so as to be properly timed.

You can generate starting configurations using the following command

    ./lattice 10 > crystal.xyz

Here 10 means that your `.xyz` file will contain 10 X 10 X 10 X 4 = 4000 atoms. You will need this to check how the performances of the code scale with the number of particles.

Moreover, you can have a look to the `energies.dat` file. It has several columns:

    step-number
    simulation-time
    instantaneous-temperature
    configurational-energy
    total-energy
    conserved-quantity

You can analyze this file to quickly check if two simulations are identical. For instance, if you optimize the code and run it again, the new `energies.dat` file should be identical to the old one.

Assignment 1 - Parallelize force calculation
================================

The calculation of forces in molecular dynamics simulations of a system of Lennard-Jones particles involves the calculation of all pairwise distances at each time step of the simulation. This in principle requires a double loop over all particles. Later we will use neighbor lists. For the moment, disable them by setting `listcutoff` to a huge number (e.g. 1e6).

TASK A
------

1.   Modify the code and the makefile so as to use MPI library. Look for all `fopen()` statements and make sure that processes which are not root (`rank!=0`) are opening `/dev/null` so that there are no duplicated lines in the output.
2.   Parallelize the computation of the forces within the double loop using MPI. A possible approch is to modify the loop on particle pairs and makes it such that every processor only includes some of the pairs. At the end of the loop you can use `MPI_Allreduce()` to sum the forces over the processors.
3. Measure the scalability of the code, that is how the speed depends on the number of processors at fixed number of atoms.

Verlet lists (neighbor lists) are used to speed up the calculation of pairwise distances and forces. They are already implemented in the code, so you can see their effect by just setting `listcutoff` to an appropriate number (e.g. 3). Simulation will be much faster.

Although neighbor lists are not calculated every step, their calculation also require a loop over all pairs. As a consequence, if your code has neighbor lists implemented, it is much more convenient to directly parallelize their calculation with MPI. Notice that by doing that each process will contain only a part of the list of neighbors. This will decrease the memory usage per process. Moreover, since each process will only contain a portion of the pairs of interacting particles, the force calculation will be implicitly parallelized. Also notice that steps when the neighbor list is updated are significantly slower than other steps.
Thus, for doing benchmarks you should use a large number of steps (e.g. "nsteps 1000")

TASK B
------

1. Parallelize the computation of the neighbor lists. Each process should only store a subset of the pairs of interacting atoms.
2. Measure the scalability of the code.


Assignment 2 - Code Linked cells
================================

As the system size increases, the size of the neighbor lists becomes very large, and their construction becomes computationally expensive, involving a double loop over all pairs and a logical testing of their distance. An important trick used in molecular simulations is the use of linked cells.
Notice that often linked cells are used to compute forces directly. Since the program you are using already implements neighbor lists, it is convenient to use linked cells to parallelize the update of the neighbor list. This will make the update scale linearly in the number of particles.

1. Write a parallel code implementing the linked cells. To do it you should modify the routine that updates the neighbor list. In particular you should
  - Divide the simulation box in a number of domains such that only neighboring domains are interacting.
  - Make a loop over the atoms assigning each of them to one of the domains
  - Make a double loop over domains considering only pairs of domains that are close to each other.
  - Make a loop over the particles of neighboring domains, adding the pair to the neighbor list if the distance is less than `listcutoff`.
2. Measure the scalability of the code. 
3. Keeping the number of processors fixed, measure the scalability of the code when you change the number of atoms in the simulation box.

Assignment 3 - Parallel tempering
=================================

One problem frequently encountered in molecular simulations is the so-called sampling problem. When high energy barriers between states exist, simulations tend to get trapped in local minima. To overcome this problem, a large number of enhanced sampling techniques have been proposed. One of the most common one is parallel tempering (or replica exchange), in which different replicas of the system are run at different temperatures, thereby accelerating the crossing of the barriers. The coordinates of neighbor replicas are swapped using a Metropolis criterion.

1. Implement a framework for multi-replica simulations. You should split `MPI_COMM_WORLD` in subgroups so that each simulation runs on multiple processors. Modify the program in such a way that it accepts multiple input files (e.g. `mpirun -np 4 ../src/simplemd.x in0 in1` should run two simulations with 4 processors each). In this manner you can generate input files `in0` and `in1` with an external script so that they write on different output files and do not interfere between each other. This will allow different independent simulations to be run. Use a different seed `idum` for each of them so that trajectories are different.

2. Implement in simplemd a parallel tempering alogrithm, in which each processor runs a replica and exchanges between them are attempted every m steps. The exchange probability has to follow the Metropolis-Hastings criterion. The right place to add it is just after (or before) the energy file is written, that is at the end of the MD loop. You should do the following things:
  - Add an input option `exchangestride` to control how frequently exchanges should be tried.
  - Everytime an exchange is tried, choose a partner replica. E.g., on even exchanges, replica 0 should try to exchange with replica 1, replica 2 with replica 3, etc. On even exchanges, replica 1 should try to exchange with replica 2, etc. The following should make the job:

        int partner=irep+(((istep+1)/exchangestride+irep)%2)*2-1;
        if(partner<0) partner=0;
        if(partner>=nrep) partner=nrep-1;
      
  - Send to the partner replica the value of configurational energy and temperature range.
  - Compute the acceptance using the Metropolis criterion (see lecture).
  - Compare the acceptance with the random number to decide if the exchange should be accepted or not.
  - Notice that the two replicas should use the same random number to take a consistent decision. To this aim, you could either send the random number together with configurational energy and temperature
  or transfer a boolean at this stage.
  - In case the exchange is accepted, swap coordinates and velocities among the two replicas. Also scale the velocities according to the temperature of the two replicas.

3. Verify that the parallel tempering implementation is working correctly. To this aim:
  - Run 16 simulations at temperatures from 1 to 1.5 following a geometric schedule.
  - Compute the average value of the potential energy (column 4 from `energies.dat` file).
  - Verify that if you do not make any exchange (e.g. set `exchangestride` to a huge number)
  or if you do frequent exchanges (e.g. set `exchangestride` to 10) you get same average potential energy for each replica.
  - Compute the average acceptance rate and check how it depends on the size of the system.









