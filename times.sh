#! /bin/bash

# import utilities
. ./utils.sh --source-only

if [ "$#" -ne 1 ]; then
    echo " "; echo "Usage: $0 tessellation_telnite"
    echo "Where tessellation_telnite is the directory created by create_objects.sh,"
    echo "including the file tessellation_telnite.objects, and the exposure_name.diff.head"
    echo "files containing the header of each difference image of the given tessellation."
    echo " "
    exit
fi

# Function to report elapsed time since start of script and path of the command issued
elapsed() {
  date +%s.%N | awk -v start=$startime -v com=$cmd '{printf "t= %.3f (%s) \n", $1-start, com}'
  return 0
}
startime=`date +%s.%N`     ; cmd=$0                    # <--- define initial parameters for function elapsed
# Call it with:
#echo $(elapsed)                                       # Report elapsed time & calling command

# Change using utils.sh
# Function to test if a file exists and give useful messages if not
filetest() {
if [[ ! -f $1 || ! -r $1 ]] ; then
  if [[ -f $1 ]] ; then
    echo "$1 is unreadable"
     exit
  else
    echo "$1 does not exist"
     exit
  fi
fi
}

tessetelnite=$1

outname="${tessetelnite}/${tessetelnite}.objemjd" # ; echo "${tessetelnite} ${outname}"

if [ -f ${outname} ] ; then      # If the output file is there, erase it
   /bin/rm "${outname}"
fi

objname="${tessetelnite}/${tessetelnite}.objects" # ; echo "${tessetelnite} ${objname}"

validate_file "${objname}"

# grab the names of the exposures that went into this tesselation

expinfo="${tessetelnite}/${tessetelnite}.exposures"   # ; echo "${expinfo}"           # this is the filename of the tessellation info. Tessellation name is the first string

validate_file "${expinfo}"

expname+=($(cat ${expinfo}))                          # ; echo "${expname[@]}"

let "nexpo = ${#expname[@]} - 1"                      # this is the number of exposures in the tesselation

# Grab time information and compute the MJD of the middle of exposure
#
for (( i = 1 ; i <= ${nexpo}; i++ )) ; do
  diffhead="${tessetelnite}/${expname[i]}.diff.head"                #; echo "${diffhead}"
  validate_file "${diffhead}"
  expstart=$(cat "${diffhead}" | grep "MJD-OBS" | awk '{print $3}') #; echo "${expstart}"
  exptime=$(cat "${diffhead}" | grep "EXPTIME" | awk '{print $3}')  #; echo "${exptime}"
  timeobs[i]=$(echo $expstart $exptime | awk '{printf"%12.6f", ($1+($2/86400)/2)}') #; echo "${timeobs[i]} $i"
done

while read -r objline; do
  exposure=$(echo "${objline}" | awk '{print $25}') #; echo "${objline} ${exposure}"
  for (( i = 1 ; i <= ${nexpo}; i++ )) ; do
    if [ $exposure == ${expname[i]} ] ; then
#     echo "${objline} ${timeobs[i]}"
      echo "${objline} ${timeobs[i]}" | awk '{printf" %9.5f %9.5f %7.3f %6.3f %8.2f %8.2f %6.2f %6.2f %6.2f %2d %6.2f %3d %3d %3d %3d %3d %3d %3d %3d %3d %2d %9.1f %6.1f %s_%06g %s %12.6f\n", $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28}' >> "${outname}"
    fi
  done
done < ${objname}

echo $(elapsed) "${tessetelnite}" # Report elapsed time
