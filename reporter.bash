#!/bin/bash

# ==========================
#  Aligner Report Generator
# ==========================
#
# This script returns the basics mapping statistics after a STAR-RSEM run over
# multiple FASTQ files, by reading the log files returned by docker4seq
#
# - ...
# - ...
#
# NOTE: the script assumes that:
#           - all log files have the same name $logname
#           - there is a log file for each sample
#           - log files are organized in many sample-specific sub-folders of the
#               $mainpath directory
#           - log file-containing folders are just 1 level below $mainpath
#
# ISSUES: make mainpath and sep user-defined parameters
#

# System-related variables
mainpath="$HOME/Data/PANC1/pH/FASTQs"
#mainpath="/mnt/c/Users/aleph/Desktop/reporter" # For testing (WSL)
#mainpath="$HOME/Dropbox/BashScripts/reporter" # For testing (Linux)
logname="Log.final.out"
sep="\t" # Tab-separated value
sep=","  # Comma-separated value
outfile="experiment_mapping_report.csv"

# Start the script
echo "Searching STAR logs in:" $mainpath

# -maxdepth 2 --> just 1 level below $mainpath
n=$(find "$mainpath" -maxdepth 2 -type f -iname "$logname" | wc -l)
if [[ $n -ge 1 ]]; then
    echo "$n files named $logname detected"

    # Prepare output matrix headings
    echo -e "sample_ID"$sep \
            "input_reads"$sep \
            "uniMap_reads"$sep \
            "%_uniMap"$sep \
            "multiMap_reads"$sep \
            "%_multiMap"$sep \
            "input_read_length"$sep \
            "mapped_read_length" > "${mainpath}/$outfile"
else
    echo "No files $logname have been detected"
    exit 1
fi

# Since the statement
#   for logpath in $(find $mainpath -iname $logname)
# fails for space-containing dir-names, we need some workaround...
#
# List $mainpath's subfolders (just 1st level)
subfolder=$(ls -F "$mainpath" | grep "/")
m=$(ls -F "$mainpath" | grep "/" | wc -l)

# Loop over them
counter=0 # Counts only log-containing directories
for ((i=1; i<=m; i++)); do

    # Cut $subfolder list wherever you find a slash and remove the possible
    # white space at the beginning using sed
    logpath=$(echo $subfolder | cut -f$i -d'/' | sed "s:^ ::")

    # Build the absolute path to log target files
    target="${mainpath}/${logpath}/${logname}"

    # If the $logpath actually contains a log file, then fetch mapping stats from it
    if [[ -f "$target" ]]; then
        counter=$((counter+1))
        echo "${counter}..Fetching mapping stats from $target"

        n_in=$(grep -i "number of input reads"                      "$target" | cut -f2)
        l_in=$(grep -i "average input read length"                  "$target" | cut -f2)
        n_map=$(grep -i "uniquely mapped reads number"              "$target" | cut -f2)
        p_map=$(grep -i "uniquely mapped reads %"                   "$target" | cut -f2 | sed "s/%//")
        l_map=$(grep -i "average mapped length"                     "$target" | cut -f2)
        n_mul=$(grep -i "number of reads mapped to multiple loci"   "$target" | cut -f2)
        p_mul=$(grep -i "% of reads mapped to multiple loci"        "$target" | cut -f2 | sed "s/%//")

        echo -e ${logpath}${sep} \
                ${n_in}${sep} \
                ${n_map}${sep} \
                ${p_map}${sep} \
                ${n_mul}${sep} \
                ${p_mul}${sep} \
                ${l_in}${sep} \
                ${l_map} >> "${mainpath}/$outfile"
    fi
done

if [[ $counter -ne $n ]]; then
    echo "WARNING! Report may be incomplete (n=$n but counter=${counter})"
    exit 2
fi
