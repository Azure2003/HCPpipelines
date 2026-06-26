set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Copy Files"
opts_AddMandatory '--input' 'InputFiles' '' ""
opts_AddMandatory '--output' 'OutputFiles' '' ""
opts_ParseArguments "$@"

cp ${InputFiles} ${OutputFiles}




