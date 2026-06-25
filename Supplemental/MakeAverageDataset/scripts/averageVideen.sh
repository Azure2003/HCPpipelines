#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Create Videen CIFTI average"

opts_AddMandatory '--input-files' 'InputFiles' 'CIFTIs separated by @' ""
opts_AddMandatory '--output' 'OutputCIFTI' 'Output file'
opts_AddMandatory '--group-name' 'GroupName' 'Group name'

opts_ParseArguments "$@"

InputFiles=$(echo "${InputFiles}" | sed 's/@/ /g')

MERGE=""
for f in ${InputFiles}; do
    MERGE="${MERGE} -cifti ${f}"
done

${Caret7_Command} -cifti-average "${OutputCIFTI}" \
    -exclude-outliers 3 3 \
    ${MERGE}

${Caret7_Command} -cifti-palette "${OutputCIFTI}" \
    MODE_AUTO_SCALE_PERCENTAGE \
    "${OutputCIFTI}" \
    -pos-percent 4 96 \
    -palette-name videen_style \
    -disp-pos true -disp-neg false -disp-zero false

${Caret7_Command} -set-map-name "${OutputCIFTI}" 1 \
    "${GroupName}_Videen"