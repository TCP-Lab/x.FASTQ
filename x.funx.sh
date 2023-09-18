#!/bin/bash

# ============================================================================ #
#  Collection of general utility variables and functions for x.FASTQ scripts
# ============================================================================ #

# --- Variable definition ------------------------------------------------------

# x.funx version
# This special name is not to overwrite scripts' own 'ver' when sourced.
xfunx_ver=1.0.1

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

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
# respectively the names or the corresponding Bash commands for the QC tools
# currently implemented.
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

# Convert the name of a QC tool to the corresponding Bash command to execute it.
function _name2cmd_qcfastq {
	
	# Name-command corresponding table
	tool_name=($(_get_qc_tools "names"))
	tool_cmd=($(_get_qc_tools "cmds"))

	#Looping through array indices
	index=-1
	for i in ${!tool_name[@]}; do
		if [[ "${tool_name[$i]}" == "$1" ]]; then
			index=$i
			break
		fi
	done

	# Return the result
	if [[ $index -ge 0 ]]; then
		echo ${tool_cmd[$index]}
	else
		echo "Element '$1' not found in the array!"
		exit 1
	fi
}
