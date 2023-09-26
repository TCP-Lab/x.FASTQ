#!/bin/bash

# ============================================================================ #
#  Collection of general utility variables and functions for x.FASTQ scripts
# ============================================================================ #

# --- Variable definition ------------------------------------------------------

# x.funx version
# This special name is not to overwrite scripts' own 'ver' when sourced...
# ...and at the same time being compliant with the 'x.fastq -r' option!
xfunx_ver="1.3.2"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# Get current date and time in "yyyy.mm.dd_HH.MM.SS" format
function _tstamp {
	now="$(date +"%Y.%m.%d_%H.%M.%S")"
	echo $now
}

# On-screen and to-file logging function
#
# 	USAGE:	_dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; additionally, redirect it to standard
# output (i.e., print on screen) if $verbose == true
# NOTE:	the 'sed' part allows tabulations to be stripped, while still allowing
# 		the code (i.e., multi-line messages) to be indented in a natural fashion.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

# Make the two alternatives explicit from an OR regex pattern.
function _explode_ORpattern {
	
	# Input pattern must be of this type: "leading_str(alt_1|alt_2)trailing_str"
	pattern="$1"

	# Alternative 1: remove from the beginning to (, and from | to the end
	alt_1="$(echo "$pattern" | sed -E "s/.*\(|\|.*//g")"
	# Alternative 2: remove from the beginning to |, and from ) to the end
	alt_2="$(echo "$pattern" | sed -E "s/.*\||\).*//g")"

	# Build the two suffixes
	suffix_1="$(echo "$pattern" | sed -E "s/\(.*\)/${alt_1}/g")"
	suffix_2="$(echo "$pattern" | sed -E "s/\(.*\)/${alt_2}/g")"

	# Return them through echo, separated by a comma
	echo "${suffix_1},${suffix_2}"
}

# Take one of the two arguments "names" or "cmds" and return an array containing
# either the names or the corresponding Bash commands for the QC tools
# currently implemented in 'qcfastq.sh'.
function _get_qc_tools {
	
	# Name-command corresponding table
	tool_name=("FastQC" "MultiQC" "QualiMap" "PCA")
	tool_cmd=("fastqc" "multiqc" "-NA-" "-NA-")

	if [[ "$1" == "names" ]]; then
		echo ${tool_name[@]}
	elif [[ "$1" == "cmds" ]]; then
		echo ${tool_cmd[@]}
	else
		echo "Not a feature!"
		exit 1
	fi
}

# Take one of the two arguments "names" or "cmds" and return an array containing
# either the names or the corresponding Bash commands for the RNA-Seq software
# required by x.FASTQ scripts.
function _get_seq_sw {
	
	# Name-command corresponding table
	seq_name=("BBDuk" "STAR" "RSEM")
	seq_cmd=("bbduk.sh" "STAR" "-NA-")

	if [[ "$1" == "names" ]]; then
		echo ${seq_name[@]}
	elif [[ "$1" == "cmds" ]]; then
		echo ${seq_cmd[@]}
	else
		echo "Not a feature!"
		exit 1
	fi
}

# Convert the name of a software to the corresponding Bash command suitable for
# execution.
function _name2cmd {

	# Concatenate arrays
	all_name=($(_get_qc_tools "names") $(_get_seq_sw "names") "Java" "Python" "R")
	all_cmd=($(_get_qc_tools "cmds") $(_get_seq_sw "cmds") "java" "python" "R")

	# Looping through array indices
	index=-1
	for i in ${!all_name[@]}; do
		if [[ "${all_name[$i]}" == "$1" ]]; then
			index=$i
			break
		fi
	done

	# Return the result
	if [[ $index -ge 0 ]]; then
		echo ${all_cmd[$index]}
	else
		echo "Element '$1' not found in the array!"
		exit 1
	fi
}

# It's the final countdown
function _count_down {
	echo
	n=$1
	for (( i = 0; i < n; i++ )); do
		printf "    "
		printf %$((i+1))s | tr " " "."
		printf $((n-i))
		printf "\r"
		sleep 1
	done
	printf "    "
	printf "B"
	printf %$((n-1))s | tr " " "o"
	printf "M! \r"
	sleep 1
}

# Get an estimate (based on the first 100 reads) of the average length of the
# reads within the FASTQ file passed as the only input.
function _mean_read_length {

	tot=0
	for (( i = 1; i <= 100; i++ )); do
		line=$(( 4*i - 2)) # Select the FASTQ lines that contains the reads
		r_length=$(zcat "$1" | head -n 400 | sed -n "${line}p" | wc -c)
		tot=$(( tot + r_length - 1 )) # -1 because of the 'new line' from sed
	done

	# Ceiling: check if there should be a fractional part
	if [[ $tot =~ 00$ ]]; then
	    ceiling_val=$(( tot/100 ))
	else
	    ceiling_val=$(( tot/100 + 1 ))
	fi

	echo $ceiling_val
}
