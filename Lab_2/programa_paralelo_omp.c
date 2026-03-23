#define _POSIX_C_SOURCE 199311L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <omp.h>

double get_time() {
    struct timespec t;
    clock_gettime(CLOCK_REALTIME, &t);
    return (double)t.tv_sec + ((double)t.tv_nsec) / 1e9;
}

int main(int argc, char *argv[]) {
    int debug_mode = 0;
    int N, D;
    int n, i, j, d;

    /* --------------------------
       1) Leer modo de ejecución
       -------------------------- */
    if (argc == 2 && strcmp(argv[1], "0") == 0) {
        debug_mode = 1;
        N = 6;
        D = 4;
    } else if (argc == 3) {
        N = atoi(argv[1]);
        D = atoi(argv[2]);
        if (N <= 0 || D <= 0) {
            printf("Error: N y D deben ser enteros positivos.\n");
            return 1;
        }
    } else {
        printf("Uso:\n");
        printf("  %s 0        (modo depuracion)\n", argv[0]);
        printf("  %s N D      (modo experimentacion)\n", argv[0]);
        return 1;
    }

    /* --------------------------
       2) Reserva de memoria
       Matrices en bloque contiguo
       -------------------------- */
    double *X  = (double *) malloc(sizeof(double) * N * D);
    double *C  = (double *) malloc(sizeof(double) * N * D);

    double *WK = (double *) malloc(sizeof(double) * D * D);
    double *WV = (double *) malloc(sizeof(double) * D * D);
    double *WQ = (double *) malloc(sizeof(double) * D * D);

    double *bK = (double *) malloc(sizeof(double) * D);
    double *bV = (double *) malloc(sizeof(double) * D);
    double *bQ = (double *) malloc(sizeof(double) * D);

    double *K  = (double *) malloc(sizeof(double) * N * D);
    double *V  = (double *) malloc(sizeof(double) * N * D);

    double *q  = (double *) malloc(sizeof(double) * D); /* q_n temporal */
    double *A  = (double *) malloc(sizeof(double) * N); /* pesos atención temporales */

    if (!X || !C || !WK || !WV || !WQ || !bK || !bV || !bQ || !K || !V || !q || !A) {
        printf("Error: no se pudo reservar memoria.\n");
        free(X); free(C);
        free(WK); free(WV); free(WQ);
        free(bK); free(bV); free(bQ);
        free(K); free(V);
        free(q); free(A);
        return 1;
    }

    /* --------------------------
       3) Inicialización de datos
       -------------------------- */
    if (debug_mode) {
        /* X(n,d) según el enunciado:
           filas:
           0 6 12 18
           1 7 13 19
           ...
           5 11 17 23
           -> X[n*D + d] = n + N*d (con N=6)
        */
        for (n = 0; n < N; n++) {
            for (d = 0; d < D; d++) {
                X[n * D + d] = (double)(n + N * d);
            }
        }

        /* WK: todas las filas iguales a [-0.2, -0.1, 0.0, 0.1] */
        for (i = 0; i < D; i++) {
            for (j = 0; j < D; j++) {
                WK[i * D + j] = -0.2 + 0.1 * j;
            }
        }
        for (j = 0; j < D; j++) bK[j] = -1.0;

        /* WQ:
           fila 0: -0.2 -0.2 -0.2 -0.2
           fila 1: -0.1 -0.1 -0.1 -0.1
           fila 2:  0.0  0.0  0.0  0.0
           fila 3:  0.1  0.1  0.1  0.1
        */
        for (i = 0; i < D; i++) {
            double val = -0.2 + 0.1 * i;
            for (j = 0; j < D; j++) {
                WQ[i * D + j] = val;
            }
        }
        for (j = 0; j < D; j++) bQ[j] = 0.1;

        /* WV = identidad, bV = 0 */
        for (i = 0; i < D; i++) {
            for (j = 0; j < D; j++) {
                WV[i * D + j] = (i == j) ? 1.0 : 0.0;
            }
        }
        for (j = 0; j < D; j++) bV[j] = 0.0;

    } else {
        /* Modo experimentación */
        srand((unsigned)time(NULL));

        /* X en [0, 10] */
        for (n = 0; n < N; n++) {
            for (d = 0; d < D; d++) {
                X[n * D + d] = 10.0 * ((double)rand() / (double)RAND_MAX);
            }
        }

        /* Pesos y sesgos pequeños en [-0.0005, 0.0005] */
        for (i = 0; i < D; i++) {
            for (j = 0; j < D; j++) {
                WK[i * D + j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
                WV[i * D + j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
                WQ[i * D + j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
            }
        }

        for (j = 0; j < D; j++) {
            bK[j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
            bV[j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
            bQ[j] = 0.001 * (((double)rand() / (double)RAND_MAX) - 0.5);
        }
    }

    /* --------------------------
       4) Algoritmo self-attention
       (misma implementación para ambos modos)
       -------------------------- */
    double t0 = 0.0, t1 = 0.0;
    if (!debug_mode) {
        t0 = get_time();
    }

    double sqrtD = sqrt((double)D);

    /* 4.1 Calcular K y V para todo n
       kn = WK^T * xn + bK
       vn = WV^T * xn + bV
    */
    #pragma omp parallel for schedule(static) private(n, j, i) shared(N, D, WK, WV, bK, bV, X, K, V)
    for (n = 0; n < N; n++) { 

        for (j = 0; j < D; j++) {
            double sumK = bK[j];
            double sumV = bV[j]; 
            for (i = 0; i < D; i++) {
                int index_traspuesta = i * D + j;
                double xni = X[n * D + i];
                /* W^T * x  => usar W[i][j] */
                sumK += WK[index_traspuesta] * xni; // 2  FLOPS
                sumV += WV[index_traspuesta] * xni; // 2  FLOPS
            }
            int index = n * D + j;
            K[index] = sumK;
            V[index] = sumV;
        }
    }

    /* 4.2 Para cada n: calcular q_n, similitudes, softmax y c_n */
    #pragma omp parallel for schedule(static) private(n, j, i, d) shared(N, D, WQ, bQ, X, K, V, C, sqrtD)
    for (n = 0; n < N; n++) {
        // Declaramos buffers locales al hilo (en el stack)
        // Esto evita que los hilos se pisen entre sí
        double q_local[D]; 
        double A_local[N];

        /* q_n = WQ^T * x_n + bQ */
        for (j = 0; j < D; j++) { 
            double sumQ = bQ[j];
            for (i = 0; i < D; i++) {
                sumQ += WQ[i * D + j] * X[n * D + i];
            }
            q_local[j] = sumQ;
        }

        /* A(i) = exp( (q_n · k_i) / sqrt(D) ) */
        double sum_exp = 0.0; // Esta variable debe ser privada (se declara aquí)
        for (i = 0; i < N; i++) {
            double dot = 0.0;
            for (d = 0; d < D; d++) {
                dot += q_local[d] * K[i * D + d];
            }
            A_local[i] = exp(dot / sqrtD);
            sum_exp += A_local[i];
        }

        /* Normalizar y calcular c_n */
        for (d = 0; d < D; d++) {
            double sumC = 0.0;
            for (i = 0; i < N; i++) {
                sumC += (A_local[i] / sum_exp) * V[i * D + d];
            }
            C[n * D + d] = sumC;
        }
    }

    if (!debug_mode) {
        t1 = get_time();
    }

    /* --------------------------
       5) Salida
       -------------------------- */
    if (debug_mode) {
        printf("C =\n");
        for (n = 0; n < N; n++) {
            for (d = 0; d < D; d++) {
                printf("%6.1f ", C[n * D + d]);
            }
            printf("\n");
        }
    } else {
        printf("Tiempo: %f s\n", t1 - t0);
    }

    /* --------------------------
       6) Liberar memoria
       -------------------------- */
    free(X);  free(C);
    free(WK); free(WV); free(WQ);
    free(bK); free(bV); free(bQ);
    free(K);  free(V);
    free(q);  free(A);

    return 0;
}
