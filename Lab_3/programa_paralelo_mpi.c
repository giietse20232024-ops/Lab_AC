#define _POSIX_C_SOURCE 199311L
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

int main(int argc, char *argv[]) {
    int debug_mode = 0;
    int N, D;
    int n, i, j, d;

    /* --------------------------
       Inicialización de MPI
       -------------------------- */
    MPI_Init(&argc, &argv);

    int num_procs, rango;
    MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
    MPI_Comm_rank(MPI_COMM_WORLD, &rango);

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
            if (rango == 0) printf("Error: N y D deben ser enteros positivos.\n");
            MPI_Finalize();
            return 1;
        }
    } else {
        if (rango == 0) {
            printf("Uso:\n");
            printf("  %s 0        (modo depuracion)\n", argv[0]);
            printf("  %s N D      (modo experimentacion)\n", argv[0]);
        }
        MPI_Finalize();
        return 1;
    }

    /* --------------------------
       Planificación del reparto de filas
       -------------------------- */
    int *counts_elems = (int *) malloc(num_procs * sizeof(int));
    int *displs_elems = (int *) malloc(num_procs * sizeof(int));
    int rem = N % num_procs;
    int offset = 0;

    for (int p = 0; p < num_procs; p++) {
        int rows = (N / num_procs) + (p < rem ? 1 : 0);
        counts_elems[p] = rows * D;
        displs_elems[p] = offset * D;
        offset += rows;
    }
    int local_N = (N / num_procs) + (rango < rem ? 1 : 0);

    /* --------------------------
       2) Reserva de memoria
       -------------------------- */
    double *X = NULL;
    double *C = NULL;
    if (rango == 0) {
        X = (double *) malloc(sizeof(double) * N * D);
        C = (double *) malloc(sizeof(double) * N * D);
    }

    double *local_X = (double *) malloc(sizeof(double) * local_N * D);
    double *local_C = (double *) malloc(sizeof(double) * local_N * D);
    double *local_K = (double *) malloc(sizeof(double) * local_N * D);
    double *local_V = (double *) malloc(sizeof(double) * local_N * D);

    double *WK = (double *) malloc(sizeof(double) * D * D);
    double *WV = (double *) malloc(sizeof(double) * D * D);
    double *WQ = (double *) malloc(sizeof(double) * D * D);

    double *bK = (double *) malloc(sizeof(double) * D);
    double *bV = (double *) malloc(sizeof(double) * D);
    double *bQ = (double *) malloc(sizeof(double) * D);

    // Matrices K y V completas necesarias para la fase de softmax
    double *K = (double *) malloc(sizeof(double) * N * D);
    double *V = (double *) malloc(sizeof(double) * N * D);
    /* --------------------------
       3) Inicialización de datos
       -------------------------- */
    if (rango == 0) {
        if (debug_mode) {
            for (n = 0; n < N; n++) {
                for (d = 0; d < D; d++) {
                    X[n * D + d] = (double)(n + N * d);
                }
            }
            for (i = 0; i < D; i++) {
                for (j = 0; j < D; j++) WK[i * D + j] = -0.2 + 0.1 * j;
            }
            for (j = 0; j < D; j++) bK[j] = -1.0;

            for (i = 0; i < D; i++) {
                double val = -0.2 + 0.1 * i;
                for (j = 0; j < D; j++) WQ[i * D + j] = val;
            }
            for (j = 0; j < D; j++) bQ[j] = 0.1;

            for (i = 0; i < D; i++) {
                for (j = 0; j < D; j++) WV[i * D + j] = (i == j) ? 1.0 : 0.0;
            }
            for (j = 0; j < D; j++) bV[j] = 0.0;

        } else {
            srand((unsigned)time(NULL));
            for (n = 0; n < N; n++) {
                for (d = 0; d < D; d++) X[n * D + d] = 10.0 * ((double)rand() / (double)RAND_MAX);
            }
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
    }

    /* --------------------------
       4) Distribución de datos (Comunicaciones Colectivas)
       -------------------------- */
    // Difundir las matrices de pesos a todos los procesos
    MPI_Bcast(WK, D * D, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(WV, D * D, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(WQ, D * D, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(bK, D, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(bV, D, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(bQ, D, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // Repartir la matriz de entrada X equitativamente
    MPI_Scatterv(X, counts_elems, displs_elems, MPI_DOUBLE,
                 local_X, local_N * D, MPI_DOUBLE,
                 0, MPI_COMM_WORLD);

    /* --------------------------
       5) Algoritmo self-attention
       -------------------------- */
    double t0 = 0.0, t1 = 0.0;
    if (!debug_mode && rango == 0) {
        t0 = MPI_Wtime();
    }

    double sqrtD = sqrt((double)D);

    // 5.1: Calcular K y V en base a la porción local de X
    for (n = 0; n < local_N; n++) {
        for (j = 0; j < D; j++) {
            double sumK = bK[j];
            double sumV = bV[j];
            for (i = 0; i < D; i++) {
                int index_traspuesta = i * D + j;
                double xni = local_X[n * D + i];
                sumK += WK[index_traspuesta] * xni;
                sumV += WV[index_traspuesta] * xni;
            }
            int index = n * D + j;
            local_K[index] = sumK;
            local_V[index] = sumV;
        }
    }

    // INTERCAMBIO: Reconstruir K y V al completo en todos los procesos
    MPI_Allgatherv(local_K, local_N * D, MPI_DOUBLE,
                   K, counts_elems, displs_elems, MPI_DOUBLE,
                   MPI_COMM_WORLD);
    MPI_Allgatherv(local_V, local_N * D, MPI_DOUBLE,
                   V, counts_elems, displs_elems, MPI_DOUBLE,
                   MPI_COMM_WORLD);

    // 5.2: Calcular matriz resultante local de C
    for (n = 0; n < local_N; n++) {
        double q_local[D];
        double A_local[N];

        for (j = 0; j < D; j++) {
            double sumQ = bQ[j];
            for (i = 0; i < D; i++) {
                sumQ += WQ[i * D + j] * local_X[n * D + i];
            }
            q_local[j] = sumQ;
        }

        double sum_exp = 0.0;
        for (i = 0; i < N; i++) {
            double dot = 0.0;
            for (d = 0; d < D; d++) {
                dot += q_local[d] * K[i * D + d];
            }
            A_local[i] = exp(dot / sqrtD);
            sum_exp += A_local[i];
        }

        for (d = 0; d < D; d++) {
            double sumC = 0.0;
            for (i = 0; i < N; i++) {
                sumC += (A_local[i] / sum_exp) * V[i * D + d];
            }
            local_C[n * D + d] = sumC;
        }
    }

    // 5.3: Recolectar todas las porciones en C en el proceso raíz
    MPI_Gatherv(local_C, local_N * D, MPI_DOUBLE,
                C, counts_elems, displs_elems, MPI_DOUBLE,
                0, MPI_COMM_WORLD);

    if (!debug_mode && rango == 0) {
        t1 = MPI_Wtime();
    }

    /* --------------------------
       6) Salida y Liberación de memoria
       -------------------------- */
    if (rango == 0) {
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
    }

    if (rango == 0) { free(X); free(C); }
    free(local_X); free(local_C);
    free(local_K); free(local_V);
    free(WK); free(WV); free(WQ);
    free(bK); free(bV); free(bQ);
    free(K);  free(V);
    free(counts_elems); free(displs_elems);

    MPI_Finalize();
    return 0;
}
