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
default_telescope="01a"
current_nite=$(( ( $(date +%s) / 86400 ) + 40587 ))
telescope=${1:-$default_telescope}
nite=${2:-$current_nite}
# Path to log file
log_path="/atlas/red"
log_file="${log_path}/${telescope}/${nite}/${telescope}${nite}.log"
# Associative array to hold the exposure's groups
#declare -A groups

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
  if [ ${telescope} != "01a" ] && [ ${telescope} != "02a" ]; then
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
  # Ignore preflight, twiflat and header values
  if [ "$tessellation" != "preflight" ] && [ "$tessellation" != "twiflat" ] && [ "$tessellation" != "QC" ] ; then
    local tolerance="1.9"
    out "Processing exposure $exposure"
    ./create_objects.sh $tessellation $exposure $tolerance
  fi
}

# Execute the main functions
wait_for_file ${log_file} 30
validate_input
follow_file grab_data process_data
