#!/bin/bash

set -u

THREADS_LIST=(2 4 8)
EXECUTABLES=("paralelo" "paralelo_O2")
REPS=4
STEP=50
MIN_SIZE=100

read -p "Introduce la talla maxima del programa (multiplo de 100): " MAX_SIZE

if ! [[ "$MAX_SIZE" =~ ^[0-9]+$ ]]; then
    echo "Error: la talla maxima debe ser un entero positivo."
    exit 1
fi

if (( MAX_SIZE < 100 || MAX_SIZE % 100 != 0 )); then
    echo "Error: la talla maxima debe ser multiplo de 100 y mayor o igual que 100."
    exit 1
fi

for exe in "${EXECUTABLES[@]}"; do
    if [[ ! -x "./$exe" ]]; then
        echo "Error: no existe el ejecutable ./$exe o no tiene permisos de ejecucion."
        exit 1
    fi
done

extract_time() {
    local output="$1"
    echo "$output" | sed -n 's/.*Tiempo:[[:space:]]*\([0-9.]\+\)[[:space:]]*s.*/\1/p'
}

compute_average() {
    local exe="$1"
    local n="$2"
    local d="$3"
    local threads="$4"

    local sum="0"
    local time_val=""
    local output=""

    for ((r=1; r<=REPS; r++)); do
        output=$(OMP_NUM_THREADS="$threads" "./$exe" "$n" "$d")
        time_val=$(extract_time "$output")

        if [[ -z "$time_val" ]]; then
            echo "Error: no se pudo extraer el tiempo de ./$exe N=$n D=$d con $threads hilos"
            echo "Salida recibida:"
            echo "$output"
            exit 1
        fi

        sum=$(awk -v a="$sum" -v b="$time_val" 'BEGIN { printf "%.10f", a + b }')
    done

    awk -v s="$sum" -v r="$REPS" 'BEGIN { printf "%.10f", s / r }'
}

for exe in "${EXECUTABLES[@]}"; do
    csv_file="resultados_${exe}_hilos.csv"

    {
        printf "hilos"
        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%d" "$size"
        done
        printf "\n"

        for threads in "${THREADS_LIST[@]}"; do
            printf "%d" "$threads"

            for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
                avg_time=$(compute_average "$exe" "$size" "$size" "$threads")
                printf ";%s" "$avg_time"
            done

            printf "\n"
        done
    } > "$csv_file"

    echo "Generado: $csv_file"
done

echo "Benchmark completado."
