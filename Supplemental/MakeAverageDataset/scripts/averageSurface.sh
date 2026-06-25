#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Surface average (clean wb_command wrapper)"

# -------------------------
# INPUTS
# -------------------------
opts_AddMandatory '--input-files' 'InputFiles' 'Files separated by @' ""
opts_AddMandatory '--output' 'OutputFile' 'Output surface (.surf.gii)' ""

# optional outputs
opts_AddOptional '--output-std' 'OutputStd' 'Stddev metric output (.shape.gii)' ""
opts_AddOptional '--output-uncertainty' 'OutputUncertainty' 'Uncertainty metric output (.shape.gii)' ""

opts_ParseArguments "$@"

# -------------------------
# NORMALISE INPUTS
# -------------------------
InputFiles=$(echo "${InputFiles}" | sed 's/@/ /g')

# -------------------------
# BUILD COMMAND (SAFE ARRAY STYLE)
# -------------------------
CMD=(wb_command -surface-average "${OutputFile}")

# optional blocks (must come BEFORE -surf)
if [[ -n "${OutputStd:-}" ]]; then
    CMD+=(-stddev "${OutputStd}")
fi

if [[ -n "${OutputUncertainty:-}" ]]; then
    CMD+=(-uncertainty "${OutputUncertainty}")
fi

# -------------------------
# ADD SURFACES
# -------------------------
for f in ${InputFiles}; do
    CMD+=(-surf "${f}")
done

# -------------------------
# EXECUTE (NO eval)
# -------------------------
"${CMD[@]}"

if [[ -n "${OutputUncertainty:-}" ]]; then
    wb_command -metric-palette ${OutputUncertainty} MODE_AUTO_SCALE_PERCENTAGE \
	-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
fi

if [[ -n "${OutputStd:-}" ]]; then
    wb_command -metric-palette ${OutputStd} MODE_AUTO_SCALE_PERCENTAGE \
	-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

fi
echo "Done: ${OutputFile}"