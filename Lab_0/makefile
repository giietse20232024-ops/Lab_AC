CC = gcc
CFLAGS = -Wall -g
LDFLAGS = -lm

SRC = programa_secuencial.c
OUT = programa_secuencial

all: $(OUT)

$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $(OUT) $(SRC) $(LDFLAGS)

clean:
	rm -f $(OUT)
