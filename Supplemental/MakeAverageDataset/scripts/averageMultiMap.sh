#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

#Example usage
#./CreateCiftiAverage.sh \
#  --input-files \
#    subj1_FA_MSMSulc.32k_fs_LR.dscalar.nii@\
#    subj2_FA_MSMSulc.32k_fs_LR.dscalar.nii@\
#    subj3_FA_MSMSulc.32k_fs_LR.dscalar.nii \
#  --output Group_FA_MSMSulc.32k_fs_LR.dscalar.nii

opts_SetScriptDescription "Create CIFTI average from explicit file list"

opts_AddMandatory '--input-files' 'InputFiles' 'CIFTI files separated by @' ""
opts_AddMandatory '--output' 'OutputCIFTI' 'Output CIFTI filename (full path)'

opts_ParseArguments "$@"

# -------------------------
# Build merge string
# -------------------------

MERGE=""

InputFiles=$(echo "${InputFiles}" | sed 's/@/ /g')

for File in ${InputFiles}; do
    if [[ ! -f "${File}" ]]; then
        log_Msg "WARNING: File not found: ${File}"
        continue
    fi

    MERGE="${MERGE} -cifti ${File}"
done

if [[ -z "${MERGE}" ]]; then
    log_Msg "ERROR: No valid input files provided"
    exit 1
fi

# -------------------------
# Run average
# -------------------------

${Caret7_Command} -cifti-average "${OutputCIFTI}" \
    -exclude-outliers 3 3 \
    ${MERGE}

log_Msg "Completed: ${OutputCIFTI}"