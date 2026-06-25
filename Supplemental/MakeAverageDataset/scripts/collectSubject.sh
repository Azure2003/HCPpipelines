#!/bin/bash
set -eu
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
opts_SetScriptDescription "Collect subject IDs from directory"

# -------------------------
# INPUTS
# -------------------------
opts_AddMandatory '--root' 'RootDir' 'Directory containing subject folders' ""
opts_AddOptional '--pattern' 'Pattern' 'Regex pattern to filter subject names (default: .*)' ".*"
opts_ParseArguments "$@"

Pattern=${Pattern:-".*"}

# -------------------------
# COLLECT SUBJECTS
# -------------------------
SUBJECTS=""
for d in "${RootDir}"/*/; do
    [[ -d "${d}" ]] || continue
    subj=$(basename "${d}")
    # Filter using regex
    [[ "${subj}" =~ ${Pattern} ]] || continue
    SUBJECTS="${SUBJECTS}@${subj}"
done
SUBJECTS=${SUBJECTS#@}
echo "${SUBJECTS}"