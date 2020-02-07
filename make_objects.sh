#!/bin/bash
#
# for a given tessellation of a given night grab the associated exposures, find the *.ddc files and output a list of
# candidate transient objects as an ordered list of ATLAS detections grouped by DEC & RA within a given tolerance
#
if [ "$#" -ne 3 ]; then
    echo " "; echo "Usage: $0 [tessellation name] [output group file from imggrps.sh] Tolerance"
    echo "Script asks for an ATLAS style tessellation ID, the imggrps.sh output with the exposures associated to each tessellation,"
    echo "and the tolerance in arcseconds to match detections in different *.ddc files and declare they are the same object." ; echo " "
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

tesse=$1 ; grpfile=$2 # e.g.: tesse: SV341N74
telnite="${grpfile:0:8}" # todo: change this, may be too custom, better to parse '_'. e.g.: 02a58884
tessetelnite="${tesse}_${telnite}" # e.g.: SV341N74_02a58884

tol=$(echo "$3" | awk '{printf"%s\n",($1/3600.)""}')           # ttt is the tolerance in degrees

# check whether the group file is there and can be read

if [ ! -f ${grpfile} ] ; then
  echo "File ${grpfile} does not exist."
  exit
fi

if [ ! -r ${grpfile} ] ; then
  echo "File ${grpfile} is unreadable"
  exit
fi

# if the file exists and can be read check that the tessellation requested is in the file
# appends tessellation + exposures
istesse+=($(grep ${tesse} ${grpfile}))            # echo "${istesse[*]}"

if [ "${#istesse[@]}" -eq 0 ] ; then
  echo "Tessellation ${tesse} is not in ${grpfile}." ; echo " "
  exit
else                                    # else everything is ready to look for the associated exposures and their products
  if [ -d ${tessetelnite} ] ; then      # If a directory named tessetelnite exists remove it and make it clean again
     /bin/rm -r "${tessetelnite}"
     mkdir "${tessetelnite}"
  else
    mkdir "${tessetelnite}"
  fi
  # Prepares a file with the name of the tesselation and the associated exposures
  echo "${istesse[@]}" > "${tessetelnite}/${tessetelnite}.exposures" # e.g.: SV341N74_02a58884
  awkword=''
  for (( i = 1 ; i <= (${#istesse[@]}-1); i++ )) ; do # do this for every argument but the tessellation
    exp="${istesse[i]}"
    ddcfile="/atlas/diff/${exp:0:3}/${exp:3:5}/${exp}.ddc" #; echo "${ddcfile}" # second argument is how many characters to take
    # if the file exists and is readable
    if [ -f ${ddcfile} ] && [ -r ${ddcfile} ] ; then
      awkword=${awkword}" ${ddcfile}" # awkword is a string with the ddc file paths/names separated by spaces
    else
      if [ ! -r ${ddcfile}] ; then
        echo "File ${ddcfile} is unreadable."
      else
        echo "File ${ddcfile} does not exist."
      fi
    fi
    diffimg="/atlas/diff/${exp:0:3}/${exp:3:5}/${exp}.diff.fz"       #; echo "${diffimg}"
    if [ -f ${diffimg} ] && [ -r ${diffimg} ] ; then
      diffhead="${exp}.diff.head"                                    #; echo ${diffhead}
      /atlas/bin/fitshdr ${diffimg} > "${tessetelnite}/${diffhead}"    # Store the header of the diff images for further use
    else
      if [ ! -r ${diffimg}] ; then
        echo "File ${diffimg} is unreadable."
      else
        echo "File ${diffimg} does not exist."
      fi
    fi
  done
  nddc=$(echo ${awkword} | awk '{print NF}')
  if [ "${nddc}" -le 1 ] ; then
    echo "Only one .ddc file to look for object candidates?"
    exit
  else
# Following line is key: jointly scans all the .ddc files of the tessellation taking only detections that a priori have more than 1% chance of being interesting to Alerce. Keeps the .ddc record, but adds
# the exposure name and order of appearance in the .ddc file for later use in the candid name. Sorts the detections using declination.
    awk '$1~"#"{n0=NR};$1!~"#"&&$21>=0&&(1000-($14+$15+$16+$17+$18+$19+$20))>=10{print $0,substr(FILENAME,23,14),NR-n0}' ${awkword} | sort -n -k2 > "${tessetelnite}/${tesse}_candids.tmp"
# Following line is key as well: Process the file with the filtered and sorted detections and finds those that coincide within ${tol}. Assign an object number and gives a unique name to each group
# Uses Tonry's column merge program "cm" in friends of friends mode.
    /atlas/bin/cm 2,1 "${tessetelnite}/${tesse}_candids.tmp" -tol ${tol},d -grp -grporder | awk -v obj=${tessetelnite} '{printf"%s %17s_%04g\n",$0,obj,$1}' > "${tessetelnite}/${tessetelnite}.objects"
  fi
fi
/bin/rm "${tessetelnite}/${tesse}_candids.tmp"                          # delete temporary file

echo $(elapsed) "${tessetelnite}"                         # Report elapsed time
