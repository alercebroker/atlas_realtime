#!/bin/bash

if [ "$#" -ne 2 ]
then
    echo "Usage: 1) logfile to read from, 2) output file."
    echo "Script needs a logfile to to read and get the exposure names from and an output file
    where to write the groups."
    exit
fi

logfile=$1
outfile=$2
# Create map (associative array)
declare -A groups

# Listen to the log file for new lines, starting from the beginning
last_processed_line=0
while :
do
  # Count lines in the logfile
  line_count=$(cat "$logfile" | wc -l)
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
      line_text="$( sed "${current_line}q;d" ${logfile} | awk '{print $1, $17}' )"
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
        echo "$tessellation ${groups[$tessellation]}" >> $outfile
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
# add usage info
# multidimensional associative array
# put everything in functions and call the functions from a different script
# Log file in /atlas/red/02a/58819/02a58819.log
# The "Object" column contains the observations (preflight and twiflat values should be ignored.)
