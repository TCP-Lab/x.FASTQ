#!/bin/bash

# ==============================================
#  Get FastQ Files from ENA Browser
# ==============================================

# NOTE:
#	- The script assumes all the target address are in the input file
# 	- the script reads line by line
# 	- because of limitations on FTP, target address are converted to HTTP,
# 		taking advantage of the intrinsic versatility of ENA browser
#	- the for loop instantiates all downloads in parallel
#	- use, e.g., `tail -n 3 *.log` to see their progress
#	- use, e.g., `pgrep -l -u fear` to get the IDs of the active wget processes
#
# ISSUES:
#	1. write the help option
#	2. the verbose on screen log assumes that the two wget options -nc are always present... it could be more general
#

while IFS= read -r line
do
	# Using Bash-native string substitution syntax to change FTP into HTTP
	# ${string/$substring/$replacement}
	# NOTE: while `$substring` and `$replacement` are literal strings
	# 		the starting `string` MUST be a reference to a variable name!
	target=${line/ftp:/http:}

	fastq_name="$(basename "$target")"
	fastq_address="$(dirname ${target/wget* /})"

	# `nohup` (no hangups) allows keeping processes running even after exiting
	# the shell (`2>&1` is used to redirect both the standard output and the
	# standard error to the FASTQ-specific log file).
	nohup $target > ${fastq_name}.log 2>&1 &

	# Toggle verbose on-screen logging
	if true; then
		echo
		echo "Downloading: $fastq_name"
		echo "From       : $fastq_address"
	fi
	
done < "$1"
