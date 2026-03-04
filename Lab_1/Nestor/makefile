CC = gcc
CFLAGS = -fopenmp 
LDFLAGS =

SRC = Ejercicio_1.c
OUT = Ejercicio_1

all: $(OUT)

$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $(OUT) $(SRC) $(LDFLAGS)

clean:
	rm -f $(OUT)
