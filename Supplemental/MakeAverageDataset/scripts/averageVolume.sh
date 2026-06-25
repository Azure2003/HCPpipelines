#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Create average volume or merged volume"

opts_AddMandatory '--input-files' 'InputFiles' 'Volumes separated by @' ""
opts_AddMandatory '--output' 'OutputFile' 'Output NIfTI volume (.nii.gz)' ""
opts_AddOptional '--mode' 'Mode' 'ALL|AVERAGE|BOTH' 'BOTH'

opts_ParseArguments "$@"

InputFiles=$(echo "${InputFiles}" | sed 's/@/ /g')

if [[ -z "${InputFiles}" ]]; then
    echo "ERROR: no input files provided"
    exit 1
fi

case "${Mode}" in
    AVERAGE)
        fsladd "${OutputFile}" -m ${InputFiles}
        echo "Created average: ${OutputFile}"
        ;;
    ALL)
        fslmerge -t "${OutputFile}" ${InputFiles}
        echo "Created merged volume: ${OutputFile}"
        ;;
    BOTH)
        Base="${OutputFile%.nii.gz}"

        fsladd "${Base}_mean.nii.gz" -m ${InputFiles}
        fslmerge -t "${Base}_all.nii.gz" ${InputFiles}

        echo "Created:"
        echo "  ${Base}_mean.nii.gz"
        echo "  ${Base}_all.nii.gz"
        ;;
    *)
        echo "ERROR: mode must be ALL, AVERAGE, or BOTH"
        exit 1
        ;;
esac