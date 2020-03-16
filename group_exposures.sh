#!/bin/bash
#
# For a given telescope and camera and a given night, group the exposures based on the corresponding tessellation.

# Import utilities
. ./utils.sh --source-only

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 telescope+camera_ID night_number"
    echo "Script needs a telescope + camera id (e.g. 02a) and an ATLAS style night number (e.g. 58XXX)."
    exit
fi

telescope=$1 ; nite=$2

## Global variables ##
# Path to log file
log_path="/atlas/red"
log_file="${log_path}/${telescope}/${nite}/${telescope}${nite}.log"
# Associative array to hold the exposure's groups
declare -A groups

# Validate user input
validate_input () {
  # Check the first and last nights available for the requested telescope
  nites=$(ls -1 ${log_path}/${telescope}/ | wc | awk '{print $1}')
  nnf=$(ls ${log_path}/${telescope}/ | awk 'NR==1{print substr($0,1,5)}') # First nite in ATLAS database
  nnl=$(ls ${log_path}/${telescope}/ | awk -v fin=${nites} 'NR==fin{print substr($0,1,5)}') # Last nite in ATLAS database

  if [ ${telescope} != "01a" ] && [ ${telescope} != "02a" ] ;  then
    echo "Telescope has to be either 01a or 02a."
    exit
  fi

  if [ ${nite} -gt ${nnl} ] ; then
    echo "Last nite of telescope ${telescope} in reduced directory is ${nnl}"
    exit
  fi

  if [ ${nite} -lt ${nnf} ] ; then
    echo "First nite of telescope ${telescope} in reduced directory is ${nnf}"
    exit
  fi

  # If nite and telescope are within expectations check whether the night is there and can be executed.
  if [ ! -d "${log_path}/${telescope}/${nite}/" ] ; then
    echo "Directory ${log_path}/${telescope}/ does not exist."
    exit
  fi

  if [ ! -x "${log_path}/${telescope}/${nite}/" ] ; then
    echo "Directory ${log_path}/${telescope}/ is not executable."
    exit
  fi

  # If the nite's directory is there and can be opened, check whether a log file was produced and can be read
  validate_file $log_file "logfile"
}

# Get the pointing and exposure data
# Parameter: $1, current line
grab_data () {
  local current_line=$1
  exposure_pointing="$( sed "${current_line}q;d" ${log_file} | awk '{print $1, $17}' )"
  echo $exposure_pointing
}

# Function to process the data gotten from the grab function
process_data () {
  data=$1
  set -- $data
  exposure=$1
  tessellation=$2
  # Grab value and put it on the map
  current_array=(${groups[$tessellation]})
  # Check whether the key tessellation is already in the map, if not, add it and then add the exposure
  # Ignore preflight and twiflat values
  if [ "$tessellation" != "preflight" ] && [ "$tessellation" != "twiflat" ]
  then
    current_array+=("$exposure")
    groups[$tessellation]="${current_array[@]}"
    # TODO: reject if exposure already in the list
    if [ ${#current_array[@]} -eq 4 ]
    then
      echo "$tessellation ${groups[$tessellation]}" >> "${telescope}${nite}_img.groups"
      # Call create_objects, next step in the pipeline
      tolerance="1.9"
      #./create_objects.sh $tessellation "${telescope}${nite}_img.groups" $tolerance &
    fi
  fi
}

# Execute the main functions
validate_input
follow_file grab_data process_data

# check folder for changes
# The "Object" column contains the observations (preflight and twiflat values should be ignored.)
# remove the entry from the map
# headers shouldn't be captured
