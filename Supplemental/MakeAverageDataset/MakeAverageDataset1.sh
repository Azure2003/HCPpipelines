#!/bin/bash
set -e

FILE="$1"
PARSER="${HCPPIPEDIR}/Supplemental/MakeAverageDataset/scripts/parser.py"
COLLECT="${HCPPIPEDIR}/Supplemental/MakeAverageDataset/scripts/collectSubject.sh"
TEMPLATE_SCRIPT="${HCPPIPEDIR}/Supplemental/MakeAverageDataset/scripts/buildFileList.sh"


echo "[DEBUG] Input file: $FILE"
echo "[DEBUG] Parser: $PARSER"

# Call Python and capture output
JOBS=$(python3 "$PARSER" "$FILE")

echo "[DEBUG] Raw jobs output:"
echo "$JOBS"
echo "---"

while IFS= read -r -d '' BLOCK; do
    [ -z "$BLOCK" ] && continue

    echo "[DEBUG] Processing block:"
    echo "$BLOCK"
    echo "---"

    # Parse key=value lines into associative array
    declare -A JOB
    while IFS='=' read -r KEY VAL; do
        [ -z "$KEY" ] && continue
        JOB["$KEY"]="$VAL"
    done <<< "$BLOCK"

    echo "[DEBUG] Parsed job keys: ${!JOB[@]}"

    if [ -n "${JOB[subject_pattern]+x}" ]; then
        export log_Level=ERROR

        echo "[DEBUG] Subject block detected — pattern=${JOB[subject_pattern]} root=${JOB[subject_root]}"

        SUBJECTS=$("$COLLECT" \
            --pattern="${JOB[subject_pattern]}" \
            --root="${JOB[subject_root]}")

        echo "[DEBUG] Collected subjects: $SUBJECTS"

        unset JOB[subject_pattern]
        unset JOB[subject_root]

        for KEY in "${!JOB[@]}"; do
            VAL="${JOB[$KEY]}"
            case "$VAL" in
                *"{subject}"*)
                    echo "[DEBUG] Resolving {subject} in $KEY=$VAL"
                    RESULT=$("$TEMPLATE_SCRIPT" \
                        --template="$VAL" \
                        --subjects="$SUBJECTS")
                    echo "[DEBUG] $KEY resolved to: $RESULT"
                    JOB["$KEY"]="$RESULT"
                    ;;
            esac
        done
    else
        echo "[DEBUG] No subject block — skipping collect/template steps"
    fi

    # Call average{Type}.sh with all remaining keys as --key=value args
    TYPE="${JOB[type]}"
    AVERAGE_SCRIPT="${HCPPIPEDIR}/Supplemental/MakeAverageDataset/scripts/average${TYPE^}.sh"

    ARGS=()
    for KEY in "${!JOB[@]}"; do
        [ "$KEY" = "type" ] && continue
        ARGS+=("--${KEY}=${JOB[$KEY]}")
    done
    export log_Level=INFO

    echo "[DEBUG] Calling: $AVERAGE_SCRIPT ${ARGS[@]}"
    "$AVERAGE_SCRIPT" "${ARGS[@]}"
    echo "[DEBUG] $AVERAGE_SCRIPT completed"

    unset JOB

done < <(printf '%s\0' "$JOBS" | awk 'BEGIN{RS=""; ORS="\0"} {print}')

echo "[DEBUG] All jobs complete"