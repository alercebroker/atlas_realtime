#! /bin/bash
#
# Compiles the information for candidates in a given tessellation_telnite.objemjd file and
# prepares the directories to translate to .avro format

# Import utils
source utils.sh

if [ "$#" -ne 2 ]; then
  echo " "; echo "Usage: $0 tessellation_telnite exposures"
  echo "Where tessellation_telnite is the directory created by create_objects.sh, and"
  echo "exposures is the list of exposures of the current tessellation"
  echo " "
  exit
fi

startime=`date +%s.%N`     ; cmd=$0                    # <--- define initial parameters for function elapsed

tessetelnite=$1
exposures=$2

objname="data/${tessetelnite}/${tessetelnite}.objemjd" # ; echo "${tessetelnite} ${objname}"
validate_file  "${objname}"

expname=(${exposures})                          # ; echo "${expname[@]}"

let "nexpo = ${#expname[@]}"                      # this is the number of exposures in the tesselation

# Write a file with basic info about the objects (object name, average coordinates of detections, and number of detections)

#nlines=$(wc "${objname}" | awk '{print $1}')

#awk -v ll=${nlines} 'NR==1{o=$25;a=$1;d=$2;t=$26;n=1;l=$25};NR>1&&NR<=ll&&$25==o{a=a+$1;d=d+$2;t=t+$26;n=n+1;l=$25};\
#  NR>1&&NR<=ll&&$25!=o{printf"%s %9.5f %9.5f %12.6f %d\n",l,a/n,d/n,t/n,n;a=$1;d=$2;t=$26;n=1;o=$25};\
#  END{printf"%s %9.5f %9.5f %12.6f %d\n",l,a/n,d/n,t/n,n}' "${objname}" > "data/${tessetelnite}/${tessetelnite}_objects.data"

while read -r candinfo; do
  # expnome is a string read from objname, expname is an array read from expinfo and kept in memory (refer to the same objects but are different variables here)
  expnomecandlab=$(echo "${candinfo}" | awk '{print $24}')                          #; echo "${expnome}_${candlab}"
  expnome=$(echo "${expnomecandlab}" | awk -F"_" '{print $1}')                      #; echo "${expnome}"
  candfile="${expnomecandlab}.info"    # ; echo $candfile
  printf "%s\n" "${candinfo}" > "data/${tessetelnite}/${candfile}"                      # output 1-line file with candidate info

  # prepare the stamp commands for monsta. All of them mixed together in this loop to split and activate exposure by exposure in next loop
  # TODO validation "if ($5 < 10544)" to avoid monsta errors when stamp overflows xedge. Remove when monsta solve it.
  image_size=10560
  stamp_size=61
  xy=$(echo ${candinfo} | awk '{ print $5,$6 }')        # ; echo "${xy}"
  dstamp="${expnomecandlab}_dstamp.fits"    #; echo $dstamp
  istamp="${expnomecandlab}_istamp.fits"    #; echo $istamp
  #tstamp="${expnomecandlab}_tstamp.fits"    #; echo $tstamp
  
  dmonstastamps="data/${tessetelnite}/${expnome}_d_stamps.monsta"                                   # name of the file for the monsta commands for difference image
  imonstastamps="data/${tessetelnite}/${expnome}_i_stamps.monsta"                                   # name of the file for the monsta commands for science image
  #tmonstastamps="data/${tessetelnite}/${expnome}_t_stamps.monsta"                                   # name of the file for the monsta commands for template image
  if [[ -n $xy ]]; then
    echo "${xy} ${tessetelnite}/${dstamp}" >> "${dmonstastamps}"                           # command line of the form x y stamp_file_name for a difference stamp
    echo "${xy} ${tessetelnite}/${istamp}" >> "${imonstastamps}"                           # command line of the form x y stamp_file_name for an image stamp
    #echo "${xy} ${tessetelnite}/${tstamp}" >> "${tmonstastamps}"                          # command line of the form x y stamp_file_name for a template stamp
  fi
done < ${objname}

for (( i = 0 ; i < ${nexpo}; i++ )); do

  nstamps=$(wc -l "data/${tessetelnite}/${expname[i]}_d_stamps.monsta" | awk '{print $1}')           #   ; echo "${nstamps}"               # nstamps is the same for diff, img, and template

  # prepare monsta commands for the difference image of this exposure
  diffimg="/data/atlas-local/diff/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.diff.fz"                # ; echo "${diffimg}"
  validate_file "${diffimg}"
  dmonstastamps="data/${tessetelnite}/${expname[i]}_d_stamps.monsta"                                  # name of the file for the monsta commands for difference image
  sed -i "1s/^/${nstamps}\n/" ${dmonstastamps}                                                # first line in the file of commands for monsta
  monsta /atlas/src/trunk/red/subarrays.pro ${diffimg} ${dmonstastamps} $stamp_size
  find "data/${tessetelnite}" -name *.fits -print0 | parallel  --will-cite -0 gzip
  
  # prepare monsta commands for the science image of this exposure
  scieimg="/data/atlas-local/red/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.fits.fz"             #  ; echo "$scieimg"
  validate_file "${scieimg}"
  imonstastamps="data/${tessetelnite}/${expname[i]}_i_stamps.monsta"                                   # name of the file for the monsta commands for science image
  sed -i "1s/^/${nstamps}\n/" ${imonstastamps}                                                # first line in the file of commands for monsta
  monsta /atlas/src/trunk/red/subarrays.pro ${scieimg} ${imonstastamps} $stamp_size
  find "data/${tessetelnite}" -name *.fits -print0 | parallel  --will-cite -0 gzip

  ### prepare monsta commands for the template image of this exposure
  ##  tempimg="/data/atlas-local/red/${expname[i]:0:3}/${expname[i]:3:5}/${expname[i]}.fits.fz"             #  ; echo "$tempimg"           # same as science image for the time being!!!
  ##  validate_file "${tempimg}"
  ##  tmonstastamps="data/${tessetelnite}/${expname[i]}_t_stamps.monsta"                                   # name of the file for the monsta commands for template image
  ##  sed -i "1s/^/${nstamps}\n/"  ${tmonstastamps}                                                # first line in the file of commands for monsta
  ##  monsta /atlas/src/trunk/red/subarrays.pro ${tempimg} ${tmonstastamps} $stamp_size
  
done

# clean up the monsta command files
/bin/rm "data/${tessetelnite}"/*.monsta

out $(elapsed) "${tessetelnite}"                         # Report elapsed time

# Create the directory where to put the avro files
if [ ! -d "data/${tessetelnite}/avro" ]
then
  mkdir "data/${tessetelnite}/avro"
fi
go run config.go create_records.go confluent_producer.go  generate_alerts.go "data/${tessetelnite}"
