CC = gcc

SRC_SEQ = programa_secuencial.c
SRC_PAR = programa_paralelo_omp.c

CFLAGS = -Wall
CFLAGS_O2 = -Wall -O2
OMPFLAGS = -fopenmp
LDFLAGS = -lm

all: secuencial secuencial_O2 paralelo paralelo_O2

secuencial: $(SRC_SEQ)
	$(CC) $(CFLAGS) $(SRC_SEQ) -o secuencial $(LDFLAGS)

secuencial_O2: $(SRC_SEQ)
	$(CC) $(CFLAGS_O2) $(SRC_SEQ) -o secuencial_O2 $(LDFLAGS)

paralelo: $(SRC_PAR)
	$(CC) $(CFLAGS) $(OMPFLAGS) $(SRC_PAR) -o paralelo $(LDFLAGS)

paralelo_O2: $(SRC_PAR)
	$(CC) $(CFLAGS_O2) $(OMPFLAGS) $(SRC_PAR) -o paralelo_O2 $(LDFLAGS)

clean:
	rm -f secuencial secuencial_O2 paralelo paralelo_O2
