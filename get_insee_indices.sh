#!/usr/bin/env bash
set -euo pipefail

# get_insee_indices.sh
# Auteur : Julien JEAN
# Génère des INSERT SQL pour ref_indice_loyer à partir des données INSEE (IRL, ILC, ILAT)
# Usage :
#   ./get_insee_indices.sh <INDICE_REVISION> <IDBANK> [SGBD]
# Exemple :
#   ./get_insee_indices.sh IRL 001515333 pgsql

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <INDICE_REVISION> <IDBANK> [SGBD]"
  exit 1
fi

INDICE_REV="$1"
IDBANK="$2"
DB_TYPE="${3:-pgsql}"

if ! command -v xmllint >/dev/null 2>&1; then
  echo "xmllint manquant. Installe-le via : sudo apt install -y libxml2-utils"
  exit 1
fi

API_URL="https://bdm.insee.fr/series/sdmx/data/SERIES_BDM/${IDBANK}?detail=full"

XML_FILE="$(mktemp)"
trap 'rm -f "$XML_FILE"' EXIT

curl -fsSL "$API_URL" -o "$XML_FILE"

OBS_LINES=$(xmllint --xpath '//*[local-name()="Obs"]' "$XML_FILE" 2>/dev/null \
  | sed 's/></>\n</g' \
  | grep '<Obs ' \
  | sed -n 's/.*TIME_PERIOD="\([^"]*\)".*OBS_VALUE="\([^"]*\)".*DATE_JO="\([^"]*\)".*/\1|\2|\3/p')

if [[ -z "$OBS_LINES" ]]; then
  echo "Aucune donnée trouvée pour ${INDICE_REV} (${IDBANK})"
  exit 1
fi

declare -A VALS
declare -A PUBS
YEARS=()

while IFS='|' read -r period value datejo; do
  [[ -z "$period" || -z "$value" ]] && continue
  if [[ "$period" =~ ^([0-9]{4})-Q([1-4])$ ]]; then
    YEAR="${BASH_REMATCH[1]}"
    TRI="${BASH_REMATCH[2]}"
    KEY="${YEAR}-${TRI}"
    VALS["$KEY"]="${value/,/.}"
    PUBS["$KEY"]="$datejo"
    YEARS+=("$YEAR")
  fi
done <<< "$OBS_LINES"

YEARS=($(printf "%s\n" "${YEARS[@]}" | sort -u))

for YEAR in "${YEARS[@]}"; do
  for TRI in 1 2 3 4; do
    KEY="${YEAR}-${TRI}"
    VAL="${VALS[$KEY]:-}"
    PUB="${PUBS[$KEY]:-}"
    [[ -z "$VAL" ]] && continue

    PREV_KEY="$((YEAR-1))-${TRI}"
    VAR="NULL"
    # HOTFIXES: avoid division by zero, inf or nan
    if [[ -n "${VALS[$PREV_KEY]:-}" ]]; then
      PREV_VAL="${VALS[$PREV_KEY]}"
      VAR=$(awk -v a="$VAL" -v b="$PREV_VAL" '
        BEGIN {
          if (b == 0) { print "0.00"; exit }
          diff = ((a - b) / b) * 100
          if (diff == "inf" || diff == "-inf" || diff != diff) { diff = 0.00 }
          printf "%.2f", diff
        }')
    fi

    case "$DB_TYPE" in
      pgsql|postgres|postgresql)
        printf "INSERT INTO ref_indice_loyer (indice_revision, annee, trimestre, valeur, variation_annee, published_at, created_at)\n"
        printf "VALUES ('%s', %s, %s, %.3f, %s, '%s', CURRENT_TIMESTAMP)\n" \
          "$INDICE_REV" "$YEAR" "$TRI" "$VAL" \
          "$( [[ "$VAR" == "NULL" ]] && echo "NULL" || echo "$VAR" )" \
          "$PUB"
        printf "ON CONFLICT (indice_revision, annee, trimestre) DO NOTHING;\n\n"
        ;;
      mariadb|mysql)
        printf "INSERT IGNORE INTO ref_indice_loyer (indice_revision, annee, trimestre, valeur, variation_annee, published_at, created_at)\n"
        printf "VALUES ('%s', %s, %s, %.3f, %s, '%s', CURRENT_TIMESTAMP);\n\n" \
          "$INDICE_REV" "$YEAR" "$TRI" "$VAL" \
          "$( [[ "$VAR" == "NULL" ]] && echo "NULL" || echo "$VAR" )" \
          "$PUB"
        ;;
      *)
        echo "Type de base de données inconnu : $DB_TYPE"
        exit 1
        ;;
    esac
  done
done
