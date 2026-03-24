#!/usr/bin/env bash
set -euo pipefail

N_FIXED=100
D_FIXED=100
STEP=50
EXECUTABLES=("secuencial" "secuencial_O2" "paralelo" "paralelo_O2")
ROW_LABELS=("N=100,D_variable" "D=100,N_variable" "N=D_variable")

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
TOTAL_COLS=${#all_sizes[@]}

declare -a row_n_fixed row_d_fixed row_both

reps_for_exe() {
    local exe="$1"
    case "$exe" in
        secuencial|secuencial_O2)
            printf '2\n'
            ;;
        paralelo|paralelo_O2)
            printf '4\n'
            ;;
        *)
            printf '4\n'
            ;;
    esac
}

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
    local reps="$4"
    local sum="0"
    local t

    for ((rep=1; rep<=reps; rep++)); do
        t=$(get_time "$exe" "$n" "$d")
        sum=$(awk -v s="$sum" -v t="$t" 'BEGIN { printf "%.10f", s + t }')
    done

    awk -v s="$sum" -v reps="$reps" 'BEGIN { printf "%.10f", s / reps }'
}

reset_rows() {
    row_n_fixed=()
    row_d_fixed=()
    row_both=()
    for ((i=0; i<TOTAL_COLS; i++)); do
        row_n_fixed+=("")
        row_d_fixed+=("")
        row_both+=("")
    done
}

load_existing_csv() {
    local outfile="$1"
    reset_rows

    [[ -f "$outfile" ]] || return 0

    local line_num=0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        IFS=';' read -r -a fields <<< "$line"
        case "$line_num" in
            1)
                for ((i=1; i<${#fields[@]} && i<=TOTAL_COLS; i++)); do
                    row_n_fixed[$((i-1))]="${fields[i]}"
                done
                ;;
            2)
                for ((i=1; i<${#fields[@]} && i<=TOTAL_COLS; i++)); do
                    row_d_fixed[$((i-1))]="${fields[i]}"
                done
                ;;
            3)
                for ((i=1; i<${#fields[@]} && i<=TOTAL_COLS; i++)); do
                    row_both[$((i-1))]="${fields[i]}"
                done
                ;;
        esac
        ((line_num+=1))
    done < "$outfile"
}

save_csv() {
    local outfile="$1"
    local tmpfile
    tmpfile="$(mktemp)"

    {
        printf 'modo'
        for size in "${all_sizes[@]}"; do
            printf ';%s' "$size"
        done
        printf '\n'

        printf '%s' "${ROW_LABELS[0]}"
        for ((i=0; i<TOTAL_COLS; i++)); do
            printf ';%s' "${row_n_fixed[i]}"
        done
        printf '\n'

        printf '%s' "${ROW_LABELS[1]}"
        for ((i=0; i<TOTAL_COLS; i++)); do
            printf ';%s' "${row_d_fixed[i]}"
        done
        printf '\n'

        printf '%s' "${ROW_LABELS[2]}"
        for ((i=0; i<TOTAL_COLS; i++)); do
            printf ';%s' "${row_both[i]}"
        done
        printf '\n'
    } > "$tmpfile"

    mv "$tmpfile" "$outfile"
}

process_row() {
    local exe="$1"
    local outfile="$2"
    local row_type="$3"
    local reps="$4"
    local -n row_ref="$5"
    local size n d avg label

    case "$row_type" in
        n_fixed)
            label="${ROW_LABELS[0]}"
            ;;
        d_fixed)
            label="${ROW_LABELS[1]}"
            ;;
        both)
            label="${ROW_LABELS[2]}"
            ;;
        *)
            echo "Tipo de fila desconocido: $row_type" >&2
            exit 1
            ;;
    esac

    for ((idx=0; idx<TOTAL_COLS; idx++)); do
        if [[ -n "${row_ref[idx]}" ]]; then
            continue
        fi

        size="${all_sizes[idx]}"
        case "$row_type" in
            n_fixed)
                n="$N_FIXED"
                d="$size"
                ;;
            d_fixed)
                n="$size"
                d="$D_FIXED"
                ;;
            both)
                n="$size"
                d="$size"
                ;;
        esac

        echo "[$exe] $label -> N=$n D=$d (${reps} repeticiones)"
        avg=$(average_time "$exe" "$n" "$d" "$reps")
        row_ref[$idx]="$avg"
        save_csv "$outfile"
    done
}

process_executable() {
    local exe="$1"
    local outfile="resultados_${exe}.csv"
    local reps
    reps=$(reps_for_exe "$exe")

    echo "Procesando $outfile ..."
    load_existing_csv "$outfile"
    save_csv "$outfile"

    process_row "$exe" "$outfile" n_fixed "$reps" row_n_fixed
    process_row "$exe" "$outfile" d_fixed "$reps" row_d_fixed
    process_row "$exe" "$outfile" both "$reps" row_both

    echo "Completado $outfile"
}

for exe in "${EXECUTABLES[@]}"; do
    process_executable "$exe"
done

echo "Proceso completado. Archivos actualizados:"
printf ' - resultados_%s.csv\n' "${EXECUTABLES[@]}"
