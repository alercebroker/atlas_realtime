#!/bin/bash

# log file in /atlas/red/02a/58819/02a58819.log
logfile="logfile.log"
# the "Object" column contains the observations (preflight and twiflat values should be ignored.)
# create map
declare -A objects

# listen to the log file for new lines
last_processed_line=0
while :
do
  # count lines in the logfile
  line_count=$(cat "$logfile" | wc -l)
  # get the difference to see if there's something that needs to be processed
  difference="$((line_count - last_processed_line))"
  # if there is
  if [[ $difference -gt "0" ]]
  then
    # create a process for each of those lines, this part should guarantee that
    # every line is processed (in order may be better)
    while [[ $last_processed_line -lt $line_count ]]
    do
      echo 'missing lines'
      current_line="$((last_processed_line+1))"
      # grab value and put it on the map
      sleep 1 # dummy processing
      # here I should add the key and value to the hash map
      echo $(sed '`${current_line}`q;d' "$logfile")

      last_processed_line="$((last_processed_line+1))"
      echo $line_count
      echo $last_processed_line
    done
  fi
  sleep 1
  #tail -n 1 -f logfile.log | awk -W interactive '{print $17}'
done



# check folder for changes
# add file to the map
