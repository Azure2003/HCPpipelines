#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Generate inflated and very inflated surfaces"

# -------------------------
# INPUTS (PURE)
# -------------------------
opts_AddMandatory '--input-surface' 'InputSurface' 'Midthickness surface (.surf.gii)' ""
opts_AddMandatory '--output-inflated' 'OutputInflated' 'Inflated surface output' ""
opts_AddMandatory '--output-very-inflated' 'OutputVeryInflated' 'Very inflated surface output' ""
opts_AddMandatory '--scale' 'Scale' 'Inflation iteration scale' ""

opts_ParseArguments "$@"

# -------------------------
# VALIDATION
# -------------------------
if [[ ! -f "${InputSurface}" ]]; then
    echo "ERROR: input surface not found: ${InputSurface}"
    exit 1
fi

# -------------------------
# RUN INFLATION
# -------------------------
wb_command -surface-generate-inflated \
    "${InputSurface}" \
    "${OutputInflated}" \
    "${OutputVeryInflated}" \
    -iterations-scale "${Scale}"

echo "Done inflation:"
echo "  inflated:      ${OutputInflated}"
echo "  very inflated: ${OutputVeryInflated}"