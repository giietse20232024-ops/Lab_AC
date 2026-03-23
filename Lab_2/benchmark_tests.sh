#!/usr/bin/env bash
set -euo pipefail

REPS=4
N_FIXED=100
D_FIXED=100
STEP=50
EXECUTABLES=("secuencial" "secuencial_O2" "paralelo" "paralelo_O2")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

read -r -p "Introduce la talla maxima (multiplo de 100): " MAX_SIZE

if ! [[ "$MAX_SIZE" =~ ^[0-9]+$ ]]; then
    echo "Error: la talla maxima debe ser un entero positivo." >&2
    exit 1
fi

if (( MAX_SIZE < 100 || MAX_SIZE % 100 != 0 )); then
    echo "Error: la talla maxima debe ser un multiplo de 100 y mayor o igual que 100." >&2
    exit 1
fi

missing=()
for exe in "${EXECUTABLES[@]}"; do
    if [[ ! -x "./$exe" ]]; then
        missing+=("$exe")
    fi
done

if (( ${#missing[@]} > 0 )); then
    echo "Error: faltan estos ejecutables en el directorio actual: ${missing[*]}" >&2
    echo "Compilalos antes de lanzar el script." >&2
    exit 1
fi

all_sizes=()
for ((size=100; size<=MAX_SIZE; size+=STEP)); do
    all_sizes+=("$size")
done

get_time() {
    local exe="$1"
    local n="$2"
    local d="$3"
    local output
    local time_value

    if ! output=$("./$exe" "$n" "$d" 2>&1); then
        echo "Error ejecutando ./$exe con N=$n y D=$d" >&2
        echo "$output" >&2
        return 1
    fi

    time_value=$(printf '%s\n' "$output" | awk '/Tiempo:/ {print $2; exit}')

    if [[ -z "$time_value" ]]; then
        echo "No se pudo extraer el tiempo de ./$exe con N=$n y D=$d" >&2
        echo "$output" >&2
        return 1
    fi

    printf '%s\n' "$time_value"
}

average_time() {
    local exe="$1"
    local n="$2"
    local d="$3"
    local sum="0"
    local t

    for ((rep=1; rep<=REPS; rep++)); do
        t=$(get_time "$exe" "$n" "$d")
        sum=$(awk -v s="$sum" -v t="$t" 'BEGIN { printf "%.10f", s + t }')
    done

    awk -v s="$sum" -v reps="$REPS" 'BEGIN { printf "%.10f", s / reps }'
}

write_header() {
    printf 'modo'
    for size in "${all_sizes[@]}"; do
        printf ';%s' "$size"
    done
    printf '\n'
}

write_row_n_fixed() {
    local exe="$1"
    local avg

    printf 'N=100,D_variable'
    for size in "${all_sizes[@]}"; do
        avg=$(average_time "$exe" "$N_FIXED" "$size")
        printf ';%s' "$avg"
    done
    printf '\n'
}

write_row_d_fixed() {
    local exe="$1"
    local avg

    printf 'D=100,N_variable'
    for size in "${all_sizes[@]}"; do
        avg=$(average_time "$exe" "$size" "$D_FIXED")
        printf ';%s' "$avg"
    done
    printf '\n'
}

write_row_both_variable() {
    local exe="$1"
    local avg

    printf 'N=D_variable'
    for size in "${all_sizes[@]}"; do
        avg=$(average_time "$exe" "$size" "$size")
        printf ';%s' "$avg"
    done
    printf '\n'
}

write_csv_for_executable() {
    local exe="$1"
    local outfile="resultados_${exe}.csv"

    echo "Generando $outfile ..."

    {
        write_header
        write_row_n_fixed "$exe"
        write_row_d_fixed "$exe"
        write_row_both_variable "$exe"
    } > "$outfile"
}

for exe in "${EXECUTABLES[@]}"; do
    write_csv_for_executable "$exe"
done

echo "Proceso completado. Archivos generados:"
printf ' - resultados_%s.csv\n' "${EXECUTABLES[@]}"
