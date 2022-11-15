#!/bin/bash
#
# The functions in this file should be imported using this command: source utils.sh

#######################################
# Follow a file while being written, get data from it and process this data.
# Globals:
#   log_file
# Arguments:
#   function to grab the data
#   function to process the data
#######################################
follow_file () {
  # Function to grab data from each line
  local grab_function=$1
  # Function to process the data
  local process_function=$2
  # Listen to the log file for new lines, starting from the beginning
  local last_processed_line=0

  local srise=$3
  while :
  do
    # Count lines in the log file
    local line_count=$(cat "$log_file" | wc -l)
    # Get the difference to see if there is something new that needs to be processed
    local difference="$(( line_count - last_processed_line ))"
    # If there is something
    if [[ $difference -gt "0" ]]; then
      # TODO: Create a process for each of those lines, this part should guarantee that every line is processed (in order might be better)
      while [[ $last_processed_line -lt $line_count ]]; do
        #echo "There are unprocessed lines"
        local current_line="$((last_processed_line+1))"
        # Get the exposure and tessellation of the current line
        read -r -a data <<< $($grab_function "$current_line")
        $process_function "${data[*]}"
        # Increment number of processed lines
        last_processed_line="$((last_processed_line+1))"
        mjdtime_day=$(echo "${data[2]}")
        time_read=$(date +%s.%N)
      done
    else
      time_now=$(date +%s.%N)
      elapsed_day=$(awk -v tn="${time_now}" -v tr="${time_read}" -v td="${mjdtime_day}" -v sr="${srise}" 'BEGIN {if((tn - tr)/86400 + td > sr ) print 1; else print 0;}')
      if [[ $elapsed_day -gt 0 ]]; then
        awk '{print fin (($1-$2)/86400)+$3,$4}' <<< "${time_now} ${time_read} ${mjdtime_day} ${srise}"
        exit 0
      fi
    fi
  done
}

#######################################
# Check that a file exists and is readable.
# Arguments:
#   file to check
# Errors:
#   exit 1 if the Argument does not exists or is not readable
#######################################
validate_file () {
  local log_file=$1
  if [ ! -f "$log_file" ]; then
    err "File $log_file does not exist."
    exit 1
  fi

  if [ ! -r "$log_file" ]; then
    err "File $log_file is unreadable."
    exit 1
  fi
}

#######################################
# Wait for the file to be created.
# Arguments:
#   file to check
#   frequence to check
#######################################
wait_for_file () {
  local file=$1
  local time=$2
  while [ ! -f $file ]; do
    sleep 1
    ((time=time - 1))
    if [[ $time -le 0 ]]; then
       break
    fi
  done
  out "Waiting for the file $file finished."
}

#######################################
# Check that a directory exists and is executable.
# Arguments:
#   directory to check
# Errors:
#   exit 1 if the Argument does not exists or is not executable
#######################################
validate_directory () {
  local log_dir=$1
  if [ ! -d "$log_dir" ]; then
    err "Directory $log_dir does not exist."
    exit 1
  fi

  if [ ! -x "$log_dir" ]; then
    err "Directory $log_dir is not executable."
    exit 1
  fi
}


#######################################
# Function to report elapsed time since start of script and path of the command issued.
# Globals:
#   startime
#   cmd
# Outputs:
#   Writes elapsed time
#######################################
elapsed() {
  date +%s.%N | awk -v start=$startime -v com=$cmd '{printf "t= %.3f (%s) \n", $1-start, com}'
  return 0
}

#######################################
# Function to print out error messages along with other status information.
# Outputs:
#   Writes time followed by error messages
#######################################
err() {
  echo "$(date +'%Y-%m-%dT%H:%M:%S') ERROR $*" >&1
}

#######################################
# Function to print out messages along with other status information.
# Outputs:
#   Writes time followed by messages
#######################################
out() {
  echo "$(date +'%Y-%m-%dT%H:%M:%S') INFO $*" >&1
}
 
