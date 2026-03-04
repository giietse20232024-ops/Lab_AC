#include <omp.h>
#include <stdio.h>

int main() {
int nthreads, thread;

  #pragma omp parallel private(nthreads, thread) omp_set_num_theads(2)
  {
    thread = omp_get_thread_num();
    nthreads = omp_get_num_threads();
    printf("Hola soy el hilo = %d de %d\n", thread, nthreads);
  }

return 0;
}

// P1: Un camvio simple:
// P2: al hacer eso unos se sobrescribirian a otros las variables dando resultados no fiables
// P3: Al pasarle la variable como private, cada uno tendra una copia diferente que no podra modificar ningun otro proceso.
// P4: Se puede poner un if que identifique si es el thread = 0;
