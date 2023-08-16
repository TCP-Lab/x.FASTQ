#!/bin/bash

# ============================================================================ #
#  Get FastQ Files from ENA Database
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Minimal implementation ---------------------------------------------------

# Change false to true to toggle the 'minimal implementation' of the script
if false; then
	printf "\n===\\\ Running minimal implementation \\\===\n"
	target_dir="$(dirname "$1")"
	sed "s|ftp:|-P $target_dir http:|g" "$1" | nohup bash \
		> "${target_dir}"/getFASTQ_"${now}".log 2>&1 &
	exit 0
fi

# --- Function definition ------------------------------------------------------

# Default options
ver="1.0.1"
verbose=true
sequential=true

# Print the help
function _help_getfastq {
	echo
	echo "This script schedules a persistent (i.e., 'nohup') queue of FASTQ"
	echo "downloads from ENA database via HTTP, based on the target addresses"
	echo "provided as input. Target addresses need to be converted to HTTP"
	echo "because of the limitations on FTP imposed by UniTo. Fortunately,"
	echo "this can be done simply replacing 'ftp' with 'http' in each address"
	echo "to wget, thanks to the great versatility of ENA Browser."
	echo
	echo "Usage:"
	echo "    getfastq [-h | --help] [-v | --version]"
	echo "    getfastq -p | --progress [TARGETS]"
	echo "    getfastq -k | --kill"
	echo "    getfastq [-q | --quiet] [-m | --multi] TARGETS"
	echo
	echo "Positional options:"
	echo "    -h | --help     Show this help."
	echo "    -v | --version  Show script's version."
	echo "    -p | --progress Show TARGETS downloading progress. If TARGETS is"
	echo "                    not specified, search \$PWD for wget processes."
	echo "    -k | --kill     Kill all the 'wget' processes currently running"
	echo "                    and started by the current user (i.e., \$USER)."
	echo "    -q | --quiet    Disable verbose on-screen logging."
	echo "    -m | --multi    Multi process option. A separate download process"
	echo "                    is instantiated in background for each target"
	echo "                    FASTQ file at once, resulting in a parallel"
	echo "                    download of all the TARGETS files. While the"
	echo "                    default behavior is sequential download of the"
	echo "                    individual FASTQs, '-m' option can be useful in"
	echo "                    case of broadband Internet connections."
	echo "    TARGETS         Path to the text file containing the 'wgets' to"
	echo "                    be scheduled."
	echo
	echo "Additional Notes:"
	echo "    You can use 'pgrep -l -u \"\$USER\"' to get the IDs of the active"
	echo "    'wget' processes, and possibly kill'em all or selectively."
}

# Show download progress
function _progress_getfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	elif [[ -f "$1" ]]; then
		target_dir="$(dirname "$1")"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	# `compgen` is the only reliable way in Bash to test if there are files
	# matching a pattern (i.e., test whether a glob has any matches).
	if compgen -G "${target_dir}"/*.log > /dev/null; then
		printf "\n${grn}Completed:${end}\n"
		grep --no-filename "saved" "${target_dir}"/*.log || [[ $? == 1 ]]
		
		printf "\n${red}Tails:${end}\n"
		tail -n 3 "${target_dir}"/*.log
		printf "\n"
		exit $? # pipe tail's exit status
	else
		printf "No log file found in '$(realpath $target_dir)'.\n"
		exit 5 # Argument failure exit status: missing log
	fi
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
	    case "$1" in
	    	-h | --help)
				_help_getfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet get FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
		    -p | --progress)
		    	# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_getfastq "${2:-.}"
			;;
			-k | --kill)
				while [[ $? -eq 0 ]]; do
					pkill -eu $USER wget
				done
			;;
	        -q | --quiet)
	        	verbose=false
	        	shift
	        ;;
	        -m | --multi)
	        	sequential=false
	        	shift
	        ;;
	        * )
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 2 # Argument failure exit status: bad flag
	        ;;
	    esac
	else
		# The first non-FRP sequence is taken as the TARGETS argument
		target_file="$1"
		break
	fi
done

# Argument check: target file
if [[ -z "${target_file:-""}" ]]; then
	printf "Missing option or TARGETS file.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 3 # Argument failure exit status: missing TARGETS
elif [[ ! -f "$target_file" ]]; then
	printf "Invalid target file '$target_file'.\n"
	exit 4 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

target_dir="$(dirname "$(realpath "$target_file")")"

# Verbose on-screen logging
if $verbose; then
	echo
	echo "========================"
	if $sequential; then
		echo "| Sequential Job Queue |"
	else
		echo "|  Parallel Job Queue  |"
	fi
	echo "========================"

	counter=1
	while IFS= read -r line
	do
		# Using Bash-native string substitution syntax to change FTP into HTTP
		# ${string/$substring/$replacement}
		# NOTE: while `$substring` and `$replacement` are literal strings
		# 		the starting `string` MUST be a reference to a variable name!
		fastq_name="$(basename "$line")"
		fastq_address="$(dirname ${line/wget* ftp:/http:})"

		echo
		echo "[${counter}]"
		echo "Downloading: $fastq_name"
		echo "From       : $fastq_address"

		((counter++))

	done < "$target_file"
fi

# Make a temporary copy of TARGETS file, where FTP is replaced by HTTP and the
# wget's -P option is added to specify the target directory
sed "s|ftp:|-P $target_dir http:|g" "$target_file" > "${target_file}.tmp"

# In the code block below:
#
# 	`nohup` (no hangups) allows processes to keep running even upon user logout
# 		(e.g., when exiting an SSH session)
# 	`>` allows output to be redirected somewhere other than the default
# 		./nohup.out file
# 	`2>&1` is to redirect both standard output and standard error to the
# 		getFASTQ log file
# 	`&&` is to execute the next command only after the first one is terminated
# 		with exit status == 0 
# 	`&` at the end of the line, is, as usual, to run the command in the
# 		background and get the shell prompt active again
#
if $sequential; then
	nohup bash "${target_file}.tmp" \
		> "${target_dir}"/getFASTQ_"${now}".log 2>&1 \
		&& rm "${target_file}.tmp" &
else
	while IFS= read -r line
	do
		fastq_name="$(basename "$line")"
		nohup $line > "${target_dir}"/"${fastq_name}"_"${now}".log 2>&1 &

	done < "${target_file}.tmp"

	# Remove the temporary copy of TARGETS file
	rm "${target_file}.tmp"
fi
