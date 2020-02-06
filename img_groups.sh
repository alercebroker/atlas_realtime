#!/bin/bash

# $1 is an ATLAS style night number (e.g. 58XXX); $2 is as ATLAS style telescope + camera id (e.g. 02a)
#
# For a given night and telescope grabs the telescope logfile and builds the image groups observed
# (either quads, quintuplets, triplets or doubletts).
# Outputs them to a file named telescope+camera_ID_night_img.groups

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 telescope+camera_ID night_number"
    echo "Script needs a telescope + camera id (e.g. 02a) and an ATLAS style night number (e.g. 58XXX)."
    exit
fi

tele=$1 ; nite=$2

# validate the input
# check the first and last nights available for the requested telescope
nites=$(ls -1 /atlas/red/${tele}/ | wc | awk '{print $1}')
nnf=$(ls /atlas/red/${tele}/ | awk 'NR==1{print substr($0,1,5)}')                              # first nite in ATLAS database
nnl=$(ls /atlas/red/${tele}/ | awk -v fin=${nites} 'NR==fin{print substr($0,1,5)}')            # last  nite in ATLAS database

if [ ${tele} != "01a" ] && [ ${tele} != "02a" ] ;  then
  echo "Telescope has to be either 01a or 02a."
  exit
fi

if [ ${nite} -gt ${nnl} ] ; then
  echo "Last nite of telescope ${tele} in reduced directory is ${nnl}"
  exit
fi

if [ ${nite} -lt ${nnf} ] ; then
  echo "First nite of telescope ${tele} in reduced directory is ${nnf}"
  exit
fi

# if nite and telescope are within expectations check whether the night is there and can be executed

if [ ! -d "/atlas/red/${tele}/${nite}/" ] ; then
  echo "Directory /atlas/red/${tele}/ does not exist."
  exit
fi

if [ ! -x "/atlas/red/${tele}/${nite}/" ] ; then
  echo "Directory /atlas/red/${tele}/ is not executable."
  exit
fi

# if the night directory is there and can be opened check whether a logfile was produced and can be read

if [ ! -f "/atlas/red/${tele}/${nite}/${tele}${nite}.log" ] ; then
  echo "Log file /atlas/red/${tele}/${nite}/${tele}${nite}.log does not exist."
  exit
fi

if [ ! -r "/atlas/red/${tele}/${nite}/${tele}${nite}.log" ] ; then
  echo "Log file /atlas/red/${tele}/${nite}/${tele}${nite}.log is unreadable"
  exit
fi

# if everything is OK logfile can be opened and observations can be grouped in quads, quintuplets, triplets, etc.
# first clean the log file from unneeded info and sort it according to names of tessellations on column 17

awk '$NF!~"Object"&&$NF!~"preflight"&&$NH!~"twiflat"' "/atlas/red/${tele}/${nite}/${tele}${nite}.log" | sort -k 17 > "./${tele}${nite}_sorted_log"

# now do the grouping

grpids=''
first='yes'

while read -r line ; do
array+=($line)
if [ ${first} == 'yes' ] ; then
  echo "#Tessel. Exposures -------------->" > "./${tele}${nite}_img.groups"
  tesse="${array[16]}"
  first='no'
fi

if [[ ${first} == 'no' && (${array[16]} == ${tesse}) ]] ; then
  grpids="${grpids} ${array[0]}"
else
  echo ${tesse} ${grpids} >> "./${tele}${nite}_img.groups"
  tesse="${array[16]}" ; grpids="${array[0]}"
fi

unset array[@]

done < "./${tele}${nite}_sorted_log"

# remove the .log sorted file

/bin/rm "./${tele}${nite}_sorted_log"

echo "Script finished normally. Created file ${tele}${nite}_img.groups"
