#!/bin/bash

set -u

# Ejecutables MPI a probar
EXECUTABLES=("paralelo_mpi" "paralelo_mpi_O2")

# Solo se ejecuta con 12 procesos MPI
NUM_PROCS=12

# Repeticiones por punto
REPS=4

# Tallas
MIN_SIZE=100
STEP=50

# Comando MPI
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
        echo "Error: no existe el ejecutable ./$exe o no tiene permisos de ejecucion."
        echo "Compila primero con: make"
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
    local time_val=""
    local output=""

    for ((r=1; r<=REPS; r++)); do
        echo "      Repeticion $r/$REPS..."

        output=$($MPI_RUN -np "$NUM_PROCS" "./$exe" "$n" "$d")
        time_val=$(extract_time "$output")

        if [[ -z "$time_val" ]]; then
            echo "Error: no se pudo extraer el tiempo."
            echo "Ejecutable: ./$exe"
            echo "Procesos MPI: $NUM_PROCS"
            echo "N=$n D=$d"
            echo "Salida recibida:"
            echo "$output"
            exit 1
        fi

        sum=$(awk -v a="$sum" -v b="$time_val" 'BEGIN { printf "%.10f", a + b }')
    done

    awk -v s="$sum" -v r="$REPS" 'BEGIN { printf "%.10f", s / r }'
}

write_csv() {
    local csv_file="$1"
    local -n values_ref="$2"

    {
        printf "procesos"
        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%d" "$size"
        done
        printf "\n"

        printf "%d" "$NUM_PROCS"
        local idx=0
        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%s" "${values_ref[$idx]}"
            ((idx++))
        done
        printf "\n"
    } > "$csv_file"
}

load_existing_csv() {
    local csv_file="$1"
    local -n values_ref="$2"

    [[ -f "$csv_file" ]] || return 0

    local line=""
    local -a fields=()

    while IFS= read -r line; do
        # Buscar la fila que empieza por "12;"
        if [[ "$line" == "$NUM_PROCS;"* ]]; then
            IFS=';' read -r -a fields <<< "$line"

            local idx=0
            local col=1

            for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
                if (( col < ${#fields[@]} )); then
                    values_ref[$idx]="${fields[$col]}"
                else
                    values_ref[$idx]=""
                fi

                ((idx++))
                ((col++))
            done

            return 0
        fi
    done < "$csv_file"
}

for exe in "${EXECUTABLES[@]}"; do
    csv_file="resultados_${exe}_12procesos.csv"

    echo "========================================"
    echo "Procesando ejecutable: $exe"
    echo "Procesos MPI: $NUM_PROCS"
    echo "CSV: $csv_file"
    echo "========================================"

    values=()

    idx=0
    for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
        values[$idx]=""
        ((idx++))
    done

    load_existing_csv "$csv_file" values

    # Crear o actualizar el CSV antes de empezar
    write_csv "$csv_file" values

    idx=0
    for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do

        if [[ -n "${values[$idx]}" ]]; then
            echo "  Saltando N=D=$size. Ya calculado: ${values[$idx]}"
            ((idx++))
            continue
        fi

        echo "  Calculando N=D=$size con $NUM_PROCS procesos MPI..."
        avg_time=$(compute_average "$exe" "$size" "$size")

        values[$idx]="$avg_time"

        # Guardar progreso inmediatamente
        write_csv "$csv_file" values

        echo "  Guardado: N=D=$size, tiempo medio=$avg_time"

        ((idx++))
    done

    echo "Finalizado/actualizado: $csv_file"
    echo
done

echo "Benchmark MPI con 12 procesos completado."
