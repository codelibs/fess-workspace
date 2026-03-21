#!/usr/bin/env bash
set -euo pipefail

# i18n Sync Script for Fess
# Finds keys present in base properties files but missing in language variants,
# and appends them with the English (base) value as a placeholder.

RESOURCE_DIR="${1:-src/main/resources}"

if [[ ! -d "$RESOURCE_DIR" ]]; then
    echo "Error: Resource directory not found: $RESOURCE_DIR" >&2
    exit 1
fi

LANGUAGES=(de en es fr hi id it ja ko nl pl pt_BR ru tr zh_CN zh_TW)
BASE_FILES=(fess_label fess_message)

TOTAL_ADDED=0
SUMMARY=""

# Extract keys from a properties file (ignoring comments and blank lines)
extract_keys() {
    local file="$1"
    grep -v '^\s*#' "$file" | grep -v '^\s*$' | cut -d'=' -f1 | sort
}

# Ensure file ends with a newline (prevents key concatenation when appending)
ensure_trailing_newline() {
    local file="$1"
    if [[ -s "$file" ]] && [[ "$(tail -c1 "$file" | wc -l)" -eq 0 ]]; then
        echo "" >> "$file"
    fi
}

for base_name in "${BASE_FILES[@]}"; do
    base_file="$RESOURCE_DIR/${base_name}.properties"

    if [[ ! -f "$base_file" ]]; then
        echo "Warning: Base file not found: $base_file" >&2
        continue
    fi

    base_keys=$(extract_keys "$base_file")

    for lang in "${LANGUAGES[@]}"; do
        variant_file="$RESOURCE_DIR/${base_name}_${lang}.properties"

        if [[ ! -f "$variant_file" ]]; then
            echo "Warning: Variant file not found: $variant_file" >&2
            continue
        fi

        variant_keys=$(extract_keys "$variant_file")

        # Find keys in base but not in variant
        missing_keys=$(comm -23 <(echo "$base_keys") <(echo "$variant_keys"))

        if [[ -z "$missing_keys" ]]; then
            continue
        fi

        # Ensure file has trailing newline before appending
        ensure_trailing_newline "$variant_file"

        count=0
        # Append missing keys with their base (English) values
        while IFS= read -r key; do
            # Use grep -F for fixed-string match and cut to extract value after first '='
            value=$(grep -Fm1 "${key}=" "$base_file" | cut -d'=' -f2-)
            echo "${key}=${value}" >> "$variant_file"
            count=$((count + 1))
        done <<< "$missing_keys"

        TOTAL_ADDED=$((TOTAL_ADDED + count))
        SUMMARY="${SUMMARY}$(printf "%-40s %s\n" "${base_name}_${lang}.properties" "+${count} keys")\n"
    done
done

echo "=== i18n Sync Summary ==="
echo ""
if [[ -n "$SUMMARY" ]]; then
    printf "%-40s %s\n" "File" "Keys Added"
    printf "%-40s %s\n" "----" "----------"
    echo -e "$SUMMARY"
else
    echo "All variant files are in sync. No missing keys found."
fi
echo "Total keys added: $TOTAL_ADDED"

if [[ $TOTAL_ADDED -gt 0 ]]; then
    echo ""
    echo "NOTE: Added keys use English values as placeholders."
    echo "      Please review and translate the added entries."
fi
