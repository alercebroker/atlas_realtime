#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 telescope+camera_ID night_number"
    echo "Script needs a telescope + camera id (e.g. 02a) and an ATLAS style night number (e.g. 58XXX)."
    exit
fi

telescope=$1 ; nite=$2

# Path to log file
log_path="/atlas/red"
log_file="${log_path}/${telescope}/${nite}/${telescope}${nite}.log"

# Validate the input
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

# if the night directory is there and can be opened check whether a log file was produced and can be read

if [ ! -f "$log_file" ] ; then
  echo "Log file ${log_file} does not exist."
  exit
fi

if [ ! -r "$log_file" ] ; then
  echo "Log file ${log_file} is unreadable"
  exit
fi

# Create map (associative array)
declare -A groups

# Listen to the log file for new lines, starting from the beginning
last_processed_line=0
while :
do
  # Count lines in the log file
  line_count=$(cat "$log_file" | wc -l)
  # Get the difference to see if there is something new that needs to be processed
  difference="$(( line_count - last_processed_line ))"
  # If there is something
  if [[ $difference -gt "0" ]]
  then
    # Create a process for each of those lines, this part should guarantee that
    # every line is processed (in order might be better)
    while [[ $last_processed_line -lt $line_count ]]
    do
      #echo "There are unprocessed lines"
      current_line="$((last_processed_line+1))"
      # Get the exposure and tessellation of the current line
      line_text="$( sed "${current_line}q;d" ${log_file} | awk '{print $1, $17}' )"
      set -- $line_text
      exposure=$1
      tessellation=$2
      echo "exposure+tessellation $exposure $tessellation"
      # Grab value and put it on the map
      current_array=(${groups[$tessellation]})
      # Check if the key tessellation is already in the map, if not, add it
      # then add the exposure.
      current_array+=("$exposure")
      groups[$tessellation]="${current_array[@]}"
      # TODO: reject if exposure already in the list
      if [ ${#current_array[@]} -eq 4 ]
      then
        echo "$tessellation ${groups[$tessellation]}" >> "${telescope}${nite}_img.groups"
      fi
      # Increment number of processed lines
      last_processed_line="$((last_processed_line+1))"
    done
  fi
done

# check folder for changes
# add file to the map
# todo: improve format, check that the log file exists and wait if not,
# stop when there are 4 exposures, call the next script
# put everything in functions and call the functions from a different script
# Log file in /atlas/red/02a/58819/02a58819.log
# The "Object" column contains the observations (preflight and twiflat values should be ignored.)
