#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "T1w divided by T2w"

# -------------------------
# INPUTS
# -------------------------
opts_AddMandatory '--T1w' '.nii.gz' 'T1w file' ""
opts_AddMandatory '--T2w' '.nii.gz' 'T2w file' ""
opts_AddMandatory '--output' 'OutputFile' 'Output volume (.nii.gz)' ""
wb_command -volume-math "clamp((T1w / T2w), 0, 100)" ${output} \
	-var T1w ${T1w} \
	-var T2w ${T2w} \
	-fixnan 0
wb_command -volume-palette ${output} \
	MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style

opts_ParseArguments "$@"