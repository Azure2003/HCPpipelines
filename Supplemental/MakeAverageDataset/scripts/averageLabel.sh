#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "merge and/or mode-reduce from explicit file list for labeled volume"

opts_AddMandatory '--input-files' 'InputFiles' 'Files separated by @' ""
opts_AddMandatory '--output' 'OutputFile' 'Base output name (.nii.gz)' ""
opts_AddOptional '--freesurferlabels' 'FreeSurferLabels' 'Label LUT' ""
opts_AddOptional '--mode' 'Mode' 'ALL|AVERAGE|BOTH' "" 'BOTH'

opts_ParseArguments "$@"
echo $Mode
# -------------------------
# CLEANUP TRAP
# -------------------------
TMP_FILES=()
cleanup() {
    rm -f "${TMP_FILES[@]}" 2>/dev/null || true
}
trap cleanup EXIT

# -------------------------
# INPUT PARSING
# -------------------------
IFS='@' read -r -a FILES <<< "${InputFiles}"

MERGE_ARR=()
for f in "${FILES[@]}"; do
    if [[ -e "$f" ]]; then
        MERGE_ARR+=("$f")
    else
        log_Msg "WARNING missing file: $f"
    fi
done

if [[ ${#MERGE_ARR[@]} -eq 0 ]]; then
    log_Msg "ERROR: no valid input files"
    exit 1
fi

# -------------------------
# TRUE TEMP FILES
# -------------------------
TMP_ALL=$(mktemp --suffix=_ALL.nii.gz)
TMP_AVG=$(mktemp --suffix=_AVG.nii.gz)

TMP_FILES+=("$TMP_ALL" "$TMP_AVG")

# -------------------------
# MODE FLAGS
# -------------------------
DO_ALL=0
DO_AVG=0

case "${Mode}" in
    ALL) DO_ALL=1 ;;
    AVERAGE) DO_AVG=1 ;;
    BOTH) DO_ALL=1; DO_AVG=1 ;;
    *) log_Msg "ERROR: invalid mode ${Mode}"; exit 1 ;;
esac

# -------------------------
# 1. MERGE
# -------------------------
fslmerge -t "${TMP_ALL}" "${MERGE_ARR[@]}"

wb_command -volume-label-import \
    "${TMP_ALL}" \
    "${FreeSurferLabels}" \
    "${TMP_ALL}" \
    -drop-unused-labels

# -------------------------
# 2. MODE REDUCE
# -------------------------
if [[ ${DO_AVG} -eq 1 ]]; then
    wb_command -volume-reduce \
        "${TMP_ALL}" \
        MODE \
        "${TMP_AVG}"

    wb_command -volume-label-import \
        "${TMP_AVG}" \
        "${FreeSurferLabels}" \
        "${TMP_AVG}" \
        -drop-unused-labels
fi

# -------------------------
# 3. OUTPUT
# -------------------------
BASE="${OutputFile%.nii.gz}"

if [[ ${DO_ALL} -eq 1 && ${DO_AVG} -eq 1 ]]; then
    mv "${TMP_ALL}" "${BASE}_ALL.nii.gz"
    mv "${TMP_AVG}" "${BASE}_AVG.nii.gz"

elif [[ ${DO_ALL} -eq 1 ]]; then
    mv "${TMP_ALL}" "${OutputFile}"

elif [[ ${DO_AVG} -eq 1 ]]; then
    mv "${TMP_AVG}" "${OutputFile}"
fi

echo "Done"