#!/bin/bash

# ==============================================
#  Get FastQ Files from ENA database
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

# Default options
verbose=true

# Print the help
function _help_getfastq {
	echo
	echo "Based on target addresses provided in the input file, this script"
	echo "schedules a persistent queue of FASTQ downloads from ENA database"
	echo "using HTTP."
	echo
	echo "Usage: $0 [-h | --help]"
	echo "       $0 [-s | --silent] TARGETS"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "    -s | --silent   disable verbose on-screen logging"
	echo "    TARGETS         text file with the list of the wgets to schedule"
	echo
}

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9]+$"

# Argument check
if [[ "$1" =~ $frp ]]; then
    case "$1" in
    	-h | --help)
			_help_getfastq
			exit 0 # Success exit status
        ;;
        -s | --silent)
        	verbose=false
        	shift
        ;;
        * )
			printf "Unrecognized flag '$1'.\n"
			printf "Use '--help' or '-h' to see the possible options.\n"
			exit 1 # Argument failure exit status
        ;;
    esac
elif [[ -z "$1" ]]; then
	printf "Missing TARGET file.\n"
	printf "Use '--help' or '-h' to see possible options.\n"
	exit 1 # Argument failure exit status
fi

# Program starts here
if $verbose; then
	echo
	echo "============="
	echo "| Job Queue |"
	echo "============="
	echo
fi

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

	# Verbose on-screen logging
	if $verbose; then
		echo
		echo "Downloading: $fastq_name"
		echo "From       : $fastq_address"
	fi

done < "$1"
