#!/usr/bin/env bash
set -euo pipefail

# fetch.sh
# Auteur : Julien JEAN
# Lance get_insee_indices.sh pour IRL, ILC et ILAT
# Usage :
#   ./fetch.sh [SGBD]
# Exemple :
#   ./fetch.sh mariadb
#   ./fetch.sh pgsql

DB_TYPE="${1:-pgsql}"
SCRIPT_PATH="./get_insee_indices.sh"
EXPORT_DIR="./export"

if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "Le script get_insee_indices.sh est introuvable ou non exécutable."
  exit 1
fi

mkdir -p "$EXPORT_DIR"

declare -A INDICES=(
  [IRL]="001515333"        # France métropolitaine
  [IRL-CORSE]="010760507"  # Collectivité de Corse
  [IRL-DOM]="010760509"    # Collectivités d’Outre-mer (régies par l’article 73)
  [ILC]="001532540"        # Loyers commerciaux
  [ILAT]="001532541"       # Loyers activités tertiaires
)

for CODE in "${!INDICES[@]}"; do
  IDBANK="${INDICES[$CODE]}"
  OUT_FILE="$EXPORT_DIR/insert_${CODE,,}.sql"
  "$SCRIPT_PATH" "$CODE" "$IDBANK" "$DB_TYPE" > "$OUT_FILE" || {
    echo "Erreur lors de la récupération de $CODE"
    continue
  }
  if [[ -s "$OUT_FILE" ]]; then
    echo "Fichier généré : $OUT_FILE"
  else
    echo "Aucun contenu généré pour $CODE"
  fi
done

echo "Terminé. Fichiers SQL dans $EXPORT_DIR"
