#!/bin/bash

# This script simulates a logfile being written in real time
# to test the rest of the scripts in the ATLAS avro pipeline.

if [ "$#" -ne 2 ]
then
    echo "Usage: 1) original logfile, 2) file where to copy the data"
    echo "Script needs a real logfile to be copied into a new file and the path to this other file."
    exit
fi

logfile=$1 ; newfile=$2

# Start from the first line of the logfile ($1)
line_number=1
# Get the first line of the logfile
line_text="$( sed "1q;d" ${logfile} )"

while [ ! -z "$line_text" ]
do
  # Generate a random number between 1 and 10, which is the number of
  # seconds to wait before copying the next line into the other file.
  random=$(( ( RANDOM % 10 ) + 1 ))
  sleep $random
  # Echo the line to the other simulated logfile
  echo $line_text >> $newfile
  # then increment the line number and reassign line_text
  ((line_number++))
  line_text="$( sed "${line_number}q;d" ${logfile} )"
done
