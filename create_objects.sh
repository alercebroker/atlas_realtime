#!/bin/bash
#
# for a given tessellation of a given night grab the associated exposures, find the *.ddc files and output a list of
# candidate transient objects as an ordered list of ATLAS detections grouped by DEC & RA within a given tolerance

# Import utils
source utils.sh

if [ "$#" -ne 3 ]; then
    echo " "; echo "Usage: $0 [tessellation name] [output group file from imggrps.sh] tolerance"
    echo "Script asks for an ATLAS style tessellation ID, the imggrps.sh output with the exposures associated to each tessellation,"
    echo "and the tolerance in arcseconds to match detections in different *.ddc files and declare they are the same object." ; echo " "
    exit 1
fi

startime=`date +%s.%N` ; cmd=$0 # <--- define initial parameters for function elapsed
# Call it with: echo $(elapsed) # Report elapsed time & calling command

if [ ! -d "data" ]
then
  mkdir "data"
fi

tesse=$1 ; exposures=$2 # e.g.: tesse: SV341N74
telnite="${exposures:0:8}" # todo: change this, may be too custom, better to parse '_'. e.g.: 02a58884
tessetelnite="${tesse}_${telnite}" # e.g.: SV341N74_02a58884

tol=$(echo "$3" | awk '{printf"%s\n",($1/3600.)""}') # ttt is the tolerance in degrees

# Exposures as array
istesse=(${exposures})

if [ -d ${tessetelnite} ]; then      # If a directory named tessetelnite exists remove it and make it clean again
  /bin/rm -r "data/${tessetelnite}"
  mkdir "data/${tessetelnite}"
else
  mkdir "data/${tessetelnite}"
fi
# Prepares a file with the name of the tesselation and the associated exposures
#echo "${tesse} ${istesse[@]}" > "${tessetelnite}/${tessetelnite}.exposures" # e.g.: SV341N74_02a58884
awkword=''
for (( i = 0 ; i < (${#istesse[@]}); i++ )); do # do this for every argument but the tessellation
  exp="${istesse[i]}"
  ddcfile="/data/atlas-local/diff/${exp:0:3}/${exp:3:5}/${exp}.ddc" #; echo "${ddcfile}" # second argument is how many characters to take
  
  # Wait for the creation of the ddc file
  out "Waiting for the file ${ddcfile} to be created."
  wait_for_file ${ddcfile} "86400"
  
  # If the file exists and is readable
  validate_file ${ddcfile}  
  awkword=${awkword}" ${ddcfile}" # awkword is a string with the ddc file paths/names separated by spaces
  
  diffimg="/data/atlas-local/diff/${exp:0:3}/${exp:3:5}/${exp}.diff.fz"       #; echo "${diffimg}"
  wait_for_file ${diffimg} "86400"
  validate_file ${diffimg}  
  
  diffhead=$(/atlas/bin/fitshdr ${diffimg})		# Store the header of the diff images for further use
  #diffheadfile="${exp}.diff.head"
  #echo $diffhead >  "${tessetelnite}/${diffheadfile}"
  expstart=$(echo "${diffhead}" | grep "MJD-OBS" | awk '{print $3}') #; echo "${expstart}"
  exptime=$(echo "${diffhead}" | grep "EXPTIME" | awk '{print $3}')  #; echo "${exptime}"
  fids[i]=$(echo "${diffhead}" | grep "FILTER" | awk -F "[' ]+" '{print $3}')  #; echo "${fid}"
  timeobs[i]=$(echo $expstart $exptime | awk '{printf"%12.6f", ($1+($2/86400)/2)}') #; echo "${timeobs[i]} $i"
done

# Following line is key: jointly scans all the .ddc files of the tessellation taking only detections that a priori have more than 1% chance of being interesting to Alerce. Keeps the .ddc record, but adds
# the exposure name and order of appearance in the .ddc file for later use in the candid name. Sorts the detections using declination.
awk '$1~"#"{n0=NR};$1!~"#"&&$14<500&&$15<500&&$16<500&&$17<500&&$18<500&&$19<500&&$21>=0{print $0,substr(FILENAME,34,14),NR-n0}' ${awkword} > "data/${tessetelnite}/${tesse}_candids.tmp"
# Following line is key as well: Process the file with the filtered and sorted detections and finds those that coincide within ${tol}. Assign an object number and gives a unique name to each group
# Uses Tonry's column merge program "cm" in friends of friends mode.
/atlas/bin/cm 2,1 "data/${tessetelnite}/${tesse}_candids.tmp" -tol ${tol},d -grp -grporder | awk -v fids="${fids[*]}" -v obj="${tessetelnite}" -v timeobs="${timeobs[*]}" -v exposures="${istesse[*]}" ' \
function f(ra,dec) {

    # 19 Digit ID - two spare at the end for up to 100 duplicates

    id = 1000000000000000000;

    # 2013-11-15 KWS Altered code to fix the negative RA problem
    if (ra < 0.0)
    {
        ra += 360.0;
    }

    if (ra > 360.0)
    {
        ra -= 360.0;
    }

    # Calculation assumes Decimal Degrees:

    ra_hh = int(ra / 15);
    ra_mm = int((ra / 15 - ra_hh) * 60);
    ra_ss = int(((ra / 15 - ra_hh) * 60 - ra_mm) * 60);
    ra_ff = int((((ra / 15 - ra_hh) * 60 - ra_mm) * 60 - ra_ss) * 100);

    if (dec >= 0) {
        h = 1;
    } else {
        h = 0;
        dec = dec * -1;
    }

    dec_deg = int(dec);
    dec_mm = int((dec - dec_deg) * 60);
    dec_ss = int(((dec - dec_deg) * 60 - dec_mm) * 60);
    dec_f = int(((((dec - dec_deg) * 60 - dec_mm) * 60) - dec_ss) * 10);

    id += (ra_hh * 10000000000000000);
    id += (ra_mm *   100000000000000);
    id += (ra_ss *     1000000000000);
    id += (ra_ff *       10000000000);

    id += (h *            1000000000);
    id += (dec_deg *        10000000);
    id += (dec_mm *           100000);
    id += (dec_ss *             1000);
    id += (dec_f *               100);

    return id;
}
BEGIN { split(timeobs,times," "); \
        split(exposures,exps," "); \
        split(fids,fides," "); \
		for(i in exps){ \
		  values[exps[i]]=times[i]; \
                  fid[exps[i]]=fides[i]; \
		} \
 } \
 {oid = f($2,$3);printf" %9.5f %9.5f %7.3f %6.3f %8.2f %8.2f %6.2f %6.2f %6.2f %2d %6.2f %3d %3d %3d %3d %3d %3d %3d %3d %3d %2d %9.1f %6.1f %s_%06g %s %12.6f %s\n", \
          $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,oid,values[$25],fid[$25]}' > "data/${tessetelnite}/${tessetelnite}.objemjd"

/bin/rm "data/${tessetelnite}/${tesse}_candids.tmp" # Delete temporary file
# here tessetelnite is ready
out "Calling candids for ${tessetelnite} ${exposures} "
./candids.sh ${tessetelnite} "${exposures}"

out $(elapsed) "${tessetelnite}" # Report elapsed time
