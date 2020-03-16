#! /bin/bash
#
# Compiles the information for candidates in a given tessellation_telnite.objemjd file and
# prepares the directories to translate to .avro format
#

if [ "$#" -ne 1 ]; then
    echo " "; echo "Usage: $0 tessellation_telnite"
    echo "Where tessellation_telnite is the directory created by create_objects.sh, including"
    echo "the file tessellation_telnite.objemjd created by times.sh"
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

objname="${tessetelnite}/${tessetelnite}.objemjd" # ; echo "${tessetelnite} ${objname}"

filetest "${objname}"

# grab the names of the exposures that went into this tesselation

expinfo="${tessetelnite}/${tessetelnite}.exposures"   # ; echo "${expinfo}"           # this is the filename of the tessellation info. Tessellation name is the first string

filetest "${expinfo}"

expname+=($(cat ${expinfo}))                          # ; echo "${expname[@]}"

let "nexpo = ${#expname[@]} - 1"                      # this is the number of exposures in the tesselation

# Write a file with basic info about the objects (object name, average coordinates of detections, and number of detections)

nlines=$(wc "${objname}" | awk '{print $1}')

#'NR==1{o=$25;a=$1;d=$2;n=1;l=$25};NR>1&&NR<=ll&&$25==o{a=a+$1;d=d+$2;n=n+1;l=$25};NR>1&&NR<=ll&&$25!=o{print l,a/n,d/n,n;a=$1;d=$2;n=1;o=$25};END{print $25,a/n,d/n,n}'
awk -v ll=${nlines} 'NR==1{o=$25;a=$1;d=$2;t=$26;n=1;l=$25};NR>1&&NR<=ll&&$25==o{a=a+$1;d=d+$2;t=t+$26;n=n+1;l=$25};\
  NR>1&&NR<=ll&&$25!=o{printf"%s %9.5f %9.5f %12.6f %d\n",l,a/n,d/n,t/n,n;a=$1;d=$2;t=$26;n=1;o=$25};\
  END{printf"%s %9.5f %9.5f %12.6f %d\n",l,a/n,d/n,t/n,n}' "${objname}" > "${tessetelnite}/${tessetelnite}_objects.data"

# Check if a temporary file with monsta subarrays commands exist. If so, erase it and create a new one

tmpmons="${tessetelnite}/${tessetelnite}.monsta"      #; echo "${tessetelnite} ${tmpmons}"

if [ -f ${tmpmons} ] ; then      # If a file named $tmpmons exists remove it and make it clean again
   /bin/rm -r "${tmpmons}"
   touch "${tmpmons}"
else
  touch "${tmpmons}"
fi

while read -r candinfo; do

# expnome is a string read from objname, expname is an array read from expinfo and kept in memory (refer to the same objects but are different variables here)

  expnome=$(echo "${candinfo}" | awk '{print $24}' | awk -F"_" '{print $1}')                          #; echo "${expnome}"
  candlab=$(echo "${candinfo}" | awk '{print $24}'  | awk -F"_" '{print $2}')                         #; echo "${candlab}"

  candfile="${expnome}_${candlab}.info"    # ; echo $candfile
  xy=$(echo ${candinfo} | awk '{print $5,$6}')        # ; echo "${xy}"
  dstamp="${expnome}_${candlab}_dstamp.fits"    #; echo $dstamp
  istamp="${expnome}_${candlab}_istamp.fits"    #; echo $istamp
##  tstamp="${expnome}_${candlab}_tstamp.fits"    #; echo $tstamp
#
  printf "%s\n" "${candinfo}" > "${tessetelnite}/${candfile}"                      # output 1-line file with candidate info

# prepare the stamp commands for monsta. All of them mixed together in this loop to split and activate exposure by exposure in next loop
#
  echo "${xy} ${tessetelnite}/${dstamp}" >> "${tmpmons}"                           # command line of the form x y stamp_file_name for a difference stamp
  echo "${xy} ${tessetelnite}/${istamp}" >> "${tmpmons}"                           # command line of the form x y stamp_file_name for an image stamp
##  echo "${xy} ${tessetelnite}/${tstamp}" >> "${tmpmons}"                           # command line of the form x y stamp_file_name for a template stamp
done < ${objname}

for (( i = 1 ; i <= ${nexpo}; i++ )) ; do

  nstamps=$(grep "${expname[i]}" "${tmpmons}" | grep "dstamp" | wc | awk '{print $1}')           #   ; echo "${nstamps}"               # nstamps is the same for diff, img, and template

# prepare monsta commands for the difference image of this exposure
  diffimg="/atlas/diff/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.diff.fz"                # ; echo "${diffimg}"
  filetest "${diffimg}"
  dmonstastamps="${tessetelnite}/d_stamps.monsta"                                   # name of the file for the monsta commands for difference image
  echo ${nstamps} > ${dmonstastamps}                                                # first line in the file of commands for monsta
  grep "${expname[i]}" "${tmpmons}" | grep "dstamp" >> ${dmonstastamps}             # rest of the lines with x y stamp_file_name
# echo "monsta /atlas/src/trunk/red/subarrays.pro ${diffimg} ${dmonstastamps} 33"
  monsta /atlas/src/trunk/red/subarrays.pro ${diffimg} ${dmonstastamps} 33

# prepare monsta commands for the science image of this exposure
  scieimg="/atlas/red/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.fits.fz"             #  ; echo "$scieimg"
  filetest "${scieimg}"
  imonstastamps="${tessetelnite}/i_stamps.monsta"                                   # name of the file for the monsta commands for science image
  echo ${nstamps} > ${imonstastamps}                                                # first line in the file of commands for monsta
  grep "${expname[i]}" "${tmpmons}" | grep "istamp" >> ${imonstastamps}             # rest of the lines with x y stamp_file_name
# echo "monsta /atlas/src/trunk/red/subarrays.pro ${scieimg} ${imonstastamps} 33"
  monsta /atlas/src/trunk/red/subarrays.pro ${scieimg} ${imonstastamps} 33

### prepare monsta commands for the template image of this exposure
##  tempimg="/atlas/red/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.fits.fz"             #  ; echo "$tempimg"           # same as science image for the time being!!!
##  filetest "${tempimg}"
##  tmonstastamps="${tessetelnite}/t_stamps.monsta"                                   # name of the file for the monsta commands for template image
##  echo ${nstamps} > ${tmonstastamps}                                                # first line in the file of commands for monsta
##  grep "${expname[i]}" "${tmpmons}" | grep "tstamp" >> ${tmonstastamps}             # rest of the lines with x y stamp_file_name
# echo "monsta /atlas/src/trunk/red/subarrays.pro ${tempimg} ${tmonstastamps} 33"
##  monsta /atlas/src/trunk/red/subarrays.pro ${tempimg} ${tmonstastamps} 33

done

# clean up the monsta command files
/bin/rm ${tmpmons} ${dmonstastamps} ${imonstastamps} ${tmonstastamps}

echo $(elapsed) "${tessetelnite}"                         # Report elapsed time

##### Here I should call the golang scripts #####
# candfile="${expnome}_${candlab}.info" is ready here
echo "${tessetelnite} ${expnome}_${candlab}"
# Create the directory where to put the avro files
if [ ! -d "avro" ]
then
    mkdir avro
fi
go run config.go create_records.go generate_alerts.go "${tessetelnite}"
