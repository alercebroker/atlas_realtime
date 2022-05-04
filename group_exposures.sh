#!/bin/bash
#
# For a given telescope and camera and a given night, group the exposures based on the corresponding tessellation.
cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1
# Import utilities
source utils.sh

#if [ "$#" -ne 2 ]; then
#    echo "Usage: $0 telescope+camera_ID night_number"
#    echo "Script needs a telescope + camera id (e.g. 02a) and an ATLAS style night number (e.g. 58XXX)."
#    exit 1
#fi

## Global variables ##
declare -A teles=( ["01a"]="-10" ["02a"]="-10" ["03a"]="+1" ["04a"]="-5")
default_telescope="01a"
telescope=${1:-$default_telescope}
current_nite=$(nn $(mjd) "${teles[$telescope]}")
nite=${2:-$current_nite}

# Path to log file
log_path="/data/atlas-local/red"
log_file="${log_path}/${telescope}/${nite}/${telescope}${nite}.log"

ATLAS_01_LONG_DEG="-155.5761"
ATLAS_01_LAT_DEG="19.5361"
ATLAS_01_ELEV_M="3429.3000"

ATLAS_02_LONG_DEG="-156.2570"
ATLAS_02_LAT_DEG="20.7075"
ATLAS_02_ELEV_M="3062.6580"

ATLAS_03_LONG_DEG="20.8107"
ATLAS_03_LAT_DEG="-32.3802"
ATLAS_03_ELEV_M="1764.0000"

ATLAS_04_LONG_DEG="-70.7650"
ATLAS_04_LAT_DEG="-30.4710"
ATLAS_04_ELEV_M="1609.6000"

ATLAS_SITE_LONG_DEG="ATLAS_${telescope:0:2}_LONG_DEG"
ATLAS_SITE_LAT_DEG="ATLAS_${telescope:0:2}_LAT_DEG"
ATLAS_SITE_ELEV_M="ATLAS_${telescope:0:2}_ELEV_M"

eval $(skyangle lng="${!ATLAS_SITE_LONG_DEG}" lat="${!ATLAS_SITE_LAT_DEG}" elev="${!ATLAS_SITE_ELEV_M}" mjd="$nite" az=90 alt=89)
#srise

# Associative array to hold the exposure's groups
declare -A groups

#######################################
# Validate user input.
# Globals:
#   telescope
#   nite
#   log_path
#   log_file
# Errors:
#   exit 1 if the inputs is invalid
#######################################
validate_input () {
  if [ ${telescope} != "01a" ] && [ ${telescope} != "02a" ] && [ ${telescope} != "03a" ] && [ ${telescope} != "04a" ]; then
    err "Telescope has to be either 01a or 02a."
    exit 1
  fi

  # If nite and telescope are within expectations check whether the night is there and can be executed.
  validate_directory ${log_path}/${telescope}/${nite}

  # If the nite's directory is there and can be opened, check whether a log file was produced and can be read
  validate_file $log_file
}
 
#######################################
# Get the pointing and exposure data.
# Globals:
#   log_file
# Arguments:
#   Log file line
# Outputs:
#   Writes observation and tessellation to stdout
#######################################
grab_data () {
  local current_line=$1
  local exposure_pointing="$( sed "${current_line}q;d" ${log_file} | awk '{print $1, $17, $2}' )"
  echo $exposure_pointing
}

#######################################
# Function to process the data gotten from the grab function.
# Globals:
#   groups
#   telescope
#   nite
# Arguments:
#   Observation and tessellation separete by space
#######################################
process_data () {
  local data=$1
  set -- $data
  local exposure=$1
  local tessellation=$2
#  local tesse_time=$3
  # Grab value and put it on the map
  local current_array=(${groups[$tessellation]})
  # Check whether the key tessellation is already in the map, if not, add it and then add the exposure
  # Ignore preflight and twiflat values
  if [ "$tessellation" != "preflight" ] && [ "$tessellation" != "twiflat" ] && [ "$tessellation" != "QC" ] ; then
    current_array+=("$exposure")
    groups[$tessellation]="${current_array[@]}"
    # TODO: reject if exposure already in the list
    if [ ${#current_array[@]} -eq 4 ]; then
#      echo "$tessellation ${groups[$tessellation]}"  >> "${telescope}${nite}_img.groups"
#      echo "$tessellation $tesse_time" >> "${telescope}${nite}_img.groups"
      # Call create_objects, next step in the pipeline
      local tolerance="1.9"
      out "Processing tessellation $tessellation "${groups[$tessellation]}" $tolerance"
      ./create_objects.sh $tessellation "${groups[$tessellation]}" $tolerance &
    fi
  fi
}

# Execute the main functions
out "wait for file ${log_file}"
wait_for_file ${log_file} "28800"
validate_input
out "following file until $srise"
follow_file grab_data process_data "$srise"
