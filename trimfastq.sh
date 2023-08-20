#!/bin/bash

# ============================================================================ #
#  Persistently Trim FastQ Files using BBDuk
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.1.0"
verbose=true
progress=false

# Print the help
function _help_trimfastq {
	echo
	echo "This is a wrapper of 'trimmer.sh' script, designed to schedules a"
	echo "persistent (by 'nohup') queue of FASTQ adapter-trimming processes."
	echo "Syntax and options are the same for both 'trimfastq.sh' and"
	echo "'trimmer.sh' (which is in turn a wrapper of BBDuk trimmer) the only"
	echo "difference being that 'trimfastq' is designed to always run"
	echo "persistently, in background, and more quietly than 'trimmer.sh'. In"
	echo "any case, trimfastq can even be made completely silent by adding a"
	echo "'-q | --quiet' flag."
	echo
	printf "Here it follows the 'trimmer.sh --help'."
	bash ./trimmer.sh --help
}

# --- Argument parsing ---------------------------------------------------------

# Argument check: override -h, -v, and -q option settings
for arg in "$@"; do
	if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
		_help_trimfastq
		exit 0 # Success exit status
	elif [[ "$arg" == "-v" || "$arg" == "--version" ]]; then
		figlet trim FASTQ
		printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
		exit 0 # Success exit status
	elif [[ "$arg" == "-q" || "$arg" == "--quiet" ]]; then
		verbose=false
	elif [[ "$arg" == "-p" || "$arg" == "--progress" ]]; then
		progress=true
	fi
done

# --- Main program -------------------------------------------------------------

# Get the last argument (i.e., FQPATH)
target_dir="${!#}"

# Hand down all the arguments
if $verbose; then
	echo -e "\nRunning: nohup bash ./trimmer.sh -q $@ &"
fi

# MAIN STATEMENT
nohup bash ./trimmer.sh -q $@ > "nohup.out" 2>&1 &

# Allow time for 'nohup.out' to be created
sleep 0.5
# When in '--quiet' mode, 'trimmer.sh' sends messages to the standard output
# (i.e., display on screen) only in the case of bad arguments, exceptions, or to
# show progress when run with -p option. For this reason, only when 'nohup.out'
# file is empty 'trimmer.sh' is actually going to trim something...
if [[ -s "nohup.out" ]]; then
	echo
	cat "nohup.out" # Retrieve error messages...
	rm "nohup.out"  # ...and clean
	exit 17
fi

rm "nohup.out"

# Print the head of the log file just created, as a preview of the scheduled job
if $verbose && (! $progress); then

	# Allow time for the new log to be created and found
	sleep 0.5
	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f \
		-iname "Trimmer_*.log" -printf "%T@ %p\n" \
		| sort -n | tail -n 1 | cut -d " " -f 2)

	printf "\nHead of ${latest_log}\n"
	head -n 8 "$latest_log"
	printf "Start trimming through BBDuk in background...\n"
fi
