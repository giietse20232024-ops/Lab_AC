#include <omp.h>
#include <stdio.h>
#include <unistd.h>

#define N 10
#define NTHREADS 4

int main() {
int tid, i;

omp_set_num_threads(NTHREADS);

#pragma omp parallel private(tid)
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
