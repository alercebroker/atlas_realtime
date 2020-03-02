#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: 1) logfile to read from"
    echo "Script needs a logfile to to read and get the exposure names from."
    exit
fi

logfile=$1
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
      #echo "exposure $exposure"
      #echo "tessellation $tessellation"
      # Grab value and put it on the map
      current_array=(${groups[$tessellation]})
      echo "The current value for $tessellation is ${current_array[@]}"
      echo "Now adding the exposure"
      # Check if the key tessellation is already in the map, if not, add it
      # then add the exposure.
      echo "before if ${#current_array[@]}"
      if [ ${#current_array[@]} -eq 0 ]
      then
        current_array+=("$exposure")
        groups[$tessellation]="${current_array[*]}" #$current_array
        #groups[$tessellation]="$exposure"
        #groups[$tessellation]+=("$exposure")
        #groups([$tessellation]="$exposure")
      else
        #echo "groups tessellation ${groups[$tessellation]}"
        #echo ${current_array[@]}
        current_values=("${groups[$tessellation]}")
        current_array=( "${current_values[@]}" )
        #current_array=("${groups[$tessellation]}")
        current_array+=("$exposure")
        echo "after adding, first if ${#current_array[@]}"
        #echo $current_array
        #echo "current array is ${current_array}"
        groups[$tessellation]="${current_array[@]}"
        #current_array=(${groups[$tessellation]})
        #current_array+=("$exposure")
        #groups[$tessellation]=$current_array
        #current_array=(${groups[$tessellation]})
        #current_array+=("$exposure")
        #groups[$tessellation]+=("$exposure")
        # TODO: reject if exposure already in the list
        #groups[$tessellation]="${groups[$tessellation]} $exposure"
        #groups[$tessellation]+=("$exposure")
        #groups[$tessellation]="${groups[$tessellation]} $exposure"
      fi
      #echo "Should be concatenated here: ${groups[$tessellation]}"
      sleep 1 # Dummy processing
      # Increment number of processed lines
      last_processed_line="$((last_processed_line+1))"

      # here I should add the key and value to the hash map
      #current=${groups[$tessellation]}
      #echo "the current value for the $tessellation is $current"
      # check if the key (tessellation, $17) is already in the map, if not, add it
      # then add the exposure ($1)
      #echo "now adding the exposure"
      #if [ -z "$current" ]
      #then
      #  groups[$tessellation]="$exposure"
      #else
      #  groups[$tessellation]="${groups[$tessellation]} $exposure"
      #fi
      #echo "should be concatenated here: ${groups[$tessellation]}"

      # check if the key is already in the map or not
      #echo "$current and $exposure"
      #if [ -z "$current" ]
      #then
      #  groups=( [$tessellation]=$exposure )
      #else
      #  groups=( [$tessellation]=${groups[$tessellation]}$exposure)
      #fi
      #echo "the tessellation $tessellation has the exposure ${groups[$tessellation]}"
      #last_processed_line="$((last_processed_line+1))"
      #echo $line_count
      #echo $last_processed_line
    done
  fi
  #sleep 1
  #tail -n 1 -f logfile.log | awk -W interactive '{print $17}'
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
