#!/bin/bash

# The functions in this file should be imported using this command: . ./utils.sh --source-only

# Follow a file while being written, get data from it and process this data.
# Parameters: $1 function to grab the data, $2 function to process the data
follow_file () {
  # Function to grab data from each line
  grab_function=$1
  # Function to process the data
  process_function=$2
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
      # TODO: Create a process for each of those lines, this part should guarantee that every line is processed (in order might be better)
      while [[ $last_processed_line -lt $line_count ]]
      do
        #echo "There are unprocessed lines"
        current_line="$((last_processed_line+1))"
        # Get the exposure and tessellation of the current line
        data=$($grab_function "$current_line")
        $process_function "${data[@]}"
        # Increment number of processed lines
        last_processed_line="$((last_processed_line+1))"
      done
    fi
  done
}

# Check that a file exists and is readable
# Parameters: $1 file to check
validate_file () {
  local log_file=$1
  file_name=$2
  if [ ! -f "$log_file" ] ; then
    echo "File $file_name does not exist."
    exit
  fi

  if [ ! -r "$log_file" ] ; then
    echo "File $file_name is unreadable"
    exit
  fi
}

# Wait for the file to be created
wait_for_file () {
  local file=$1
  local time=$2
  while [ ! -f $file ]
  do
    sleep $time
    echo "sleeping"
  done
}

# Function to report elapsed time since start of script and path of the command issued
elapsed() {
  date +%s.%N | awk -v start=$startime -v com=$cmd '{printf "t= %.3f (%s) \n", $1-start, com}'
  return 0
}
