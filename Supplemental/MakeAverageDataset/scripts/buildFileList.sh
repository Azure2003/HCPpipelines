#!/bin/bash
set -eu
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/log.shlib" "$@"


opts_SetScriptDescription "Template-based file list builder (no domain logic)"

# -------------------------
# INPUTS
# -------------------------
opts_AddMandatory '--template' 'Template' 'File path template with {variables}' ""
opts_AddMandatory '--subjects' 'Subjects' 'Subjects separated by @' ""

opts_AddOptional '--study' 'Study' 'Study path' ""
opts_AddOptional '--folder' 'Folder' 'Folder name' ""
opts_AddOptional '--surface' 'Surface' 'Surface type' ""
opts_AddOptional '--reg' 'RegSTRING' 'Registration string' ""
opts_AddOptional '--mesh' 'Mesh' 'Mesh resolution' ""

opts_ParseArguments "$@"

Subjects=$(echo "${Subjects}" | sed 's/@/ /g')

LIST=""

# -------------------------
# EXPAND TEMPLATE PER SUBJECT
# -------------------------
for s in ${Subjects}; do
    FILE="${Template}"

    FILE=${FILE//\{subject\}/$s}
    FILE=${FILE//\{study\}/${Study:-}}
    FILE=${FILE//\{folder\}/${Folder:-}}
    FILE=${FILE//\{surface\}/${Surface:-}}
    FILE=${FILE//\{reg\}/${RegSTRING:-}}
    FILE=${FILE//\{mesh\}/${Mesh:-}}

    LIST="${LIST}@${FILE}"
done

LIST=${LIST#@}

echo "${LIST}"