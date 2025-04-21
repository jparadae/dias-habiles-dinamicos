#!/usr/bin/env bash
set -euo pipefail

# Configuración de zona horaria y año
export TZ="America/Santiago"
year=$(date +%Y)

# Mapea nombre de mes en español a número (sin cero inicial)
month_num() {
  case "$1" in
    Enero)      echo 1 ;;
    Febrero)    echo 2 ;;
    Marzo)      echo 3 ;;
    Abril)      echo 4 ;;
    Mayo)       echo 5 ;;
    Junio)      echo 6 ;;
    Julio)      echo 7 ;;
    Agosto)     echo 8 ;;
    Septiembre) echo 9 ;;
    Octubre)    echo 10 ;;
    Noviembre)  echo 11 ;;
    Diciembre)  echo 12 ;;
    *)          echo 0 ;;
  esac
}

declare -a cells
declare -a holidays

# Descarga y parsea los feriados en formato YYYY-MM-DD
fetch_holidays() {
  local html
  html=$(curl -s "https://www.feriados.cl/")

  # Extrae el contenido de cada <td>
  mapfile -t cells < <(printf '%s\n' "$html" | grep -oP '(?<=<td>)[^<]+')

  for idx in "${!cells[@]}"; do
    # Solo celdas pares => fechas
    if (( idx % 2 == 0 )); then
      local date_cell day month mes formatted
      date_cell=${cells[idx]}

      # Extraer día y mes
      day=$(grep -oP '\d{1,2}' <<<"$date_cell" || echo "")
      month=$(grep -oP '(?<=de )[[:alpha:]]+' <<<"$date_cell" || echo "")

      # Mapear mes a número
      mes=$(month_num "$month")
      if [[ "$mes" -eq 0 ]] || [[ -z "$day" ]]; then
        continue
      fi

      # Formatear a YYYY-MM-DD
      formatted=$(printf '%s-%02d-%02d' "$year" "$mes" "$day")
      holidays+=( "$formatted" )
    fi
  done
}

# Comprueba fin de semana
is_weekend() {
  local d=$1 dow
  dow=$(date -d "$d" +%u)
  (( dow >= 6 ))
}

# Comprueba feriado
is_holiday() {
  local d=$1
  for h in "${holidays[@]}"; do
    [[ $h == "$d" ]] && return 0
  done
  return 1
}

# Devuelve el último día hábil anterior a una fecha dada
prev_workday() {
  local d=$1
  while is_weekend "$d" || is_holiday "$d"; do
    d=$(date -d "$d -1 day" +%Y-%m-%d)
  done
  printf '%s' "$d"
}

# --- Flujo principal ---
fetch_holidays

today=$(date +%Y-%m-%d)

# Cálculo de ayer y anteayer hábiles
yesterday_raw=$(date -d "$today -1 day" +%Y-%m-%d)
yesterday=$(prev_workday "$yesterday_raw")

day_before_yesterday_raw=$(date -d "$yesterday -1 day" +%Y-%m-%d)
day_before_yesterday=$(prev_workday "$day_before_yesterday_raw")

# Salida final
echo "=== RESULTADOS ==="
echo "Ayer hábil:     $yesterday"
echo "Anteayer hábil: $day_before_yesterday"
