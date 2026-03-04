#include <omp.h>
#include <stdio.h>
#include <unistd.h>

#define N 10
#define NTHREADS 4

int main() {
int tid, i;

omp_set_num_threads(NTHREADS);

#pragma omp for schedule(static) parallel private(tid)
{
  tid = omp_get_thread_num();

  #pragma omp for
  for (i = 0; i < N; i++) {
    sleep(i);
    printf("El hilo %d ejecuta la iteracion %d\n", tid, i);
  }
}

  return 0;
}

// P1.1: cada una ejecuta N/NTHREADS iteraciones, en este caso 2
// P1.2: Las asignaciones son ejecutuvas porque se han hecho de forma statica.
// P1:3: La carga no esta equilibrada.

// P2.1: La ejecucion se mantiene igual
// P2.2: L
