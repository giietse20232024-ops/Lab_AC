CC = gcc
CFLAGS = -fopenmp
LDFLAGS =

N ?= 1
SRC = Ejercicio_$(N).c
OUT = Ejercicio_$(N)

all: $(OUT)

$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $(OUT) $(SRC) $(LDFLAGS)

%:
	@$(MAKE) N=$@ all

clean:
	rm -f $(OUT)
