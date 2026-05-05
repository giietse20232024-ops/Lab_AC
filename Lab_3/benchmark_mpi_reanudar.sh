#!/usr/bin/env bash

set -u

EXECUTABLES=("paralelo_mpi" "paralelo_mpi_O2")

NUM_PROCS=12
REPS=4

MIN_SIZE=100
STEP=100

MPI_RUN="mpirun"

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
        echo "Error: no existe ./$exe o no tiene permisos de ejecucion."
        echo "Compila primero con make."
        exit 1
    fi
done

extract_time() {
    local output="$1"

    echo "$output" | sed -n 's/.*Tiempo:[[:space:]]*\([0-9.]\+\)[[:space:]]*s.*/\1/p' | head -n 1
}

compute_average() {
    local exe="$1"
    local n="$2"
    local d="$3"

    local sum="0"
    local output=""
    local time_val=""

    for ((rep=1; rep<=REPS; rep++)); do
        echo "      Repeticion $rep/$REPS" >&2

        output=$($MPI_RUN -np "$NUM_PROCS" "./$exe" "$n" "$d")
        time_val=$(extract_time "$output")

        if [[ -z "$time_val" ]]; then
            echo "Error: no se pudo extraer el tiempo." >&2
            echo "Ejecutable: ./$exe" >&2
            echo "Procesos MPI: $NUM_PROCS" >&2
            echo "N=$n D=$d" >&2
            echo "Salida recibida:" >&2
            echo "$output" >&2
            exit 1
        fi

        sum=$(awk -v a="$sum" -v b="$time_val" 'BEGIN { printf "%.10f", a + b }')
    done

    awk -v s="$sum" -v r="$REPS" 'BEGIN { printf "%.10f", s / r }'
}

is_valid_number() {
    local value="$1"

    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

create_empty_csv_if_needed() {
    local csv_file="$1"

    if [[ -f "$csv_file" ]]; then
        return 0
    fi

    {
        printf "procesos"

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%d" "$size"
        done

        printf "\n"
        printf "%d" "$NUM_PROCS"

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";"
        done

        printf "\n"
    } > "$csv_file"
}

load_existing_results() {
    local csv_file="$1"
    local -n results_ref="$2"

    local line=""
    local -a fields

    while IFS= read -r line; do
        if [[ "$line" == "$NUM_PROCS;"* ]]; then
            IFS=';' read -r -a fields <<< "$line"

            local col=1

            for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
                local value=""

                if (( col < ${#fields[@]} )); then
                    value="${fields[$col]}"
                fi

                if is_valid_number "$value"; then
                    results_ref["$size"]="$value"
                else
                    results_ref["$size"]=""
                fi

                ((col++))
            done

            return 0
        fi
    done < "$csv_file"
}

write_csv() {
    local csv_file="$1"
    local -n results_ref="$2"

    {
        printf "procesos"

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%d" "$size"
        done

        printf "\n"
        printf "%d" "$NUM_PROCS"

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%s" "${results_ref[$size]}"
        done

        printf "\n"
    } > "$csv_file"
}

for exe in "${EXECUTABLES[@]}"; do
    csv_file="resultados_${exe}_12procesos.csv"

    echo "========================================"
    echo "Ejecutable: $exe"
    echo "Procesos MPI: $NUM_PROCS"
    echo "Tallas: $MIN_SIZE, $((MIN_SIZE + STEP)), ..., $MAX_SIZE"
    echo "CSV: $csv_file"
    echo "========================================"

    declare -A results=()

    for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
        results["$size"]=""
    done

    create_empty_csv_if_needed "$csv_file"
    load_existing_results "$csv_file" results
    write_csv "$csv_file" results

    for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
        if [[ -n "${results[$size]}" ]]; then
            echo "  Saltando N=D=$size. Ya calculado: ${results[$size]}"
            continue
        fi

        echo "  Calculando N=D=$size con $NUM_PROCS procesos MPI..."

        avg_time=$(compute_average "$exe" "$size" "$size")

        results["$size"]="$avg_time"

        write_csv "$csv_file" results

        echo "  Guardado N=D=$size -> $avg_time"
    done

    echo "Finalizado: $csv_file"
    echo

    unset results
done

echo "Benchmark MPI completado."
