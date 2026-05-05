CC_MPI = mpicc

SRC_MPI = programa_paralelo_mpi.c

CFLAGS = -Wall
CFLAGS_O2 = -Wall -O2
LDFLAGS = -lm

TARGETS = paralelo_mpi paralelo_mpi_O2

all: $(TARGETS)

paralelo_mpi: $(SRC_MPI)
	$(CC_MPI) $(CFLAGS) $(SRC_MPI) -o paralelo_mpi $(LDFLAGS)

paralelo_mpi_O2: $(SRC_MPI)
	$(CC_MPI) $(CFLAGS_O2) $(SRC_MPI) -o paralelo_mpi_O2 $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
