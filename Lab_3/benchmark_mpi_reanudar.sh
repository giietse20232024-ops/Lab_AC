#!/bin/bash

set -u

# Ejecutables MPI a probar
EXECUTABLES=("paralelo_mpi" "paralelo_mpi_O2")

# Número de procesos MPI a probar
PROCS_LIST=(2 4 8)

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

    echo "$output" | sed -n 's/.*Tiempo:[[:space:]]*\([0-9.]\+\)[[:space:]]*s.*/\1/p'
}

compute_average() {
    local exe="$1"
    local n="$2"
    local d="$3"
    local procs="$4"

    local sum="0"
    local time_val=""
    local output=""

    for ((r=1; r<=REPS; r++)); do
        output=$($MPI_RUN -np "$procs" "./$exe" "$n" "$d")
        time_val=$(extract_time "$output")

        if [[ -z "$time_val" ]]; then
            echo "Error: no se pudo extraer el tiempo."
            echo "Ejecutable: ./$exe"
            echo "Procesos MPI: $procs"
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
    declare -n data_ref="$2"

    {
        printf "procesos"
        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            printf ";%d" "$size"
        done
        printf "\n"

        for procs in "${PROCS_LIST[@]}"; do
            printf "%d" "$procs"

            for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
                key="${procs}_${size}"
                printf ";%s" "${data_ref[$key]}"
            done

            printf "\n"
        done
    } > "$csv_file"
}

load_existing_csv() {
    local csv_file="$1"
    declare -n data_ref="$2"

    [[ -f "$csv_file" ]] || return 0

    local line_num=0

    while IFS=';' read -r -a fields; do
        ((line_num++))

        # Saltar cabecera
        if (( line_num == 1 )); then
            continue
        fi

        local procs="${fields[0]}"
        [[ -z "$procs" ]] && continue

        local col=1

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            if (( col < ${#fields[@]} )); then
                data_ref["${procs}_${size}"]="${fields[$col]}"
            else
                data_ref["${procs}_${size}"]=""
            fi

            ((col++))
        done
    done < "$csv_file"
}

for exe in "${EXECUTABLES[@]}"; do
    csv_file="resultados_${exe}_procesos.csv"

    declare -A data=()

    # Inicializar todas las celdas como vacías
    for procs in "${PROCS_LIST[@]}"; do
        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            data["${procs}_${size}"]=""
        done
    done

    # Cargar datos previos si el CSV ya existe
    load_existing_csv "$csv_file" data

    # Crear CSV inicial si no existe
    if [[ ! -f "$csv_file" ]]; then
        write_csv "$csv_file" data
    fi

    echo "Procesando ejecutable: $exe"

    for procs in "${PROCS_LIST[@]}"; do
        echo "  Procesos MPI: $procs"

        for ((size=MIN_SIZE; size<=MAX_SIZE; size+=STEP)); do
            key="${procs}_${size}"

            # Si ya existe valor, no se recalcula
            if [[ -n "${data[$key]}" ]]; then
                echo "    Saltando N=D=$size con $procs procesos. Ya calculado: ${data[$key]}"
                continue
            fi

            echo "    Calculando N=D=$size con $procs procesos..."

            avg_time=$(compute_average "$exe" "$size" "$size" "$procs")
            data["$key"]="$avg_time"

            # Guardar progreso tras cada punto
            write_csv "$csv_file" data

            echo "    Guardado: procesos=$procs, N=D=$size, tiempo medio=$avg_time"
        done
    done

    echo "Generado/actualizado: $csv_file"
    unset data
done

echo "Benchmark MPI completado."
