#!/bin/bash
set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Create Distortion CIFTI average"

# -------------------------
# REQUIRED
# -------------------------
opts_AddMandatory '--input-files' 'InputFiles' 'CIFTIs separated by @' ""
opts_AddMandatory '--output' 'OutputCIFTI' 'Output file (.dscalar.nii)'
opts_AddMandatory '--group-name' 'GroupName' 'Group name'

# -------------------------
# OPTIONAL FLAGS
# -------------------------
opts_AddOptional '--no-abs' 'NoAbs' 'If set, do not take absolute value' "FALSE"
opts_AddOptional '--no-outliers' 'NoOutliers' 'Disable outlier exclusion' "FALSE"
opts_AddOptional '--keep-mean' 'KeepMean' 'Also save intermediate mean map' "FALSE"

opts_ParseArguments "$@"

# -------------------------
# BUILD INPUT LIST
# -------------------------
InputFiles=$(echo "${InputFiles}" | sed 's/@/ /g')

MERGE=""
for f in ${InputFiles}; do
    MERGE="${MERGE} -cifti ${f}"
done

# -------------------------
# OUTPUTS
# -------------------------
TMP_MEAN="${OutputCIFTI%.dscalar.nii}.mean.dscalar.nii"
ABS_FILE="${OutputCIFTI%.dscalar.nii}_abs.dscalar.nii"

# -------------------------
# STEP 1: MEAN
# -------------------------
if [[ "${NoOutliers}" == "TRUE" ]]; then
    ${Caret7_Command} -cifti-average "${TMP_MEAN}" ${MERGE}
else
    ${Caret7_Command} -cifti-average "${TMP_MEAN}" \
        -exclude-outliers 3 3 \
        ${MERGE}
fi

# optionally keep mean output
if [[ "${KeepMean}" == "TRUE" ]]; then
    cp "${TMP_MEAN}" "${OutputCIFTI%.dscalar.nii}_mean.dscalar.nii"
fi

# -------------------------
# STEP 2: TRANSFORM
# -------------------------
if [[ "${NoAbs}" == "TRUE" ]]; then

    cp "${TMP_MEAN}" "${OutputCIFTI}"

else

    ${Caret7_Command} -cifti-math 'abs(var)' \
        "${ABS_FILE}" \
        -var var "${TMP_MEAN}"

    # -------------------------
    # STEP 3: FINAL OUTPUT
    # -------------------------
    cp "${ABS_FILE}" "${OutputCIFTI}"
fi

# -------------------------
# STEP 4: DEFAULT PALETTE
# -------------------------
${Caret7_Command} -cifti-palette "${OutputCIFTI}" \
    MODE_USER_SCALE \
    "${OutputCIFTI}" \
    -pos-user 0 1 \
    -neg-user 0 -1 \
    -palette-name ROY-BIG-BL \
    -disp-pos true -disp-neg true -disp-zero false

# -------------------------
# NAME MAP
# -------------------------
${Caret7_Command} -set-map-name "${OutputCIFTI}" 1 \
    "${GroupName}_Distortion"

# -------------------------
# CLEANUP
# -------------------------
rm -f "${TMP_MEAN}" "${ABS_FILE}"