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

tesse=$1 ; exposure=$2 # e.g.: tesse: SV341N74
telnite="${exposure:0:8}" # todo: change this, may be too custom, better to parse '_'. e.g.: 02a58884
tessetelnite="${tesse}_${telnite}" # e.g.: SV341N74_02a58884

if [ -d ${tessetelnite} ]; then      # If a directory named tessetelnite exists remove it and make it clean again
  /bin/rm -r "${tessetelnite}"
  mkdir "${tessetelnite}"
else
  mkdir "${tessetelnite}"
fi
# Prepares a file with the name of the tesselation and the associated exposures
#echo "${tesse} ${istesse[@]}" > "${tessetelnite}/${tessetelnite}.exposures" # e.g.: SV341N74_02a58884

exp="${exposure}"
ddcfile="/atlas/diff/${exp:0:3}/${exp:3:5}/${exp}.ddc" #; echo "${ddcfile}" # second argument is how many characters to take

# Wait for the creation of the ddc file
out "Waiting for the file ${ddcfile} to be created."
wait_for_file ${ddcfile} "2"

# If the file exists and is readable
validate_file ${ddcfile}

diffimg="/atlas/diff/${exp:0:3}/${exp:3:5}/${exp}.diff.fz"       #; echo "${diffimg}"
validate_file ${diffimg}  

diffhead=$(/atlas/bin/fitshdr ${diffimg})		# Store the header of the diff images for further use
#diffheadfile="${exp}.diff.head"
#echo $diffhead >  "${tessetelnite}/${diffheadfile}"
expstart=$(echo "${diffhead}" | grep "MJD-OBS" | awk '{print $3}') #; echo "${expstart}"
exptime=$(echo "${diffhead}" | grep "EXPTIME" | awk '{print $3}')  #; echo "${exptime}"
timeobs=$(echo $expstart $exptime | awk '{printf"%12.6f", ($1+($2/86400)/2)}') #; echo "${timeobs}"

awk -v mjd="${timeobs}" -v expo="${exp}" '
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
$1~"#"{n0=NR}; \
$1!~"#"&&($12>50||$13>50)&&$15<500&&$14<500&&$19<500&&$10!=5&&$21>=0{oid = f($1,$2);printf" %s %17s_%04g %s %12.6f\n",$0,expo,NR-n0,oid,mjd}' ${ddcfile}  > "${tessetelnite}/${tessetelnite}.objemjd"

# here tessetelnite is ready
#echo "Calling candids for ${tesse}"

./candids.sh ${tessetelnite} "${exposure}"

out $(elapsed) "${tessetelnite}" # Report elapsed time
