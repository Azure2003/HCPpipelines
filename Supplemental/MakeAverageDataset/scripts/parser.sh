#!/bin/bash
set -eu

FILE="$1"

# -------------------------
# GLOBAL STATE
# -------------------------
declare -A GLOBAL_VARS=()

declare -A BLOCK_CONTEXT=()
declare -A BLOCK_VARS=()
declare -A JOB_VARS=()

JOB_TEMPLATE=""
CURRENT_BLOCK=""
SCOPE="NONE"

# -------------------------
# HELPERS
# -------------------------
trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# -------------------------
# EXPAND SCALARS
# -------------------------
expand() {
    local str="$1"
    declare -n MAP="$2"

    for k in "${!MAP[@]}"; do
        str="${str//\{$k\}/${MAP[$k]}}"
    done

    echo "$str"
}

# -------------------------
# MERGE VARS
# -------------------------
declare -A MERGED=()

merge_vars() {
    MERGED=()

    for k in "${!GLOBAL_VARS[@]}"; do
        MERGED["$k"]="${GLOBAL_VARS[$k]}"
    done

    for k in "${!BLOCK_VARS[@]}"; do
        MERGED["$k"]="${BLOCK_VARS[$k]}"
    done

    for k in "${!JOB_VARS[@]}"; do
        MERGED["$k"]="${JOB_VARS[$k]}"
    done
}

# -------------------------
# CARTESIAN SUPPORT
# -------------------------
declare -A LISTS=()

build_lists() {
    LISTS=()

    for k in "${!MERGED[@]}"; do
        if [[ "${MERGED[$k]}" == *"@"* ]]; then
            IFS='@' read -r -a arr <<< "${MERGED[$k]}"
            LISTS["$k"]="${arr[*]}"
        else
            LISTS["$k"]="${MERGED[$k]}"
        fi
    done
}

cartesian() {
    local items=("")
    local first=1

    for k in "${!LISTS[@]}"; do
        IFS=' ' read -r -a vals <<< "${LISTS[$k]}"

        if [[ $first -eq 1 ]]; then
            for v in "${vals[@]}"; do
                items+=("$k=$v")
            done
            items=("${items[@]:1}")
            first=0
            continue
        fi

        new=()
        for item in "${items[@]}"; do
            for v in "${vals[@]}"; do
                new+=("${item}|$k=$v")
            done
        done
        items=("${new[@]}")
    done

    printf "%s\n" "${items[@]}"
}

# -------------------------
# EMIT JOB
# -------------------------
emit() {

    [[ -z "$JOB_TEMPLATE" ]] && return 0

    merge_vars

    build_lists
    combos=$(cartesian)

    template=$(expand "$JOB_TEMPLATE" BLOCK_CONTEXT)

    while read -r combo; do
        out="$template"

        IFS='|' read -ra pairs <<< "$combo"
        for p in "${pairs[@]}"; do
            key="${p%%=*}"
            val="${p#*=}"
            out="${out//\{$key\}/$val}"
        done

        echo "$out"
    done <<< "$combos"
}

reset_job() {
    JOB_VARS=()
    JOB_TEMPLATE=""
}

# -------------------------
# PARSER
# -------------------------
while IFS= read -r raw || [[ -n "$raw" ]]; do

    [[ -z "${raw// /}" ]] && continue
    line="$(trim "$raw")"

    # -------------------------
    # BLOCK DETECTION (DYNAMIC)
    # -------------------------
    if [[ "$line" =~ ^([A-Za-z0-9_]+):$ ]]; then

        # flush previous job
        emit
        reset_job

        CURRENT_BLOCK="${BASH_REMATCH[1]}"
        SCOPE="BLOCK"
        BLOCK_CONTEXT=()
        BLOCK_VARS=()
        continue
    fi

    # -------------------------
    # SCOPE SWITCHES
    # -------------------------
    if [[ "$line" == vars:* ]]; then
        SCOPE="GLOBAL"
        continue
    fi

    if [[ "$line" == context:* ]]; then
        SCOPE="CONTEXT"
        continue
    fi

    if [[ "$line" == jobs:* ]]; then
        SCOPE="JOBS"
        continue
    fi

    # -------------------------
    # KEY: VALUE
    # -------------------------
    if [[ "$line" =~ ^([A-Za-z0-9_]+):[[:space:]]*(.*)$ ]]; then

        key="${BASH_REMATCH[1],,}"
        val="${BASH_REMATCH[2]}"

        case "$SCOPE" in
            GLOBAL)
                GLOBAL_VARS["$key"]="$val"
                ;;
            BLOCK)
                BLOCK_VARS["$key"]="$val"
                ;;
            CONTEXT)
                BLOCK_CONTEXT["$key"]="$val"
                ;;
            JOBS)
                if [[ "$key" == "template" ]]; then
                    JOB_TEMPLATE="$val"
                else
                    JOB_VARS["$key"]="$val"
                fi
                ;;
        esac
    fi

done < "$FILE"

emit