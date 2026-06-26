set -eu

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Copy Files"
opts_AddMandatory '--metricleft' 'MetricLeft' '' ""
opts_AddMandatory '--metricright' 'MetricRight' '' ""
opts_AddMandatory '--roileft' 'ROILeft' '' ""
opts_AddMandatory '--roiright' 'ROIRight' '' ""
opts_AddMandatory '--output' 'OutputFiles' '' ""
opts_AddMandatory '--deleteFiles' 'DeleteFiles' '' ""
opts_ParseArguments "$@"

PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
wb_command -cifti-create-dense-scalar ${OutputFiles} \
    -left-metric ${MetricLeft} \
    -roi-left ${ROILeft} \
	-right-metric ${MetricRight} \
	-roi-right ${ROIRight}

wb_command -set-map-name ${OutputFiles} 1 ${GroupAverageName}_${Map}
wb_command -cifti-palette ${OutputFiles} ${PaletteStringOne} ${OutputFiles} ${PaletteStringTwo}

if [[ "${DeleteFiles}" == "true" ]]; then
    rm ${MetricLeft} ${MetricRight}
fi

